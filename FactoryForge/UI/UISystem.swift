import UIKit
import Metal

/// Global UI scale factor for retina displays
let UIScale: Float = Float(UIScreen.main.scale)

/// Main UI system that manages all UI elements
@available(iOS 17.0, *)
@available(iOS 17.0, *)
final class UISystem {
    private weak var gameLoop: GameLoop?
    private weak var renderer: MetalRenderer?
    private weak var inputManager: InputManager?
    
    // UI Panels
    private(set) var hud: HUD
    private var inventoryUI: InventoryUI
    private var craftingMenu: CraftingMenu
    private var buildMenu: BuildMenu
    private var researchUI: ResearchUI
    private var machineUI: MachineUI
    private var loadingMenu: LoadingMenu
    private var autoplayMenu: AutoPlayMenu
    private var helpMenu: HelpMenu?
    private var documentViewer: DocumentViewer?
    private var entitySelectionDialog: EntitySelectionDialog?
    private var inserterConnectionDialog: InserterConnectionDialog?
    
    // Current state
    private(set) var activePanel: UIPanel?
    private(set) var isAnyPanelOpen: Bool = false

    /// Public property to check if any UI panels are currently open
    var isAnyPanelCurrentlyOpen: Bool {
        craftingMenu.isOpen ||
        buildMenu.isOpen ||
        researchUI.isOpen ||
        inventoryUI.isOpen ||
        machineUI.isOpen ||
        (entitySelectionDialog?.isOpen ?? false) ||
        (inserterConnectionDialog?.isOpen ?? false) ||
        loadingMenu.isOpen ||
        autoplayMenu.isOpen ||
        (helpMenu?.isOpen ?? false) ||
        (documentViewer?.isOpen ?? false) ||
        (activePanel != nil)
    }
    
    // Touch handling
    private var touchedElement: UIElement?
    
    init(gameLoop: GameLoop?, renderer: MetalRenderer?) {
        self.gameLoop = gameLoop
        self.renderer = renderer
        
        let screenSize = renderer?.screenSize ?? Vector2(800, 600)
        
        loadingMenu = LoadingMenu(screenSize: screenSize)
        autoplayMenu = AutoPlayMenu(screenSize: screenSize)
        hud = HUD(screenSize: screenSize, gameLoop: gameLoop, inputManager: nil)
        inventoryUI = InventoryUI(screenSize: screenSize, gameLoop: gameLoop)
        craftingMenu = CraftingMenu(screenSize: screenSize, gameLoop: gameLoop)
        buildMenu = BuildMenu(screenSize: screenSize, gameLoop: gameLoop)
        researchUI = ResearchUI(screenSize: screenSize, gameLoop: gameLoop)
        machineUI = MachineUI(screenSize: screenSize, gameLoop: gameLoop)

        // Initialize entity selection dialog
        entitySelectionDialog = EntitySelectionDialog(screenSize: screenSize, gameLoop: gameLoop, renderer: renderer)

        setupCallbacks()
    }
    
    func setGameLoop(_ gameLoop: GameLoop) {
        self.gameLoop = gameLoop
        let screenSize = renderer?.screenSize ?? Vector2(800, 600)

        // Update all UI components that need gameLoop
        hud = HUD(screenSize: screenSize, gameLoop: gameLoop, inputManager: inputManager)
        inventoryUI = InventoryUI(screenSize: screenSize, gameLoop: gameLoop)
        craftingMenu = CraftingMenu(screenSize: screenSize, gameLoop: gameLoop)
        buildMenu = BuildMenu(screenSize: screenSize, gameLoop: gameLoop)
        researchUI = ResearchUI(screenSize: screenSize, gameLoop: gameLoop)
        machineUI = MachineUI(screenSize: screenSize, gameLoop: gameLoop)

        // Clear help menu and document viewer (will be recreated lazily)
        helpMenu = nil
        documentViewer = nil

        // Reinitialize entity selection dialog with gameLoop
        entitySelectionDialog = EntitySelectionDialog(screenSize: screenSize, gameLoop: gameLoop, renderer: renderer)

        // Reinitialize inserter connection dialog with gameLoop
        inserterConnectionDialog = InserterConnectionDialog(screenSize: screenSize, gameLoop: gameLoop, renderer: renderer)

        // Set up callbacks AFTER creating UI components (so they're set on the correct instances)
        setupCallbacks()
    }

    func setInputManager(_ inputManager: InputManager) {
        self.inputManager = inputManager
        // Update HUD with inputManager reference
        hud.setInputManager(inputManager)
    }
    
    func getLoadingMenu() -> LoadingMenu {
        return loadingMenu
    }

    func getAutoplayMenu() -> AutoPlayMenu {
        return autoplayMenu
    }

    func getHelpMenu() -> HelpMenu {
        if helpMenu == nil {
            let screenSize = renderer?.screenSize ?? Vector2(800, 600)
            helpMenu = HelpMenu(screenSize: screenSize)
        }
        return helpMenu!
    }

    func getDocumentViewer() -> DocumentViewer? {
        return documentViewer
    }

    func getInventoryUI() -> InventoryUI {
        return inventoryUI
    }

    func getMachineUI() -> MachineUI {
        return machineUI
    }

    func getResearchUI() -> ResearchUI {
        return researchUI
    }

    func getCraftingMenu() -> CraftingMenu {
        return craftingMenu
    }

    func getBuildMenu() -> BuildMenu {
        return buildMenu
    }

    func getInserterConnectionDialog() -> InserterConnectionDialog? {
        return inserterConnectionDialog
    }
    
    func setupCallbacks() {
        // HUD button callbacks
        hud.onInventoryPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.togglePanel(.inventory)
        }
        
        hud.onCraftingPressed = { [weak self] in
            // Check if any panels are currently open - if so, ignore HUD button presses
            if let self = self, self.isAnyPanelCurrentlyOpen {
                return
            }
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            // Only toggle if not already the active panel
            if self?.activePanel != .crafting {
                self?.togglePanel(.crafting)
            }
        }
        
