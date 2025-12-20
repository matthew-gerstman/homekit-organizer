import Foundation
import ArgumentParser
import HomeKit

// MARK: - Main Entry Point

@main
struct HomeKitOrganizer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "homekit-organizer",
        abstract: "Organize Home Assistant devices in Apple HomeKit",
        version: "0.1.0",
        subcommands: [List.self, Apply.self, Diff.self, Export.self],
        defaultSubcommand: nil
    )
}

// MARK: - List Command

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List HomeKit homes, rooms, or accessories",
        subcommands: [ListHomes.self, ListRooms.self, ListAccessories.self]
    )
}

struct ListHomes: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "homes",
        abstract: "List all HomeKit homes"
    )
    
    @Flag(name: .shortAndLong, help: "Show verbose output including UUIDs")
    var verbose = false
    
    @MainActor
    func run() async throws {
        let manager = HomeKitManager()
        try await manager.waitForHomesLoaded()
        
        let summary = manager.getHomesSummary()
        
        if summary.homes.isEmpty {
            print("No HomeKit homes found.")
            print("Please set up a home in the Home app first.")
            return
        }
        
        print("HomeKit Homes (\(summary.homes.count)):")
        print(String(repeating: "-", count: 40))
        
        for home in summary.homes {
            let primaryMarker = home.isPrimary ? " ★" : ""
            print("  \(home.name)\(primaryMarker)")
            if verbose {
                print("    ID: \(home.id)")
            }
        }
        
print("")
        print("★ = Primary home")
    }
}

struct ListRooms: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rooms",
        abstract: "List all rooms in the primary home"
    )
    
    @Flag(name: .shortAndLong, help: "Show verbose output including UUIDs")
    var verbose = false
    
    @Flag(name: .long, help: "Include the default room (unassigned accessories)")
    var includeDefault = false
    
    @MainActor
    func run() async throws {
        let manager = HomeKitManager()
        try await manager.waitForHomesLoaded()
        
        let snapshot = try manager.loadPrimaryHomeSnapshot()
        
        print("Rooms in '\(snapshot.home.name)' (\(snapshot.rooms.count - 1) rooms + default):")
        print(String(repeating: "-", count: 50))
        
        for room in snapshot.rooms {
            if room.isDefault && !includeDefault {
                continue
            }
            
            let accessoryCount = snapshot.accessories.filter { 
                room.isDefault ? $0.roomId == nil : $0.roomId == room.id 
            }.count
            
            let defaultMarker = room.isDefault ? " (Default Room)" : ""
            print("  \(room.name)\(defaultMarker) - \(accessoryCount) accessories")
            
            if verbose {
                print("    ID: \(room.id)")
            }
        }
    }
}

struct ListAccessories: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "accessories",
        abstract: "List all accessories in the primary home"
    )
    
    @Flag(name: .shortAndLong, help: "Show verbose output including UUIDs and services")
    var verbose = false
    
    @Flag(name: .long, help: "Only show unassigned accessories (in default room)")
    var unassigned = false
    
    @Option(name: .long, help: "Filter by room name")
    var room: String?
    
    @MainActor
    func run() async throws {
        let manager = HomeKitManager()
        try await manager.waitForHomesLoaded()
        
        let snapshot = try manager.loadPrimaryHomeSnapshot()
        
        var accessories = snapshot.accessories
        
        // Apply filters
        if unassigned {
            accessories = snapshot.unassignedAccessories
        } else if let roomName = room {
            guard let roomInfo = snapshot.rooms.first(where: { $0.name == roomName }) else {
                print("Room '\(roomName)' not found.")
                return
            }
            accessories = accessories.filter { $0.roomId == roomInfo.id }
        }
        
        // Header
        if unassigned {
            print("Unassigned Accessories in '\(snapshot.home.name)' (\(accessories.count)):")
        } else if let roomName = room {
            print("Accessories in '\(roomName)' (\(accessories.count)):")
        } else {
            print("All Accessories in '\(snapshot.home.name)' (\(accessories.count)):")
        }
        print(String(repeating: "-", count: 60))
        
        if accessories.isEmpty {
            if unassigned {
                print("  No unassigned accessories found.")
            } else {
                print("  No accessories found.")
            }
            return
        }
        
        // Group by room for better readability (unless already filtered)
        if !unassigned && room == nil {
            // Show unassigned first
            let unassignedList = accessories.filter { $0.roomId == nil }
            if !unassignedList.isEmpty {
                print("\n  [Default Room - Unassigned] (\(unassignedList.count))")
                for accessory in unassignedList.sorted(by: { $0.name < $1.name }) {
                    printAccessory(accessory, verbose: verbose)
                }
            }
            
            // Then by room
            let byRoom = snapshot.accessoriesByRoom
            for room in snapshot.rooms.filter({ !$0.isDefault }).sorted(by: { $0.name < $1.name }) {
                if let roomAccessories = byRoom[room.id], !roomAccessories.isEmpty {
                    print("\n  [\(room.name)] (\(roomAccessories.count))")
                    for accessory in roomAccessories.sorted(by: { $0.name < $1.name }) {
                        printAccessory(accessory, verbose: verbose)
                    }
                }
            }
        } else {
            // Simple list
            for accessory in accessories.sorted(by: { $0.name < $1.name }) {
                printAccessory(accessory, verbose: verbose)
            }
        }
    }
    
    private func printAccessory(_ accessory: AccessoryInfo, verbose: Bool) {
        let reachable = accessory.isReachable ? "✓" : "✗"
        print("    \(reachable) \(accessory.name)")
        print("      Category: \(accessory.category)")
        
        if verbose {
            print("      ID: \(accessory.id)")
            print("      Services:")
            for service in accessory.services {
                print("        - \(service.name) (\(service.serviceType))")
            }
        }
    }
}

