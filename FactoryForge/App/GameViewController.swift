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
    private var tooltipIconView: UIImageView!
    private var tooltipHideTimer: Timer?

    // Persistent tooltip for selected entity
    private var selectedEntityTooltip: (text: String, entity: Entity?, persistent: Bool) = ("", nil, false)

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
        
        tooltipIconView = UIImageView()
        tooltipIconView.contentMode = .scaleAspectFit
        tooltipIconView.isHidden = true
        tooltipIconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tooltipIconView)

        // Set up icon view constraints (relative to label)
        tooltipIconView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        tooltipIconView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        tooltipIconView.centerYAnchor.constraint(equalTo: tooltipLabel.centerYAnchor).isActive = true
        tooltipIconView.trailingAnchor.constraint(equalTo: tooltipLabel.leadingAnchor, constant: -8).isActive = true
        tooltipIconView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20).isActive = true
        
        // Set up label constraints (can work with or without icon)
        tooltipLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        tooltipLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        tooltipLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20).isActive = true
        tooltipLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20).isActive = true
    }

    func showTooltip(_ text: String, duration: TimeInterval = 3.0) {
        showTooltip(text, entity: nil, duration: duration)
    }

    func showTooltip(_ text: String, entity: Entity?, duration: TimeInterval = 3.0, persistent: Bool = false) {
        // Store tooltip info
        selectedEntityTooltip = (text, entity, persistent)

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

        // Show/hide icon based on entity
        if let entity = entity, let gameLoop = gameLoop {
            // Get texture ID from entity
            let textureId = getEntityTextureId(entity: entity, gameLoop: gameLoop)

            // Load UIImage from bundle using texture ID
            if let image = loadTextureImage(textureId: textureId) {
                tooltipIconView.image = image
                tooltipIconView.isHidden = false
            } else {
                tooltipIconView.isHidden = true
            }
        } else {
            tooltipIconView.isHidden = true
        }

        // Cancel existing timer
        tooltipHideTimer?.invalidate()

        // Only set timer for non-persistent tooltips
        if !persistent {
            // Hide after duration and show persistent tooltip if available
            tooltipHideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.hideTooltip()
            }
        }
    }

    /// Update the persistent tooltip for the selected entity
    func updateSelectedEntityTooltip(entity: Entity?, text: String?) {
        if let entity = entity, let text = text {
            // Set persistent tooltip for selected entity
            showTooltip(text, entity: entity, persistent: true)
        } else {
            // Clear persistent tooltip
            selectedEntityTooltip = ("", nil, false)
            hideTooltip()
        }
    }

    /// Show the persistent tooltip for the selected entity (called when temporary tooltip expires)
    private func showPersistentTooltipIfAvailable() {
        if selectedEntityTooltip.persistent && !selectedEntityTooltip.text.isEmpty {
            showTooltip(selectedEntityTooltip.text, entity: selectedEntityTooltip.entity, persistent: true)
        }
    }
    
    private func getEntityTextureId(entity: Entity, gameLoop: GameLoop) -> String {
        guard let sprite = gameLoop.world.get(SpriteComponent.self, for: entity) else {
            return "solid_white"
        }
        
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
    
    private func loadTextureImage(textureId: String) -> UIImage? {
        // Map texture IDs to actual filenames (some have different names)
        var filename = textureId
        
        // Handle special mappings
        switch textureId {
        case "burner_mining_drill":
            filename = "burner_miner_drill"
        case "transport_belt":
            filename = "belt"
        case "fast_transport_belt":
            filename = "belt"  // Use same image
        case "express_transport_belt":
            filename = "belt"  // Use same image
        default:
            break
        }
        
        // Try to load from bundle
        if let imagePath = Bundle.main.path(forResource: filename, ofType: "png") {
            return UIImage(contentsOfFile: imagePath)
        }
        
        // Try with underscore replacement
        let altFilename = textureId.replacingOccurrences(of: "_", with: "-")
        if let imagePath = Bundle.main.path(forResource: altFilename, ofType: "png") {
            return UIImage(contentsOfFile: imagePath)
        }
        
        return nil
    }
    
    private func hideTooltip() {
        tooltipLabel.isHidden = true
        tooltipIconView.isHidden = true
        tooltipHideTimer?.invalidate()
        tooltipHideTimer = nil

        // Show persistent tooltip if available
        showPersistentTooltipIfAvailable()
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


    private func showAutoplayMenu() {
        guard let uiSystem = uiSystem else { return }

        uiSystem.openPanel(.autoplayMenu)

        let autoplayMenu = uiSystem.getAutoplayMenu()
        print("GameViewController: Setting up AutoPlayMenu callbacks")

        autoplayMenu.onScenarioSelected = { [weak self] (scenarioId: String) in
            // Scenario selection handled - will be used when starting auto-play
        }

        autoplayMenu.onStartAutoplay = { [weak self] (scenarioId: String, speed: Double) in
            guard let self = self, let gameLoop = self.gameLoop else { return }

            // Set the game speed first
            gameLoop.setGameSpeed(speed)

            // Start the scenario
            if let scenario = AutoPlaySystem.builtInScenario(name: scenarioId) {
                gameLoop.startAutoPlayScenario(scenario)
                showTooltip("Started: \(scenario.name)", duration: 2.0)
                uiSystem.closeAllPanels()
            }
        }

        autoplayMenu.onStopAutoplay = { [weak self] in
            self?.gameLoop?.stopAutoPlay()
            self?.showTooltip("Auto-play stopped", duration: 2.0)
        }

        autoplayMenu.onCloseTapped = { [weak self] in
            self?.uiSystem?.closeAllPanels()
            // Force redraws like the loading menu
            self?.metalView.setNeedsDisplay()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.metalView.setNeedsDisplay()
            }
        }

        // Setup text labels
        autoplayMenu.setupLabels(in: view)
    }

    private func showHelpMenu() {
        guard let uiSystem = uiSystem else { return }

        uiSystem.openPanel(.helpMenu)

        let helpMenu = uiSystem.getHelpMenu()
        print("GameViewController: Setting up HelpMenu callbacks")

        helpMenu.onDocumentSelected = { [weak self] (documentName: String) in
            self?.showDocumentViewer(documentName: documentName)
        }

        helpMenu.onCloseTapped = { [weak self] in
            self?.uiSystem?.closeAllPanels()
            // Force redraws like other menus
            self?.metalView.setNeedsDisplay()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.metalView.setNeedsDisplay()
            }
        }

        // Setup text labels
        helpMenu.setupLabels(in: view)
    }

    private func showDocumentViewer(documentName: String) {
        guard let uiSystem = uiSystem else { return }

        uiSystem.openDocumentViewer(documentName: documentName)

        if let documentViewer = uiSystem.getDocumentViewer() {
            print("GameViewController: Setting up DocumentViewer callbacks")

            documentViewer.onCloseTapped = { [weak self] in
                // Go back to help menu instead of closing all panels
                self?.showHelpMenu()
            }

            // Setup text labels
            documentViewer.setupLabels(in: view)
        }
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

        loadingMenu.onAutoplayTapped = { [weak self] in
            self?.showAutoplayMenu()
        }

        loadingMenu.onHelpTapped = { [weak self] in
            self?.showHelpMenu()
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

        // Load initial chunks for new game (no save slot needed for new games)
        gameLoop?.chunkManager.update(playerPosition: gameLoop!.player.position)

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

        // Exit build mode when starting a new game
        inputManager?.exitBuildMode()

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

        // Inserter type dialog uses Metal rendering - no view setup needed

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
        
        // Load save data into game loop (pass slot name so chunks load from correct directory)
        saveSystem.load(saveData: saveData, into: gameLoop!, slotName: slotName)
        
        // Update UI system with game loop
        uiSystem?.setGameLoop(gameLoop!)
        
        // Setup input
        setupInput()

        // Exit build mode when loading a saved game
        inputManager?.exitBuildMode()

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

        // Inserter type dialog uses Metal rendering - no view setup needed

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
            inputManager = InputManager(view: view, gameLoop: gameLoop, renderer: renderer)
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
            self?.showTooltip(text, entity: nil, persistent: false)
        }

        // Setup tooltip callback with entity
        inputManager?.onTooltipWithEntity = { [weak self] text, entity in
            self?.showTooltip(text, entity: entity, persistent: false)
        }
        
        // Setup entity selection callback - open machine UI for furnaces/assemblers
        inputManager?.onEntitySelected = { [weak self] entity in
            guard let self = self else { return }
            guard let gameLoop = self.gameLoop else { return }
            
            // Update HUD with selected entity first (before any UI operations)
            print("GameViewController: onEntitySelected called with entity: \(entity?.id ?? 0)")
            self.uiSystem?.hud.selectedEntity = entity

            // Update renderer with selected entity for highlighting
            self.renderer.selectedEntity = entity

            // Show persistent tooltip for selected entity
            if let entity = entity, let tooltipText = self.inputManager?.getEntityTooltipText(entity: entity, gameLoop: gameLoop) {
                self.updateSelectedEntityTooltip(entity: entity, text: tooltipText)
            } else {
                self.updateSelectedEntityTooltip(entity: nil, text: nil)
            }
            
            // Verify the entity was set correctly in HUD
            if let entity = entity {
                if let hudEntity = self.uiSystem?.hud.selectedEntity {
                    if hudEntity.id != entity.id || hudEntity.generation != entity.generation {
                        print("GameViewController: ERROR - Failed to set HUD selectedEntity correctly!")
                        print("GameViewController: Expected \(entity), but got \(hudEntity)")
                        // Force set it again
                        self.uiSystem?.hud.selectedEntity = entity
                    } else {
                        print("GameViewController: HUD selectedEntity set correctly to \(entity)")
                    }
                }
            }
            
            // If no entity selected, clear selection
            guard let entity = entity else { return }

            let world = gameLoop.world

            // Only open inventory UI for chests automatically (other machines require clicking the Open button)
            if world.has(ChestComponent.self, for: entity) {
                print("GameViewController: Chest selected, opening Inventory UI")
                // Open inventory UI for chest
                gameLoop.uiSystem?.openChestInventory(for: entity)
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
            
            // Get selected entity from HUD and validate it's still the same as InputManager
            guard let hudSelectedEntity = self.uiSystem?.hud.selectedEntity else {
                print("GameViewController: Delete callback - no selected entity in HUD")
                return
            }
            
            // Validate entity is still alive
            guard gameLoop.world.isAlive(hudSelectedEntity) else {
                print("GameViewController: Delete callback - selected entity is no longer alive")
                self.uiSystem?.hud.selectedEntity = nil
                self.inputManager?.selectedEntity = nil
                return
            }
            
            // Verify InputManager also has the same entity selected (safety check)
            if let inputManagerEntity = self.inputManager?.selectedEntity {
                if inputManagerEntity.id != hudSelectedEntity.id || inputManagerEntity.generation != hudSelectedEntity.generation {
                    print("GameViewController: WARNING - HUD and InputManager have different entities selected!")
                    print("GameViewController: HUD entity: \(hudSelectedEntity), InputManager entity: \(inputManagerEntity)")
                    // Use HUD's entity since that's what the user sees selected
                }
            }

            // Debug: check what type of entity is selected
            let isInserter = gameLoop.world.has(InserterComponent.self, for: hudSelectedEntity)
            let isBelt = gameLoop.world.has(BeltComponent.self, for: hudSelectedEntity)
            print("GameViewController: Deleting entity \(hudSelectedEntity) - Inserter: \(isInserter), Belt: \(isBelt)")

            // Close machine UI if open
            self.uiSystem?.closeAllPanels()

            // Delete the building - use the entity from HUD
            if gameLoop.removeBuilding(entity: hudSelectedEntity) {
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
        
        // Setup rotate building callback (for belts)
        uiSystem?.hud.onRotateBuildingPressed = { [weak self] in
            guard let self = self, let gameLoop = self.gameLoop else {
                print("GameViewController: Rotate callback - self or gameLoop is nil")
                return
            }
            guard let selectedEntity = self.uiSystem?.hud.selectedEntity else {
                print("GameViewController: Rotate callback - no selected entity")
                return
            }
            
            // Close machine UI if open
            self.uiSystem?.closeAllPanels()
            
            print("GameViewController: Rotating belt entity \(selectedEntity)")
            // Rotate the belt
            if gameLoop.rotateBelt(entity: selectedEntity) {
                self.showTooltip("Belt rotated")
                print("GameViewController: Belt rotated successfully")
            } else {
                self.showTooltip("Failed to rotate belt")
                print("GameViewController: Failed to rotate belt")
            }
        }
        
        uiSystem?.hud.onOpenMachinePressed = { [weak self] in
            guard let self = self else {
                print("GameViewController: Open callback - self is nil")
                return
            }
            guard let selectedEntity = self.uiSystem?.hud.selectedEntity else {
                print("GameViewController: Open callback - no selected entity")
                return
            }
            
            guard let _ = self.gameLoop else { return }
            
            print("GameViewController: Open button pressed for entity \(selectedEntity)")
            
            // Otherwise, open the machine UI for the selected entity
            self.uiSystem?.openMachineUI(for: selectedEntity)
        }
        
        uiSystem?.hud.onConfigureInserterPressed = { [weak self] in
            guard let self = self else {
                print("GameViewController: Configure inserter callback - self is nil")
                return
            }
            guard let selectedEntity = self.uiSystem?.hud.selectedEntity else {
                print("GameViewController: Configure inserter callback - no selected entity")
                return
            }

            print("GameViewController: Configure inserter button pressed for entity \(selectedEntity)")

            // Open inserter connection dialog
            self.uiSystem?.showInserterConnectionDialog(entity: selectedEntity)
        }

        // Setup exit build mode callback
        uiSystem?.hud.onExitBuildModePressed = { [weak self] in
            print("GameViewController: Exit build mode button pressed")
            self?.inputManager?.exitBuildMode()
        }

        // Setup callback for when HUD selection changes (e.g., entity dies)
        uiSystem?.hud.onSelectedEntityChanged = { [weak self] entity in
            guard let self = self else { return }
            // Update renderer
            self.renderer.selectedEntity = entity
            // Only show persistent tooltip if entity became nil (died) - otherwise let normal tooltips handle it
            if entity == nil {
                self.updateSelectedEntityTooltip(entity: nil, text: nil)
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

