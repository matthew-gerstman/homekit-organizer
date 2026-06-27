import Foundation

// MARK: - Operation Types

/// An operation that can be performed on HomeKit
enum Operation: CustomStringConvertible {
    /// Create a new room
    case createRoom(name: String)
    
    /// Delete an existing room
    case deleteRoom(roomId: UUID, name: String)
    
    /// Create a new zone
    case createZone(name: String)
    
    /// Delete an existing zone
    case deleteZone(zoneId: UUID, name: String)
    
    /// Add a room to a zone
    case addRoomToZone(roomName: String, zoneName: String)
    
    /// Remove a room from a zone
    case removeRoomFromZone(roomId: UUID, roomName: String, zoneId: UUID, zoneName: String)
    
    /// Remove an accessory from HomeKit
    case removeAccessory(accessoryId: UUID, name: String)
    
    /// Assign an accessory to a room
    case assignAccessory(accessoryId: UUID, accessoryName: String, toRoom: String)
    
    /// Rename an accessory
    case renameAccessory(accessoryId: UUID, from: String, to: String)
    
    /// Create a new scene
    case createScene(name: String)
    
    /// Add an action to a scene
    case addSceneAction(sceneName: String, accessoryId: UUID, accessoryName: String, 
                        service: String, characteristics: [(String, Any)])
    
    var description: String {
        switch self {
        case .createRoom(let name):
            return "Create room '\(name)'"
        case .deleteRoom(_, let name):
            return "Delete room '\(name)'"
        case .createZone(let name):
            return "Create zone '\(name)'"
        case .deleteZone(_, let name):
            return "Delete zone '\(name)'"
        case .addRoomToZone(let roomName, let zoneName):
            return "Add room '\(roomName)' to zone '\(zoneName)'"
        case .removeRoomFromZone(_, let roomName, _, let zoneName):
            return "Remove room '\(roomName)' from zone '\(zoneName)'"
        case .removeAccessory(_, let name):
            return "Remove accessory '\(name)'"
        case .assignAccessory(_, let accessoryName, let room):
            return "Assign '\(accessoryName)' to '\(room)'"
        case .renameAccessory(_, let from, let to):
            return "Rename '\(from)' → '\(to)'"
        case .createScene(let name):
            return "Create scene '\(name)'"
        case .addSceneAction(let scene, _, let accessory, _, let chars):
            let charStr = chars.map { "\($0.0): \($0.1)" }.joined(separator: ", ")
            return "Add action to '\(scene)': \(accessory) [\(charStr)]"
        }
    }
    
    /// Category for grouping in output
    var category: OperationCategory {
        switch self {
        case .removeAccessory: return .accessoryRemove
        case .deleteRoom: return .roomDelete
        case .createRoom: return .room
        case .deleteZone: return .zoneDelete
        case .createZone: return .zone
        case .addRoomToZone, .removeRoomFromZone: return .zoneAssignment
        case .assignAccessory: return .assignment
        case .renameAccessory: return .rename
        case .createScene, .addSceneAction: return .scene
        }
    }
}

enum OperationCategory: String, CaseIterable {
    case accessoryRemove = "Remove Accessories"
    case rename = "Renames"
    case roomDelete = "Delete Rooms"
    case room = "Create Rooms"
    case zoneDelete = "Delete Zones"
    case zone = "Create Zones"
    case zoneAssignment = "Zone Assignments"
    case assignment = "Assignments"
    case scene = "Scenes"
    
    var order: Int {
        switch self {
        case .accessoryRemove: return 0  // Remove accessories first
        case .rename: return 1           // Renames so matching works
        case .roomDelete: return 2       // Delete rooms before creating new ones
        case .room: return 3             // Create rooms before assigning
        case .zoneDelete: return 4       // Delete zones
        case .zone: return 5             // Create zones after rooms exist
        case .zoneAssignment: return 6   // Assign rooms to zones
        case .assignment: return 7       // Assign accessories
        case .scene: return 8            // Scenes last
        }
    }
}

// MARK: - Operation Plan

/// A plan of operations to execute
struct OperationPlan {
    let operations: [Operation]
    let skipped: [SkippedOperation]
    let warnings: [String]
    
    /// Operations grouped by category
    var operationsByCategory: [(OperationCategory, [Operation])] {
        let grouped = Dictionary(grouping: operations, by: { $0.category })
        return OperationCategory.allCases
            .sorted { $0.order < $1.order }
            .compactMap { category in
                guard let ops = grouped[category], !ops.isEmpty else { return nil }
                return (category, ops)
            }
    }
    
    /// Whether the plan has any operations
    var isEmpty: Bool {
        operations.isEmpty
    }
    
    /// Total operation count
    var count: Int {
        operations.count
    }
}

/// An operation that was skipped (already satisfied)
struct SkippedOperation {
    let reason: String
    let detail: String
    
    var description: String {
        "\(reason): \(detail)"
    }
}

// MARK: - Operation Result

/// Result of executing an operation
struct OperationResult {
    let operation: Operation
    let success: Bool
    let error: Error?
    
    static func success(_ operation: Operation) -> OperationResult {
        OperationResult(operation: operation, success: true, error: nil)
    }
    
    static func failure(_ operation: Operation, error: Error) -> OperationResult {
        OperationResult(operation: operation, success: false, error: error)
    }
}

/// Result of executing a full plan
struct ExecutionResult {
    let results: [OperationResult]
    
    var successCount: Int {
        results.filter { $0.success }.count
    }
    
    var failureCount: Int {
        results.filter { !$0.success }.count
    }
    
    var hasFailures: Bool {
        failureCount > 0
    }
}

