import Foundation

// MARK: - Top-Level Configuration

/// Root configuration structure parsed from YAML
struct Config: Codable {
    /// Target home name (optional - uses primary/first home if not specified)
    var home: String?
    
    /// Room definitions with accessory assignments
    var rooms: [RoomConfig]?
    
    /// Accessory rename rules
    var renames: [RenameRule]?
    
    /// Scene definitions
    var scenes: [SceneConfig]?
    
    /// Whether this config has any actual content
    var isEmpty: Bool {
        let hasRooms = !(rooms?.isEmpty ?? true)
        let hasRenames = !(renames?.isEmpty ?? true)
        let hasScenes = !(scenes?.isEmpty ?? true)
        return !hasRooms && !hasRenames && !hasScenes
    }
}

// MARK: - Room Configuration

/// Configuration for a single room
struct RoomConfig: Codable {
    /// Room name (will be created if doesn't exist)
    let name: String
    
    /// Accessories to assign to this room
    let accessories: [AccessorySelector]?
}

/// Selector for matching accessories - either exact name or pattern
enum AccessorySelector: Codable {
    case exact(String)
    case pattern(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding as a simple string first (exact match)
        if let exactName = try? container.decode(String.self) {
            self = .exact(exactName)
            return
        }
        
        // Try decoding as an object with pattern key
        let patternContainer = try decoder.container(keyedBy: PatternCodingKeys.self)
        if let pattern = try? patternContainer.decode(String.self, forKey: .pattern) {
            self = .pattern(pattern)
            return
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Accessory selector must be a string or object with 'pattern' key"
        )
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .exact(let name):
            var container = encoder.singleValueContainer()
            try container.encode(name)
        case .pattern(let pattern):
            var container = encoder.container(keyedBy: PatternCodingKeys.self)
            try container.encode(pattern, forKey: .pattern)
        }
    }
    
    private enum PatternCodingKeys: String, CodingKey {
        case pattern
    }
    
    /// Description for display
    var description: String {
        switch self {
        case .exact(let name):
            return "\"\(name)\""
        case .pattern(let pattern):
            return "pattern: \"\(pattern)\""
        }
    }
    
    /// Whether this is a pattern (vs exact match)
    var isPattern: Bool {
        switch self {
        case .exact: return false
        case .pattern: return true
        }
    }
    
    /// The raw string value
    var value: String {
        switch self {
        case .exact(let name): return name
        case .pattern(let pattern): return pattern
        }
    }
}

// MARK: - Rename Rules

/// Rule for renaming an accessory
struct RenameRule: Codable {
    /// Current name to match
    let from: String
    
    /// New name to apply
    let to: String
}

// MARK: - Scene Configuration

/// Configuration for a HomeKit scene (action set)
struct SceneConfig: Codable {
    /// Scene name
    let name: String
    
    /// Actions to include in the scene
    let actions: [SceneAction]?
}

/// A single action within a scene
struct SceneAction: Codable {
    /// Accessory name to target
    let accessory: String
    
    /// Service type (e.g., "lightbulb", "switch")
    let service: String
    
    /// Characteristics to set
    let characteristics: CharacteristicValues
}

/// Supported characteristic values
/// Note: v0.1 only supports 'on' and 'brightness'
struct CharacteristicValues: Codable {
    /// Power state (on/off)
    var on: Bool?
    
    /// Brightness level (0-100)
    var brightness: Int?
    
    // Future: Add more characteristics as needed
    // var hue: Int?
    // var saturation: Int?
    // var colorTemperature: Int?
    
    /// Whether any characteristic is set
    var isEmpty: Bool {
        on == nil && brightness == nil
    }
    
    /// List of set characteristics for display
    var setCharacteristics: [(name: String, value: Any)] {
        var result: [(String, Any)] = []
        if let on = on {
            result.append(("on", on))
        }
        if let brightness = brightness {
            result.append(("brightness", brightness))
        }
        return result
    }
}

// MARK: - Config Extensions for Display

extension Config: CustomStringConvertible {
    var description: String {
        var parts: [String] = []
        
        if let home = home {
            parts.append("Home: \(home)")
        }
        
        if let rooms = rooms, !rooms.isEmpty {
            parts.append("Rooms: \(rooms.count)")
        }
        
        if let renames = renames, !renames.isEmpty {
            parts.append("Renames: \(renames.count)")
        }
        
        if let scenes = scenes, !scenes.isEmpty {
            parts.append("Scenes: \(scenes.count)")
        }
        
        return "Config(\(parts.joined(separator: ", ")))"
    }
}