        hud.onBuildPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.togglePanel(.build)
        }
        
        hud.onResearchPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.togglePanel(.research)
        }

        hud.onBuyPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            // Directly present the StoreViewController modal
            self?.presentStoreViewControllerModal()
        }

        hud.onMenuPressed = { [weak self] in
            // Close machine UI if open when clicking any HUD button
            if self?.activePanel == .machine {
                self?.closeAllPanels()
            }
            self?.openPanel(.loadingMenu)
        }
        
        // Build menu handles building selection directly
        

        // Machine UI callback for opening inventory
        machineUI.onOpenInventoryForMachine = { [weak self] entity, slotIndex in
            // Open inventory UI in machine input mode
            self?.inventoryUI.enterMachineInputMode(entity: entity, slotIndex: slotIndex)
            self?.inventoryUI.onMachineInputCompleted = { [weak self] in
                // Reopen machine UI after inventory input is completed
                self?.openPanel(.machine)
            }
            self?.openPanel(.inventory)
        }

        // Machine UI callback for opening research menu
        machineUI.onOpenResearchMenu = { [weak self] in
            self?.togglePanel(.research)
        }

        // Machine UI callback for launching rockets
        machineUI.onLaunchRocket = { [weak self] entity in
            guard let self = self, let gameLoop = self.gameLoop else { return }

            // Attempt to launch rocket from the silo
            let success = gameLoop.rocketSystem.launchRocketFromSilo(entity)

            if success {
                print("UISystem: Rocket launch initiated!")
                // Close machine UI to show the launch
                self.closeAllPanels()
            } else {
                print("UISystem: Rocket launch failed - check silo status")
            }
        }

        // Machine UI callback for selecting recipes on machines
        machineUI.onSelectRecipeForMachine = { [weak self] entity, recipe in
            guard let self = self, let gameLoop = self.gameLoop else { return }

            // Set the recipe on the machine's AssemblerComponent
            if let assembler = gameLoop.world.get(AssemblerComponent.self, for: entity) {
                assembler.recipe = recipe
                assembler.craftingProgress = 0.0  // Reset progress
                gameLoop.world.add(assembler, to: entity)

                print("UISystem: Set recipe \(recipe.id) on machine \(entity.id)")
            }
        }

        // Machine UI callback for closing when tapped outside
        machineUI.onClosePanel = { [weak self] in
            self?.closeAllPanels()
        }

        // Quick bar slot callback
    }

    // MARK: - StoreKit Integration

    private func presentStoreViewControllerModal() {
        // Set up IAPManager callback for inventory delivery
        IAPManager.shared.onPurchaseDelivered = { [weak self] itemId, quantity in
            self?.gameLoop?.addItemToInventory(itemId: itemId, quantity: quantity)
            // Autosave after IAP completion
            if let gameLoop = self?.gameLoop, let autosaveSlot = gameLoop.saveSystem.currentAutosaveSlot {
                gameLoop.saveSystem.save(gameLoop: gameLoop, slotName: autosaveSlot)
                print("Game autosaved after IAP completion to slot: \(autosaveSlot)")
            }
        }

        // Set up IAPManager callback for upgrade delivery
        print("🎮 UISystem: Setting up upgrade purchase callback")
        IAPManager.shared.onUpgradePurchased = { [weak self] upgradeType in
            print("📞 UISystem: Received upgrade callback for type: \(upgradeType)")
            self?.handleUpgradePurchase(upgradeType)
        }

        // Debug: Add a way to manually test inventory expansion
        #if DEBUG
        // You can call this method programmatically to test inventory expansion
        // Example: Add a temporary debug button in the UI that calls this
        #endif

        // Get all product IDs from IAPManager
        let productIds = IAPManager.shared.productIds
        print("🛍️ UISystem: Opening store with \(productIds.count) products:")
        for id in productIds {
            print("📦 UISystem: - \(id)")
        }

        // Create the StoreViewController
        let storeVC = StoreViewController(productIds: productIds) {
            // Purchase completed - items are automatically added to inventory via IAPManager
            // No additional UI action needed
        }

        // Present the StoreViewController directly
        presentStoreViewController(storeVC)
    }

    private func handleUpgradePurchase(_ upgradeType: String) {
        print("🎮 UISystem: Handling upgrade purchase of type: \(upgradeType)")
        switch upgradeType {
        case "inventory_expansion":
            print("📦 UISystem: Calling expandPlayerInventory()")
            expandPlayerInventory()
        default:
            print("❓ UISystem: Unknown upgrade type: \(upgradeType)")
        }
    }

    private func expandPlayerInventory() {
        print("🎒 expandPlayerInventory: Starting inventory expansion")
        guard let gameLoop = gameLoop else {
            print("❌ expandPlayerInventory: No gameLoop available")
            return
        }

        // Increase player inventory by 8 slots
        let currentSlots = gameLoop.player.inventory.slotCount
        let newSlots = currentSlots + 8
        print("📊 expandPlayerInventory: Expanding from \(currentSlots) to \(newSlots) slots")

        // Create new inventory with expanded slots
        var newInventory = InventoryComponent(slots: newSlots, allowedItems: nil)
        print("🆕 expandPlayerInventory: Created new inventory with \(newInventory.slotCount) slots")

        // Copy existing items to the new inventory
        var copiedItems = 0
        for i in 0..<min(currentSlots, newInventory.slotCount) {
            if gameLoop.player.inventory.slots[i] != nil {
                newInventory.slots[i] = gameLoop.player.inventory.slots[i]
                copiedItems += 1
            }
        }
        print("📦 expandPlayerInventory: Copied \(copiedItems) item stacks to new inventory")

        // Update player's inventory
        gameLoop.player.inventory = newInventory
        print("✅ expandPlayerInventory: Player inventory updated successfully")

        // Autosave after upgrade
        if let autosaveSlot = gameLoop.saveSystem.currentAutosaveSlot {
            gameLoop.saveSystem.save(gameLoop: gameLoop, slotName: autosaveSlot)
            print("💾 expandPlayerInventory: Autosaved to slot: \(autosaveSlot)")
        } else {
            print("⚠️ expandPlayerInventory: No autosave slot available")
        }

        // Show notification
        NotificationCenter.default.post(
            name: .inventoryExpanded,
            object: nil,
            userInfo: ["newSlotCount": newSlots]
        )
        print("🔔 expandPlayerInventory: Posted inventory expanded notification")
    }

    func presentStoreViewController(_ viewController: UIViewController) {
        // Find the root view controller to present the StoreView
        // Use iOS 15+ API for window access
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(viewController, animated: true)
        }
    }

    // MARK: - Update
    
    func update(deltaTime: Float) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.update(deltaTime: deltaTime)
            }
            return
        }

        if let panel = activePanel, panel == .loadingMenu || panel == .autoplayMenu || panel == .helpMenu || panel == .documentViewer {
            if panel == .loadingMenu {
                loadingMenu.update(deltaTime: deltaTime)
            } else if panel == .autoplayMenu {
                autoplayMenu.update(deltaTime: deltaTime)
            } else if panel == .helpMenu {
                helpMenu?.update(deltaTime: deltaTime)
            } else if panel == .documentViewer {
                documentViewer?.update(deltaTime: deltaTime)
            }
            return // Don't update game UI if menus are open
        }
        
        hud.update(deltaTime: deltaTime)
        
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                loadingMenu.update(deltaTime: deltaTime)
            case .autoplayMenu:
                autoplayMenu.update(deltaTime: deltaTime)
            case .helpMenu:
                helpMenu?.update(deltaTime: deltaTime)
            case .documentViewer:
                documentViewer?.update(deltaTime: deltaTime)
            case .inventory:
                inventoryUI.update(deltaTime: deltaTime)
            case .crafting:
                craftingMenu.update(deltaTime: deltaTime)
            case .build:
                buildMenu.update(deltaTime: deltaTime)
            case .research:
                researchUI.update(deltaTime: deltaTime)
            case .machine:
                machineUI.update(deltaTime: deltaTime)
            case .entitySelection:
                entitySelectionDialog?.update(deltaTime: deltaTime)
            case .inserterConnection:
                inserterConnectionDialog?.update(deltaTime: deltaTime)
            }
        }
    }

    func showEntitySelectionDialog(entities: [Entity], onSelected: @escaping (Entity) -> Void) {
        guard let dialog = entitySelectionDialog else { return }
        dialog.setEntities(entities)
        
        dialog.onEntitySelected = { [weak self] entity in
            onSelected(entity)
            // Delay closing the dialog to prevent the same tap from being processed by game world
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.closeEntitySelectionDialog()
            }
        }
        
        dialog.onEntityDoubleTapped = { [weak self] entity in
            guard let self = self, let gameLoop = self.gameLoop else { return }
            let world = gameLoop.world
            
            // Check if it's an inserter
            if world.has(InserterComponent.self, for: entity) {
                print("UISystem: Double-tapped inserter in selection dialog, opening connection dialog")
                self.closeEntitySelectionDialog()
                self.showInserterConnectionDialog(entity: entity)
            } else if world.has(ChestComponent.self, for: entity) {
                // Only open inventory UI for chests automatically
                print("UISystem: Double-tapped chest in selection dialog, opening inventory UI")
                self.closeEntitySelectionDialog()
                self.openChestInventory(for: entity)
            }
        }
        
        dialog.onCancel = { [weak self] in
            self?.closeEntitySelectionDialog()
        }
        
        dialog.open()
        activePanel = .entitySelection
        isAnyPanelOpen = true
    }
    
    private func closeEntitySelectionDialog() {
        entitySelectionDialog?.close()
        activePanel = nil
        isAnyPanelOpen = false
    }
    
    func showInserterConnectionDialog(entity: Entity) {
        guard let dialog = inserterConnectionDialog else { return }
        dialog.setInserter(entity: entity)
        dialog.setInputManager(inputManager)  // Pass inputManager to dialog
        
        dialog.onInputSet = { [weak self] entity, targetEntity, targetPosition in
            guard let self = self else { return }
            if let gameLoop = self.gameLoop {
                // If both are nil, it's a clear operation
                let clearInput = (targetEntity == nil && targetPosition == nil)
                if gameLoop.setInserterConnection(entity: entity, inputTarget: targetEntity, inputPosition: targetPosition, clearInput: clearInput) {
                    print("UISystem: Input connection set successfully - targetEntity: \(targetEntity != nil ? "set" : "nil"), targetPosition: \(targetPosition != nil ? "\(targetPosition!)" : "nil")")
                    // Don't close dialog - allow setting both input and output
                    // Update the dialog to show the new connection
                    dialog.setInserter(entity: entity)
                } else {
                    print("UISystem: Failed to set input connection")
                }
            }
        }
        
        dialog.onOutputSet = { [weak self] entity, targetEntity, targetPosition in
            guard let self = self else { return }
            if let gameLoop = self.gameLoop {
                // If both are nil, it's a clear operation
                let clearOutput = (targetEntity == nil && targetPosition == nil)
                if gameLoop.setInserterConnection(entity: entity, outputTarget: targetEntity, outputPosition: targetPosition, clearOutput: clearOutput) {
                    print("UISystem: Output connection set successfully - targetEntity: \(targetEntity != nil ? "set" : "nil"), targetPosition: \(targetPosition != nil ? "\(targetPosition!)" : "nil")")
                    // Don't close dialog - allow setting both input and output
                    // Update the dialog to show the new connection
                    dialog.setInserter(entity: entity)
                } else {
                    print("UISystem: Failed to set output connection")
                }
            }
        }
        
        dialog.onCancel = { [weak self] in
            self?.closeInserterConnectionDialog()
        }
        
        dialog.open()
        activePanel = .inserterConnection
        isAnyPanelOpen = true
    }
    
    private func closeInserterConnectionDialog() {
        inserterConnectionDialog?.close()
        activePanel = nil
        isAnyPanelOpen = false
    }

    // MARK: - Rendering
    
    func render(renderer: MetalRenderer) {
        if let panel = activePanel, panel == .loadingMenu || panel == .helpMenu || panel == .documentViewer {
            // Only render these menus if they're active (replace entire view)
            if panel == .loadingMenu {
                loadingMenu.render(renderer: renderer)
            } else if panel == .helpMenu {
                helpMenu?.render(renderer: renderer)
            } else if panel == .documentViewer {
                documentViewer?.render(renderer: renderer)
            }
            return
        }
        
        hud.render(renderer: renderer)
        
        // Render active panel
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                loadingMenu.render(renderer: renderer)
            case .autoplayMenu:
                autoplayMenu.render(renderer: renderer)
            case .helpMenu:
                helpMenu?.render(renderer: renderer)
            case .documentViewer:
                documentViewer?.render(renderer: renderer)
            case .inventory:
                inventoryUI.render(renderer: renderer)
            case .crafting:
                craftingMenu.render(renderer: renderer)
            case .build:
                buildMenu.render(renderer: renderer)
            case .research:
                researchUI.render(renderer: renderer)
            case .machine:
                machineUI.render(renderer: renderer)
            case .entitySelection:
                entitySelectionDialog?.render(renderer: renderer)
            case .inserterConnection:
                inserterConnectionDialog?.render(renderer: renderer)
            }
        }
    }
    
    func renderMetal(encoder: MTLRenderCommandEncoder, screenSize: Vector2) {
        // Metal-based UI rendering would go here
        // For now, UI is rendered through the sprite system
    }
    
    // MARK: - Panel Management
    

    func togglePanel(_ panel: UIPanel) {
        if activePanel == panel {
            closeAllPanels()
        } else {
            openPanel(panel)
        }
    }
    
    func openPanel(_ panel: UIPanel) {
        print("UISystem: openPanel(\(panel)) called, current activePanel = \(String(describing: activePanel))")
        closeAllPanels()
        activePanel = panel
        isAnyPanelOpen = true
        print("UISystem: Set activePanel to \(panel)")

        switch panel {
        case .loadingMenu:
            loadingMenu.open()
        case .autoplayMenu:
            autoplayMenu.open()
        case .helpMenu:
            helpMenu?.open()
        case .documentViewer:
            documentViewer?.open()
        case .inventory:
            inventoryUI.open()
        case .crafting:
            craftingMenu.open()
        case .build:
            buildMenu.open()
        case .research:
            researchUI.open()
        case .machine:
            print("UISystem: Calling machineUI.open()")
            machineUI.open()
            print("UISystem: machineUI.open() completed")
            case .entitySelection:
                entitySelectionDialog?.open()
            case .inserterConnection:
                inserterConnectionDialog?.open()
        }
    }
    
    func closeAllPanels() {
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                loadingMenu.close()
            case .autoplayMenu:
                autoplayMenu.close()
            case .helpMenu:
                helpMenu?.close()
            case .documentViewer:
                documentViewer?.close()
            case .inventory:
                inventoryUI.close()
            case .crafting:
                craftingMenu.close()
            case .build:
                buildMenu.close()
            case .research:
                researchUI.close()
            case .machine:
                machineUI.close()
            case .entitySelection:
                entitySelectionDialog?.close()
            case .inserterConnection:
                inserterConnectionDialog?.close()
            }
        }

        activePanel = nil
        isAnyPanelOpen = false
    }
    
    func updateMachineUI(for entity: Entity) {
        // If the machine UI is currently open for this entity, update it
        if activePanel == .machine && machineUI.currentEntity?.id == entity.id {
            machineUI.updateMachine(entity)
        }
    }

    func openMachineUI(for entity: Entity) {
        print("UISystem: openMachineUI called for entity \(entity.id)")
        machineUI.setEntity(entity)
        print("UISystem: setEntity completed, calling openPanel(.machine)")
        openPanel(.machine)
        print("UISystem: openPanel completed, machineUI.isOpen = \(machineUI.isOpen)")
    }

    func openPipeTankSelection(for entity: Entity) {
        machineUI.openPipeTankSelectionOnOpen = true
        openMachineUI(for: entity)
    }

    func openChestInventory(for entity: Entity) {
        inventoryUI.enterChestOnlyMode(entity: entity)
        openPanel(.inventory)
    }

    func openHelpMenu() {
        openPanel(.helpMenu)
    }

    func openDocumentViewer(documentName: String) {
        let screenSize = renderer?.screenSize ?? Vector2(800, 600)
        documentViewer = DocumentViewer(screenSize: screenSize, documentName: documentName)
        openPanel(.documentViewer)
    }
    
    func isPanelOpen(_ panel: UIPanel) -> Bool {
        return activePanel == panel
    }
    
    func handleDoubleTap(at screenPos: Vector2) -> Bool {
        // Check active panel
        if let panel = activePanel {
            switch panel {
            case .entitySelection:
                return entitySelectionDialog?.handleDoubleTap(at: screenPos) ?? false
            default:
                return false
            }
        }
        return false
    }
    
    func updateScreenSize(_ newSize: Vector2) {
        hud.updateScreenSize(newSize)
        // TODO: Update other UI panels if they need screen size updates
    }
    
    // MARK: - Touch Handling
    
    func handleTap(at screenPos: Vector2) -> Bool {
        // If ANY UI panel is open, consume the tap completely - no HUD or game world interaction allowed
        let anyPanelOpen = craftingMenu.isOpen ||
                          buildMenu.isOpen ||
                          researchUI.isOpen ||
                          inventoryUI.isOpen ||
                          machineUI.isOpen ||
                          (entitySelectionDialog?.isOpen ?? false) ||
                          (inserterConnectionDialog?.isOpen ?? false) ||
                          loadingMenu.isOpen ||
                          autoplayMenu.isOpen ||
                          (helpMenu?.isOpen ?? false) ||
                          (documentViewer?.isOpen ?? false)

        if anyPanelOpen {
            // Allow panels to handle their own interactions
            var tapHandled = false
            if let panel = activePanel {
                switch panel {
                case .loadingMenu:
                    tapHandled = loadingMenu.handleTap(at: screenPos)
                case .autoplayMenu:
                    tapHandled = autoplayMenu.handleTap(at: screenPos)
                case .helpMenu:
                    tapHandled = helpMenu?.handleTap(at: screenPos) ?? false
                case .documentViewer:
                    tapHandled = documentViewer?.handleTap(at: screenPos) ?? false
                case .inventory:
                    tapHandled = inventoryUI.handleTap(at: screenPos)
                case .crafting:
                    tapHandled = craftingMenu.handleTap(at: screenPos)
                case .build:
                    tapHandled = buildMenu.handleTap(at: screenPos)
                case .research:
                    tapHandled = researchUI.handleTap(at: screenPos)
                case .machine:
                    if machineUI.isOpen {
                        tapHandled = machineUI.handleTap(at: screenPos)
                    }
                case .entitySelection:
                    tapHandled = entitySelectionDialog?.handleTap(at: screenPos) ?? false
                case .inserterConnection:
                    tapHandled = inserterConnectionDialog?.handleTap(at: screenPos) ?? false
                }
            }

            // If the panel handled the tap, consume it regardless of whether the panel is still open
            if tapHandled {
                return true
            }

            // Check if panels are still open after handling (in case a panel closed itself)
            let stillAnyPanelOpen = craftingMenu.isOpen ||
                                   buildMenu.isOpen ||
                                   researchUI.isOpen ||
                                   inventoryUI.isOpen ||
                                   machineUI.isOpen ||
                                   (entitySelectionDialog?.isOpen ?? false) ||
                                   (inserterConnectionDialog?.isOpen ?? false) ||
                                   loadingMenu.isOpen ||
                                   autoplayMenu.isOpen ||
                                   (helpMenu?.isOpen ?? false) ||
                                   (documentViewer?.isOpen ?? false)

            if stillAnyPanelOpen {
                // Consume the tap if panels are still open
                return true
            }
            // Panels were closed during handling, proceed to HUD handling
        }

        // No panels open - allow HUD and game world interaction
        let currentScreenSize = renderer?.screenSize ?? Vector2(800, 600)
        if hud.handleTap(at: screenPos, screenSize: currentScreenSize) {
            return true
        }

        return false
    }
    func getTooltip(at screenPos: Vector2) -> String? {
        // If loading menu is active, check tooltips only for it
        if let panel = activePanel, panel == .loadingMenu {
            return nil // Loading menu doesn't need tooltips
        }

        // Check if any panels are open - if so, don't show HUD tooltips
        let anyPanelOpen = craftingMenu.isOpen ||
                          buildMenu.isOpen ||
                          researchUI.isOpen ||
                          inventoryUI.isOpen ||
                          machineUI.isOpen ||
                          (entitySelectionDialog?.isOpen ?? false) ||
                          (inserterConnectionDialog?.isOpen ?? false) ||
                          loadingMenu.isOpen ||
                          autoplayMenu.isOpen ||
                          (helpMenu?.isOpen ?? false) ||
                          (documentViewer?.isOpen ?? false) ||
                          (activePanel != nil)

        // Get current screen size from renderer
        let currentScreenSize = renderer?.screenSize ?? Vector2(800, 600)

        // Check HUD first (only if no panels are open)
        if !anyPanelOpen {
            if let tooltip = hud.getButtonName(at: screenPos, screenSize: currentScreenSize) {
                return tooltip
            }
        }

        // Check active panel
        if let panel = activePanel {
            switch panel {
            case .loadingMenu:
                return nil
            case .autoplayMenu:
                return nil  // AutoPlayMenu doesn't have detailed tooltips
            case .helpMenu:
                return nil  // HelpMenu doesn't have detailed tooltips
            case .documentViewer:
                return nil  // DocumentViewer doesn't have detailed tooltips
            case .inventory:
                return inventoryUI.getTooltip(at: screenPos)
            case .crafting:
                return craftingMenu.getTooltip(at: screenPos)
            case .build:
                return buildMenu.getTooltip(at: screenPos)
            case .research:
                return researchUI.getTooltip(at: screenPos)
            case .machine:
                return machineUI.getTooltip(at: screenPos)
            case .entitySelection:
                return nil // EntitySelectionDialog doesn't need tooltips
            case .inserterConnection:
                return nil // InserterConnectionDialog doesn't need tooltips
            }
        }

        return nil
    }

    func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        // Check active panels
        if let panel = activePanel {
            switch panel {
            case .inventory:
                return inventoryUI.handleDrag(from: startPos, to: endPos)
            case .machine:
                return machineUI.handleDrag(from: startPos, to: endPos)
            case .documentViewer:
                return documentViewer?.handleDrag(from: startPos, to: endPos) ?? false
            default:
                return false
            }
        }
        return false
    }

    #if DEBUG
    /// Debug method to manually test inventory expansion
    /// Call this to test if the upgrade logic works without StoreKit
    func debugExpandInventory() {
        print("🐛 DEBUG: Manually triggering inventory expansion")
        handleUpgradePurchase("inventory_expansion")
    }
    #endif
}

