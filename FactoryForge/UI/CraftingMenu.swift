import Foundation
import UIKit

/// Crafting menu panel
final class CraftingMenu: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var recipeButtons: [RecipeButton] = []
    private var closeButton: CloseButton!
    private var selectedRecipe: Recipe?
    private var lastRenderedRecipe: Recipe?
    private var recipeLabels: [UILabel] = [] // Track labels for recipe details

    // Callbacks for managing UIKit labels
    var onAddLabels: (([UILabel]) -> Void)?
    var onRemoveLabels: (([UILabel]) -> Void)?
    
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

    override func open() {
        super.open()
        refreshRecipes()
        setupLabels()
    }

    override func close() {
        super.close()
        selectedRecipe = nil
        lastRenderedRecipe = nil
        removeLabels()
    }

    private func setupLabels() {
        // Labels will be created when rendering recipe details
    }

    private func removeLabels() {
        onRemoveLabels?(recipeLabels)
        recipeLabels.removeAll()
    }
    
    private func refreshRecipes() {
        recipeButtons.removeAll()
        
        guard let gameLoop = gameLoop else { return }
        
        let buttonSize: Float = 50 * UIScale
        let buttonSpacing: Float = 5 * UIScale
        let buttonsPerRow = 6
        let totalWidth = Float(buttonsPerRow) * buttonSize + Float(buttonsPerRow - 1) * buttonSpacing
        let startX = frame.center.x - totalWidth / 2 + buttonSize / 2
        let startY = frame.center.y - 100 * UIScale
        
        let recipes = gameLoop.recipeRegistry.enabled.filter { recipe in
            gameLoop.isRecipeUnlocked(recipe.id)
        }
        
        for (index, recipe) in recipes.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow
            
            let buttonX = startX + Float(col) * (buttonSize + buttonSpacing) + buttonSize / 2
            let buttonY = startY + Float(row) * (buttonSize + buttonSpacing) + buttonSize / 2
            
            let button = RecipeButton(
                frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)),
                recipe: recipe
            )
            button.onTap = { [weak self] in
                self?.selectRecipe(recipe)
            }
            recipeButtons.append(button)
        }
    }
    
    private func selectRecipe(_ recipe: Recipe) {
        // Update selected recipe for display purposes
        selectedRecipe = recipe

        // Check if player can craft
        guard let player = gameLoop?.player else { return }

        if player.craft(recipe: recipe) {
            AudioManager.shared.playClickSound()
            // Recipe successfully queued for crafting
        } else {
            // Could not craft (missing ingredients) - no sound feedback needed
        }
    }
    
    override func update(deltaTime: Float) {
        guard isOpen else { return }

        // Update button states based on craftability and crafting status
        guard let player = gameLoop?.player else { return }

        for button in recipeButtons {
            button.canCraft = button.recipe.canCraft(with: player.inventory)
            button.isCrafting = player.isCrafting(recipe: button.recipe)
            button.craftingProgress = player.getCraftingProgress(recipe: button.recipe) ?? 0.0
            button.queuedCount = player.getQueuedCount(recipe: button.recipe)
        }
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        for button in recipeButtons {
            button.render(renderer: renderer)
        }
        
        // Render selected recipe details
        if let recipe = selectedRecipe {
            // Always render the icons (every frame)
            renderRecipeIcons(recipe: recipe, renderer: renderer)
            
            // Only recreate labels if recipe changed
            if recipe.id != lastRenderedRecipe?.id {
                // Clear previous labels
                if !recipeLabels.isEmpty {
                    onRemoveLabels?(recipeLabels)
                    recipeLabels.removeAll()
                }
                // Create new labels for this recipe
                createRecipeLabels(recipe: recipe, renderer: renderer)
                // Add the new labels to the view
                if !recipeLabels.isEmpty {
                    onAddLabels?(recipeLabels)
                }
                lastRenderedRecipe = recipe
            }
            // If recipe hasn't changed, labels already exist and persist
        } else if lastRenderedRecipe != nil {
            // Recipe was deselected, clear the details
            if !recipeLabels.isEmpty {
                onRemoveLabels?(recipeLabels)
                recipeLabels.removeAll()
            }
            lastRenderedRecipe = nil
        }
    }
    
    private func renderRecipeIcons(recipe: Recipe, renderer: MetalRenderer) {
        let iconSize: Float = 30 * UIScale
        let iconSpacing: Float = 40 * UIScale
        let detailsY = frame.maxY - 100 * UIScale

        // Recipe inputs
        var inputX = frame.minX + 50 * UIScale
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
    
    private func createRecipeLabels(recipe: Recipe, renderer: MetalRenderer) {
        // Create count labels for recipe inputs and outputs
        let iconSize: Float = 30 * UIScale
        let iconSpacing: Float = 40 * UIScale
        let detailsY = frame.maxY - 100 * UIScale

        // Input count labels
        var inputX = frame.minX + 50 * UIScale
        for input in recipe.inputs {
            if input.count > 1 {
                let countLabel = createCountLabel(
                    text: "\(input.count)",
                    iconCenterX: inputX,
                    iconCenterY: detailsY,
                    iconSize: iconSize,
                    screenHeight: Float(frame.height)
                )
                recipeLabels.append(countLabel)
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
                    iconSize: iconSize,
                    screenHeight: Float(frame.height)
                )
                recipeLabels.append(countLabel)
            }
            outputX += iconSpacing
        }
    }

    private func createCountLabel(text: String, iconCenterX: Float, iconCenterY: Float, iconSize: Float, screenHeight: Float) -> UILabel {
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
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else {
            return false
        }

        // When the crafting menu is open, ALWAYS consume the tap to prevent it from passing through to other UI
        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        for button in recipeButtons {
            if button.handleTap(at: position) {
                return true
            }
        }

        // Consume ALL other taps when menu is open, even if they're outside our frame
        return true
    }

    func getTooltip(at position: Vector2) -> String? {
        guard isOpen else { return nil }

        for button in recipeButtons {
            if button.frame.contains(position) {
                var tooltip = button.recipe.name

                if button.isCrafting {
                    if button.craftingProgress > 0 {
                        let percent = Int(button.craftingProgress * 100)
                        tooltip += " (Crafting: \(percent)%)"
                    } else {
                        tooltip += " (Queued)"
                    }
                }

                if button.queuedCount > 0 {
                    tooltip += " (\(button.queuedCount) queued)"
                }

                return tooltip
            }
        }

        return nil
    }
}

