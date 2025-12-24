import UIKit
import MetalKit

class GameViewController: UIViewController {
    private var metalView: MTKView!
    private var renderer: MetalRenderer!
    private var gameLoop: GameLoop!
    private var inputManager: InputManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMetalView()
        setupRenderer()
        setupGameLoop()
        setupInput()
        setupNotifications()
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

