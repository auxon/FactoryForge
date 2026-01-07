import AVFoundation

/// Manages all game audio
final class AudioManager {
    static let shared = AudioManager()
    
    private var musicPlayer: AVAudioPlayer?
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    private var soundPool: [String: [AVAudioPlayer]] = [:]
    
    private let maxPoolSize = 5
    
    var musicVolume: Float = 0.25 {
        didSet {
            musicPlayer?.volume = musicVolume
        }
    }
    
    var soundVolume: Float = 0.7
    var isMuted: Bool = false
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Music
    
    func playMusic(_ filename: String, loop: Bool = true) {
        guard !isMuted else { return }

        // Handle files in subdirectories (e.g., "sounds/little_maze.m4a")
        var resourceName = filename
        var subdirectory: String? = nil

        if filename.contains("/") {
            let components = filename.split(separator: "/", maxSplits: 1)
            subdirectory = String(components[0])
            resourceName = String(components[1])
        }

        // If there's an extension, separate it
        var resource = resourceName
        var extensionName: String? = nil
        if resourceName.contains(".") {
            let components = resourceName.split(separator: ".", maxSplits: 1)
            resource = String(components[0])
            extensionName = String(components[1])
        }

        // Try with subdirectory first, then without
        var url: URL? = nil
        if let subdirectory = subdirectory {
            url = Bundle.main.url(forResource: resource, withExtension: extensionName, subdirectory: subdirectory)
        }

        // If subdirectory didn't work, try without subdirectory (files might be flattened)
        if url == nil {
            url = Bundle.main.url(forResource: filename, withExtension: nil)
        }

        guard let finalUrl = url else {
            print("Music file not found: \(filename) (tried with subdirectory: \(subdirectory ?? "nil") and without)")
            return
        }

        do {
            musicPlayer = try AVAudioPlayer(contentsOf: finalUrl)
            musicPlayer?.volume = musicVolume
            musicPlayer?.numberOfLoops = loop ? -1 : 0
            musicPlayer?.prepareToPlay()
            // Play music on background thread to avoid main thread blocking
            DispatchQueue.global(qos: .userInitiated).async {
                self.musicPlayer?.play()
            }
        } catch {
            print("Failed to play music: \(error)")
        }
    }
    
    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }
    
    func pauseMusic() {
        musicPlayer?.pause()
    }
    
    func resumeMusic() {
        // Resume music on background thread to avoid main thread blocking
        DispatchQueue.global(qos: .userInitiated).async {
            self.musicPlayer?.play()
        }
    }
    
    // MARK: - Sound Effects
    
    func playSound(_ filename: String, volume: Float? = nil) {
        guard !isMuted else { return }
        
        let effectiveVolume = volume ?? soundVolume
        
        // Try to reuse a player from the pool
        if var pool = soundPool[filename] {
            for player in pool {
                if !player.isPlaying {
                    player.volume = effectiveVolume
                    player.currentTime = 0
                    // Play audio on background thread to avoid main thread blocking
                    DispatchQueue.global(qos: .userInitiated).async {
                        player.play()
                    }
                    return
                }
            }
            
            // All players are busy, create a new one if under limit
            if pool.count < maxPoolSize {
                if let player = createPlayer(for: filename) {
                    player.volume = effectiveVolume
                    player.play()
                    pool.append(player)
                    soundPool[filename] = pool
                }
            }
        } else {
            // First time playing this sound
            if let player = createPlayer(for: filename) {
                player.volume = effectiveVolume
                // Play audio on background thread to avoid main thread blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    player.play()
                }
                soundPool[filename] = [player]
            }
        }
    }
    
    private func createPlayer(for filename: String) -> AVAudioPlayer? {
        // Handle files in subdirectories (e.g., "sounds/little_maze.m4a")
        var resourceName = filename
        var subdirectory: String? = nil

        if filename.contains("/") {
            let components = filename.split(separator: "/", maxSplits: 1)
            subdirectory = String(components[0])
            resourceName = String(components[1])
        }

        // If there's an extension, separate it
        var resource = resourceName
        var extensionName: String? = nil
        if resourceName.contains(".") {
            let components = resourceName.split(separator: ".", maxSplits: 1)
            resource = String(components[0])
            extensionName = String(components[1])
        }

        // Try with subdirectory first, then without
        var url: URL? = nil
        if let subdirectory = subdirectory {
            url = Bundle.main.url(forResource: resource, withExtension: extensionName, subdirectory: subdirectory)
        }

        // If subdirectory didn't work, try without subdirectory (files might be flattened)
        if url == nil {
            url = Bundle.main.url(forResource: filename, withExtension: nil)
        }

        guard let finalUrl = url else {
            print("Sound file not found: \(filename) (tried with subdirectory: \(subdirectory ?? "nil") and without)")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: finalUrl)
            player.prepareToPlay()
            return player
        } catch {
            print("Failed to create player: \(error)")
            return nil
        }
    }
    
    // MARK: - Sound Effect Names
    
    func playPlaceSound() {
        playSound("place.m4a")
    }
    
    func playRemoveSound() {
        playSound("place.m4a")
    }
    
    func playClickSound() {
        playSound("click.m4a")
    }
    
    func playResearchCompleteSound() {
        playSound("research_complete.wav")
    }
    
    func playAlertSound() {
        playSound("alert.wav")
    }
    
    func playExplosionSound() {
        playSound("explosion.wav", volume: 0.6)
    }
    
    func playTurretFireSound() {
        playSound("turret_fire.wav", volume: 0.4)
    }
    
    func playPlayerFireSound() {
        playSound("player_fire.m4a", volume: 0.4)
    }
    
    func playMiningSound() {
        playSound("mining.m4a", volume: 0.3)
    }

    func playChopSound() {
        playSound("chop.m4a", volume: 0.3)
    }

    func playCraftingCompleteSound() {
        playSound("crafting_complete.m4a", volume: 0.5)
    }

    func playBackgroundMusic() {
        playMusic("little_maze.m4a", loop: true)
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            stopMusic()
            stopAllSounds()
        } else {
            // Resume music if it was playing
            playBackgroundMusic()
        }
    }
    
    // MARK: - Cleanup
    
    func stopAllSounds() {
        for (_, pool) in soundPool {
            for player in pool {
                player.stop()
            }
        }
    }
    
    func cleanup() {
        stopMusic()
        stopAllSounds()
        soundPool.removeAll()
    }
}

