import Foundation
import HomeKit

// MARK: - Executor

/// Executes operations against HomeKit
@MainActor
final class Executor {
    private let manager: HomeKitManager
    private let home: HMHome
    private let verbose: Bool
    
    init(manager: HomeKitManager, home: HMHome, verbose: Bool = false) {
        self.manager = manager
        self.home = home
        self.verbose = verbose
    }
    
    /// Execute all operations in a plan
    /// - Parameter plan: The operation plan to execute
    /// - Returns: Results of all operations
    func execute(plan: OperationPlan) async -> ExecutionResult {
        var results: [OperationResult] = []
        
        // Group and sort operations by category for proper ordering
        let sortedOps = plan.operations.sorted { $0.category.order < $1.category.order }
        
        for operation in sortedOps {
            let result = await execute(operation: operation)
            results.append(result)
            
            if verbose {
                let status = result.success ? "✓" : "✗"
                print("  \(status) \(operation.description)")
                if let error = result.error {
                    print("    Error: \(error.localizedDescription)")
                }
            }
        }
        
        return ExecutionResult(results: results)
    }
    
    /// Execute a single operation
    private func execute(operation: Operation) async -> OperationResult {
        do {
            switch operation {
            case .createRoom(let name):
                try await executeCreateRoom(name: name)
                
            case .deleteRoom(let roomId, _):
                try await executeDeleteRoom(roomId: roomId)
                
            case .createZone(let name):
                try await executeCreateZone(name: name)
                
            case .deleteZone(let zoneId, _):
                try await executeDeleteZone(zoneId: zoneId)
                
            case .addRoomToZone(let roomName, let zoneName):
                try await executeAddRoomToZone(roomName: roomName, zoneName: zoneName)
                
            case .removeRoomFromZone(let roomId, _, let zoneId, _):
                try await executeRemoveRoomFromZone(roomId: roomId, zoneId: zoneId)
                
            case .removeAccessory(let accessoryId, _):
                try await executeRemoveAccessory(accessoryId: accessoryId)
                
            case .assignAccessory(let accessoryId, _, let roomName):
                try await executeAssignAccessory(accessoryId: accessoryId, toRoom: roomName)
                
            case .renameAccessory(let accessoryId, _, let newName):
                try await executeRenameAccessory(accessoryId: accessoryId, to: newName)
                
            case .createScene(let name):
                try await executeCreateScene(name: name)
                
            case .addSceneAction(let sceneName, let accessoryId, _, let service, let characteristics):
                try await executeAddSceneAction(
                    sceneName: sceneName,
                    accessoryId: accessoryId,
                    service: service,
                    characteristics: characteristics
                )
            }
            
            return .success(operation)
        } catch {
            return .failure(operation, error: error)
        }
    }
    
    // MARK: - Individual Operation Implementations
    
    private func executeCreateRoom(name: String) async throws {
        // Check if room already exists (idempotent)
        if manager.getRoom(named: name, in: home) != nil {
            return // Already exists, skip
        }
        
        _ = try await manager.createRoom(named: name, in: home)
    }
    
    private func executeDeleteRoom(roomId: UUID) async throws {
        guard let room = home.rooms.first(where: { $0.uniqueIdentifier == roomId }) else {
            return // Room doesn't exist anymore, skip
        }
        
        try await manager.deleteRoom(room, in: home)
    }
    
    private func executeCreateZone(name: String) async throws {
        // Check if zone already exists (idempotent)
        if manager.getZone(named: name, in: home) != nil {
            return // Already exists, skip
        }
        
        _ = try await manager.createZone(named: name, in: home)
    }
    
    private func executeDeleteZone(zoneId: UUID) async throws {
        guard let zone = manager.getZone(id: zoneId, in: home) else {
            return // Zone doesn't exist anymore, skip
        }
        
        try await manager.deleteZone(zone, in: home)
    }
    
    private func executeAddRoomToZone(roomName: String, zoneName: String) async throws {
        // Get or create the zone
        let zone: HMZone
        if let existingZone = manager.getZone(named: zoneName, in: home) {
            zone = existingZone
        } else {
            zone = try await manager.createZone(named: zoneName, in: home)
        }
        
        // Get the room
        guard let room = manager.getRoom(named: roomName, in: home) else {
            throw HomeKitError.roomNotFound(roomName)
        }
        
        // Check if already in zone (idempotent)
        if zone.rooms.contains(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) {
            return // Already in zone
        }
        
        try await manager.addRoom(room, to: zone)
    }
    
