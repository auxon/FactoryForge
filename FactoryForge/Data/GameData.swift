import Foundation

/// Central game data management
final class GameData {
    static let shared = GameData()
    
    // Current save slot
    var currentSlot: String = "save1"
    
    // Game settings
    var settings: GameSettings = GameSettings()
    
    private let settingsKey = "gameSettings"
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Settings
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let loaded = try? JSONDecoder().decode(GameSettings.self, from: data) {
            settings = loaded
        }
    }
}

struct GameSettings: Codable {
    var musicVolume: Float = 0.5
    var soundVolume: Float = 0.7
    var showTutorials: Bool = true
    var autoSave: Bool = true
    var showFPS: Bool = false
    var cameraZoomSensitivity: Float = 1.0
    var invertPan: Bool = false
}