class RecipeButton: UIElement {
    var frame: Rect
    let recipe: Recipe
    var canCraft: Bool = false
    var isCrafting: Bool = false
    var craftingProgress: Float = 0.0
    var queuedCount: Int = 0
    var onTap: (() -> Void)?
    
    init(frame: Rect, recipe: Recipe) {
        self.frame = frame
        self.recipe = recipe
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        onTap?()
        return true
    }
    
    func render(renderer: MetalRenderer) {
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")

        // Base background color
        var bgColor: Color
        if isCrafting {
            // Crafting: brighter blue background
            bgColor = Color(r: 0.3, g: 0.4, b: 0.6, a: 1)
        } else if canCraft {
            bgColor = Color(r: 0.4, g: 0.7, b: 0.4, a: 1) // Brighter, more saturated green
        } else {
            bgColor = Color(r: 0.25, g: 0.2, b: 0.2, a: 1)
        }

        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))

        // Recipe icon
        let textureRect = renderer.textureAtlas.getTextureRect(for: recipe.textureId)
        let iconColor = isCrafting ? Color(r: 1.2, g: 1.2, b: 1.2, a: 1) : // Brighter when crafting
                       (canCraft ? .white : Color(r: 0.5, g: 0.5, b: 0.5, a: 1))
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size * 0.8,
            textureRect: textureRect,
            color: iconColor,
            layer: .ui
        ))

        // Crafting progress overlay (clock-like progress indicator)
        if isCrafting && craftingProgress > 0 {
            // Create a circular progress indicator using multiple small segments
            let center = frame.center
            let radius: Float = frame.size.x * 0.35
            let segmentCount = 16
            let segmentAngle = 2 * Float.pi / Float(segmentCount)
            let progressSegments = Int(craftingProgress * Float(segmentCount))

            for i in 0..<progressSegments {
                let angle = Float(i) * segmentAngle - Float.pi / 2 // Start from top
                let segmentCenter = center + Vector2(
                    cos(angle) * radius * 0.8,
                    sin(angle) * radius * 0.8
                )
                let segmentSize = Vector2(radius * 0.15, radius * 0.15)

                renderer.queueSprite(SpriteInstance(
                    position: segmentCenter,
                    size: segmentSize,
                    textureRect: solidRect,
                    color: Color(r: 0.9, g: 0.8, b: 0.2, a: 0.8), // Golden progress segments
                    layer: .ui
                ))
            }
        }

        // Queue count indicator (small number in corner if queued)
        if queuedCount > 0 {
            // Draw a small circle with number in bottom-right corner
            let indicatorSize: Float = frame.size.x * 0.25
            let indicatorPos = frame.center + Vector2(frame.size.x * 0.3, frame.size.y * 0.3)

            renderer.queueSprite(SpriteInstance(
                position: indicatorPos,
                size: Vector2(indicatorSize, indicatorSize),
                textureRect: solidRect,
                color: Color(r: 0.8, g: 0.6, b: 0.2, a: 1), // Orange queue indicator
                layer: .ui
            ))

            // Note: Number rendering would require additional text rendering system
            // For now, just the indicator shows there are queued items
        }
    }
}
