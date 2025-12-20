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