// MARK: - UI Types

enum UIPanel {
    case loadingMenu
    case autoplayMenu
    case helpMenu
    case documentViewer
    case inventory
    case crafting
    case build
    case research
    case machine
    case entitySelection
    case inserterConnection
}

// MARK: - Entity Selection Dialog

@available(iOS 17.0, *)
class EntitySelectionDialog {
    private weak var gameLoop: GameLoop?
    private weak var renderer: MetalRenderer?
    private var screenSize: Vector2
    
    private var entities: [Entity] = []
    private var cancelButton: UIButton
    
    var onEntitySelected: ((Entity) -> Void)?
    var onCancel: (() -> Void)?
    var onEntityDoubleTapped: ((Entity) -> Void)?
    
    var isOpen: Bool = false
    
    
    init(screenSize: Vector2, gameLoop: GameLoop?, renderer: MetalRenderer?) {
        self.screenSize = screenSize
        self.gameLoop = gameLoop
        self.renderer = renderer
        
        // Create cancel button with proper texture and aspect ratio (same as InserterTypeDialog)
        let cancelSize = renderer?.textureAtlas.getTextureSize(for: "cancel_button") ?? (width: 810, height: 345)
        let cancelAspectRatio = Float(cancelSize.width) / Float(cancelSize.height)
        let targetButtonHeight: Float = 50 * UIScale
        let cancelWidth = targetButtonHeight * cancelAspectRatio
        
        let cancelX = screenSize.x / 2
        let cancelY = screenSize.y - 100 * UIScale
        
        cancelButton = UIButton(
            frame: Rect(
                center: Vector2(cancelX, cancelY),
                size: Vector2(cancelWidth, targetButtonHeight)
            ),
            textureId: "inserter_cancel_button"
        )
        
        cancelButton.onTap = { [weak self] in
            self?.onCancel?()
        }
    }
    
