import Foundation

/// Crafting menu panel
final class CraftingMenu: UIPanel_Base {
    private weak var gameLoop: GameLoop?
    private var recipeButtons: [RecipeButton] = []
    private var selectedRecipe: Recipe?
    
    init(screenSize: Vector2, gameLoop: GameLoop?) {
        let panelWidth: Float = 400
        let panelHeight: Float = 500
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(panelWidth, panelHeight)
        )
        
        super.init(frame: panelFrame)
        self.gameLoop = gameLoop
    }
    
    override func open() {
        super.open()
        refreshRecipes()
    }
    
    private func refreshRecipes() {
        recipeButtons.removeAll()
        
        guard let gameLoop = gameLoop else { return }
        
        let buttonSize: Float = 50
        let buttonSpacing: Float = 5
        let buttonsPerRow = 6
        let startX = frame.minX + 20
        let startY = frame.minY + 40
        
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
        selectedRecipe = recipe
        
        // Check if player can craft
        guard let player = gameLoop?.player else { return }
        
        if player.craft(recipe: recipe) {
            AudioManager.shared.playClickSound()
        }
    }
    
    override func update(deltaTime: Float) {
        guard isOpen else { return }
        
        // Update button states based on craftability
        guard let player = gameLoop?.player else { return }
        
        for button in recipeButtons {
            button.canCraft = button.recipe.canCraft(with: player.inventory)
        }
    }
    
    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        
        super.render(renderer: renderer)
        
        for button in recipeButtons {
            button.render(renderer: renderer)
        }
        
        // Render selected recipe details
        if let recipe = selectedRecipe {
            renderRecipeDetails(recipe: recipe, renderer: renderer)
        }
    }
    
    private func renderRecipeDetails(recipe: Recipe, renderer: MetalRenderer) {
        let detailsY = frame.maxY - 100
        
        // Recipe inputs
        var inputX = frame.minX + 50
        for input in recipe.inputs {
            let textureRect = renderer.textureAtlas.getTextureRect(for: input.itemId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(inputX, detailsY),
                size: Vector2(30, 30),
                textureRect: textureRect,
                layer: .ui
            ))
            inputX += 40
        }
        
        // Arrow (use solid white texture)
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: Vector2(inputX + 20, detailsY),
            size: Vector2(30, 30),
            textureRect: solidRect,
            color: .white,
            layer: .ui
        ))
        
        // Recipe outputs
        var outputX = inputX + 60
        for output in recipe.outputs {
            let textureRect = renderer.textureAtlas.getTextureRect(for: output.itemId.replacingOccurrences(of: "-", with: "_"))
            renderer.queueSprite(SpriteInstance(
                position: Vector2(outputX, detailsY),
                size: Vector2(30, 30),
                textureRect: textureRect,
                layer: .ui
            ))
            outputX += 40
        }
    }
    
    override func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }
        
        for button in recipeButtons {
            if button.handleTap(at: position) {
                return true
            }
        }
        
        return super.handleTap(at: position)
    }
}

class RecipeButton: UIElement {
    var frame: Rect
    let recipe: Recipe
    var canCraft: Bool = false
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
        let bgColor = canCraft ?
            Color(r: 0.2, g: 0.3, b: 0.2, a: 1) :
            Color(r: 0.25, g: 0.2, b: 0.2, a: 1)
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: bgColor,
            layer: .ui
        ))
        
        let textureRect = renderer.textureAtlas.getTextureRect(for: recipe.textureId)
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size * 0.8,
            textureRect: textureRect,
            color: canCraft ? .white : Color(r: 0.5, g: 0.5, b: 0.5, a: 1),
            layer: .ui
        ))
    }
}

