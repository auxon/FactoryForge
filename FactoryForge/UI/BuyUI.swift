import Foundation
import UIKit
import StoreKit

/// In-App Purchase UI panel that presents Apple's StoreView
@available(iOS 17.0, *)
final class BuyUI: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private weak var iapManager: IAPManager?
    private var closeButton: CloseButton!
    private let screenSize: Vector2

    /// Callback to present the StoreViewController (provided by UI system)
    var presentStoreViewController: ((UIViewController) -> Void)?

    init(screenSize: Vector2, gameLoop: GameLoop?, iapManager: IAPManager?) {
        self.screenSize = screenSize
        self.iapManager = iapManager

        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )

        super.init(frame: panelFrame)
        self.gameLoop = gameLoop

        setupCloseButton()
    }

    private func setupCloseButton() {
        closeButton = CloseButton(frame: Rect(
            x: frame.maxX - 60,
            y: frame.minY + 20,
            width: 40,
            height: 40
        ))
        closeButton.onTap = { [weak self] in
            self?.onPurchaseCompleted?()
        }
    }

    override func handleTap(at position: Vector2) -> Bool {
        // Check if close button was tapped
        if closeButton.handleTap(at: position) {
            return true
        }

        // Any tap on the panel opens the StoreView
        presentStoreView()
        return true
    }

    private func presentStoreView() {
        // Get all product IDs from IAPManager
        let productIds = IAPManager.shared.productIds

        // Create the StoreViewController
        let storeVC = StoreViewController(productIds: productIds) { [weak self] in
            // Purchase completed callback
            self?.onPurchaseCompleted?()
        }

        // Use the callback provided by the UI system to present it
        // This will be set by the UI system when the panel is opened
        presentStoreViewController?(storeVC)
    }

    override func render(renderer: MetalRenderer) {
        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render instruction text (simplified - just render a sprite for now)
        let textRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: Vector2(300, 100),
            textureRect: textRect,
            color: Color(r: 1, g: 1, b: 1, a: 0.8),
            layer: .ui
        ))
    }

    // MARK: - Callbacks

    var onPurchaseCompleted: (() -> Void)?

    // MARK: - Lifecycle

    override func open() {
        super.open()

        // Setup IAPManager callback for StoreView purchases
        IAPManager.shared.onPurchaseDelivered = { [weak self] itemId, quantity in
            self?.gameLoop?.addItemToInventory(itemId: itemId, quantity: quantity)
        }
    }

    override func close() {
        super.close()

        // Clean up IAPManager callback
        IAPManager.shared.onPurchaseDelivered = nil
    }
}
