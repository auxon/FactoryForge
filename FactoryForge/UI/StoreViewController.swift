import UIKit
import SwiftUI
import StoreKit

/// SwiftUI view that uses Apple's recommended StoreView
@available(iOS 17.0, *)
struct StoreViewRepresentable: View {
    let productIds: [String]
    let onPurchaseCompleted: () -> Void

    var body: some View {
        StoreView(ids: productIds) { product in
            ProductView(id: product.id) {
                VStack {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if !product.description.isEmpty {
                        Text(product.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .productViewStyle(.compact)
            .onInAppPurchaseCompletion { product, result in
                switch result {
                case .success(let purchaseResult):
                    switch purchaseResult {
                    case .success:
                        // Purchase completed successfully - deliver items
                        handlePurchaseSuccess(for: product.id)
                        onPurchaseCompleted()
                    case .userCancelled:
                        // User cancelled the purchase
                        print("Purchase cancelled by user")
                    @unknown default:
                        // Handle future cases
                        print("Unknown purchase result: \(purchaseResult)")
                    }
                case .failure(let error):
                    // Purchase failed
                    print("Purchase failed: \(error)")
                @unknown default:
                    // Handle any future Result cases
                    print("Unknown result: \(result)")
                }
            }
        }
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.hidden, for: .cancellation)
        .tint(.blue)
    }

    private func handlePurchaseSuccess(for productId: String) {
        // Extract item information from product ID and deliver to inventory
        if let itemInfo = IAPManager.shared.parseProductId(productId) {
            IAPManager.shared.deliverPurchaseToInventory(itemId: itemInfo.itemId, quantity: itemInfo.quantity)
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

        let storeView = StoreViewRepresentable(
            productIds: productIds,
            onPurchaseCompleted: onPurchaseCompleted
        )

        super.init(rootView: storeView)

        // Configure the hosting controller
        self.view.backgroundColor = .systemBackground
        self.modalPresentationStyle = .fullScreen
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
