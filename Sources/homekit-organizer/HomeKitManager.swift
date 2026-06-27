import Foundation
import HomeKit

// MARK: - HomeKit Manager Errors

enum HomeKitError: LocalizedError {
    case notAuthorized
    case noHomesAvailable
    case noPrimaryHome
    case homeNotFound(String)
    case roomNotFound(String)
    case accessoryNotFound(String)
    case operationFailed(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "HomeKit access not authorized. Please grant permission in System Settings > Privacy & Security > HomeKit."
        case .noHomesAvailable:
            return "No HomeKit homes found. Please set up a home in the Home app first."
        case .noPrimaryHome:
            return "No primary home available. Please set a primary home in the Home app."
        case .homeNotFound(let name):
            return "Home '\(name)' not found."
        case .roomNotFound(let name):
            return "Room '\(name)' not found."
        case .accessoryNotFound(let name):
            return "Accessory '\(name)' not found."
        case .operationFailed(let message):
            return "HomeKit operation failed: \(message)"
        case .timeout:
            return "HomeKit operation timed out. Please check your network connection and iCloud status."
        }
    }
}

// MARK: - HomeKit Manager

/// Wraps HMHomeManager to provide async/await APIs for HomeKit operations
@MainActor
final class HomeKitManager: NSObject {
    private let homeManager: HMHomeManager
    private var homesLoadedContinuation: CheckedContinuation<Void, Never>?
    private var isReady = false
    
    override init() {
        self.homeManager = HMHomeManager()
        super.init()
        self.homeManager.delegate = self
    }
    
    // MARK: - Initialization
    
    /// Wait for HomeKit to finish loading homes
    /// This must be called before any other operations
    func waitForHomesLoaded(timeout: TimeInterval = 30) async throws {
        print("[DEBUG] Starting waitForHomesLoaded, isReady=\(isReady)")
        
        if isReady {
            print("[DEBUG] Already ready, checking auth...")
        } else {
            print("[DEBUG] Waiting for homes to load...")
            // Wait for delegate callback
            await withCheckedContinuation { continuation in
                self.homesLoadedContinuation = continuation
            }
            print("[DEBUG] Delegate callback received")
        }
        
        // Check authorization status
        let status = homeManager.authorizationStatus
        print("[DEBUG] Authorization status: \(status.rawValue)")
        print("[DEBUG] Status breakdown - determined: \(status.contains(.determined)), restricted: \(status.contains(.restricted)), authorized: \(status.contains(.authorized))")
        print("[DEBUG] Number of homes: \(homeManager.homes.count)")
        
        // On Mac Catalyst, we may get .determined without .authorized initially
        // If we have homes, we're authorized even if the status doesn't show it
        if homeManager.homes.count > 0 {
            print("[DEBUG] Homes available, proceeding...")
            return
        }
        
        guard status.contains(.authorized) else {
            print("[DEBUG] Not authorized, throwing error")
            throw HomeKitError.notAuthorized
        }
    }
    
    // MARK: - Home Operations
    
    /// Get all available homes
    func getAllHomes() -> [HMHome] {
        return homeManager.homes
    }
    
    /// Get the primary home (or first home if primary is unavailable)
    func getPrimaryHome() throws -> HMHome {
        // primaryHome is deprecated in Mac Catalyst 16.1, fallback to first home
        if let first = homeManager.homes.first {
            // Debug home permissions
            print("[DEBUG] Home: '\(first.name)'")
            print("[DEBUG] Home UUID: \(first.uniqueIdentifier)")
            print("[DEBUG] Home hub state: \(first.homeHubState.rawValue)")
            switch first.homeHubState {
            case .notAvailable:
                print("[DEBUG] ⚠️ Home hub NOT AVAILABLE - writes will fail!")
                print("[DEBUG] You need an Apple TV, HomePod, or iPad as a home hub")
            case .connected:
                print("[DEBUG] ✓ Home hub CONNECTED - writes should work")
            case .disconnected:
                print("[DEBUG] ⚠️ Home hub DISCONNECTED - writes will fail!")
            @unknown default:
                print("[DEBUG] -> Unknown hub state")
            }
            print("[DEBUG] Current user: \(first.currentUser.name ?? "unknown")")
            return first
        }
        throw HomeKitError.noPrimaryHome
    }
    
