import UIKit
import MetalKit
import Security
import Darwin

class GameViewController: UIViewController {
    private var metalView: MTKView!
    private var renderer: MetalRenderer!
    private var gameLoop: GameLoop?
    private var inputManager: InputManager?
    private var uiSystem: UISystem?
    
    // Tooltip label
    private var tooltipLabel: UILabel!
    private var tooltipHideTimer: Timer?

    // Game over UI
    private var gameOverLabel: UILabel!
    private var menuButtonLabel: UILabel!
    
    // Splash screen
    private var splashImageView: UIImageView!
    private var splashTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupMetalView()
        setupRenderer()
        setupUISystem()
        setupSplashScreen()
        setupNotifications()
        setupTooltip()
        setupGameOverUI()

        // Ensure splash screen is on top after all views are added
        if let splash = splashImageView {
            view.bringSubviewToFront(splash)
        }

        print("View bounds: \(view.bounds), scale: \(UIScreen.main.scale)")
        print("Metal view bounds: \(metalView.bounds)")
    }
    
    private func setupSplashScreen() {
        // Create splash image view
        splashImageView = UIImageView()
        splashImageView.image = UIImage(named: "splash")
        splashImageView.contentMode = .scaleAspectFit  // Fit the entire image on screen
        splashImageView.clipsToBounds = true
        splashImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splashImageView)

        // Make splash screen cover entire view
        NSLayoutConstraint.activate([
            splashImageView.topAnchor.constraint(equalTo: view.topAnchor),
            splashImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splashImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splashImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Bring splash screen to front
        view.bringSubviewToFront(splashImageView)

        // After 3 seconds, hide splash and show loading menu
        splashTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hideSplashAndShowLoadingMenu()
        }
    }

    private func hideSplashAndShowLoadingMenu() {
        // Fade out splash screen
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.splashImageView?.alpha = 0.0
        }) { [weak self] _ in
            self?.splashImageView?.removeFromSuperview()
            self?.splashImageView = nil
            self?.splashTimer?.invalidate()
            self?.splashTimer = nil

            // Now show loading menu
            self?.setupLoadingMenu()
        }
    }

    private func setupTooltip() {
        tooltipLabel = UILabel()
        tooltipLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        tooltipLabel.textColor = .black
        tooltipLabel.textAlignment = .center
        tooltipLabel.backgroundColor = .clear
        tooltipLabel.numberOfLines = 0  // Allow unlimited lines
        tooltipLabel.isHidden = true
        tooltipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tooltipLabel)

        NSLayoutConstraint.activate([
            tooltipLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            tooltipLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tooltipLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            tooltipLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }

    func showTooltip(_ text: String, duration: TimeInterval = 3.0) {
        // Create attributed string with black text and white outline
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // Set black text color
        attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: range)
        
        // Add white stroke/outline (negative stroke width creates an outline)
        attributedString.addAttribute(.strokeColor, value: UIColor.white, range: range)
        attributedString.addAttribute(.strokeWidth, value: -3.0, range: range)
        
        tooltipLabel.attributedText = attributedString
        tooltipLabel.isHidden = false
        
        // Cancel existing timer
        tooltipHideTimer?.invalidate()
        
        // Hide after duration
        tooltipHideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hideTooltip()
        }
    }
    
    private func hideTooltip() {
        tooltipLabel.isHidden = true
        tooltipHideTimer?.invalidate()
        tooltipHideTimer = nil
    }

    private func setupGameOverUI() {
        // GAME OVER label
        gameOverLabel = UILabel()
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        gameOverLabel.textColor = .white
        gameOverLabel.textAlignment = .center
        gameOverLabel.backgroundColor = .clear
        gameOverLabel.isHidden = true
        gameOverLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameOverLabel)

        // MENU button label
        menuButtonLabel = UILabel()
        menuButtonLabel.text = "MENU"
        menuButtonLabel.font = UIFont.systemFont(ofSize: 32, weight: .semibold)
        menuButtonLabel.textColor = .white
        menuButtonLabel.textAlignment = .center
        menuButtonLabel.backgroundColor = .clear
        menuButtonLabel.isHidden = true
        menuButtonLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuButtonLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            gameOverLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gameOverLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),

            menuButtonLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuButtonLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20)
        ])

        // Add tap gesture to menu button
        let menuTapGesture = UITapGestureRecognizer(target: self, action: #selector(menuButtonTapped))
        menuButtonLabel.isUserInteractionEnabled = true
        menuButtonLabel.addGestureRecognizer(menuTapGesture)
    }

    @objc private func menuButtonTapped() {
        print("Game over MENU button tapped")
        gameLoop?.returnToMenu()
    }

    func showGameOverScreen() {
        gameOverLabel.isHidden = false
        menuButtonLabel.isHidden = false
    }

    func hideGameOverScreen() {
        gameOverLabel.isHidden = true
        menuButtonLabel.isHidden = true
    }
    
    private func setupMetalView() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        metalView = MTKView(frame: view.bounds, device: device)
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.preferredFramesPerSecond = 60
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0) // Transparent background
        metalView.isOpaque = false // Allow transparency
        view.addSubview(metalView)
    }
    
    private func setupRenderer() {
        guard let device = metalView.device else { return }
        renderer = MetalRenderer(device: device, view: metalView)
        metalView.delegate = renderer
    }
    
    private func setupUISystem() {
        print("GameViewController: setupUISystem() called")
        // Create UISystem without GameLoop initially
        uiSystem = UISystem(gameLoop: nil, renderer: renderer)
        renderer.uiSystem = uiSystem
        print("GameViewController: UISystem created, uiSystem = \(uiSystem != nil ? "exists" : "nil")")

        // Set up inventory label callbacks
        uiSystem?.getInventoryUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                // Bring labels to front so they're above the metal view
                self?.view.bringSubviewToFront($0)
            }
        }
        uiSystem?.getInventoryUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }

        // Set up machine UI label callbacks
        uiSystem?.getMachineUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                // Bring labels to front so they're above the metal view
                self?.view.bringSubviewToFront($0)
            }
        }
        uiSystem?.getMachineUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }

        // Set up research UI label callbacks
        uiSystem?.getResearchUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                // Bring labels to front so they're above the metal view
                self?.view.bringSubviewToFront($0)
                // Also ensure they're above the Metal view by inserting at the top
                if let metalView = self?.metalView {
                    self?.view.insertSubview($0, aboveSubview: metalView)
                }
            }
        }
        uiSystem?.getResearchUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }

        // Set up crafting menu label callbacks
        print("GameViewController: Setting up CraftingMenu callbacks in setupUISystem")
        let craftingMenu = uiSystem?.getCraftingMenu()
        print("GameViewController: Got CraftingMenu instance: \(craftingMenu != nil ? "exists" : "nil")")
        craftingMenu?.onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            print("GameViewController: onAddLabels callback called with \(labels.count) labels")
            guard let self = self else {
                print("GameViewController: ERROR - self is nil in onAddLabels callback!")
                return
            }
            print("GameViewController: Adding labels to view, view.bounds=\(self.view.bounds)")
            labels.forEach {
                let originalFrame = $0.frame
                print("GameViewController: Adding label '\($0.text ?? "")' with frame=\(originalFrame)")
                self.view.addSubview($0)
                // Set frame again after adding to view (in case it was reset)
                $0.frame = originalFrame
                print("GameViewController: Frame after adding: \($0.frame)")
                // Bring labels to front so they're above the metal view
                self.view.bringSubviewToFront($0)
                // Also ensure they're above the Metal view by inserting at the top
                if let metalView = self.metalView {
                    self.view.insertSubview($0, aboveSubview: metalView)
                    // Set frame again after inserting (in case it was reset)
                    $0.frame = originalFrame
                    print("GameViewController: Frame after inserting: \($0.frame)")
                } else {
                    print("GameViewController: WARNING - metalView is nil!")
                }
                print("GameViewController: Final frame: \($0.frame), superview=\($0.superview != nil ? "exists" : "nil")")
                // Force layout to ensure frame is applied
                $0.setNeedsLayout()
                $0.layoutIfNeeded()
                print("GameViewController: Frame after layout: \($0.frame)")
            }
        }
        craftingMenu?.onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }
        print("GameViewController: CraftingMenu callback setup complete. onAddLabels = \(craftingMenu?.onAddLabels != nil ? "set" : "nil")")
    }
    
    private func setupLoadingMenu() {
        guard let uiSystem = uiSystem else { return }
        
        // Show loading menu
        uiSystem.openPanel(.loadingMenu)
        
        // Setup callbacks
        let loadingMenu = uiSystem.getLoadingMenu()
        print("GameViewController: Setting up LoadingMenu callbacks")
        loadingMenu.onNewGameSelected = { [weak self] in
            self?.startNewGame()
        }
        
        loadingMenu.onSaveSlotSelected = { [weak self] slotName in
            self?.loadGame(from: slotName)
        }
        
        loadingMenu.onSaveSlotDelete = { [weak self] slotName in
            self?.deleteSave(slotName: slotName)
        }
        
        loadingMenu.onSaveGameRequested = { [weak self] in
            self?.saveCurrentGame()
        }

        loadingMenu.onCloseTapped = { [weak self] in
            self?.uiSystem?.closeAllPanels()
            // Force multiple redraws to ensure HUD renders properly after menu closes
            self?.metalView.setNeedsDisplay()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.metalView.setNeedsDisplay()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.metalView.setNeedsDisplay()
            }
        }
        
        // Setup UILabel overlays for save slot information
        loadingMenu.setupLabels(in: view)
        
        // Setup input manager for loading menu (before gameLoop exists)
        setupInputForLoadingMenu()
    }
    
    private func setupInputForLoadingMenu() {
        // Create InputManager without GameLoop initially (it will be set later)
        inputManager = InputManager(view: metalView, gameLoop: nil, renderer: renderer)

        // Set inputManager on UI system so HUD can access build mode
        uiSystem?.setInputManager(inputManager!)
    }
    
    private func startNewGame() {
        // Clear any saved chunks from previous games to ensure fresh terrain generation
        clearSavedChunks()

        // Create new game with truly random seed using system entropy
        var randomSeed: UInt64 = 0
        let result = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt64>.size, &randomSeed)

        if result != errSecSuccess {
            // Fallback: Use multiple entropy sources to ensure randomness
            let timestamp = UInt64(Date().timeIntervalSince1970 * 1000000)
            let processId = UInt64(getpid())
            let threadId = UInt64(pthread_self().hashValue)

            // Combine multiple sources of entropy
            randomSeed = timestamp ^ processId ^ threadId ^ UInt64.random(in: 1...UInt64.max)
        }

        // Ensure seed is never 0 (which could cause issues)
        if randomSeed == 0 {
            randomSeed = UInt64.random(in: 1...UInt64.max)
        }

        print("GameViewController: Starting new game with random seed: \(randomSeed)")
        print("  - SecRandomCopyBytes result: \(result == errSecSuccess ? "SUCCESS" : "FAILED")")
        gameLoop = GameLoop(renderer: renderer, seed: randomSeed)
        renderer.gameLoop = gameLoop

        // Reset camera to snap to new player position immediately
        if let playerPosition = gameLoop?.player.position {
            renderer.camera.position = playerPosition
            renderer.camera.target = playerPosition
            renderer.camera.zoom = 1.0  // Reset to default zoom
            renderer.camera.targetZoom = 1.0
            // Force camera to snap immediately by resetting its first update flag
            renderer.camera.resetForNewGame()
        }

        // Clear any cached rendering data
        renderer.clearCachesForNewGame()

        // Set UI system on game loop
        gameLoop?.uiSystem = uiSystem

        // Update UI system with game loop
        uiSystem?.setGameLoop(gameLoop!)
        
        // Setup input (this will also set up HUD callbacks)
        setupInput()
        
        // Force immediate redraw after UI system update
        metalView.setNeedsDisplay()

        // Re-set up inventory label callbacks (UI system was recreated)
        uiSystem?.getInventoryUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                // Bring labels to front so they're above the metal view
                self?.view.bringSubviewToFront($0)
            }
        }
        uiSystem?.getInventoryUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }

        // Re-set up machine UI label callbacks
        uiSystem?.getMachineUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                // Bring labels to front so they're above the metal view
                self?.view.bringSubviewToFront($0)
            }
        }
        uiSystem?.getMachineUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }

        // Re-set up research UI label callbacks (UI system was recreated)
        uiSystem?.getResearchUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                // Bring labels to front so they're above the metal view
                self?.view.bringSubviewToFront($0)
                // Also ensure they're above the Metal view by inserting at the top
                if let metalView = self?.metalView {
                    self?.view.insertSubview($0, aboveSubview: metalView)
                }
            }
        }
        uiSystem?.getResearchUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }

        // Re-set up crafting menu label callbacks (UI system was recreated)
        uiSystem?.getCraftingMenu().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            print("GameViewController: onAddLabels callback called with \(labels.count) labels")
            guard let self = self else {
                print("GameViewController: ERROR - self is nil in onAddLabels callback!")
                return
            }
            print("GameViewController: Adding labels to view, view.bounds=\(self.view.bounds)")
            labels.forEach {
                let originalFrame = $0.frame
                print("GameViewController: Adding label '\($0.text ?? "")' with frame=\(originalFrame)")
                self.view.addSubview($0)
                // Set frame again after adding to view (in case it was reset)
                $0.frame = originalFrame
                print("GameViewController: Frame after adding: \($0.frame)")
                // Bring labels to front so they're above the metal view
                self.view.bringSubviewToFront($0)
                // Also ensure they're above the Metal view by inserting at the top
                if let metalView = self.metalView {
                    self.view.insertSubview($0, aboveSubview: metalView)
                    // Set frame again after inserting (in case it was reset)
                    $0.frame = originalFrame
                    print("GameViewController: Frame after inserting: \($0.frame)")
                } else {
                    print("GameViewController: WARNING - metalView is nil!")
                }
                print("GameViewController: Final frame: \($0.frame), superview=\($0.superview != nil ? "exists" : "nil")")
                // Force layout to ensure frame is applied
                $0.setNeedsLayout()
                $0.layoutIfNeeded()
                print("GameViewController: Frame after layout: \($0.frame)")
            }
        }
        uiSystem?.getCraftingMenu().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }

        // Enable save button in loading menu (game is now running)
        uiSystem?.getLoadingMenu().onSaveGameRequested = { [weak self] in
            self?.saveCurrentGame()
        }

        // Ensure renderer has the correct uiSystem reference before closing panels
        if let uiSystem = uiSystem {
            renderer.uiSystem = uiSystem
        }

        // Close loading menu
        uiSystem?.closeAllPanels()

        // Force multiple redraws to ensure HUD renders properly after menu closes
        metalView.setNeedsDisplay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.metalView.setNeedsDisplay()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.metalView.setNeedsDisplay()
        }
        // Force redraw to ensure HUD renders properly after menu closes
        metalView.setNeedsDisplay()
    }
    
    private func loadGame(from slotName: String) {
        let saveSystem = SaveSystem()
        
        // Load save data
        guard let saveData = saveSystem.loadFromSlot(slotName) else {
            print("Failed to load save from slot: \(slotName)")
            return
        }
        
        // Create game loop with save's seed
        gameLoop = GameLoop(renderer: renderer, seed: saveData.seed)
        renderer.gameLoop = gameLoop
        
        // Set UI system on game loop
        gameLoop?.uiSystem = uiSystem
        
        // Load save data into game loop
        saveSystem.load(saveData: saveData, into: gameLoop!)
        
        // Update UI system with game loop
        uiSystem?.setGameLoop(gameLoop!)
        
        // Setup input
        setupInput()

        // Enable save button in loading menu (game is now running)
        uiSystem?.getLoadingMenu().onSaveGameRequested = { [weak self] in
            self?.saveCurrentGame()
        }

        // Update UI system with game loop to ensure HUD has correct reference
        // NOTE: This recreates the HUD, so callbacks must be set AFTER this
        uiSystem?.setGameLoop(gameLoop!)
        
        // Re-setup HUD callbacks after HUD is recreated by setGameLoop
        setupHUDBuildingCallbacks()

        // Re-set up label callbacks (UI system was recreated)
        uiSystem?.getInventoryUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                self?.view.bringSubviewToFront($0)
            }
        }
        uiSystem?.getInventoryUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }
        uiSystem?.getMachineUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                self?.view.bringSubviewToFront($0)
            }
        }
        uiSystem?.getMachineUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }
        uiSystem?.getResearchUI().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            labels.forEach {
                self?.view.addSubview($0)
                self?.view.bringSubviewToFront($0)
                if let metalView = self?.metalView {
                    self?.view.insertSubview($0, aboveSubview: metalView)
                }
            }
        }
        uiSystem?.getResearchUI().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }
        
        // Re-set up crafting menu label callbacks
        print("GameViewController: Setting up CraftingMenu callbacks in loadGame")
        uiSystem?.getCraftingMenu().onAddLabels = { [weak self] (labels: [UILabel]) -> Void in
            print("GameViewController: onAddLabels callback called with \(labels.count) labels")
            guard let self = self else {
                print("GameViewController: ERROR - self is nil in onAddLabels callback!")
                return
            }
            print("GameViewController: Adding labels to view, view.bounds=\(self.view.bounds)")
            labels.forEach {
                let originalFrame = $0.frame
                print("GameViewController: Adding label '\($0.text ?? "")' with frame=\(originalFrame)")
                self.view.addSubview($0)
                // Set frame again after adding to view (in case it was reset)
                $0.frame = originalFrame
                print("GameViewController: Frame after adding: \($0.frame)")
                // Bring labels to front so they're above the metal view
                self.view.bringSubviewToFront($0)
                // Also ensure they're above the Metal view by inserting at the top
                if let metalView = self.metalView {
                    self.view.insertSubview($0, aboveSubview: metalView)
                    // Set frame again after inserting (in case it was reset)
                    $0.frame = originalFrame
                    print("GameViewController: Frame after inserting: \($0.frame)")
                } else {
                    print("GameViewController: WARNING - metalView is nil!")
                }
                print("GameViewController: Final frame: \($0.frame), superview=\($0.superview != nil ? "exists" : "nil")")
                // Force layout to ensure frame is applied
                $0.setNeedsLayout()
                $0.layoutIfNeeded()
                print("GameViewController: Frame after layout: \($0.frame)")
            }
        }
        uiSystem?.getCraftingMenu().onRemoveLabels = { (labels: [UILabel]) -> Void in
            labels.forEach { $0.removeFromSuperview() }
        }

        // Ensure renderer has the correct uiSystem reference
        if let uiSystem = uiSystem {
            renderer.uiSystem = uiSystem
        }

        // Close loading menu
        uiSystem?.closeAllPanels()

        // Update chunk manager with player position to load surrounding chunks
        gameLoop?.chunkManager.update(playerPosition: gameLoop!.player.position)
    }
    
    private func saveCurrentGame() {
        guard let gameLoop = gameLoop else { return }
        
        let saveSystem = SaveSystem()
        
        // Generate a save slot name with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = formatter.string(from: Date())
        let slotName = "save_\(timestamp)"
        
        // Save the game
        saveSystem.save(gameLoop: gameLoop, slotName: slotName)
        
        print("Game saved to slot: \(slotName)")
        
        // Refresh the loading menu to show the new save
        uiSystem?.getLoadingMenu().refreshSaveSlots()
        
        // Close the loading menu after saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // Ensure renderer has the correct uiSystem reference
            if let uiSystem = self?.uiSystem {
                self?.renderer.uiSystem = uiSystem
            }

            self?.uiSystem?.closeAllPanels()
        }
    }
    
    private func deleteSave(slotName: String) {
        let saveSystem = SaveSystem()
        saveSystem.deleteSave(slotName)

        print("Deleted save slot: \(slotName)")

        // Refresh the loading menu to update the save slot list
        uiSystem?.getLoadingMenu().refreshSaveSlots()
    }

    private func returnToMainMenu() {
        print("Returning to main menu from game over")

        // Hide game over screen
        hideGameOverScreen()

        // Clean up current game
        gameLoop = nil

        // Reset renderer
        renderer.gameLoop = nil

        // Update inputManager for menu-only mode (don't destroy it)
        inputManager?.setGameLoop(nil)

        // Setup menu-only callbacks
        inputManager?.onTooltip = { [weak self] text in
            self?.showTooltip(text)
        }

        // Show loading menu
        uiSystem?.openPanel(.loadingMenu)
    }
    
    private func setupInput() {
        guard let gameLoop = gameLoop else { return }
        
        // If InputManager doesn't exist yet, create it
        if inputManager == nil {
            inputManager = InputManager(view: metalView, gameLoop: gameLoop, renderer: renderer)
        } else {
            // Update existing InputManager with gameLoop
            inputManager?.setGameLoop(gameLoop)
        }

        // Set inputManager on UI system so HUD can access build mode
        uiSystem?.setInputManager(inputManager!)
        gameLoop.inputManager = inputManager

        // Setup return to menu callback
        gameLoop.onReturnToMenu = { [weak self] in
            self?.returnToMainMenu()
        }

        // Setup player death callback
        gameLoop.onPlayerDeath = { [weak self] in
            self?.showGameOverScreen()
        }

        // Start background music
        AudioManager.shared.playBackgroundMusic()

        // Setup tooltip callback
        inputManager?.onTooltip = { [weak self] text in
            self?.showTooltip(text)
        }
        
        // Setup entity selection callback - open machine UI for furnaces/assemblers
        inputManager?.onEntitySelected = { [weak self] entity in
            guard let self = self else { return }
            guard let gameLoop = self.gameLoop else { return }
            
            // Update HUD with selected entity
            self.uiSystem?.hud.selectedEntity = entity
            
            // If no entity selected, clear selection
            guard let entity = entity else { return }
            
            let world = gameLoop.world
            
            // Check if it's a machine we can interact with
            if world.has(FurnaceComponent.self, for: entity) {
                print("GameViewController: Furnace selected, opening Machine UI")
                // Open machine UI
                gameLoop.uiSystem?.openMachineUI(for: entity)
            } else if world.has(AssemblerComponent.self, for: entity) {
                print("GameViewController: Assembler selected, opening Machine UI")
                // Open machine UI
                gameLoop.uiSystem?.openMachineUI(for: entity)
            } else if world.has(MinerComponent.self, for: entity) {
                print("GameViewController: Mining drill selected, opening Machine UI")
                // Open machine UI
                gameLoop.uiSystem?.openMachineUI(for: entity)
            } else if world.has(GeneratorComponent.self, for: entity) {
                print("GameViewController: Generator/Boiler selected, opening Machine UI")
                // Open machine UI for generators (boilers, etc.)
                gameLoop.uiSystem?.openMachineUI(for: entity)
            } else if world.has(ChestComponent.self, for: entity) {
                print("GameViewController: Chest selected, opening Inventory UI")
                // Open inventory UI for chest
                gameLoop.uiSystem?.openChestInventory(for: entity)
            } else {
                // Fallback: check if it's a boiler by size/texture (for old saves that don't have GeneratorComponent)
                if let sprite = world.get(SpriteComponent.self, for: entity) {
                    // Boiler is 2x3 tiles
                    if sprite.size.x == 2.0 && sprite.size.y == 3.0 {
                        print("GameViewController: Boiler detected by size (2x3), opening Machine UI")
                        // Open machine UI for boiler
                        gameLoop.uiSystem?.openMachineUI(for: entity)
                    }
                }
            }
        }
        
        // Setup HUD building callbacks
        setupHUDBuildingCallbacks()
    }
    
    private func setupHUDBuildingCallbacks() {
        print("GameViewController: setupHUDBuildingCallbacks() called, uiSystem=\(uiSystem != nil ? "exists" : "nil"), hud=\(uiSystem?.hud != nil ? "exists" : "nil")")
        
        // Setup move building callback
        uiSystem?.hud.onMoveBuildingPressed = { [weak self] in
            print("GameViewController: Move button callback triggered")
            guard let self = self, let _ = self.gameLoop else {
                print("GameViewController: Move callback - self or gameLoop is nil")
                return
            }
            guard let selectedEntity = self.uiSystem?.hud.selectedEntity else {
                print("GameViewController: Move callback - no selected entity")
                return
            }
            
            // Close machine UI if open
            self.uiSystem?.closeAllPanels()
            
            print("GameViewController: Entering move mode for entity \(selectedEntity)")
            // Enter move mode
            self.inputManager?.enterMoveMode(entity: selectedEntity)
            self.showTooltip("Tap where you want to move the building")
        }
        
        // Setup delete building callback
        uiSystem?.hud.onDeleteBuildingPressed = { [weak self] in
            print("GameViewController: Delete button callback triggered")
            guard let self = self, let gameLoop = self.gameLoop else {
                print("GameViewController: Delete callback - self or gameLoop is nil")
                return
            }
            guard let selectedEntity = self.uiSystem?.hud.selectedEntity else {
                print("GameViewController: Delete callback - no selected entity")
                return
            }
            
            // Close machine UI if open
            self.uiSystem?.closeAllPanels()
            
            print("GameViewController: Deleting entity \(selectedEntity)")
            // Delete the building
            if gameLoop.removeBuilding(entity: selectedEntity) {
                // Clear selection
                self.uiSystem?.hud.selectedEntity = nil
                self.inputManager?.selectedEntity = nil
                self.showTooltip("Building deleted")
                print("GameViewController: Building deleted successfully")
            } else {
                self.showTooltip("Failed to delete building")
                print("GameViewController: Failed to delete building")
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(pauseGame), name: .gameShouldPause, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeGame), name: .gameShouldResume, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveGame), name: .gameShouldSave, object: nil)
    }
    
    @objc private func pauseGame() {
        gameLoop?.pause()
    }
    
    @objc private func resumeGame() {
        gameLoop?.resume()
    }
    
    @objc private func saveGame() {
        gameLoop?.save()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Clear all saved chunk files to ensure fresh terrain generation for new games
    private func clearSavedChunks() {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let chunksDir = documentsDir.appendingPathComponent("saves/chunks")

        do {
            // Check if chunks directory exists
            if fileManager.fileExists(atPath: chunksDir.path) {
                // Get all files in the chunks directory
                let chunkFiles = try fileManager.contentsOfDirectory(at: chunksDir, includingPropertiesForKeys: nil)

                // Delete all chunk files (files starting with "chunk_")
                for fileURL in chunkFiles where fileURL.lastPathComponent.hasPrefix("chunk_") {
                    try fileManager.removeItem(at: fileURL)
                    print("GameViewController: Deleted saved chunk: \(fileURL.lastPathComponent)")
                }

                print("GameViewController: Cleared \(chunkFiles.filter { $0.lastPathComponent.hasPrefix("chunk_") }.count) saved chunk files")
            }
        } catch {
            print("GameViewController: Error clearing saved chunks: \(error)")
        }
    }
}

