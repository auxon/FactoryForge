import UIKit
import SwiftUI
import StoreKit

/// SwiftUI view that uses Apple's recommended StoreView
@available(iOS 17.0, *)
struct StoreViewRepresentable: View {
    let productIds: [String]
    let onPurchaseCompleted: () -> Void
    let onClose: () -> Void

    init(productIds: [String], onPurchaseCompleted: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.productIds = productIds
        self.onPurchaseCompleted = onPurchaseCompleted
        self.onClose = onClose
        print("🛍️ StoreView: Initialized with \(productIds.count) product IDs:")
        for id in productIds {
            print("📦 StoreView: - \(id)")
        }
    }
    
    var body: some View {
        ZStack {
            StoreView(ids: productIds)
                .productViewStyle(.large)
                .imageScale(.large)
                .storeButton(.visible, for: .restorePurchases)
                .storeButton(.hidden, for: .cancellation)
                .tint(.blue)
                .onInAppPurchaseCompletion { product, result in
                    print("🛍️ StoreView: Purchase completion called for product: \(product.id)")
                    switch result {
                    case .success(let purchaseResult):
                        print("✅ StoreView: Purchase result: \(purchaseResult)")
                        switch purchaseResult {
                        case .success:
                            print("✅ StoreView: Purchase successful for: \(product.id)")
                            // Handle both item purchases and upgrade purchases
                            Task {
                                await handlePurchaseSuccess(for: product.id)
                                onPurchaseCompleted()
                                // Clean up callback after successful purchase
                                IAPManager.shared.onPurchaseDelivered = nil
                            }
                        case .userCancelled:
                            // User cancelled the purchase - do NOT deliver items
                            print("❌ StoreView: Purchase cancelled by user for product: \(product.id)")
                        case .pending:
                            // Transaction is pending - do NOT deliver items yet
                            print("⏳ StoreView: Purchase pending for product: \(product.id)")
                        @unknown default:
                            // Handle future cases - do NOT deliver items
                            print("❓ StoreView: Unknown purchase result: \(purchaseResult)")
                        }
                    case .failure(let error):
                        // Purchase failed - do NOT deliver items
                        print("❌ StoreView: Purchase failed for product \(product.id): \(error)")
                    @unknown default:
                        // Handle any future Result cases - do NOT deliver items
                        print("❓ StoreView: Unknown result for product \(product.id): \(result)")
                    }
                }
            
            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(SwiftUI.Color.black)
                                .opacity(0.7)
                                .frame(width: 40, height: 40)
                            Text("✕")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(SwiftUI.Color.white)
                        }
                    }
                    .padding(.top, 50)
                    .padding(.trailing, 20)
                }

                // Debug button for testing inventory expansion
                #if DEBUG
                HStack {
                    Button(action: {
                        print("🐛 Debug button pressed - testing inventory expansion")
                        // Find the UISystem instance and call debug method
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController as? GameViewController,
                           let uiSystem = rootVC.uiSystem {
                            uiSystem.debugExpandInventory()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(SwiftUI.Color.blue)
                                .frame(width: 200, height: 44)
                            Text("🧪 Test Inventory +8")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(SwiftUI.Color.white)
                        }
                    }
                    .padding(.bottom, 50)
                }
                #endif

                Spacer()
            }
        }
    }
    
    private func handlePurchaseSuccess(for productId: String) async {
        print("🛍️ StoreView: handlePurchaseSuccess called for: \(productId)")

        // Extract item information from product ID and deliver to inventory
        if let itemInfo = IAPManager.shared.parseProductId(productId) {
            print("📦 StoreView: Delivering item: \(itemInfo.itemId) x\(itemInfo.quantity)")
            IAPManager.shared.deliverPurchaseToInventory(itemId: itemInfo.itemId, quantity: itemInfo.quantity)
            // Autosave is handled by the IAPManager callback set up in UISystem
        } else if IAPManager.shared.isUpgradeProduct(productId) {
            print("⬆️ StoreView: Detected upgrade product: \(productId)")
            // For upgrades, deliver directly since StoreView handles the transaction
            await IAPManager.shared.deliverUpgrade(productId: productId)
        } else {
            print("❓ StoreView: Unknown product type for: \(productId)")
        }
    }
}

/// UIKit view controller that hosts the StoreView
@available(iOS 17.0, *)
class StoreViewController: UIHostingController<StoreViewRepresentable> {
    private let productIds: [String]
    private let onPurchaseCompleted: () -> Void

    init(productIds: [String], onPurchaseCompleted: @escaping () -> Void) {
        self.productIds = productIds
        self.onPurchaseCompleted = onPurchaseCompleted

        // Create initial view without self-capturing closure
        let storeView = StoreViewRepresentable(
            productIds: productIds,
            onPurchaseCompleted: onPurchaseCompleted,
            onClose: {}  // Empty closure initially
        )

        super.init(rootView: storeView)

        // Configure the hosting controller
        self.view.backgroundColor = UIKit.UIColor.systemBackground
        self.modalPresentationStyle = .fullScreen

        // Now update the rootView with the proper closure
        self.rootView = StoreViewRepresentable(
            productIds: productIds,
            onPurchaseCompleted: onPurchaseCompleted,
            onClose: { [weak self] in
                self?.dismiss(animated: true) {
                    // Clean up IAPManager callback when dismissed
                    IAPManager.shared.onPurchaseDelivered = nil
                }
            }
        )
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