    /// Get a home by name
    func getHome(named name: String) throws -> HMHome {
        guard let home = homeManager.homes.first(where: { $0.name == name }) else {
            throw HomeKitError.homeNotFound(name)
        }
        return home
    }
    
    // MARK: - Snapshot Operations
    
    /// Get a summary of all homes
    func getHomesSummary() -> HomesSummary {
        // primaryHome is deprecated; mark first home as "primary" for display
        let primaryId = homeManager.homes.first?.uniqueIdentifier
        let homes = homeManager.homes.map { HomeInfo(from: $0, isPrimary: $0.uniqueIdentifier == primaryId) }
        return HomesSummary(homes: homes, primaryHomeId: primaryId)
    }
    
    /// Load a complete snapshot of a home's state
    func loadSnapshot(for home: HMHome) -> HomeKitSnapshot {
        // primaryHome is deprecated; treat first home as primary
        let isPrimary = home.uniqueIdentifier == homeManager.homes.first?.uniqueIdentifier
        let homeInfo = HomeInfo(from: home, isPrimary: isPrimary)
        
        let defaultRoomId = home.roomForEntireHome().uniqueIdentifier
        
        // Get all rooms (excluding the default room)
        var rooms = home.rooms.map { RoomInfo(from: $0, homeId: home.uniqueIdentifier) }
        
        // Add the default room for reference
        let defaultRoom = RoomInfo(from: home.roomForEntireHome(), homeId: home.uniqueIdentifier, isDefault: true)
        rooms.insert(defaultRoom, at: 0)
        
        // Get all zones
        let zones = home.zones.map { ZoneInfo(from: $0) }
        
        // Get all accessories
        let accessories = home.accessories.map { AccessoryInfo(from: $0, defaultRoomId: defaultRoomId) }
        
        return HomeKitSnapshot(home: homeInfo, rooms: rooms, zones: zones, accessories: accessories)
    }
    
    /// Load snapshot for the primary home
    func loadPrimaryHomeSnapshot() throws -> HomeKitSnapshot {
        let home = try getPrimaryHome()
        return loadSnapshot(for: home)
    }
    
    // MARK: - Room Operations
    
