import Foundation
import UIKit


/// Crafting menu panel
final class CraftingMenu: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var recipeScrollView: ClearScrollView?
    private var recipePanelBackground: UIView?
    private var recipeHeaderLabel: UILabel?
    private var recipeUIButtons: [UIKit.UIButton] = []
    private var filteredRecipes: [Recipe] = []
    private var closeButton: CloseButton!
    private var closeButtonView: UIKit.UIButton?
    private var selectedRecipe: Recipe?
    private var lastRenderedRecipe: Recipe?
    private var recipeLabels: [UILabel] = [] // Track labels for recipe details

    // UIKit container for crafting menu content
    private var rootView: UIView?

    private var craftButton: UIKit.UIButton?
    private var progressBarBackground: UIView?
    private var progressBarFill: UIView?
    private var progressStatusLabel: UILabel?

    private var detailsIconYPoints: CGFloat = 0.0

    // Callbacks for managing UIKit labels (legacy, still used for counts)
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?

    // Callbacks for managing UIKit root view
    var onAddRootView: ((UIView) -> Void)?
    var onRemoveRootView: ((UIView) -> Void)?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )

        super.init(frame: panelFrame)

        // Make background completely opaque black to block ALL underlying UI
        backgroundColor = Color(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
        self.gameLoop = gameLoop

        setupCloseButton()
    }

    private func setupCloseButton() {
        let buttonSize: Float = 30 * UIScale
        let buttonX = frame.maxX - 25 * UIScale
        let buttonY = frame.minY + 25 * UIScale

        closeButton = CloseButton(frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)))
        closeButton.onTap = { [weak self] in
            self?.close()
            // Also notify UISystem to update panel state
            self?.gameLoop?.uiSystem?.closeAllPanels()
        }
    }

    private func setupCloseButtonViewIfNeeded() {
        guard let rootView = rootView else { return }
        if closeButtonView != nil { return }

        let button = UIKit.UIButton(type: .system)
        button.setTitle("X", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        button.layer.cornerRadius = 4
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        rootView.addSubview(button)
        closeButtonView = button
    }

    @objc private func closeButtonTapped() {
        close()
        gameLoop?.uiSystem?.closeAllPanels()
    }

    /// Convert Metal frame to UIKit points for panel container
    private func panelFrameInPoints() -> CGRect {
        let screenScale = UIScreen.main.scale
        return CGRect(
            x: CGFloat(frame.minX) / screenScale,
            y: CGFloat(frame.minY) / screenScale,
            width: CGFloat(frame.size.x) / screenScale,
            height: CGFloat(frame.size.y) / screenScale
        )
    }

    override func open() {
        super.open()
        if rootView == nil {
            rootView = UIView(frame: panelFrameInPoints())
            rootView?.backgroundColor = .clear
            rootView?.isUserInteractionEnabled = true
        }

        setupProgressBarIfNeeded()
        setupCloseButtonViewIfNeeded()
        setupRecipeScrollViewIfNeeded()
        layoutUI()
        refreshRecipes()
        updateCraftButtonState()
        updateProgressStatus()

        if let rootView = rootView {
            onAddRootView?(rootView)
        }
    }

    override func close() {
        super.close()
        selectedRecipe = nil
        lastRenderedRecipe = nil
        clearRecipeLabels()

        closeButtonView?.removeFromSuperview()
        closeButtonView = nil

        craftButton?.removeFromSuperview()
        craftButton = nil

        progressBarFill?.removeFromSuperview()
        progressBarFill = nil
        progressBarBackground?.removeFromSuperview()
        progressBarBackground = nil
        progressStatusLabel?.removeFromSuperview()
        progressStatusLabel = nil

        recipeUIButtons.forEach { $0.removeFromSuperview() }
        recipeUIButtons.removeAll()
        filteredRecipes.removeAll()

        recipeScrollView?.removeFromSuperview()
        recipeScrollView = nil
        recipeHeaderLabel?.removeFromSuperview()
        recipeHeaderLabel = nil
        recipePanelBackground?.removeFromSuperview()
        recipePanelBackground = nil

        if let rv = rootView {
            rv.isUserInteractionEnabled = false
            rv.removeFromSuperview()
            onRemoveRootView?(rv)
        }
        rootView = nil
    }

    private func clearRecipeLabels() {
        recipeLabels.forEach { $0.removeFromSuperview() }
        onRemoveLabels?(recipeLabels)
        recipeLabels.removeAll()
    }
    
    private func refreshRecipes() {
        guard let gameLoop = gameLoop else { return }

        filteredRecipes = gameLoop.recipeRegistry.enabled.filter { recipe in
            gameLoop.isRecipeUnlocked(recipe.id)
        }

        setupRecipeButtons()
        updateRecipeButtonStates()
    }
    
    private func selectRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
        updateRecipeButtonStates()
        updateRecipeDetails(for: recipe)
        updateCraftButtonState()
        updateProgressStatus()
        AudioManager.shared.playClickSound()
    }

    @objc private func craftSelectedRecipe() {
        guard let recipe = selectedRecipe, let player = gameLoop?.player else { return }

        if player.craft(recipe: recipe) {
            AudioManager.shared.playClickSound()
        }

        updateRecipeButtonStates()
        updateCraftButtonState()
        updateProgressStatus()
    }
    
    override func update(deltaTime: Float) {
        guard isOpen else { return }

        updateRecipeButtonStates()
        updateCraftButtonState()
        updateProgressStatus()
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render selected recipe details
        if let recipe = selectedRecipe {
            // Always render the icons (every frame)
            renderRecipeIcons(recipe: recipe, renderer: renderer)
        } else if lastRenderedRecipe != nil {
            clearRecipeLabels()
            lastRenderedRecipe = nil
        }
    }
    
    private func renderRecipeIcons(recipe: Recipe, renderer: MetalRenderer) {
        let iconSize: Float = 30 * UIScale
        let iconSpacing: Float = 40 * UIScale
        let detailsY = Float(detailsIconYPoints) * UIScale

        let totalItems = recipe.inputs.count + recipe.outputs.count + 1
        let leftCenterX = leftColumnCenterXInPixels()
        let startX = leftCenterX - Float(max(totalItems - 1, 0)) * iconSpacing * 0.5

        // Recipe inputs
        var inputX = startX
        for input in recipe.inputs {
            let textureRect = renderer.textureAtlas.getTextureRect(for: input.itemId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(inputX, detailsY),
                size: Vector2(iconSize, iconSize),
                textureRect: textureRect,
                layer: .ui
            ))

            inputX += iconSpacing
        }

        // Arrow
        let arrowRect = renderer.textureAtlas.getTextureRect(for: "right_arrow")
        renderer.queueSprite(SpriteInstance(
            position: Vector2(inputX + 20 * UIScale, detailsY),
            size: Vector2(iconSize, iconSize),
            textureRect: arrowRect,
            color: .white, // Make arrow bright white against black background
            layer: .ui
        ))

        // Recipe outputs
        var outputX = inputX + 60 * UIScale
        for output in recipe.outputs {
            let textureRect = renderer.textureAtlas.getTextureRect(for: output.itemId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(outputX, detailsY),
                size: Vector2(iconSize, iconSize),
                textureRect: textureRect,
                layer: .ui
            ))

            outputX += iconSpacing
        }
    }
    
    private func createRecipeLabels(recipe: Recipe) {
        // Create count labels for recipe inputs and outputs
        let iconSize: Float = 30 * UIScale
        let iconSpacing: Float = 40 * UIScale
        let detailsY = Float(detailsIconYPoints) * UIScale

        let totalItems = recipe.inputs.count + recipe.outputs.count + 1
        let leftCenterX = leftColumnCenterXInPixels()
        let startX = leftCenterX - Float(max(totalItems - 1, 0)) * iconSpacing * 0.5

        // Input count labels
        var inputX = startX
        for input in recipe.inputs {
            if input.count > 1 {
                let countLabel = createCountLabel(
                    text: "\(input.count)",
                    iconCenterX: inputX,
                    iconCenterY: detailsY,
                    iconSize: iconSize
                )
                recipeLabels.append(countLabel)
                rootView?.addSubview(countLabel)
            }
            inputX += iconSpacing
        }

        // Skip arrow

        // Output count labels
        var outputX = inputX + 60 * UIScale
        for output in recipe.outputs {
            if output.count > 1 {
                let countLabel = createCountLabel(
                    text: "\(output.count)",
                    iconCenterX: outputX,
                    iconCenterY: detailsY,
                    iconSize: iconSize
                )
                recipeLabels.append(countLabel)
                rootView?.addSubview(countLabel)
            }
            outputX += iconSpacing
        }
    }

    private func createCountLabel(text: String, iconCenterX: Float, iconCenterY: Float, iconSize: Float) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 8, weight: .bold)  // Match MachineUI font size
        label.textColor = .white
        label.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        label.textAlignment = .center
        label.layer.cornerRadius = 2
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = true  // Match MachineUI
        label.isHidden = false
        label.alpha = 1.0
        label.isOpaque = false
        
        label.sizeToFit()

        // Minimal padding
        let padding: CGFloat = 2
        let labelWidth = label.frame.width + padding * 2
        let labelHeight = label.frame.height + padding

        // Convert to UIKit coordinates (iconCenterX/Y are in Metal pixels, convert to points)
        let scale = UIScreen.main.scale
        let uiIconCenterX = CGFloat(iconCenterX) / scale
        let uiIconCenterY = CGFloat(iconCenterY) / scale
        let uiIconSize = CGFloat(iconSize) / scale

        // Calculate label position in UIKit coordinates (bottom-right corner of icon)
        let uiIconTopLeftX = uiIconCenterX - uiIconSize / 2
        let uiIconTopLeftY = uiIconCenterY - uiIconSize / 2
        let uiLabelX = uiIconTopLeftX + uiIconSize - labelWidth  // Right edge - label width
        let uiLabelY = uiIconTopLeftY + uiIconSize - labelHeight  // Bottom edge - label height

        label.frame = CGRect(x: uiLabelX, y: uiLabelY, width: labelWidth, height: labelHeight)
        
        print("CraftingMenu: Label '\(text)' frame set to: \(label.frame)")

        return label
    }

    private func setupProgressBarIfNeeded() {
        guard let rootView = rootView else { return }

        if progressBarBackground == nil {
            let background = UIView()
            background.backgroundColor = UIColor.gray
            background.layer.cornerRadius = 4
            rootView.addSubview(background)
            progressBarBackground = background
        }

        if progressBarFill == nil {
            let fill = UIView()
            fill.backgroundColor = UIColor.blue
            fill.layer.cornerRadius = 4
            rootView.addSubview(fill)
            progressBarFill = fill
        }

        if progressStatusLabel == nil {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            label.text = "0% (idle)"
            rootView.addSubview(label)
            progressStatusLabel = label
        }

        if craftButton == nil {
            let button = UIKit.UIButton(type: .system)
            var config = UIKit.UIButton.Configuration.filled()
            config.title = "Craft"
            config.baseForegroundColor = .white
            config.baseBackgroundColor = UIColor.systemBlue
            config.cornerStyle = .medium
            button.configuration = config
            button.addTarget(self, action: #selector(craftSelectedRecipe), for: .touchUpInside)
            rootView.addSubview(button)
            craftButton = button
        }
    }

    private func setupRecipeScrollViewIfNeeded() {
        guard let rootView = rootView else { return }

        if recipePanelBackground == nil {
            let background = UIView()
            background.backgroundColor = UIColor(white: 0.12, alpha: 0.6)
            background.layer.cornerRadius = 10
            rootView.addSubview(background)
            recipePanelBackground = background
        }

        if recipeHeaderLabel == nil {
            let label = UILabel()
            label.text = "Recipes"
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            label.textColor = UIColor(white: 0.85, alpha: 1.0)
            label.textAlignment = .center
            rootView.addSubview(label)
            recipeHeaderLabel = label
        }

        if recipeScrollView == nil {
            recipeScrollView = ClearScrollView(frame: .zero)
        }

        guard let scrollView = recipeScrollView else { return }

        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = true
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        scrollView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 0.6)
        scrollView.layer.cornerRadius = 8
        scrollView.clipsToBounds = true

        if scrollView.superview == nil {
            rootView.addSubview(scrollView)
        }
    }

    private func layoutUI() {
        guard let rootView = rootView else { return }

        let bounds = rootView.bounds
        let padding: CGFloat = 24
        let leftWidth = max(220, bounds.width * 0.4)

        let rightX = padding + leftWidth + padding
        let scrollWidth = max(160, bounds.width - rightX - padding)
        let scrollHeight = bounds.height - padding * 2

        let craftButtonHeight: CGFloat = 44
        let craftButtonWidth = min(220, leftWidth - 20)
        let craftButtonX = padding + (leftWidth - craftButtonWidth) * 0.5
        let craftButtonY = bounds.height - padding - craftButtonHeight

        let progressBarHeight: CGFloat = 16
        let progressBarWidth = craftButtonWidth
        let progressBarX = padding + (leftWidth - progressBarWidth) * 0.5
        let progressBarY = craftButtonY - 50

        let leftContentTop = padding
        let leftContentBottom = craftButtonY + craftButtonHeight
        let leftContentCenterY = (leftContentTop + leftContentBottom) * 0.5

        var scrollY = leftContentCenterY - scrollHeight * 0.5
        scrollY = max(padding, min(scrollY, bounds.height - padding - scrollHeight))

        recipePanelBackground?.frame = CGRect(
            x: rightX - 8,
            y: scrollY - 8,
            width: scrollWidth + 16,
            height: scrollHeight + 16
        )
        recipeHeaderLabel?.frame = CGRect(x: rightX, y: scrollY - 22, width: scrollWidth, height: 18)
        recipeScrollView?.frame = CGRect(x: rightX, y: scrollY, width: scrollWidth, height: scrollHeight)

        craftButton?.frame = CGRect(x: craftButtonX, y: craftButtonY, width: craftButtonWidth, height: craftButtonHeight)

        progressBarBackground?.frame = CGRect(x: progressBarX, y: progressBarY, width: progressBarWidth, height: progressBarHeight)
        progressBarFill?.frame = CGRect(x: progressBarX, y: progressBarY, width: 0, height: progressBarHeight)

        progressStatusLabel?.frame = CGRect(x: progressBarX, y: progressBarY + progressBarHeight + 4, width: progressBarWidth, height: 14)

        let closeSize: CGFloat = 36
        let closeMargin: CGFloat = 10
        closeButtonView?.frame = CGRect(
            x: bounds.width - closeMargin - closeSize,
            y: closeMargin,
            width: closeSize,
            height: closeSize
        )

        if let closeButtonView = closeButtonView {
            rootView.bringSubviewToFront(closeButtonView)
        }

        detailsIconYPoints = max(padding + 50, progressBarY - 45)
    }

    private func leftColumnCenterXInPixels() -> Float {
        let bounds = rootView?.bounds ?? panelFrameInPoints()
        let padding: CGFloat = 24
        let leftWidth = max(220, bounds.width * 0.4)
        let centerXPoints = padding + leftWidth * 0.5
        return Float(centerXPoints) * UIScale
    }

    private func updateRecipeDetails(for recipe: Recipe) {
        if recipe.id != lastRenderedRecipe?.id {
            clearRecipeLabels()
            createRecipeLabels(recipe: recipe)
            lastRenderedRecipe = recipe
        }
    }

    private func setupRecipeButtons() {
        guard let scrollView = recipeScrollView else { return }

        recipeUIButtons.forEach { $0.removeFromSuperview() }
        recipeUIButtons.removeAll()

        let buttonSize: CGFloat = 50
        let buttonSpacing: CGFloat = 8
        let columns = max(1, Int((scrollView.bounds.width + buttonSpacing) / (buttonSize + buttonSpacing)))
        let rows = (filteredRecipes.count + columns - 1) / columns

        let contentHeight = CGFloat(rows) * (buttonSize + buttonSpacing) + buttonSpacing
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: contentHeight)

        for (index, recipe) in filteredRecipes.enumerated() {
            let row = index / columns
            let col = index % columns

            let itemsInRow = min(columns, filteredRecipes.count - row * columns)
            let rowWidth = CGFloat(itemsInRow) * buttonSize + CGFloat(max(0, itemsInRow - 1)) * buttonSpacing
            let rowInset = max(buttonSpacing, (scrollView.bounds.width - rowWidth) * 0.5)

            let buttonX = rowInset + CGFloat(col) * (buttonSize + buttonSpacing)
            let buttonY = buttonSpacing + CGFloat(row) * (buttonSize + buttonSpacing)

            let button = UIKit.UIButton(frame: CGRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize))
            var config = UIKit.UIButton.Configuration.plain()
            config.background.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.8)
            config.background.strokeColor = UIColor.white
            config.background.strokeWidth = 1.0
            config.background.cornerRadius = 4.0
            config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)

            if let image = loadRecipeImage(for: recipe.textureId) {
                let scaledSize = CGSize(width: buttonSize * 0.8, height: buttonSize * 0.8)
                UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: scaledSize))
                let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                config.image = scaledImage
                config.imagePlacement = .all
            } else {
                config.title = "?"
                config.baseForegroundColor = UIColor.white
            }

            button.configuration = config
            button.tag = index
            button.addTarget(self, action: #selector(recipeButtonTapped(_:)), for: .touchUpInside)

            scrollView.addSubview(button)
            recipeUIButtons.append(button)
        }
    }

    @objc private func recipeButtonTapped(_ sender: UIKit.UIButton) {
        let index = sender.tag
        guard index >= 0 && index < filteredRecipes.count else { return }
        selectRecipe(filteredRecipes[index])
    }

    private func updateRecipeButtonStates() {
        guard let player = gameLoop?.player else { return }

        for (index, button) in recipeUIButtons.enumerated() {
            guard index < filteredRecipes.count else { continue }
            let recipe = filteredRecipes[index]
            let canCraft = recipe.canCraft(with: player.inventory)

            var config = button.configuration ?? .plain()
            if selectedRecipe?.id == recipe.id {
                config.background.backgroundColor = UIColor.blue.withAlphaComponent(0.4)
            } else if canCraft {
                config.background.backgroundColor = UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 0.8)
            } else {
                config.background.backgroundColor = UIColor(red: 0.25, green: 0.2, blue: 0.2, alpha: 0.7)
            }
            button.configuration = config
        }
    }

    private func updateCraftButtonState() {
        guard let button = craftButton else { return }

        if let recipe = selectedRecipe, let player = gameLoop?.player {
            let canCraft = recipe.canCraft(with: player.inventory)
            button.isHidden = false
            button.isEnabled = canCraft
            button.alpha = canCraft ? 1.0 : 0.5
            var config = button.configuration
            config?.title = "Craft"
            button.configuration = config
        } else {
            button.isHidden = false
            button.isEnabled = false
            button.alpha = 0.6
            var config = button.configuration
            config?.title = "Select a recipe"
            button.configuration = config
        }
    }

    private func updateProgressStatus() {
        guard let recipe = selectedRecipe, let player = gameLoop?.player else {
            progressStatusLabel?.text = "0% (idle)"
            progressBarFill?.frame.size.width = 0
            return
        }

        let isCrafting = player.isCrafting(recipe: recipe)
        let progress = player.getCraftingProgress(recipe: recipe) ?? 0.0
        let queuedCount = player.getQueuedCount(recipe: recipe)

        let percent = Int(progress * 100)
        if isCrafting {
            var text = "Crafting (\(percent)%)"
            if queuedCount > 0 {
                text += " + \(queuedCount) queued"
            }
            progressStatusLabel?.text = text
        } else if queuedCount > 0 {
            progressStatusLabel?.text = "Crafting (0%) + \(queuedCount) queued"
        } else {
            progressStatusLabel?.text = "0% (idle)"
        }

        if let background = progressBarBackground {
            let width = max(0, min(1, progress)) * Float(background.frame.width)
            progressBarFill?.frame.size.width = CGFloat(width)
        }
    }

    private func loadRecipeImage(for textureId: String) -> UIImage? {
        if let textureAtlas = gameLoop?.renderer?.textureAtlas {
            let textureName = textureId.replacingOccurrences(of: "-", with: "_")
            if let image = textureAtlas.getUIImage(for: textureName) {
                return image
            }
        }

        var filename = textureId
        switch textureId {
        case "transport_belt":
            filename = "belt"
        default:
            filename = textureId.replacingOccurrences(of: "-", with: "_")
        }

        if let imagePath = Bundle.main.path(forResource: filename, ofType: "png") {
            return UIImage(contentsOfFile: imagePath)
        }

        return nil
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else {
            return false
        }

        // When the crafting menu is open, ALWAYS consume the tap to prevent it from passing through to other UI
        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        // Consume ALL other taps when menu is open, even if they're outside our frame
        return true
    }

    func getTooltip(at position: Vector2) -> String? {
        guard isOpen else { return nil }

        return nil
    }
}