    func setEntities(_ entities: [Entity]) {
        self.entities = entities

        guard let gameLoop = gameLoop else { return }

        print("EntitySelectionDialog: setEntities called with \(entities.count) entities")
        for entity in entities {
            let hasInserter = gameLoop.world.has(InserterComponent.self, for: entity)
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            print("EntitySelectionDialog: Entity \(entity) - Inserter: \(hasInserter), Belt: \(hasBelt), Furnace: \(hasFurnace)")
        }
    }
    
    private func getEntityTextureId(entity: Entity, gameLoop: GameLoop) -> String {
        // Get sprite texture ID, but handle directional textures (like belts)
        if let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) {
            var textureId = sprite.textureId
            
            // Handle belt directional textures (e.g., "transport_belt_north_001" -> "transport_belt")
            if textureId.contains("_belt_") {
                let parts = textureId.split(separator: "_")
                if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                    textureId = parts[0...beltIndex].joined(separator: "_")
                }
            }
            
            return textureId
        }
        
        return "solid_white"
    }
    
    private func getEntityName(entity: Entity, gameLoop: GameLoop) -> String {
        // Try to get name from sprite texture
        if let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) {
            // Check for player
            if sprite.textureId == "player" {
                return "Player"
            }
            
            // Handle belt directional textures
            var textureId = sprite.textureId
            if textureId.contains("_belt_") {
                let parts = textureId.split(separator: "_")
                if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                    textureId = parts[0...beltIndex].joined(separator: "_")
                }
            }
            
            // Try to find building by texture
            if let building = gameLoop.buildingRegistry.getByTexture(textureId) {
                return building.name
            }
            
            // Fallback to texture ID
            return textureId.replacingOccurrences(of: "_", with: " ").capitalized
        }
        
        return "Entity"
    }
    
    func open() {
        isOpen = true
    }
    
    func close() {
        isOpen = false
    }
    
    func handleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Calculate grid layout (same as in setEntities)
        let iconSize: Float = 80 * UIScale
        let spacing: Float = 20 * UIScale
        let padding: Float = 40 * UIScale
        let cols = min(3, entities.count)
        let rows = (entities.count + cols - 1) / cols
        let totalWidth = Float(cols) * iconSize + Float(cols - 1) * spacing + padding * 2
        let totalHeight = Float(rows) * iconSize + Float(rows - 1) * spacing + padding * 2 + 100

        let startX = (screenSize.x - totalWidth) / 2 + padding
        let startY = (screenSize.y - totalHeight) / 2 + padding

        // Check if tap is within the entity grid area
        for (index, _) in entities.enumerated() {
            let row = index / cols
            let col = index % cols

            let buttonCenterX = startX + Float(col) * (iconSize + spacing) + iconSize / 2
            let buttonCenterY = startY + Float(row) * (iconSize + spacing) + iconSize / 2

            // Simple bounding box check
            let left = buttonCenterX - iconSize / 2
            let right = buttonCenterX + iconSize / 2
            let top = buttonCenterY - iconSize / 2
            let bottom = buttonCenterY + iconSize / 2

            if position.x >= left && position.x <= right && position.y >= top && position.y <= bottom {
                // Entity button tapped - select it
                onEntitySelected?(entities[index])
                return true
            }
        }

        // Check cancel button
        let cancelLeft = cancelButton.frame.center.x - cancelButton.frame.size.x / 2
        let cancelRight = cancelButton.frame.center.x + cancelButton.frame.size.x / 2
        let cancelTop = cancelButton.frame.center.y - cancelButton.frame.size.y / 2
        let cancelBottom = cancelButton.frame.center.y + cancelButton.frame.size.y / 2

        if position.x >= cancelLeft && position.x <= cancelRight &&
           position.y >= cancelTop && position.y <= cancelBottom {
            onCancel?()
            return true
        }

        // Check if tap is within dialog area
        let dialogLeft = screenSize.x / 2 - totalWidth / 2
        let dialogRight = screenSize.x / 2 + totalWidth / 2
        let dialogTop = screenSize.y / 2 - totalHeight / 2
        let dialogBottom = screenSize.y / 2 + totalHeight / 2

        if position.x >= dialogLeft && position.x <= dialogRight &&
           position.y >= dialogTop && position.y <= dialogBottom {
            // Tap is within dialog but not on any interactive element - consume the tap
            print("EntitySelectionDialog: Tap consumed within dialog bounds at (\(position.x), \(position.y))")
            return true
        }

        // Tap outside dialog - close it
        onCancel?()
        return true
    }
    
    func handleDoubleTap(at position: Vector2) -> Bool {
        guard isOpen else { return false }

        // Calculate grid layout (same as in handleTap)
        let iconSize: Float = 80 * UIScale
        let spacing: Float = 20 * UIScale
        let padding: Float = 40 * UIScale
        let cols = min(3, entities.count)
        let rows = (entities.count + cols - 1) / cols
        let totalWidth = Float(cols) * iconSize + Float(cols - 1) * spacing + padding * 2
        let totalHeight = Float(rows) * iconSize + Float(rows - 1) * spacing + padding * 2 + 100

        let startX = (screenSize.x - totalWidth) / 2 + padding
        let startY = (screenSize.y - totalHeight) / 2 + padding

        // Check if double tap is within any entity area
        for (index, _) in entities.enumerated() {
            let row = index / cols
            let col = index % cols

            let buttonCenterX = startX + Float(col) * (iconSize + spacing) + iconSize / 2
            let buttonCenterY = startY + Float(row) * (iconSize + spacing) + iconSize / 2

            // Simple bounding box check
            let left = buttonCenterX - iconSize / 2
            let right = buttonCenterX + iconSize / 2
            let top = buttonCenterY - iconSize / 2
            let bottom = buttonCenterY + iconSize / 2

            if position.x >= left && position.x <= right && position.y >= top && position.y <= bottom {
                // Entity double-tapped
                print("EntitySelectionDialog: Double-tap detected on entity \(index) at position (\(position.x), \(position.y))")
                print("EntitySelectionDialog: Button bounds: left=\(left), right=\(right), top=\(top), bottom=\(bottom)")
                onEntityDoubleTapped?(entities[index])
                return true
            }
        }

        // Double tap outside dialog - ignore it (don't close dialog)
        return false
    }
    
    func update(deltaTime: Float) {
        cancelButton.update(deltaTime: deltaTime)
    }
    
    func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        
        // Render background
        let iconSize: Float = 80 * UIScale
        let spacing: Float = 20 * UIScale
        let padding: Float = 40 * UIScale
        
        let cols = min(3, entities.count)
        let rows = (entities.count + cols - 1) / cols
        
        let totalWidth = Float(cols) * iconSize + Float(cols - 1) * spacing + padding * 2
        let totalHeight = Float(rows) * iconSize + Float(rows - 1) * spacing + padding * 2 + 100
        
        let bgRect = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(totalWidth, totalHeight)
        )
        
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: bgRect.center,
            size: bgRect.size,
            textureRect: solidRect,
            color: Color(r: 0.1, g: 0.1, b: 0.15, a: 0.95),
            layer: .ui
        ))
        
        // Render entity icons directly
        let startX = (screenSize.x - totalWidth) / 2 + padding
        let startY = (screenSize.y - totalHeight) / 2 + padding

        for (index, entity) in entities.enumerated() {
            let row = index / cols
            let col = index % cols

            let x = startX + Float(col) * (iconSize + spacing) + iconSize / 2
            let y = startY + Float(row) * (iconSize + spacing) + iconSize / 2

            let textureId = getEntityTextureId(entity: entity, gameLoop: gameLoop!)
            let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)

            renderer.queueSprite(SpriteInstance(
                position: Vector2(x, y),
                size: Vector2(iconSize, iconSize),
                textureRect: textureRect,
                color: .white,
                layer: .ui
            ))
        }
        
        // Render cancel button
        cancelButton.render(renderer: renderer)
    }
}

