import UIKit
import MetalKit

class GameViewController: UIViewController {
    private var metalView: MTKView!
    private var renderer: MetalRenderer!
    private var gameLoop: GameLoop!
    private var inputManager: InputManager!
    
    // Tooltip label
    private var tooltipLabel: UILabel!
    private var tooltipHideTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMetalView()
        setupRenderer()
        setupGameLoop()
        setupInput()
        setupNotifications()
        setupTooltip()

        print("View bounds: \(view.bounds), scale: \(UIScreen.main.scale)")
        print("Metal view bounds: \(metalView.bounds)")
    }
    
    private func setupTooltip() {
        tooltipLabel = UILabel()
        tooltipLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        tooltipLabel.textColor = .black
        tooltipLabel.textAlignment = .center
        tooltipLabel.backgroundColor = .clear
        tooltipLabel.numberOfLines = 1
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
    
    func showTooltip(_ text: String, duration: TimeInterval = 1.0) {
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
    
    private func setupGameLoop() {
        gameLoop = GameLoop(renderer: renderer)
        renderer.gameLoop = gameLoop
    }
    
    private func setupInput() {
        // Add gesture recognizers to metalView since it's on top and receives touches
        inputManager = InputManager(view: metalView, gameLoop: gameLoop)
        gameLoop.inputManager = inputManager
        
        // Setup tooltip callback
        inputManager.onTooltip = { [weak self] text in
            self?.showTooltip(text)
        }
        
        // Setup entity selection callback - open machine UI for furnaces/assemblers
        inputManager.onEntitySelected = { [weak self] entity in
            guard let self = self, let entity = entity else { return }
            let world = self.gameLoop.world
            
            // Check if it's a machine we can interact with
            if world.has(FurnaceComponent.self, for: entity) {
                print("GameViewController: Furnace selected, opening Machine UI")
                // Open machine UI
                self.gameLoop.uiSystem?.openMachineUI(for: entity)
            } else if world.has(AssemblerComponent.self, for: entity) {
                print("GameViewController: Assembler selected, opening Machine UI")
                // Open machine UI
                self.gameLoop.uiSystem?.openMachineUI(for: entity)
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(pauseGame), name: .gameShouldPause, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeGame), name: .gameShouldResume, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveGame), name: .gameShouldSave, object: nil)
    }
    
    @objc private func pauseGame() {
        gameLoop.pause()
    }
    
    @objc private func resumeGame() {
        gameLoop.resume()
    }
    
    @objc private func saveGame() {
        gameLoop.save()
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

