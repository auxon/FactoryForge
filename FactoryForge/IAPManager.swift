import Foundation
import StoreKit

/// Manager for handling In-App Purchases using StoreKit
final class IAPManager: NSObject, ObservableObject {
    static let shared = IAPManager()

    // MARK: - Properties

    @Published var products: [Product] = []
    @Published var isLoadingProducts = false
    @Published var isProcessingPurchase = false

    private var productIds: Set<String> = []
    private var updateListenerTask: Task<Void, Error>?

    /// Callback for delivering purchased items to inventory
    var onPurchaseDelivered: ((String, Int) -> Void)?

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
        productIds.insert("com.factoryforge.items.iron_ore_pack")
        productIds.insert("com.factoryforge.items.copper_ore_pack")
        productIds.insert("com.factoryforge.items.coal_pack")
        productIds.insert("com.factoryforge.items.stone_pack")
        productIds.insert("com.factoryforge.items.wood_pack")
        productIds.insert("com.factoryforge.items.crude_oil_pack")

        // Science packs
        productIds.insert("com.factoryforge.items.automation_science_pack")
        productIds.insert("com.factoryforge.items.logistic_science_pack")
        productIds.insert("com.factoryforge.items.chemical_science_pack")
        productIds.insert("com.factoryforge.items.production_science_pack")
        productIds.insert("com.factoryforge.items.utility_science_pack")

        // Production items
        productIds.insert("com.factoryforge.items.electric_mining_drill")
        productIds.insert("com.factoryforge.items.assembling_machine_1")
        productIds.insert("com.factoryforge.items.lab")
        productIds.insert("com.factoryforge.items.solar_panel")
        productIds.insert("com.factoryforge.items.accumulator")

        // Logistics items
        productIds.insert("com.factoryforge.items.express_transport_belt")
        productIds.insert("com.factoryforge.items.fast_inserter")
        productIds.insert("com.factoryforge.items.steel_chest")

        // Combat items
        productIds.insert("com.factoryforge.items.gun_turret")
        productIds.insert("com.factoryforge.items.wall")
        productIds.insert("com.factoryforge.items.firearm_magazine_pack")
    }

    /// Load products from the App Store
    func loadProducts() async throws {
        guard !productIds.isEmpty else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: productIds)
                .sorted { $0.displayPrice < $1.displayPrice }
        } catch {
            print("Failed to load products: \(error)")
            throw error
        }
    }

    /// Get product by ID
    func getProduct(for productId: String) -> Product? {
        return products.first { $0.id == productId }
    }

    /// Get products by category
    func getProducts(in category: IAPCategory) -> [Product] {
        return products.filter { product in
            switch category {
            case .rawMaterials:
                return product.id.contains("ore_pack") || product.id.contains("coal_pack") ||
                       product.id.contains("stone_pack") || product.id.contains("wood_pack") ||
                       product.id.contains("crude_oil_pack")
            case .sciencePacks:
                return product.id.contains("science_pack")
            case .production:
                return product.id.contains("mining_drill") || product.id.contains("assembling_machine") ||
                       product.id.contains("lab") || product.id.contains("solar_panel") ||
                       product.id.contains("accumulator")
            case .logistics:
                return product.id.contains("transport_belt") || product.id.contains("inserter") ||
                       product.id.contains("chest")
            case .combat:
                return product.id.contains("turret") || product.id.contains("wall") ||
                       product.id.contains("magazine_pack")
            }
        }
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
        // Deliver content based on the purchased product
        let productId = transaction.productID
        let quantity = transaction.quantity

        // Extract item information from product ID
        if let itemInfo = self.parseProductId(productId) {
            await self.deliverPurchase(itemId: itemInfo.itemId, quantity: itemInfo.quantity * quantity)
        }
    }

    private func parseProductId(_ productId: String) -> (itemId: String, quantity: Int)? {
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

        // Science packs
        case "automation_science_pack": return ("automation-science-pack", 10)
        case "logistic_science_pack": return ("logistic-science-pack", 10)
        case "chemical_science_pack": return ("chemical-science-pack", 10)
        case "production_science_pack": return ("production-science-pack", 10)
        case "utility_science_pack": return ("utility-science-pack", 10)

        // Production items
        case "electric_mining_drill": return ("electric-mining-drill", 1)
        case "assembling_machine_1": return ("assembling-machine-1", 1)
        case "lab": return ("lab", 1)
        case "solar_panel": return ("solar-panel", 1)
        case "accumulator": return ("accumulator", 1)

        // Logistics items
        case "express_transport_belt": return ("express-transport-belt", 1)
        case "fast_inserter": return ("fast-inserter", 1)
        case "steel_chest": return ("steel-chest", 1)

        // Combat items
        case "gun_turret": return ("gun-turret", 1)
        case "wall": return ("wall", 10)
        case "firearm_magazine_pack": return ("firearm-magazine", 100)

        default: return nil
        }
    }

    private func deliverPurchase(itemId: String, quantity: Int) async {
        // Add items to player's inventory via callback
        DispatchQueue.main.async {
            self.onPurchaseDelivered?(itemId, quantity)

            // Show notification to player
            NotificationCenter.default.post(
                name: .purchaseDelivered,
                object: nil,
                userInfo: ["itemId": itemId, "quantity": quantity]
            )
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
}

enum IAPCategory {
    case rawMaterials
    case sciencePacks
    case production
    case logistics
    case combat
}

extension IAPCategory {
    var displayName: String {
        switch self {
        case .rawMaterials: return "Raw Materials"
        case .sciencePacks: return "Science Packs"
        case .production: return "Production"
        case .logistics: return "Logistics"
        case .combat: return "Combat"
        }
    }
}