protocol UIElement {
    var frame: Rect { get }
    func handleTap(at position: Vector2) -> Bool
}

// MARK: - Base UI Components

@available(iOS 17.0, *)
class UIButton: UIElement {
    var frame: Rect
    var textureId: String
    var label: String = ""
    var isEnabled: Bool = true
    var isPressed: Bool = false
    var onTap: (() -> Void)?

    init(frame: Rect, textureId: String = "solid_white") {
        self.frame = frame
        self.textureId = textureId
    }
    
    func handleTap(at position: Vector2) -> Bool {
        print("UIButton: handleTap called at (\(position.x), \(position.y)), frame: center=(\(frame.center.x), \(frame.center.y)) size=(\(frame.size.x), \(frame.size.y)), enabled=\(isEnabled)")
        guard isEnabled && frame.contains(position) else {
            print("UIButton: Tap not detected - enabled: \(isEnabled), contains: \(frame.contains(position))")
            return false
        }
        print("UIButton: Tap detected, calling onTap")
        onTap?()
        return true
    }

    func update(deltaTime: Float) {
        // Handle button animations or state changes if needed
    }
    
    func render(renderer: MetalRenderer) {
        let color = isEnabled ? (isPressed ? Color(r: 0.8, g: 0.8, b: 0.8, a: 1) : .white) : Color(r: 0.5, g: 0.5, b: 0.5, a: 1)

        let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)

        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: textureRect,
            color: color,
            layer: .ui
        ))
    }
}