    /// Create a new room in a home
    func createRoom(named name: String, in home: HMHome) async throws -> HMRoom {
        print("[DEBUG] createRoom called: '\(name)' in '\(home.name)'")
        
        return try await withCheckedThrowingContinuation { continuation in
            home.addRoom(withName: name) { room, error in
                if let error = error {
                    let nsError = error as NSError
                    print("[DEBUG] Create room FAILED:")
                    print("[DEBUG]   Error domain: \(nsError.domain)")
                    print("[DEBUG]   Error code: \(nsError.code)")
                    print("[DEBUG]   Error description: \(nsError.localizedDescription)")
                    print("[DEBUG]   Error userInfo: \(nsError.userInfo)")
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else if let room = room {
                    print("[DEBUG] Create room SUCCEEDED: '\(room.name)'")
                    continuation.resume(returning: room)
                } else {
                    continuation.resume(throwing: HomeKitError.operationFailed("Unknown error creating room"))
                }
            }
        }
    }
    
    /// Get a room by name in a home
    func getRoom(named name: String, in home: HMHome) -> HMRoom? {
        return home.rooms.first { $0.name == name }
    }
    
    /// Delete a room from a home
    func deleteRoom(_ room: HMRoom, in home: HMHome) async throws {
        print("[DEBUG] deleteRoom called: '\(room.name)' in '\(home.name)'")
        
        return try await withCheckedThrowingContinuation { continuation in
            home.removeRoom(room) { error in
                if let error = error {
                    let nsError = error as NSError
                    print("[DEBUG] Delete room FAILED:")
                    print("[DEBUG]   Error domain: \(nsError.domain)")
                    print("[DEBUG]   Error code: \(nsError.code)")
                    print("[DEBUG]   Error description: \(nsError.localizedDescription)")
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
                    print("[DEBUG] Delete room SUCCEEDED")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - Zone Operations
    
    /// Create a new zone in a home
    func createZone(named name: String, in home: HMHome) async throws -> HMZone {
        print("[DEBUG] createZone called: '\(name)' in '\(home.name)'")
        
        return try await withCheckedThrowingContinuation { continuation in
            home.addZone(withName: name) { zone, error in
                if let error = error {
                    let nsError = error as NSError
                    print("[DEBUG] Create zone FAILED:")
                    print("[DEBUG]   Error domain: \(nsError.domain)")
                    print("[DEBUG]   Error code: \(nsError.code)")
                    print("[DEBUG]   Error description: \(nsError.localizedDescription)")
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else if let zone = zone {
                    print("[DEBUG] Create zone SUCCEEDED: '\(zone.name)'")
                    continuation.resume(returning: zone)
                } else {
                    continuation.resume(throwing: HomeKitError.operationFailed("Unknown error creating zone"))
                }
            }
        }
    }
    
    /// Get a zone by name in a home
    func getZone(named name: String, in home: HMHome) -> HMZone? {
        return home.zones.first { $0.name == name }
    }
    
    /// Get a zone by ID in a home
    func getZone(id: UUID, in home: HMHome) -> HMZone? {
        return home.zones.first { $0.uniqueIdentifier == id }
    }
    
    /// Delete a zone from a home
    func deleteZone(_ zone: HMZone, in home: HMHome) async throws {
        print("[DEBUG] deleteZone called: '\(zone.name)' in '\(home.name)'")
        
        return try await withCheckedThrowingContinuation { continuation in
            home.removeZone(zone) { error in
                if let error = error {
                    let nsError = error as NSError
                    print("[DEBUG] Delete zone FAILED:")
                    print("[DEBUG]   Error domain: \(nsError.domain)")
                    print("[DEBUG]   Error code: \(nsError.code)")
                    print("[DEBUG]   Error description: \(nsError.localizedDescription)")
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
                    print("[DEBUG] Delete zone SUCCEEDED")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Add a room to a zone
    func addRoom(_ room: HMRoom, to zone: HMZone) async throws {
        print("[DEBUG] addRoom to zone called: '\(room.name)' to '\(zone.name)'")
        
        return try await withCheckedThrowingContinuation { continuation in
            zone.addRoom(room) { error in
                if let error = error {
                    let nsError = error as NSError
                    print("[DEBUG] Add room to zone FAILED:")
                    print("[DEBUG]   Error domain: \(nsError.domain)")
                    print("[DEBUG]   Error code: \(nsError.code)")
                    print("[DEBUG]   Error description: \(nsError.localizedDescription)")
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
                    print("[DEBUG] Add room to zone SUCCEEDED")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Remove a room from a zone
    func removeRoom(_ room: HMRoom, from zone: HMZone) async throws {
        print("[DEBUG] removeRoom from zone called: '\(room.name)' from '\(zone.name)'")
        
        return try await withCheckedThrowingContinuation { continuation in
            zone.removeRoom(room) { error in
                if let error = error {
                    let nsError = error as NSError
                    print("[DEBUG] Remove room from zone FAILED:")
                    print("[DEBUG]   Error domain: \(nsError.domain)")
                    print("[DEBUG]   Error code: \(nsError.code)")
                    print("[DEBUG]   Error description: \(nsError.localizedDescription)")
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
                    print("[DEBUG] Remove room from zone SUCCEEDED")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - Accessory Operations
    
    /// Assign an accessory to a room
    func assignAccessory(_ accessory: HMAccessory, to room: HMRoom, in home: HMHome) async throws {
        print("[DEBUG] assignAccessory called:")
        print("[DEBUG]   accessory: '\(accessory.name)' (UUID: \(accessory.uniqueIdentifier))")
        print("[DEBUG]   room: '\(room.name)' (UUID: \(room.uniqueIdentifier))")
        print("[DEBUG]   home: '\(home.name)' (UUID: \(home.uniqueIdentifier))")
        print("[DEBUG]   accessory.room: '\(accessory.room?.name ?? "nil")'")
        
        return try await withCheckedThrowingContinuation { continuation in
            home.assignAccessory(accessory, to: room) { error in
                if let error = error {
                    let nsError = error as NSError
                    print("[DEBUG] Assignment FAILED:")
                    print("[DEBUG]   Error domain: \(nsError.domain)")
                    print("[DEBUG]   Error code: \(nsError.code)")
                    print("[DEBUG]   Error description: \(nsError.localizedDescription)")
                    print("[DEBUG]   Error userInfo: \(nsError.userInfo)")
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
                    print("[DEBUG] Assignment SUCCEEDED")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Rename an accessory
    func renameAccessory(_ accessory: HMAccessory, to newName: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            accessory.updateName(newName) { error in
                if let error = error {
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Find an accessory by name in a home
    func getAccessory(named name: String, in home: HMHome) -> HMAccessory? {
        return home.accessories.first { $0.name == name }
    }
    
    /// Find an accessory by UUID in a home
    func getAccessory(id: UUID, in home: HMHome) -> HMAccessory? {
        return home.accessories.first { $0.uniqueIdentifier == id }
    }
    
    /// Remove an accessory from a home
    func removeAccessory(_ accessory: HMAccessory, from home: HMHome) async throws {
        print("[DEBUG] removeAccessory called: '\(accessory.name)' from '\(home.name)'")
        
        return try await withCheckedThrowingContinuation { continuation in
            home.removeAccessory(accessory) { error in
                if let error = error {
                    let nsError = error as NSError
                    print("[DEBUG] Remove accessory FAILED:")
                    print("[DEBUG]   Error domain: \(nsError.domain)")
                    print("[DEBUG]   Error code: \(nsError.code)")
                    print("[DEBUG]   Error description: \(nsError.localizedDescription)")
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
                    print("[DEBUG] Remove accessory SUCCEEDED")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - Scene Operations
    
    /// Create a new action set (scene) in a home
    func createActionSet(named name: String, in home: HMHome) async throws -> HMActionSet {
        return try await withCheckedThrowingContinuation { continuation in
            home.addActionSet(withName: name) { actionSet, error in
                if let error = error {
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else if let actionSet = actionSet {
                    continuation.resume(returning: actionSet)
                } else {
                    continuation.resume(throwing: HomeKitError.operationFailed("Unknown error creating scene"))
                }
            }
        }
    }
    
    /// Add an action to an action set
    func addAction(_ action: HMAction, to actionSet: HMActionSet) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            actionSet.addAction(action) { error in
                if let error = error {
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Get an action set by name in a home
    func getActionSet(named name: String, in home: HMHome) -> HMActionSet? {
        return home.actionSets.first { $0.name == name }
    }
}

// MARK: - HMHomeManagerDelegate

extension HomeKitManager: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        print("[DEBUG] homeManagerDidUpdateHomes called, homes count: \(manager.homes.count)")
        Task { @MainActor in
            self.isReady = true
            self.homesLoadedContinuation?.resume()
            self.homesLoadedContinuation = nil
        }
    }
    
    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        print("[DEBUG] didUpdate status called: \(status.rawValue)")
        // Authorization status changed - if we're waiting and now authorized, we'll get homeManagerDidUpdateHomes
        if status.contains(.authorized) {
            print("[DEBUG] Status contains .authorized, resuming...")
            Task { @MainActor in
                self.isReady = true
                self.homesLoadedContinuation?.resume()
                self.homesLoadedContinuation = nil
            }
        }
    }
}

