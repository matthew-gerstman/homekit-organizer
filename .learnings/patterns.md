# Working Patterns

> Patterns that work well in this codebase. Reference these when implementing new features.

---

## HomeKit Patterns

### Wrapping Completion Handlers with async/await

```swift
extension HMHome {
    func addRoomAsync(withName name: String) async throws -> HMRoom {
        try await withCheckedThrowingContinuation { continuation in
            addRoom(withName: name) { room, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let room = room {
                    continuation.resume(returning: room)
                } else {
                    continuation.resume(throwing: HomeKitError.unknownError)
                }
            }
        }
    }
}
```

### Waiting for HMHomeManager to Initialize

```swift
// HMHomeManager doesn't have homes immediately - must wait for delegate
class HomeKitManager: NSObject, HMHomeManagerDelegate {
    private let homeManager = HMHomeManager()
    private var homesLoaded = false
    private var continuation: CheckedContinuation<[HMHome], Never>?
    
    func getHomes() async -> [HMHome] {
        if homesLoaded {
            return homeManager.homes
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        homesLoaded = true
        continuation?.resume(returning: manager.homes)
        continuation = nil
    }
}
```

---

## Config Parsing Patterns

### Codable with Custom Decoding for Union Types

The config allows both strings and pattern objects for accessories:

```yaml
accessories:
  - "Exact Name"           # String
  - pattern: "Living *"    # Object
```

Handle with enum:

```swift
enum AccessoryMatcher: Codable {
    case exact(String)
    case pattern(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .exact(string)
        } else {
            let obj = try container.decode(PatternObject.self)
            self = .pattern(obj.pattern)
        }
    }
}

struct PatternObject: Codable {
    let pattern: String
}
```

---

## CLI Patterns

### ArgumentParser Subcommands

```swift
@main
struct HomeKitOrganizer: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "homekit-organizer",
        abstract: "Organize HomeKit accessories",
        subcommands: [Apply.self, List.self, Export.self, Diff.self]
    )
}

struct Apply: ParsableCommand {
    @Argument(help: "Path to config file")
    var configPath: String
    
    @Flag(name: .long, help: "Preview changes without applying")
    var dryRun = false
    
    func run() throws {
        // Implementation
    }
}
```

---

## Testing Patterns

### Using HomeKit Accessory Simulator

1. Download from Apple Developer > More Downloads > "Additional Tools for Xcode"
2. Run HomeKit Accessory Simulator
3. Add test accessories
4. They appear in Home app and are accessible via HMHomeManager

*Note: Requires real iCloud account even for simulated accessories*

---

## Error Handling Patterns

### Custom Error Types

```swift
enum HomeKitOrganizerError: LocalizedError {
    case homeNotFound(String)
    case accessoryNotFound(String)
    case configParseError(String)
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .homeNotFound(let name):
            return "Home '\(name)' not found"
        case .accessoryNotFound(let name):
            return "Accessory '\(name)' not found"
        case .configParseError(let detail):
            return "Config error: \(detail)"
        case .authorizationDenied:
            return "HomeKit access denied. Grant permission in System Settings > Privacy > HomeKit"
        }
    }
}
```

---

## Mac Catalyst Build Patterns

### project.yml for HomeKit CLI App

```yaml
name: HomeKitOrganizer
options:
  bundleIdPrefix: com.homekit-organizer
  deploymentTarget:
    iOS: "17.0"

targets:
  homekit-organizer:
    type: application
    platform: iOS
    deploymentTarget:
      iOS: "17.0"
    sources:
      - Sources/homekit-organizer
    dependencies:
      - package: Yams
      - package: swift-argument-parser
        product: ArgumentParser
      - sdk: HomeKit.framework
    settings:
      base:
        SUPPORTS_MACCATALYST: YES
        OTHER_SWIFT_FLAGS: "-parse-as-library"
        CODE_SIGN_ENTITLEMENTS: homekit-organizer.entitlements
        LSUIElement: true  # No dock icon
```

### Build Command for Mac Catalyst

```bash
# Generate project
xcodegen generate

# Build for Mac Catalyst (unsigned for dev)
xcodebuild -project HomeKitOrganizer.xcodeproj \
  -scheme homekit-organizer \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  build \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

# The CLI binary is at:
# DerivedData/.../Debug-maccatalyst/homekit-organizer.app/Contents/MacOS/homekit-organizer
```