@available(iOS 17.0, *)
class UIPanel_Base {
    var frame: Rect
    var isOpen: Bool = false
    var backgroundColor: Color = Color(r: 0.1, g: 0.1, b: 0.15, a: 1.0) // Changed from 0.95 to 1.0 for full opacity
    
    init(frame: Rect) {
        self.frame = frame
    }
    
    func open() {
        isOpen = true
    }
    
    func close() {
        isOpen = false
    }
    
    func update(deltaTime: Float) {}
    
    func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")

        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: backgroundColor,
            layer: .ui
        ))

    }

    
    func handleTap(at position: Vector2) -> Bool {
        return frame.contains(position)
    }
    
    func handleDrag(from startPos: Vector2, to endPos: Vector2) -> Bool {
        return false
    }
}

@available(iOS 17.0, *)
class CloseButton: UIElement {
    var frame: Rect
    var onTap: (() -> Void)?

    init(frame: Rect) {
        self.frame = frame
    }

    func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        onTap?()
        return true
    }

    func render(renderer: MetalRenderer) {
        // Render background circle
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        renderer.queueSprite(SpriteInstance(
            position: frame.center,
            size: frame.size,
            textureRect: solidRect,
            color: Color(r: 0.3, g: 0.3, b: 0.3, a: 1),
            layer: .ui
        ))

        // Render X symbol using diagonal lines made of small squares
        let squareSize: Float = 3 * UIScale
        let spacing = squareSize * 1.2
        let numSquares = 5

        // First diagonal (top-left to bottom-right)
        for i in 0..<numSquares {
            let t = Float(i) / Float(numSquares - 1) - 0.5
            let pos = frame.center + Vector2(t * spacing * 2, t * spacing * 2)
            renderer.queueSprite(SpriteInstance(
                position: pos,
                size: Vector2(squareSize, squareSize),
                textureRect: solidRect,
                color: .white,
                layer: .ui
            ))
        }

        // Second diagonal (top-right to bottom-left)
        for i in 0..<numSquares {
            let t = Float(i) / Float(numSquares - 1) - 0.5
            let pos = frame.center + Vector2(-t * spacing * 2, t * spacing * 2)
            renderer.queueSprite(SpriteInstance(
                position: pos,
                size: Vector2(squareSize, squareSize),
                textureRect: solidRect,
                color: .white,
                layer: .ui
            ))
        }
    }
}

// MARK: - Inserter Connection Dialog

@available(iOS 17.0, *)
class InserterConnectionDialog {
    private weak var gameLoop: GameLoop?
    private weak var renderer: MetalRenderer?
    private weak var inputManager: InputManager?
    private var screenSize: Vector2
    
    private var inserterEntity: Entity?
    private var setInputButton: UIButton
    private var setOutputButton: UIButton
    private var cancelButton: UIButton
    private var clearInputButton: UIButton
    private var clearOutputButton: UIButton
    
    var onInputSet: ((Entity, Entity?, IntVector2?) -> Void)?
    var onOutputSet: ((Entity, Entity?, IntVector2?) -> Void)?
    var onCancel: (() -> Void)?
    
    var isOpen: Bool = false
    var isSelectingInput: Bool = false
    var isSelectingOutput: Bool = false
    
    init(screenSize: Vector2, gameLoop: GameLoop?, renderer: MetalRenderer?) {
        self.screenSize = screenSize
        self.gameLoop = gameLoop
        self.renderer = renderer
        
        // Get button sizes from textures
        let buttonHeight: Float = 60 * UIScale
        let spacing: Float = 20 * UIScale
        let buttonWidth: Float = 200 * UIScale
        
        let centerX = screenSize.x / 2
        let startY = screenSize.y / 2 - 100 * UIScale
        
        // Set Input button
        setInputButton = UIButton(
            frame: Rect(
                center: Vector2(centerX, startY),
                size: Vector2(buttonWidth, buttonHeight)
            ),
            textureId: "inserter_input_button"
        )
        
        // Set Output button
        setOutputButton = UIButton(
            frame: Rect(
                center: Vector2(centerX, startY + buttonHeight + spacing),
                size: Vector2(buttonWidth, buttonHeight)
            ),
            textureId: "inserter_output_button"
        )
        
        // Clear Input button - 32x32 pixels, positioned to the right of setInputButton
        let clearButtonSize: Float = 32 * UIScale
        let clearInputX = centerX + buttonWidth / 2 + spacing / 2 + clearButtonSize / 2
        clearInputButton = UIButton(
            frame: Rect(
                center: Vector2(clearInputX, startY),
                size: Vector2(clearButtonSize, clearButtonSize)
            ),
            textureId: "clear"
        )
        
        // Clear Output button - 32x32 pixels, positioned to the right of setOutputButton
        let clearOutputX = centerX + buttonWidth / 2 + spacing / 2 + clearButtonSize / 2
        clearOutputButton = UIButton(
            frame: Rect(
                center: Vector2(clearOutputX, startY + buttonHeight + spacing),
                size: Vector2(clearButtonSize, clearButtonSize)
            ),
            textureId: "clear"
        )
        
        // Cancel button
        let cancelSize = renderer?.textureAtlas.getTextureSize(for: "inserter_cancel_button") ?? (width: 810, height: 345)
        let cancelAspectRatio = Float(cancelSize.width) / Float(cancelSize.height)
        let cancelWidth = buttonHeight * cancelAspectRatio
        cancelButton = UIButton(
            frame: Rect(
                center: Vector2(centerX, startY + (buttonHeight + spacing) * 2),
                size: Vector2(cancelWidth, buttonHeight)
            ),
            textureId: "inserter_cancel_button"
        )
        
        setInputButton.onTap = { [weak self] in
            guard let self = self, let inserterEntity = self.inserterEntity else { return }
            // Close dialog and enter connection mode
            self.onCancel?()
            // Enter connection mode via input manager
            if let inputManager = self.inputManager {
                inputManager.enterInserterConnectionMode(inserter: inserterEntity, isInput: true)
            }
        }
        
        setOutputButton.onTap = { [weak self] in
            guard let self = self, let inserterEntity = self.inserterEntity else { return }
            // Close dialog and enter connection mode
            self.onCancel?()
            // Enter connection mode via input manager
            if let inputManager = self.inputManager {
                inputManager.enterInserterConnectionMode(inserter: inserterEntity, isInput: false)
            }
        }
        
        clearInputButton.onTap = { [weak self] in
            guard let self = self, let entity = self.inserterEntity else { return }
            self.onInputSet?(entity, nil, nil)
        }
        
        clearOutputButton.onTap = { [weak self] in
            guard let self = self, let entity = self.inserterEntity else { return }
            self.onOutputSet?(entity, nil, nil)
        }
        
        cancelButton.onTap = { [weak self] in
            self?.onCancel?()
        }
    }
    
