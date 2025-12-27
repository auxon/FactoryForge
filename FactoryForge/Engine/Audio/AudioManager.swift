import AVFoundation

/// Manages all game audio
final class AudioManager {
    static let shared = AudioManager()
    
    private var musicPlayer: AVAudioPlayer?
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    private var soundPool: [String: [AVAudioPlayer]] = [:]
    
    private let maxPoolSize = 5
    
    var musicVolume: Float = 0.5 {
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
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("Music file not found: \(filename)")
            return
        }
        
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.volume = musicVolume
            musicPlayer?.numberOfLoops = loop ? -1 : 0
            musicPlayer?.prepareToPlay()
            musicPlayer?.play()
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
        musicPlayer?.play()
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
                    player.play()
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
                player.play()
                soundPool[filename] = [player]
            }
        }
    }
    
    private func createPlayer(for filename: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("Sound file not found: \(filename)")
            return nil
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("Failed to create player: \(error)")
            return nil
        }
    }
    
    // MARK: - Sound Effect Names
    
    func playPlaceSound() {
        playSound("place.wav")
    }
    
    func playRemoveSound() {
        playSound("remove.wav")
    }
    
    func playClickSound() {
        playSound("click.wav")
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
    
    func playMiningSound() {
        playSound("mining.m4a", volume: 0.3)
    }
    
    func playCraftingCompleteSound() {
        playSound("crafting_complete.wav", volume: 0.5)
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

