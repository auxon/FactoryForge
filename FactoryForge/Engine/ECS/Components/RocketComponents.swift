import Foundation

/// Component for rocket silo buildings that can launch rockets
struct RocketSiloComponent: Component {
    var launchProgress: Float = 0.0  // 0.0 to 1.0
    var isLaunching: Bool = false
    var rocketAssembled: Bool = false
    var launchTimer: Float = 0.0
    var launchDuration: Float = 10.0  // 10 seconds launch sequence
}

/// Component for rocket entities during flight
struct RocketComponent: Component {
    var flightProgress: Float = 0.0  // 0.0 to 1.0
    var altitude: Float = 0.0
    var maxAltitude: Float = 1000.0  // Screen units
    var velocity: Float = 0.0
    var acceleration: Float = 50.0  // Units per second squared
    var hasSatellite: Bool = false
}

/// Component for tracking space science pack generation
struct SpaceScienceComponent: Component {
    var packsGenerated: Int = 0
    var maxPacksPerLaunch: Int = 1000
}