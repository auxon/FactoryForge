import UIKit
import MetalKit

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMetalView()
        setupRenderer()
        setupUISystem()
        setupLoadingMenu()
        setupNotifications()
        setupTooltip()
        setupGameOverUI()

        print("View bounds: \(view.bounds), scale: \(UIScreen.main.scale)")
        print("Metal view bounds: \(metalView.bounds)")
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
        metalView.clearColor = MTLClearColor(red: 0.1, green: 0.15, blue: 0.1, alpha: 1.0)
        view.addSubview(metalView)
    }
    
    private func setupRenderer() {
        guard let device = metalView.device else { return }
        renderer = MetalRenderer(device: device, view: metalView)
        metalView.delegate = renderer
    }
    
    private func setupUISystem() {
        // Create UISystem without GameLoop initially
        uiSystem = UISystem(gameLoop: nil, renderer: renderer)
        renderer.uiSystem = uiSystem

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
    }
    
    private func setupLoadingMenu() {
        guard let uiSystem = uiSystem else { return }
        
        // Show loading menu immediately
        uiSystem.openPanel(.loadingMenu)
        
        // Setup callbacks
        let loadingMenu = uiSystem.getLoadingMenu()
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
        // Create new game with random seed
        gameLoop = GameLoop(renderer: renderer, seed: nil)
        renderer.gameLoop = gameLoop
        
        // Set UI system on game loop
        gameLoop?.uiSystem = uiSystem

        // Update UI system with game loop
        uiSystem?.setGameLoop(gameLoop!)

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

        // Setup input
        setupInput()
        
        // Enable save button in loading menu (game is now running)
        uiSystem?.getLoadingMenu().onSaveGameRequested = { [weak self] in
            self?.saveCurrentGame()
        }
        
        // Close loading menu
        uiSystem?.closeAllPanels()
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
            guard let self = self, let entity = entity else { return }
            guard let gameLoop = self.gameLoop else { return }
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
}

