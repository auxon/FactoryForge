import Foundation

/// Component for rocket silo buildings that can launch rockets
class RocketSiloComponent: BuildingComponent {
    var launchProgress: Float = 0.0  // 0.0 to 1.0
    var isLaunching: Bool = false
    var rocketAssembled: Bool = false
    var launchTimer: Float = 0.0
    var launchDuration: Float = 10.0  // 10 seconds launch sequence

    override init(buildingId: String) {
        super.init(buildingId: buildingId)
    }

    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case buildingId, launchProgress, isLaunching, rocketAssembled, launchTimer, launchDuration
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchProgress = try container.decode(Float.self, forKey: .launchProgress)
        isLaunching = try container.decode(Bool.self, forKey: .isLaunching)
        rocketAssembled = try container.decode(Bool.self, forKey: .rocketAssembled)
        launchTimer = try container.decode(Float.self, forKey: .launchTimer)
        launchDuration = try container.decode(Float.self, forKey: .launchDuration)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(launchProgress, forKey: .launchProgress)
        try container.encode(isLaunching, forKey: .isLaunching)
        try container.encode(rocketAssembled, forKey: .rocketAssembled)
        try container.encode(launchTimer, forKey: .launchTimer)
        try container.encode(launchDuration, forKey: .launchDuration)
        try super.encode(to: encoder)
    }
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