    func setInserter(entity: Entity) {
        self.inserterEntity = entity
        self.isSelectingInput = false
        self.isSelectingOutput = false
    }
    
    func setInputManager(_ inputManager: InputManager?) {
        self.inputManager = inputManager
    }
    
    func handleConnectionSelection(at worldPos: Vector2, tilePos: IntVector2) -> Bool {
        guard let gameLoop = gameLoop, let inserterEntity = inserterEntity else { return false }
        guard let inserterPos = gameLoop.world.get(PositionComponent.self, for: inserterEntity) else { return false }
        
        // Check all tiles within 1 tile (including diagonals) from inserter to find entities
        // This ensures we catch multi-tile entities even if the tapped tile isn't adjacent
        var allFoundEntities: Set<Entity> = []
        let inserterTile = inserterPos.tilePosition
        
        // Check all adjacent tiles (including diagonals)
        for dy in -1...1 {
            for dx in -1...1 {
                // Skip center tile (that's the inserter itself)
                if dx == 0 && dy == 0 { continue }
                
                let checkTile = IntVector2(x: inserterTile.x + Int32(dx), y: inserterTile.y + Int32(dy))
                let entitiesAtTile = gameLoop.world.getAllEntitiesAt(position: checkTile)
                for entity in entitiesAtTile {
                    allFoundEntities.insert(entity)
                }
            }
        }
        
        // Also check the tapped position (in case user taps on a tile 2+ away but still valid)
        // but only if it's within reasonable range
        let distance = abs(tilePos.x - inserterTile.x) + abs(tilePos.y - inserterTile.y)
        if distance <= 2 {
            let entitiesAtTappedPos = gameLoop.world.getAllEntitiesAt(position: tilePos)
            for entity in entitiesAtTappedPos {
                allFoundEntities.insert(entity)
            }
        }
        
        // Filter to valid targets (belt, miner, machine, boiler, etc.)
        // For multi-tile entities, verify that at least one tile is within 1 tile of the inserter
        let validEntities = Array(allFoundEntities.filter { entity in
            // Check if entity has valid components
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
            let hasMiner = gameLoop.world.has(MinerComponent.self, for: entity)
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            let hasAssembler = gameLoop.world.has(AssemblerComponent.self, for: entity)
            let hasChest = gameLoop.world.has(ChestComponent.self, for: entity)
            let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entity)
            let isValidType = hasBelt || hasMiner || hasFurnace || hasAssembler || hasChest || hasGenerator
            
            guard isValidType else { return false }
            
            // For all entities (single or multi-tile), verify at least one tile is within 1 tile of inserter
            guard let entityPos = gameLoop.world.get(PositionComponent.self, for: entity) else { return false }
            let entityOrigin = entityPos.tilePosition
            
            // Get entity size from sprite component
            let sprite = gameLoop.world.get(SpriteComponent.self, for: entity)
            let width = sprite != nil ? Int32(ceil(sprite!.size.x)) : 1
            let height = sprite != nil ? Int32(ceil(sprite!.size.y)) : 1
            
            // Check if any tile of this entity is within 1 tile of the inserter
            for y in entityOrigin.y..<(entityOrigin.y + height) {
                for x in entityOrigin.x..<(entityOrigin.x + width) {
                    let entityTile = IntVector2(x: x, y: y)
                    let tileDistance = abs(entityTile.x - inserterTile.x) + abs(entityTile.y - inserterTile.y)
                    if tileDistance <= 2 {
                        return true  // Found at least one tile within range
                    }
                }
            }
            
            return false  // No tiles within range
        })
        
        // Debug logging
        print("InserterConnectionDialog: Found \(allFoundEntities.count) entities near inserter, \(validEntities.count) are valid")
        for entity in allFoundEntities {
            let hasGenerator = gameLoop.world.has(GeneratorComponent.self, for: entity)
            let hasBelt = gameLoop.world.has(BeltComponent.self, for: entity)
            let hasFurnace = gameLoop.world.has(FurnaceComponent.self, for: entity)
            print("InserterConnectionDialog: Entity \(entity.id) - Generator: \(hasGenerator), Belt: \(hasBelt), Furnace: \(hasFurnace)")
        }
        
        // If multiple entities found, show selection dialog
        if validEntities.count > 1 {
            print("InserterConnectionDialog: Found \(validEntities.count) valid entities, showing selection dialog")
            gameLoop.uiSystem?.showEntitySelectionDialog(entities: validEntities) { [weak self] selectedEntity in
                guard let self = self else { return }
                if self.isSelectingInput {
                    print("InserterConnectionDialog: User selected input entity \(selectedEntity.id)")
                    self.onInputSet?(self.inserterEntity!, selectedEntity, nil)
                    self.isSelectingInput = false
                } else if self.isSelectingOutput {
                    print("InserterConnectionDialog: User selected output entity \(selectedEntity.id)")
                    self.onOutputSet?(self.inserterEntity!, selectedEntity, nil)
                    self.isSelectingOutput = false
                }
            }
            return true
        } else if let targetEntity = validEntities.first {
            // Single entity found, connect directly
            if isSelectingInput {
                print("InserterConnectionDialog: Setting input target entity to \(targetEntity.id) (hasBelt: \(gameLoop.world.has(BeltComponent.self, for: targetEntity)), hasGenerator: \(gameLoop.world.has(GeneratorComponent.self, for: targetEntity)))")
                onInputSet?(inserterEntity, targetEntity, nil)
                isSelectingInput = false
                return true
            } else if isSelectingOutput {
                print("InserterConnectionDialog: Setting output target entity to \(targetEntity.id) (hasBelt: \(gameLoop.world.has(BeltComponent.self, for: targetEntity)), hasGenerator: \(gameLoop.world.has(GeneratorComponent.self, for: targetEntity)))")
                onOutputSet?(inserterEntity, targetEntity, nil)
                isSelectingOutput = false
                return true
            }
        }
        
