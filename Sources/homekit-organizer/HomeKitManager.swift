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
        if isReady { return }
        
        // Wait for delegate callback
        await withCheckedContinuation { continuation in
            self.homesLoadedContinuation = continuation
        }
        
        // Check authorization status
        let status = homeManager.authorizationStatus
        guard status == .authorized else {
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
        
        // Get all accessories
        let accessories = home.accessories.map { AccessoryInfo(from: $0, defaultRoomId: defaultRoomId) }
        
        return HomeKitSnapshot(home: homeInfo, rooms: rooms, accessories: accessories)
    }
    
    /// Load snapshot for the primary home
    func loadPrimaryHomeSnapshot() throws -> HomeKitSnapshot {
        let home = try getPrimaryHome()
        return loadSnapshot(for: home)
    }
    
    // MARK: - Room Operations
    
    /// Create a new room in a home
    func createRoom(named name: String, in home: HMHome) async throws -> HMRoom {
        return try await withCheckedThrowingContinuation { continuation in
            home.addRoom(withName: name) { room, error in
                if let error = error {
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else if let room = room {
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
    
    // MARK: - Accessory Operations
    
    /// Assign an accessory to a room
    func assignAccessory(_ accessory: HMAccessory, to room: HMRoom, in home: HMHome) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            home.assignAccessory(accessory, to: room) { error in
                if let error = error {
                    continuation.resume(throwing: HomeKitError.operationFailed(error.localizedDescription))
                } else {
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
        Task { @MainActor in
            self.isReady = true
            self.homesLoadedContinuation?.resume()
            self.homesLoadedContinuation = nil
        }
    }
    
    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        // Authorization status changed - if we're waiting and now authorized, we'll get homeManagerDidUpdateHomes
        if status == .authorized {
            Task { @MainActor in
                self.isReady = true
                self.homesLoadedContinuation?.resume()
                self.homesLoadedContinuation = nil
            }
        }
    }
}

