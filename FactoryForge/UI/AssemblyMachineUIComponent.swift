//
//  AssemblyMachineUIComponent.swift
//  FactoryForge
//
//  Created by Richard Anthony Hein on 2026-01-15.
//
import Foundation
import UIKit

/// Component for assembly machines (furnaces, assemblers)
class AssemblyMachineUIComponent: BaseMachineUIComponent {
    private(set) var recipeButtons: [MachineRecipeButton] = []
    private var availableRecipes: [Recipe] = []
    private var recipeSelectionCallback: RecipeSelectionCallback?
    private weak var ui: MachineUI?

    // Scrolling support
    private(set) var scrollOffset: Float = 0
    private var maxScrollOffset: Float = 0
    private var scrollArea: Rect = Rect(center: Vector2.zero, size: Vector2.zero)
    private var lastDragPosition: Vector2?

    convenience init(recipeSelectionCallback: @escaping RecipeSelectionCallback) {
        self.init()
        self.recipeSelectionCallback = recipeSelectionCallback
    }

    override func setupUI(for entity: Entity, in ui: MachineUI) {
        self.ui = ui
    }

    override func getLabels() -> [UILabel] {
        return []
    }

    override func getScrollViews() -> [UIScrollView] {
        return []
    }


    override func render(in renderer: MetalRenderer) {
        // All rendering is now handled by UIKit - no Metal rendering needed
    }

}
