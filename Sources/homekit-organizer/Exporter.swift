import Foundation
import Yams

// MARK: - Exporter

/// Exports current HomeKit state as YAML configuration
struct Exporter {
    
    /// Export a HomeKit snapshot as a Config object
    /// - Parameter snapshot: The HomeKit snapshot to export
    /// - Returns: Config object representing current state
    static func export(snapshot: HomeKitSnapshot) -> Config {
        var config = Config()
        
        // Set home name
        config.home = snapshot.home.name
        
        // Export rooms with their accessories
        var roomConfigs: [RoomConfig] = []
        
        for room in snapshot.rooms where !room.isDefault {
            let roomAccessories = snapshot.accessories.filter { $0.roomId == room.id }
            
            let selectors: [AccessorySelector] = roomAccessories.map { .exact($0.name) }
            
            let roomConfig = RoomConfig(
                name: room.name,
                accessories: selectors.isEmpty ? nil : selectors
            )
            roomConfigs.append(roomConfig)
        }
        
        // Add unassigned accessories info as a comment-like room
        // (they'll appear in the YAML but won't create a room)
        
        config.rooms = roomConfigs.isEmpty ? nil : roomConfigs
        
        // Note: We don't export renames (they're one-time operations)
        // Note: We don't export scenes yet (would need to query action sets)
        
        return config
    }
    
    /// Export a HomeKit snapshot as YAML string
    /// - Parameters:
    ///   - snapshot: The HomeKit snapshot to export
    ///   - includeComments: Whether to include helpful comments
    /// - Returns: YAML string
    static func exportYAML(snapshot: HomeKitSnapshot, includeComments: Bool = true) -> String {
        var lines: [String] = []
        
        if includeComments {
            lines.append("# HomeKit Configuration")
            lines.append("# Exported from: \(snapshot.home.name)")
            lines.append("# Date: \(ISO8601DateFormatter().string(from: Date()))")
            lines.append("")
        }
        
        // Home
        lines.append("home: \"\(snapshot.home.name)\"")
        lines.append("")
        
        // Rooms
        if includeComments {
            lines.append("# Room assignments")
        }
        lines.append("rooms:")
        
        for room in snapshot.rooms.sorted(by: { $0.name < $1.name }) where !room.isDefault {
            let roomAccessories = snapshot.accessories.filter { $0.roomId == room.id }
                .sorted(by: { $0.name < $1.name })
            
            lines.append("  - name: \"\(room.name)\"")
            
            if !roomAccessories.isEmpty {
                lines.append("    accessories:")
                for accessory in roomAccessories {
                    lines.append("      - \"\(accessory.name)\"")
                }
            }
            lines.append("")
        }
        
        // Unassigned accessories as comments
        let unassigned = snapshot.unassignedAccessories.sorted(by: { $0.name < $1.name })
        if !unassigned.isEmpty && includeComments {
            lines.append("# Unassigned accessories (in Default Room):")
            for accessory in unassigned {
                lines.append("#   - \"\(accessory.name)\"")
            }
            lines.append("")
        }
        
        // Placeholder for scenes
        if includeComments {
            lines.append("# Scenes (not exported - would need manual configuration)")
            lines.append("# scenes:")
            lines.append("#   - name: \"Example Scene\"")
            lines.append("#     actions:")
            lines.append("#       - accessory: \"Light Name\"")
            lines.append("#         service: \"lightbulb\"")
            lines.append("#         characteristics:")
            lines.append("#           on: true")
            lines.append("#           brightness: 100")
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Export using Yams encoder (alternative to manual formatting)
    static func exportWithYams(config: Config) throws -> String {
        let encoder = YAMLEncoder()
        return try encoder.encode(config)
    }
}

