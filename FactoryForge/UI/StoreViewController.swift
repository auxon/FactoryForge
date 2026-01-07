import UIKit
import SwiftUI
import StoreKit

/// SwiftUI view that uses Apple's recommended StoreView
@available(iOS 17.0, *)
struct StoreViewRepresentable: View {
    let productIds: [String]
    let onPurchaseCompleted: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            StoreView(ids: productIds)
                .productViewStyle(.large)
                .imageScale(.large)
                .storeButton(.visible, for: .restorePurchases)
                .storeButton(.hidden, for: .cancellation)
                .tint(.blue)
                .onInAppPurchaseCompletion { product, result in
                    switch result {
                    case .success(let purchaseResult):
                        switch purchaseResult {
                        case .success:
                            // Purchase completed successfully - deliver items
                            handlePurchaseSuccess(for: product.id)
                            onPurchaseCompleted()
                            // Clean up callback after successful purchase
                            IAPManager.shared.onPurchaseDelivered = nil
                        case .userCancelled:
                            // User cancelled the purchase
                            print("Purchase cancelled by user")
                        case .pending:
                            // Transaction is pending (e.g., waiting for parental approval)
                            print("Purchase pending")
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
                Spacer()
            }
        }
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