    private func executeRemoveRoomFromZone(roomId: UUID, zoneId: UUID) async throws {
        guard let zone = manager.getZone(id: zoneId, in: home) else {
            return // Zone doesn't exist anymore, skip
        }
        
        guard let room = home.rooms.first(where: { $0.uniqueIdentifier == roomId }) else {
            return // Room doesn't exist anymore, skip
        }
        
        // Check if still in zone
        guard zone.rooms.contains(where: { $0.uniqueIdentifier == roomId }) else {
            return // Already removed
        }
        
        try await manager.removeRoom(room, from: zone)
    }
    
    private func executeRemoveAccessory(accessoryId: UUID) async throws {
        guard let accessory = manager.getAccessory(id: accessoryId, in: home) else {
            return // Accessory doesn't exist anymore, skip
        }
        
        try await manager.removeAccessory(accessory, from: home)
    }
    
    private func executeAssignAccessory(accessoryId: UUID, toRoom roomName: String) async throws {
        print("[DEBUG] Looking for accessory ID: \(accessoryId)")
        guard let accessory = manager.getAccessory(id: accessoryId, in: home) else {
            throw HomeKitError.accessoryNotFound("ID: \(accessoryId)")
        }
        print("[DEBUG] Found accessory: '\(accessory.name)', reachable: \(accessory.isReachable), blocked: \(accessory.isBlocked)")
        
        // Get or create the room
        let room: HMRoom
        
        // Special handling for Default Room - use the home's built-in default room
        if roomName.lowercased() == "default room" {
            room = home.roomForEntireHome()
            print("[DEBUG] Using home's default room: '\(room.name)'")
        } else if let existingRoom = manager.getRoom(named: roomName, in: home) {
            print("[DEBUG] Found existing room: '\(existingRoom.name)'")
            room = existingRoom
        } else {
            print("[DEBUG] Creating new room: '\(roomName)'")
            room = try await manager.createRoom(named: roomName, in: home)
        }
        
        // Check if already in correct room (idempotent)
        if accessory.room?.uniqueIdentifier == room.uniqueIdentifier {
            print("[DEBUG] Already in correct room")
            return // Already assigned
        }
        
        print("[DEBUG] Assigning '\(accessory.name)' to '\(room.name)'...")
        try await manager.assignAccessory(accessory, to: room, in: home)
        print("[DEBUG] Assignment complete")
    }
    
    private func executeRenameAccessory(accessoryId: UUID, to newName: String) async throws {
        guard let accessory = manager.getAccessory(id: accessoryId, in: home) else {
            throw HomeKitError.accessoryNotFound("ID: \(accessoryId)")
        }
        
        // Check if already named correctly (idempotent)
        if accessory.name == newName {
            return
        }
        
        try await manager.renameAccessory(accessory, to: newName)
    }
    
    private func executeCreateScene(name: String) async throws {
        // Check if scene already exists (idempotent)
        if manager.getActionSet(named: name, in: home) != nil {
            return // Already exists
        }
        
        _ = try await manager.createActionSet(named: name, in: home)
    }
    
    private func executeAddSceneAction(
        sceneName: String,
        accessoryId: UUID,
        service: String,
        characteristics: [(String, Any)]
    ) async throws {
        guard let actionSet = manager.getActionSet(named: sceneName, in: home) else {
            throw HomeKitError.operationFailed("Scene '\(sceneName)' not found")
        }
        
        guard let accessory = manager.getAccessory(id: accessoryId, in: home) else {
            throw HomeKitError.accessoryNotFound("ID: \(accessoryId)")
        }
        
        // Find the appropriate service using CharacteristicMapper
        guard let hmService = CharacteristicMapper.findService(named: service, on: accessory) else {
            throw HomeKitError.operationFailed("Service '\(service)' not found on '\(accessory.name)'")
        }
        
        // Create actions for each characteristic
        for (charName, value) in characteristics {
            guard let characteristic = CharacteristicMapper.findCharacteristic(named: charName, on: hmService) else {
                throw HomeKitError.operationFailed("Characteristic '\(charName)' not found on service '\(service)'")
            }
            
            // Convert value to appropriate type for HomeKit
            let targetValue = CharacteristicMapper.convertValue(value, for: characteristic)
            
            let action = HMCharacteristicWriteAction(characteristic: characteristic, targetValue: targetValue as NSCopying)
            try await manager.addAction(action, to: actionSet)
        }
    }
    
}

