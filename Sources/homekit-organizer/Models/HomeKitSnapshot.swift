import Foundation
import HomeKit

// MARK: - HomeKit Snapshot Models

/// A snapshot of the current HomeKit state for a single home
struct HomeKitSnapshot {
    let home: HomeInfo
    let rooms: [RoomInfo]
    let accessories: [AccessoryInfo]
    
    /// Accessories that are in the "default room" (unassigned)
    var unassignedAccessories: [AccessoryInfo] {
        accessories.filter { $0.roomId == nil }
    }
    
    /// Accessories organized by room
    var accessoriesByRoom: [UUID: [AccessoryInfo]] {
        Dictionary(grouping: accessories.filter { $0.roomId != nil }, by: { $0.roomId! })
    }
}

/// Simplified representation of an HMHome
struct HomeInfo {
    let id: UUID
    let name: String
    let isPrimary: Bool
    
    init(from home: HMHome, isPrimary: Bool) {
        self.id = home.uniqueIdentifier
        self.name = home.name
        self.isPrimary = isPrimary
    }
}

/// Simplified representation of an HMRoom
struct RoomInfo {
    let id: UUID
    let name: String
    let homeId: UUID
    let isDefault: Bool
    
    init(from room: HMRoom, homeId: UUID, isDefault: Bool = false) {
        self.id = room.uniqueIdentifier
        self.name = room.name
        self.homeId = homeId
        self.isDefault = isDefault
    }
}

/// Simplified representation of an HMAccessory
struct AccessoryInfo {
    let id: UUID
    let name: String
    let roomId: UUID?
    let roomName: String?
    let isReachable: Bool
    let category: String
    let services: [ServiceInfo]
    
    init(from accessory: HMAccessory, defaultRoomId: UUID?) {
        self.id = accessory.uniqueIdentifier
        self.name = accessory.name
        
        // If accessory is in the default room, treat it as unassigned (roomId = nil)
        if let room = accessory.room, room.uniqueIdentifier != defaultRoomId {
            self.roomId = room.uniqueIdentifier
            self.roomName = room.name
        } else {
            self.roomId = nil
            self.roomName = nil
        }
        
        self.isReachable = accessory.isReachable
        self.category = accessory.category.localizedDescription
        self.services = accessory.services.map { ServiceInfo(from: $0) }
    }
}

/// Simplified representation of an HMService
struct ServiceInfo {
    let id: UUID
    let name: String
    let serviceType: String
    let characteristics: [CharacteristicInfo]
    
    init(from service: HMService) {
        self.id = service.uniqueIdentifier
        self.name = service.name
        self.serviceType = service.serviceType
        self.characteristics = service.characteristics.map { CharacteristicInfo(from: $0) }
    }
}

/// Simplified representation of an HMCharacteristic
struct CharacteristicInfo {
    let id: UUID
    let characteristicType: String
    let localizedDescription: String
    let isReadable: Bool
    let isWritable: Bool
    
    init(from characteristic: HMCharacteristic) {
        self.id = characteristic.uniqueIdentifier
        self.characteristicType = characteristic.characteristicType
        self.localizedDescription = characteristic.localizedDescription
        self.isReadable = characteristic.properties.contains(HMCharacteristicPropertyReadable)
        self.isWritable = characteristic.properties.contains(HMCharacteristicPropertyWritable)
    }
}

// MARK: - Summary Info for Listing

/// Summary of all homes for the list command
struct HomesSummary {
    let homes: [HomeInfo]
    let primaryHomeId: UUID?
}

