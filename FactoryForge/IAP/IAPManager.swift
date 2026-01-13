import Foundation
import StoreKit

/// Manager for handling In-App Purchases using StoreKit
final class IAPManager: NSObject, ObservableObject {
    static let shared = IAPManager()

    // MARK: - Properties

    @Published var products: [Product] = []
    @Published var isLoadingProducts = false
    @Published var isProcessingPurchase = false

    // Public access to product IDs for StoreView
    var productIds: [String] {
        Array(productIdsSet)
    }

    private var productIdsSet: Set<String> = []
    private var updateListenerTask: Task<Void, Error>?

    /// Callback for delivering purchased items to inventory
    var onPurchaseDelivered: ((String, Int) -> Void)?

    /// Callback for handling upgrade purchases
    var onUpgradePurchased: ((String) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        setupProductIds()
        startObservingTransactionUpdates()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Management

    private func setupProductIds() {
        // Raw materials
        productIdsSet.insert("com.factoryforge.items.iron_ore_pack")
        productIdsSet.insert("com.factoryforge.items.copper_ore_pack")
        productIdsSet.insert("com.factoryforge.items.coal_pack")
        productIdsSet.insert("com.factoryforge.items.stone_pack")
        productIdsSet.insert("com.factoryforge.items.wood_pack")
        productIdsSet.insert("com.factoryforge.items.crude_oil_pack")

        // Processed materials
        productIdsSet.insert("com.factoryforge.items.iron_plate_pack")
        productIdsSet.insert("com.factoryforge.items.copper_plate_pack")
        productIdsSet.insert("com.factoryforge.items.steel_plate_pack")
        productIdsSet.insert("com.factoryforge.items.stone_brick_pack")

        // Components
        productIdsSet.insert("com.factoryforge.items.iron_gear_wheel_pack")
        productIdsSet.insert("com.factoryforge.items.copper_cable_pack")
        productIdsSet.insert("com.factoryforge.items.pipe_pack")
        productIdsSet.insert("com.factoryforge.items.electronic_circuit_pack")
        productIdsSet.insert("com.factoryforge.items.advanced_circuit_pack")

        // Science packs
        productIdsSet.insert("com.factoryforge.items.automation_science_pack")
        productIdsSet.insert("com.factoryforge.items.logistic_science_pack")
        productIdsSet.insert("com.factoryforge.items.chemical_science_pack")
        productIdsSet.insert("com.factoryforge.items.production_science_pack")
        productIdsSet.insert("com.factoryforge.items.utility_science_pack")

        // Basic logistics
        productIdsSet.insert("com.factoryforge.items.transport_belt_pack")
        productIdsSet.insert("com.factoryforge.items.inserter")

        // Production items
        productIdsSet.insert("com.factoryforge.items.burner_mining_drill")
        productIdsSet.insert("com.factoryforge.items.stone_furnace")
        productIdsSet.insert("com.factoryforge.items.wooden_chest")
        productIdsSet.insert("com.factoryforge.items.small_electric_pole")
        productIdsSet.insert("com.factoryforge.items.radar")
        productIdsSet.insert("com.factoryforge.items.electric_mining_drill")
        productIdsSet.insert("com.factoryforge.items.assembling_machine_1")
        productIdsSet.insert("com.factoryforge.items.assembling_machine_2")
        productIdsSet.insert("com.factoryforge.items.assembling_machine_3")
        productIdsSet.insert("com.factoryforge.items.lab")
        productIdsSet.insert("com.factoryforge.items.steel_furnace")
        productIdsSet.insert("com.factoryforge.items.electric_furnace")
        productIdsSet.insert("com.factoryforge.items.solar_panel")
        productIdsSet.insert("com.factoryforge.items.accumulator")
        productIdsSet.insert("com.factoryforge.items.boiler")
        productIdsSet.insert("com.factoryforge.items.steam_engine")

        // Logistics items
        productIdsSet.insert("com.factoryforge.items.express_transport_belt")
        productIdsSet.insert("com.factoryforge.items.fast_transport_belt")
        productIdsSet.insert("com.factoryforge.items.underground_belt")
        productIdsSet.insert("com.factoryforge.items.splitter")
        productIdsSet.insert("com.factoryforge.items.merger")
        productIdsSet.insert("com.factoryforge.items.fast_inserter")
        productIdsSet.insert("com.factoryforge.items.long_handed_inserter")
        productIdsSet.insert("com.factoryforge.items.steel_chest")
        productIdsSet.insert("com.factoryforge.items.iron_chest")

        // Power infrastructure
        productIdsSet.insert("com.factoryforge.items.medium_electric_pole")
        productIdsSet.insert("com.factoryforge.items.big_electric_pole")

        // Oil processing
        productIdsSet.insert("com.factoryforge.items.oil_well")
        productIdsSet.insert("com.factoryforge.items.oil_refinery")
        productIdsSet.insert("com.factoryforge.items.chemical_plant")

        // Combat items
        productIdsSet.insert("com.factoryforge.items.gun_turret")
        productIdsSet.insert("com.factoryforge.items.laser_turret")
        productIdsSet.insert("com.factoryforge.items.wall")
        productIdsSet.insert("com.factoryforge.items.firearm_magazine_pack")

        // Upgrades
        productIdsSet.insert("com.factoryforge.upgrade.inventory_expansion")
    }

    /// Load products from the App Store
    func loadProducts() async throws {
        guard !productIdsSet.isEmpty else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        print("🛒 IAPManager: Loading \(productIdsSet.count) products from App Store...")
        for productId in productIdsSet {
            print("📦 IAPManager: Product ID: \(productId)")
        }

        do {
            products = try await Product.products(for: productIdsSet)
                .sorted { $0.displayPrice < $1.displayPrice }
            print("✅ IAPManager: Successfully loaded \(products.count) products")
            for product in products {
                print("📦 IAPManager: Loaded product: \(product.id) - \(product.displayName)")
            }
        } catch {
            print("❌ IAPManager: Failed to load products: \(error)")
            throw error
        }
    }

    /// Get product by ID
    func getProduct(for productId: String) -> Product? {
        return products.first { $0.id == productId }
    }


    // MARK: - Purchase Handling

    /// Purchase a product
    func purchase(_ product: Product) async throws -> Transaction? {
        isProcessingPurchase = true
        defer { isProcessingPurchase = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return transaction
        case .userCancelled:
            return nil
        case .pending:
            // Transaction is pending (e.g., waiting for parental approval)
            return nil
        @unknown default:
            return nil
        }
    }

    /// Restore completed transactions
    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    /// Deliver purchased items directly to inventory (used by StoreView)
    func deliverPurchaseToInventory(itemId: String, quantity: Int) {
        onPurchaseDelivered?(itemId, quantity)
    }

    // MARK: - Transaction Updates

    private func startObservingTransactionUpdates() {
        updateListenerTask = listenForTransactions()
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Handle the transaction (e.g., deliver content)
                    await self.handleTransaction(transaction)

                    // Always finish the transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    private func handleTransaction(_ transaction: Transaction) async {
        let productId = transaction.productID

        // Handle upgrade purchases regardless of how they were initiated
        if self.isUpgradeProduct(productId) {
            await self.deliverUpgrade(productId: productId)
            return
        }

        // Only deliver items for purchases NOT initiated through StoreView
        // StoreView handles its own purchases to prevent double delivery
        guard !productIdsSet.contains(productId) else {
            return
        }

        // External item purchases (not through our store)
        if let itemInfo = self.parseProductId(productId) {
            await self.deliverPurchase(itemId: itemInfo.itemId, quantity: itemInfo.quantity * transaction.purchasedQuantity)
        }
    }

    func isUpgradeProduct(_ productId: String) -> Bool {
        return productId.hasPrefix("com.factoryforge.upgrade.")
    }

    func parseProductId(_ productId: String) -> (itemId: String, quantity: Int)? {
        let components = productId.components(separatedBy: ".")

        guard components.count >= 3,
              let lastComponent = components.last else {
            return nil
        }

        // Map product IDs to item IDs and quantities
        switch lastComponent {
        // Raw materials
        case "iron_ore_pack": return ("iron-ore", 100)
        case "copper_ore_pack": return ("copper-ore", 100)
        case "coal_pack": return ("coal", 100)
        case "stone_pack": return ("stone", 100)
        case "wood_pack": return ("wood", 100)
        case "crude_oil_pack": return ("crude-oil", 1000)

        // Processed materials
        case "iron_plate_pack": return ("iron-plate", 100)
        case "copper_plate_pack": return ("copper-plate", 100)
        case "steel_plate_pack": return ("steel-plate", 50)
        case "stone_brick_pack": return ("stone-brick", 100)

        // Components
        case "iron_gear_wheel_pack": return ("iron-gear-wheel", 50)
        case "copper_cable_pack": return ("copper-cable", 100)
        case "pipe_pack": return ("pipe", 50)
        case "electronic_circuit_pack": return ("electronic-circuit", 50)
        case "advanced_circuit_pack": return ("advanced-circuit", 25)

        // Science packs
        case "automation_science_pack": return ("automation-science-pack", 10)
        case "logistic_science_pack": return ("logistic-science-pack", 10)
        case "chemical_science_pack": return ("chemical-science-pack", 10)
        case "production_science_pack": return ("production-science-pack", 10)
        case "utility_science_pack": return ("utility-science-pack", 10)

        // Basic logistics
        case "transport_belt_pack": return ("transport-belt", 50)
        case "inserter": return ("inserter", 1)

        // Basic buildings
        case "burner_mining_drill": return ("burner-mining-drill", 1)
        case "stone_furnace": return ("stone-furnace", 1)
        case "wooden_chest": return ("wooden-chest", 1)
        case "small_electric_pole": return ("small-electric-pole", 1)
        case "radar": return ("radar", 1)

        // Production items
        case "electric_mining_drill": return ("electric-mining-drill", 1)
        case "assembling_machine_1": return ("assembling-machine-1", 1)
        case "assembling_machine_2": return ("assembling-machine-2", 1)
        case "assembling_machine_3": return ("assembling-machine-3", 1)
        case "lab": return ("lab", 1)
        case "steel_furnace": return ("steel-furnace", 1)
        case "electric_furnace": return ("electric-furnace", 1)
        case "solar_panel": return ("solar-panel", 1)
        case "accumulator": return ("accumulator", 1)
        case "boiler": return ("boiler", 1)
        case "steam_engine": return ("steam-engine", 1)

        // Logistics items
        case "express_transport_belt": return ("express-transport-belt", 1)
        case "fast_transport_belt": return ("fast-transport-belt", 1)
        case "underground_belt": return ("underground-belt", 1)
        case "splitter": return ("splitter", 1)
        case "merger": return ("merger", 1)
        case "fast_inserter": return ("fast-inserter", 1)
        case "long_handed_inserter": return ("long-handed-inserter", 1)
        case "steel_chest": return ("steel-chest", 1)
        case "iron_chest": return ("iron-chest", 1)

        // Power infrastructure
        case "medium_electric_pole": return ("medium-electric-pole", 1)
        case "big_electric_pole": return ("big-electric-pole", 1)

        // Oil processing
        case "oil_well": return ("pumpjack", 1)
        case "oil_refinery": return ("oil-refinery", 1)
        case "chemical_plant": return ("chemical-plant", 1)

        // Combat items
        case "gun_turret": return ("gun-turret", 1)
        case "laser_turret": return ("laser-turret", 1)
        case "wall": return ("wall", 10)
        case "firearm_magazine_pack": return ("firearm-magazine", 100)

        default: return nil
        }
    }

    private func deliverPurchase(itemId: String, quantity: Int) async {
        // Capture the callback to avoid Sendable issues
        let callback = self.onPurchaseDelivered

        // Add items to player's inventory via callback
        DispatchQueue.main.async {
            callback?(itemId, quantity)

            // Show notification to player
            NotificationCenter.default.post(
                name: .purchaseDelivered,
                object: nil,
                userInfo: ["itemId": itemId, "quantity": quantity]
            )
        }
    }

    func deliverUpgrade(productId: String) async {
        // Handle upgrade deliveries
        let upgradeType = productId.components(separatedBy: ".").last ?? ""
        print("⬆️ IAPManager: Delivering upgrade type: \(upgradeType)")

        // Capture the callback to avoid Sendable issues
        let callback = self.onUpgradePurchased

        // Deliver upgrade via callback
        DispatchQueue.main.async {
            print("📞 IAPManager: Calling upgrade callback with type: \(upgradeType)")
            callback?(upgradeType)

            // Show notification to player
            NotificationCenter.default.post(
                name: .upgradePurchased,
                object: nil,
                userInfo: ["upgradeType": upgradeType]
            )
            print("🔔 IAPManager: Posted upgrade notification")
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let verificationError):
            throw verificationError
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let purchaseDelivered = Notification.Name("purchaseDelivered")
    static let upgradePurchased = Notification.Name("upgradePurchased")
    static let inventoryExpanded = Notification.Name("inventoryExpanded")
}