### Running Main Actor Code in Async CLI Commands

```swift
struct ListHomes: AsyncParsableCommand {
    @MainActor
    func run() async throws {
        // Now HomeKitManager methods can be called directly
        let manager = HomeKitManager()
        try await manager.waitForHomesLoaded()
        let summary = manager.getHomesSummary()
        // ...
    }
}
```

Or without marking the whole function:

```swift
func run() async throws {
    let summary = await MainActor.run {
        let manager = HomeKitManager()
        // ... main-actor-isolated code
    }
}
```

---

## Snapshot Model Pattern

### Decoupling from HomeKit with Value Types

Create simple structs to hold HomeKit data, decoupled from the framework:

```swift
/// Simplified representation - holds just what we need
struct AccessoryInfo {
    let id: UUID
    let name: String
    let roomId: UUID?
    let isReachable: Bool
    let category: String
    
    init(from accessory: HMAccessory, defaultRoomId: UUID?) {
        self.id = accessory.uniqueIdentifier
        self.name = accessory.name
        // Treat default room as "unassigned" (nil roomId)
        if let room = accessory.room, room.uniqueIdentifier != defaultRoomId {
            self.roomId = room.uniqueIdentifier
        } else {
            self.roomId = nil
        }
        self.isReachable = accessory.isReachable
        self.category = accessory.category.localizedDescription
    }
}
```

### Snapshot Container

```swift
struct HomeKitSnapshot {
    let home: HomeInfo
    let rooms: [RoomInfo]
    let accessories: [AccessoryInfo]
    
    var unassignedAccessories: [AccessoryInfo] {
        accessories.filter { $0.roomId == nil }
    }
    
    var accessoriesByRoom: [UUID: [AccessoryInfo]] {
        Dictionary(grouping: accessories.filter { $0.roomId != nil }, by: { $0.roomId! })
    }
}
```

---

## HMHomeManagerDelegate Pattern

### Proper Delegate Setup with Continuation

```swift
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
    
    func waitForHomesLoaded() async throws {
        if isReady { return }
        await withCheckedContinuation { continuation in
            self.homesLoadedContinuation = continuation
        }
        // Check authorization after homes loaded
        guard homeManager.authorizationStatus == .authorized else {
            throw HomeKitError.notAuthorized
        }
    }
}

extension HomeKitManager: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.isReady = true
            self.homesLoadedContinuation?.resume()
            self.homesLoadedContinuation = nil
        }
    }
}
```

Key points:
- Mark delegate methods `nonisolated` then dispatch to `@MainActor` via Task
- Store continuation to bridge callback to async/await
- Check `isReady` flag to avoid waiting if already loaded

---

## Config Parsing with Yams

### Union Type Decoding (String OR Object)

For YAML like:
```yaml
accessories:
  - "Exact Name"           # String
  - pattern: "Living *"    # Object with pattern key
```

Use enum with custom decoder:

```swift
enum AccessorySelector: Codable {
    case exact(String)
    case pattern(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try string first (exact match)
        if let exactName = try? container.decode(String.self) {
            self = .exact(exactName)
            return
        }
        
        // Try object with pattern key
        let patternContainer = try decoder.container(keyedBy: PatternCodingKeys.self)
        if let pattern = try? patternContainer.decode(String.self, forKey: .pattern) {
            self = .pattern(pattern)
            return
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Must be string or object with 'pattern' key"
        )
    }
    
    private enum PatternCodingKeys: String, CodingKey {
        case pattern
    }
}
```

### Validation with Aggregated Errors

Collect all errors instead of failing fast:

```swift
struct ConfigValidator {
    static func validate(_ config: Config) -> ValidationResult {
        var errors: [ConfigValidationError] = []
        var warnings: [String] = []
        
        // Validate each section, collecting all errors
        if let rooms = config.rooms {
            errors.append(contentsOf: validateRooms(rooms))
        }
        
        if errors.isEmpty {
            return .valid
        }
        return .invalid(errors, warnings: warnings)
    }
}
```

### Pretty-Print Config for Debugging

```swift
static func dump(_ config: Config) -> String {
    var output: [String] = []
    output.append("=== Configuration ===")
    
    if let rooms = config.rooms {
        output.append("\n--- Rooms (\(rooms.count)) ---")
        for room in rooms {
            output.append("  \(room.name):")
            // ...
        }
    }
    
    return output.joined(separator: "\n")
}
```