// MARK: - Apply Command

struct Apply: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Apply a configuration file to organize HomeKit"
    )
    
    @Argument(help: "Path to the YAML configuration file")
    var configPath: String
    
    @Flag(name: .long, help: "Preview changes without applying them")
    var dryRun = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose = false
    
    @MainActor
    func run() async throws {
        // Parse config
        if verbose {
            print("Loading configuration from: \(configPath)")
        }
        
        let config = try ConfigParser.parse(fromPath: configPath)
        
        // Validate config
        if verbose {
            print("Validating configuration...")
        }
        
        let validation = ConfigValidator.validate(config)
        
        // Show validation warnings
        for warning in validation.warnings {
            print("⚠️  Warning: \(warning)")
        }
        
        // Fail on validation errors
        if !validation.isValid {
            for error in validation.errors {
                print("❌ Error: \(error.errorDescription ?? "Unknown error")")
            }
            throw ExitCode.failure
        }
        
        if verbose {
            print("\n\(ConfigParser.dump(config))\n")
        }
        
        print("✅ Configuration is valid")
        print("   \(config)")
        
        // Load HomeKit state
        print("\nConnecting to HomeKit...")
        let manager = HomeKitManager()
        try await manager.waitForHomesLoaded()
        
        let home = try manager.getPrimaryHome()
        let snapshot = manager.loadSnapshot(for: home)
        
        print("Target home: \(snapshot.home.name)")
        
        // Create operation plan
        let plan = Planner.plan(config: config, snapshot: snapshot)
        
        print("\n\(plan.format(verbose: verbose))")
        
        if dryRun {
            print("\n--- Dry Run Mode ---")
            print("No changes applied.")
        } else if plan.isEmpty {
            print("\n✅ Nothing to do - HomeKit is already configured correctly!")
        } else {
            print("\n--- Executing Operations ---")
            
            let executor = Executor(manager: manager, home: home, verbose: verbose)
            let result = await executor.execute(plan: plan)
            
            print("\n--- Summary ---")
            print("✅ Succeeded: \(result.successCount)")
            if result.hasFailures {
                print("❌ Failed: \(result.failureCount)")
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Diff Command

struct Diff: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show differences between current state and configuration"
    )
    
    @Argument(help: "Path to the YAML configuration file")
    var configPath: String
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose = false
    
    @MainActor
    func run() async throws {
        // Parse and validate config
        let config = try ConfigParser.parse(fromPath: configPath)
        try ConfigValidator.validateOrThrow(config)
        
        if verbose {
            print("Configuration loaded from: \(configPath)")
            print("")
        }
        
        // Connect to HomeKit
        let manager = HomeKitManager()
        try await manager.waitForHomesLoaded()
        
        let home = try manager.getPrimaryHome()
        let snapshot = manager.loadSnapshot(for: home)
        
        print("Comparing against home: \(snapshot.home.name)")
        print(String(repeating: "=", count: 50))
        
        // Create operation plan (same as dry-run)
        let plan = Planner.plan(config: config, snapshot: snapshot)
        
        if plan.isEmpty {
            print("\n✅ No differences - HomeKit matches configuration")
            
            if verbose && !plan.skipped.isEmpty {
                print("\nAll items already configured:")
                for skip in plan.skipped {
                    print("  ✓ \(skip.description)")
                }
            }
        } else {
            print("\n\(plan.format(verbose: verbose))")
        }
        
        // Show warnings
        if !plan.warnings.isEmpty {
            print("\nWarnings:")
            for warning in plan.warnings {
                print("  ⚠️  \(warning)")
            }
        }
    }
}

// MARK: - Export Command

struct Export: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Export current HomeKit state as YAML configuration"
    )
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose = false
    
    @Flag(name: .long, help: "Exclude comments from output")
    var noComments = false
    
    @Option(name: .shortAndLong, help: "Output file path (default: stdout)")
    var output: String?
    
    @MainActor
    func run() async throws {
        // Connect to HomeKit
        if verbose {
            print("Connecting to HomeKit...")
        }
        
        let manager = HomeKitManager()
        try await manager.waitForHomesLoaded()
        
        let home = try manager.getPrimaryHome()
        let snapshot = manager.loadSnapshot(for: home)
        
        if verbose {
            print("Exporting from: \(snapshot.home.name)")
            print("  Rooms: \(snapshot.rooms.count - 1)") // Exclude default room
            print("  Accessories: \(snapshot.accessories.count)")
            print("")
        }
        
        // Generate YAML
        let yaml = Exporter.exportYAML(snapshot: snapshot, includeComments: !noComments)
        
        // Output
        if let outputPath = output {
            let expandedPath = (outputPath as NSString).expandingTildeInPath
            try yaml.write(toFile: expandedPath, atomically: true, encoding: .utf8)
            print("Configuration exported to: \(outputPath)")
        } else {
            print(yaml)
        }
    }
}