        print("InserterConnectionDialog: No valid target found at position \(tilePos) (inserter at \(inserterTile))")
        return false
    }
    
    func handleTap(at screenPos: Vector2) -> Bool {
        if setInputButton.handleTap(at: screenPos) { return true }
        if setOutputButton.handleTap(at: screenPos) { return true }
        if clearInputButton.handleTap(at: screenPos) { return true }
        if clearOutputButton.handleTap(at: screenPos) { return true }
        if cancelButton.handleTap(at: screenPos) { return true }
        return false
    }
    
    func update(deltaTime: Float) {
        setInputButton.update(deltaTime: deltaTime)
        setOutputButton.update(deltaTime: deltaTime)
        clearInputButton.update(deltaTime: deltaTime)
        clearOutputButton.update(deltaTime: deltaTime)
        cancelButton.update(deltaTime: deltaTime)
    }
    
    func open() {
        isOpen = true
    }
    
    func close() {
        isOpen = false
        isSelectingInput = false
        isSelectingOutput = false
    }
    
    func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        
        // Render background - wider to accommodate buttons and icons
        let solidRect = renderer.textureAtlas.getTextureRect(for: "solid_white")
        let bgWidth: Float = 500 * UIScale
        let bgHeight: Float = 400 * UIScale
        let bgRect = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(bgWidth, bgHeight)
        )
        renderer.queueSprite(SpriteInstance(
            position: bgRect.center,
            size: bgRect.size,
            textureRect: solidRect,
            color: Color(r: 0.1, g: 0.1, b: 0.15, a: 0.9),
            layer: .ui
        ))
        
        // Render buttons
        setInputButton.render(renderer: renderer)
        setOutputButton.render(renderer: renderer)
        clearInputButton.render(renderer: renderer)
        clearOutputButton.render(renderer: renderer)
        cancelButton.render(renderer: renderer)
        
        // Render connection status with icons
        if let gameLoop = gameLoop, let inserterEntity = inserterEntity,
           let inserter = gameLoop.world.get(InserterComponent.self, for: inserterEntity) {
            
            let iconSize: Float = 50 * UIScale
            let iconSpacing: Float = 10 * UIScale
            let buttonHeight: Float = 60 * UIScale
            let spacing: Float = 20 * UIScale
            let startY = screenSize.y / 2 - 100 * UIScale
            let centerX = screenSize.x / 2
            let buttonWidth: Float = 200 * UIScale
            
            print("InserterConnectionDialog: Rendering icons - inputTarget: \(inserter.inputTarget != nil ? "set" : "nil"), inputPosition: \(inserter.inputPosition != nil ? "set" : "nil"), outputTarget: \(inserter.outputTarget != nil ? "set" : "nil"), outputPosition: \(inserter.outputPosition != nil ? "set" : "nil")")
            
            // Render input target icon (to the right of clearInputButton)
            let clearButtonSize: Float = 32 * UIScale
            let clearInputX = centerX + buttonWidth / 2 + spacing / 2 + clearButtonSize / 2
            
            if let inputTarget = inserter.inputTarget {
                print("InserterConnectionDialog: Rendering input target icon for entity \(inputTarget)")
                let iconX = clearInputX + clearButtonSize / 2 + iconSpacing + iconSize / 2
                let iconY = startY
                if let sprite = gameLoop.world.get(SpriteComponent.self, for: inputTarget) {
                    var textureId = sprite.textureId
                    // Handle belt directional textures
                    if textureId.contains("_belt_") {
                        let parts = textureId.split(separator: "_")
                        if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                            textureId = parts[0...beltIndex].joined(separator: "_")
                        }
                    }
                    let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)
                    print("InserterConnectionDialog: Rendering input entity icon at (\(iconX), \(iconY)) with texture '\(textureId)'")
                    renderer.queueSprite(SpriteInstance(
                        position: Vector2(iconX, iconY),
                        size: Vector2(iconSize, iconSize),
                        textureRect: textureRect,
                        layer: .ui
                    ))
                } else {
                    print("InserterConnectionDialog: Input target entity \(inputTarget) has no sprite component")
                }
            } else if let inputPos = inserter.inputPosition {
                print("InserterConnectionDialog: Rendering input position icon for belt at \(inputPos)")
                // Render belt icon for position-based input
                let iconX = clearInputX + clearButtonSize / 2 + iconSpacing + iconSize / 2
                let iconY = startY
                // Try to find belt entity at this position to get its texture
                var beltTextureId = "transport_belt" // Default belt texture
                let entitiesAtPos = gameLoop.world.getAllEntitiesAt(position: inputPos)
                for entity in entitiesAtPos {
                    if gameLoop.world.has(BeltComponent.self, for: entity),
                       let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) {
                        var textureId = sprite.textureId
                        // Handle belt directional textures
                        if textureId.contains("_belt_") {
                            let parts = textureId.split(separator: "_")
                            if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                                textureId = parts[0...beltIndex].joined(separator: "_")
                            }
                        }
                        beltTextureId = textureId
                        break
                    }
                }
                print("InserterConnectionDialog: Using belt texture '\(beltTextureId)' for input position")
                let textureRect = renderer.textureAtlas.getTextureRect(for: beltTextureId)
                renderer.queueSprite(SpriteInstance(
                    position: Vector2(iconX, iconY),
                    size: Vector2(iconSize, iconSize),
                    textureRect: textureRect,
                    layer: .ui
                ))
            }
            
            // Render output target icon (to the right of clearOutputButton)
            let clearOutputX = centerX + buttonWidth / 2 + spacing / 2 + clearButtonSize / 2
            
            if let outputTarget = inserter.outputTarget {
                print("InserterConnectionDialog: Rendering output target icon for entity \(outputTarget)")
                let iconX = clearOutputX + clearButtonSize / 2 + iconSpacing + iconSize / 2
                let iconY = startY + buttonHeight + spacing
                if let sprite = gameLoop.world.get(SpriteComponent.self, for: outputTarget) {
                    var textureId = sprite.textureId
                    // Handle belt directional textures
                    if textureId.contains("_belt_") {
                        let parts = textureId.split(separator: "_")
                        if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                            textureId = parts[0...beltIndex].joined(separator: "_")
                        }
                    }
                    let textureRect = renderer.textureAtlas.getTextureRect(for: textureId)
                    print("InserterConnectionDialog: Rendering output entity icon at (\(iconX), \(iconY)) with texture '\(textureId)'")
                    renderer.queueSprite(SpriteInstance(
                        position: Vector2(iconX, iconY),
                        size: Vector2(iconSize, iconSize),
                        textureRect: textureRect,
                        layer: .ui
                    ))
                } else {
                    print("InserterConnectionDialog: Output target entity \(outputTarget) has no sprite component")
                }
            } else if let outputPos = inserter.outputPosition {
                print("InserterConnectionDialog: Rendering output position icon for belt at \(outputPos)")
                // Render belt icon for position-based output
                let iconX = clearOutputX + clearButtonSize / 2 + iconSpacing + iconSize / 2
                let iconY = startY + buttonHeight + spacing
                // Try to find belt entity at this position to get its texture
                var beltTextureId = "transport_belt" // Default belt texture
                let entitiesAtPos = gameLoop.world.getAllEntitiesAt(position: outputPos)
                for entity in entitiesAtPos {
                    if gameLoop.world.has(BeltComponent.self, for: entity),
                       let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) {
                        var textureId = sprite.textureId
                        // Handle belt directional textures
                        if textureId.contains("_belt_") {
                            let parts = textureId.split(separator: "_")
                            if let beltIndex = parts.firstIndex(where: { $0 == "belt" }) {
                                textureId = parts[0...beltIndex].joined(separator: "_")
                            }
                        }
                        beltTextureId = textureId
                        break
                    }
                }
                print("InserterConnectionDialog: Using belt texture '\(beltTextureId)' for output position")
                let textureRect = renderer.textureAtlas.getTextureRect(for: beltTextureId)
                renderer.queueSprite(SpriteInstance(
                    position: Vector2(iconX, iconY),
                    size: Vector2(iconSize, iconSize),
                    textureRect: textureRect,
                    layer: .ui
                ))
            }
        } else {
            print("InserterConnectionDialog: Cannot render icons - gameLoop or inserterEntity is nil, or inserter component not found")
        }
    }
}
