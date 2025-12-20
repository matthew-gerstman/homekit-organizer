# Testing Plan for HomeKit Organizer

This document outlines the testing strategy for the HomeKit Organizer CLI tool.

## Testing Layers

### 1. Unit Tests (No HomeKit Required)

These tests can run without HomeKit access and test pure logic:

#### Config Parsing Tests
```swift
// Tests/ConfigParserTests.swift

func testParseValidConfig() {
    let yaml = """
    home: "My Home"
    rooms:
      - name: "Living Room"
        accessories:
          - "Lamp"
    """
    let config = try ConfigParser.parse(yaml: yaml)
    XCTAssertEqual(config.home, "My Home")
    XCTAssertEqual(config.rooms?.count, 1)
}

func testParseExactAccessorySelector() {
    let yaml = """
    rooms:
      - name: "Test"
        accessories:
          - "Exact Name"
    """
    let config = try ConfigParser.parse(yaml: yaml)
    if case .exact(let name) = config.rooms![0].accessories![0] {
        XCTAssertEqual(name, "Exact Name")
    } else {
        XCTFail("Expected exact selector")
    }
}

func testParsePatternAccessorySelector() {
    let yaml = """
    rooms:
      - name: "Test"
        accessories:
          - pattern: "Living *"
    """
    let config = try ConfigParser.parse(yaml: yaml)
    if case .pattern(let p) = config.rooms![0].accessories![0] {
        XCTAssertEqual(p, "Living *")
    } else {
        XCTFail("Expected pattern selector")
    }
}

func testParseSceneWithCharacteristics() {
    let yaml = """
    scenes:
      - name: "Movie Night"
        actions:
          - accessory: "Lamp"
            service: "lightbulb"
            characteristics:
              on: true
              brightness: 50
    """
    let config = try ConfigParser.parse(yaml: yaml)
    XCTAssertEqual(config.scenes?[0].actions?[0].characteristics.on, true)
    XCTAssertEqual(config.scenes?[0].actions?[0].characteristics.brightness, 50)
}

func testParseEmptyConfigFails() {
    XCTAssertThrowsError(try ConfigParser.parse(yaml: ""))
}

func testParseInvalidYamlFails() {
    XCTAssertThrowsError(try ConfigParser.parse(yaml: "not: valid: yaml: {{"))
}
```

#### Config Validation Tests
```swift
// Tests/ConfigValidatorTests.swift

func testValidConfigPasses() {
    let config = Config(
        home: "Home",
        rooms: [RoomConfig(name: "Room", accessories: nil)],
        renames: nil,
        scenes: nil
    )
    let result = ConfigValidator.validate(config)
    XCTAssertTrue(result.isValid)
}

func testDuplicateRoomNameFails() {
    let config = Config(
        home: nil,
        rooms: [
            RoomConfig(name: "Living Room", accessories: nil),
            RoomConfig(name: "Living Room", accessories: nil)
        ],
        renames: nil,
        scenes: nil
    )
    let result = ConfigValidator.validate(config)
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains { 
        if case .duplicateRoomName = $0 { return true }
        return false
    })
}

func testEmptyRoomNameFails() {
    let config = Config(
        home: nil,
        rooms: [RoomConfig(name: "", accessories: nil)],
        renames: nil,
        scenes: nil
    )
    let result = ConfigValidator.validate(config)
    XCTAssertFalse(result.isValid)
}

func testDuplicateSceneNameFails() {
    let config = Config(
        home: nil,
        rooms: nil,
        renames: nil,
        scenes: [
            SceneConfig(name: "Scene", actions: nil),
            SceneConfig(name: "Scene", actions: nil)
        ]
    )
    let result = ConfigValidator.validate(config)
    XCTAssertFalse(result.isValid)
}

func testInvalidBrightnessFails() {
    // brightness: 150 should fail (valid range 0-100)
}

func testDuplicateRenameFromFails() {
    let config = Config(
        home: nil,
        rooms: nil,
        renames: [
            RenameRule(from: "old", to: "new1"),
            RenameRule(from: "old", to: "new2")
        ],
        scenes: nil
    )
    let result = ConfigValidator.validate(config)
    XCTAssertFalse(result.isValid)
}
```

#### AccessoryMatcher Tests
```swift
// Tests/AccessoryMatcherTests.swift

func testExactMatch() {
    let accessories = [
        AccessoryInfo(id: UUID(), name: "Living Room Lamp", roomId: nil, roomName: nil, 
                      isReachable: true, category: "Lightbulb", services: [])
    ]
    let result = AccessoryMatcher.match(
        selector: .exact("Living Room Lamp"),
        against: accessories
    )
    XCTAssertEqual(result.matchedAccessories.count, 1)
    XCTAssertTrue(result.isExact)
}

func testExactMatchCaseInsensitive() {
    let accessories = [
        AccessoryInfo(id: UUID(), name: "Living Room Lamp", ...)
    ]
    let result = AccessoryMatcher.match(
        selector: .exact("living room lamp"),
        against: accessories
    )
    XCTAssertEqual(result.matchedAccessories.count, 1)
}

func testExactMatchNoMatch() {
    let accessories = [
        AccessoryInfo(id: UUID(), name: "Kitchen Light", ...)
    ]
    let result = AccessoryMatcher.match(
        selector: .exact("Living Room Lamp"),
        against: accessories
    )
    XCTAssertEqual(result.matchedAccessories.count, 0)
}

func testWildcardMatchSuffix() {
    let accessories = [
        AccessoryInfo(id: UUID(), name: "Living Room Lamp", ...),
        AccessoryInfo(id: UUID(), name: "Living Room Fan", ...),
        AccessoryInfo(id: UUID(), name: "Kitchen Light", ...)
    ]
    let result = AccessoryMatcher.match(
        selector: .pattern("Living Room *"),
        against: accessories
    )
    XCTAssertEqual(result.matchedAccessories.count, 2)
}

func testWildcardMatchPrefix() {
    let accessories = [
        AccessoryInfo(id: UUID(), name: "Main Light", ...),
        AccessoryInfo(id: UUID(), name: "Backup Light", ...)
    ]
    let result = AccessoryMatcher.match(
        selector: .pattern("* Light"),
        against: accessories
    )
    XCTAssertEqual(result.matchedAccessories.count, 2)
}

func testWildcardMatchMiddle() {
    let accessories = [
        AccessoryInfo(id: UUID(), name: "Light 1 Main", ...),
        AccessoryInfo(id: UUID(), name: "Light 2 Main", ...)
    ]
    let result = AccessoryMatcher.match(
        selector: .pattern("Light * Main"),
        against: accessories
    )
    XCTAssertEqual(result.matchedAccessories.count, 2)
}

func testRegexMatch() {
    let accessories = [
        AccessoryInfo(id: UUID(), name: "LR_Lamp_1", ...),
        AccessoryInfo(id: UUID(), name: "LR_Lamp_2", ...),
        AccessoryInfo(id: UUID(), name: "Kitchen_Light", ...)
    ]
    let result = AccessoryMatcher.match(
        selector: .pattern("^LR_.*"),
        against: accessories
    )
    XCTAssertEqual(result.matchedAccessories.count, 2)
}

func testRegexMatchSuffix() {
    let accessories = [
        AccessoryInfo(id: UUID(), name: "Device_v1", ...),
        AccessoryInfo(id: UUID(), name: "Device_v2", ...),
        AccessoryInfo(id: UUID(), name: "Other", ...)
    ]
    let result = AccessoryMatcher.match(
        selector: .pattern(".*_v[0-9]$"),
        against: accessories
    )
    XCTAssertEqual(result.matchedAccessories.count, 2)
}
```

#### Planner Tests
```swift
// Tests/PlannerTests.swift

func testPlanCreateNewRoom() {
    let snapshot = HomeKitSnapshot(
        home: HomeInfo(id: UUID(), name: "Home", isPrimary: true),
        rooms: [],
        accessories: []
    )
    let config = Config(
        home: nil,
        rooms: [RoomConfig(name: "New Room", accessories: nil)],
        renames: nil,
        scenes: nil
    )
    
    let plan = Planner.plan(config: config, snapshot: snapshot)
    
    XCTAssertEqual(plan.operations.count, 1)
    if case .createRoom(let name) = plan.operations[0] {
        XCTAssertEqual(name, "New Room")
    } else {
        XCTFail("Expected createRoom operation")
    }
}

func testPlanSkipExistingRoom() {
    let snapshot = HomeKitSnapshot(
        home: HomeInfo(id: UUID(), name: "Home", isPrimary: true),
        rooms: [RoomInfo(id: UUID(), name: "Living Room", homeId: UUID(), isDefault: false)],
        accessories: []
    )
    let config = Config(
        home: nil,
        rooms: [RoomConfig(name: "Living Room", accessories: nil)],
        renames: nil,
        scenes: nil
    )
    
    let plan = Planner.plan(config: config, snapshot: snapshot)
    
    XCTAssertTrue(plan.isEmpty)
    XCTAssertEqual(plan.skipped.count, 1)
}

func testPlanAssignAccessory() {
    let accessoryId = UUID()
    let snapshot = HomeKitSnapshot(
        home: HomeInfo(id: UUID(), name: "Home", isPrimary: true),
        rooms: [RoomInfo(id: UUID(), name: "Living Room", homeId: UUID(), isDefault: false)],
        accessories: [
            AccessoryInfo(id: accessoryId, name: "Lamp", roomId: nil, roomName: nil,
                         isReachable: true, category: "Light", services: [])
        ]
    )
    let config = Config(
        home: nil,
        rooms: [RoomConfig(name: "Living Room", accessories: [.exact("Lamp")])],
        renames: nil,
        scenes: nil
    )
    
    let plan = Planner.plan(config: config, snapshot: snapshot)
    
    XCTAssertTrue(plan.operations.contains {
        if case .assignAccessory(let id, _, let room) = $0 {
            return id == accessoryId && room == "Living Room"
        }
        return false
    })
}

func testPlanSkipAlreadyAssigned() {
    let roomId = UUID()
    let accessoryId = UUID()
    let snapshot = HomeKitSnapshot(
        home: HomeInfo(id: UUID(), name: "Home", isPrimary: true),
        rooms: [RoomInfo(id: roomId, name: "Living Room", homeId: UUID(), isDefault: false)],
        accessories: [
            AccessoryInfo(id: accessoryId, name: "Lamp", roomId: roomId, roomName: "Living Room",
                         isReachable: true, category: "Light", services: [])
        ]
    )
    let config = Config(
        home: nil,
        rooms: [RoomConfig(name: "Living Room", accessories: [.exact("Lamp")])],
        renames: nil,
        scenes: nil
    )
    
    let plan = Planner.plan(config: config, snapshot: snapshot)
    
    XCTAssertTrue(plan.isEmpty)
}

func testPlanWarningForMissingAccessory() {
    let snapshot = HomeKitSnapshot(
        home: HomeInfo(id: UUID(), name: "Home", isPrimary: true),
        rooms: [],
        accessories: []
    )
    let config = Config(
        home: nil,
        rooms: [RoomConfig(name: "Room", accessories: [.exact("NonExistent")])],
        renames: nil,
        scenes: nil
    )
    
    let plan = Planner.plan(config: config, snapshot: snapshot)
    
    XCTAssertFalse(plan.warnings.isEmpty)
}
```

#### Exporter Tests
```swift
// Tests/ExporterTests.swift

func testExportRoundTrip() {
    let snapshot = HomeKitSnapshot(
        home: HomeInfo(id: UUID(), name: "My Home", isPrimary: true),
        rooms: [
            RoomInfo(id: UUID(), name: "Living Room", homeId: UUID(), isDefault: false)
        ],
        accessories: [
            AccessoryInfo(id: UUID(), name: "Lamp", roomId: rooms[0].id, roomName: "Living Room", ...)
        ]
    )
    
    let yaml = Exporter.exportYAML(snapshot: snapshot, includeComments: false)
    let parsed = try ConfigParser.parse(yaml: yaml)
    
    XCTAssertEqual(parsed.home, "My Home")
    XCTAssertEqual(parsed.rooms?.count, 1)
}
```

---

### 2. Integration Tests (Requires HomeKit Simulator)

These tests require the HomeKit Accessory Simulator from Xcode Additional Tools.

#### Setup
1. Download "Additional Tools for Xcode" from Apple Developer
2. Run HomeKit Accessory Simulator
3. Create test accessories:
   - Light: "Test Light 1"
   - Light: "Test Light 2"
   - Switch: "Test Switch"

#### Test Cases

```swift
// Tests/Integration/HomeKitIntegrationTests.swift

func testListHomes() async throws {
    let manager = HomeKitManager()
    try await manager.waitForHomesLoaded()
    
    let summary = manager.getHomesSummary()
    XCTAssertFalse(summary.homes.isEmpty)
}

func testListAccessories() async throws {
    let manager = HomeKitManager()
    try await manager.waitForHomesLoaded()
    
    let snapshot = try manager.loadPrimaryHomeSnapshot()
    // Should have simulator accessories
    XCTAssertFalse(snapshot.accessories.isEmpty)
}

func testCreateAndDeleteRoom() async throws {
    let manager = HomeKitManager()
    try await manager.waitForHomesLoaded()
    let home = try manager.getPrimaryHome()
    
    // Create
    let room = try await manager.createRoom(named: "Test Room \(UUID())", in: home)
    XCTAssertNotNil(room)
    
    // Verify exists
    let snapshot = manager.loadSnapshot(for: home)
    XCTAssertTrue(snapshot.rooms.contains { $0.name == room.name })
    
    // Clean up (delete room if API available)
}

func testAssignAccessoryToRoom() async throws {
    // Setup: Create test room, find unassigned accessory
    // Action: Assign accessory to room
    // Verify: Accessory.room matches target room
}

func testCreateScene() async throws {
    // Setup: Find a lightbulb accessory
    // Action: Create scene with brightness action
    // Verify: Scene appears in home.actionSets
}
```

---

### 3. CLI End-to-End Tests

Test the actual CLI commands work as expected.

#### Test Script
```bash
#!/bin/bash
# tests/e2e/test_cli.sh

CLI="./homekit-organizer.app/Contents/MacOS/homekit-organizer"

echo "=== CLI E2E Tests ==="

# Test help
echo "Testing: --help"
$CLI --help || exit 1

echo "Testing: list --help"
$CLI list --help || exit 1

# Test version
echo "Testing: --version"
$CLI --version || exit 1

# Test config parsing (doesn't need HomeKit)
echo "Testing: apply with invalid path"
$CLI apply /nonexistent/config.yaml 2>&1 | grep -q "not found" || exit 1

# Test config validation
echo "Testing: apply with valid config (dry-run would need HomeKit)"
cat > /tmp/test-config.yaml << EOF
rooms:
  - name: "Test Room"
    accessories:
      - "Test Light"
EOF

# This will fail without HomeKit access but should parse OK
$CLI apply /tmp/test-config.yaml -v 2>&1 | head -5

echo "=== All CLI tests passed ==="
```

---

### 4. Manual Testing Checklist

#### First Run Experience
- [ ] App prompts for HomeKit permission on first run
- [ ] Permission dialog shows correct usage description
- [ ] After granting permission, `list homes` works

#### List Commands
- [ ] `list homes` shows all homes with primary marker
- [ ] `list rooms` shows all rooms with accessory counts
- [ ] `list accessories` groups by room
- [ ] `list accessories --unassigned` shows only default room items
- [ ] `list accessories --room "Kitchen"` filters correctly
- [ ] `-v` flag shows UUIDs

#### Apply Command
- [ ] `apply config.yaml --dry-run` shows planned operations
- [ ] `apply config.yaml --dry-run -v` shows skipped items
- [ ] `apply config.yaml` executes operations (test with real HomeKit)
- [ ] Running apply twice is idempotent (second run shows no changes)
- [ ] Invalid config path shows clear error
- [ ] Invalid YAML shows parsing error with line info
- [ ] Validation errors list all issues

#### Diff Command
- [ ] `diff config.yaml` shows differences
- [ ] When state matches config, shows "no differences"
- [ ] Warnings shown for missing accessories

#### Export Command
- [ ] `export` prints YAML to stdout
- [ ] `export -o file.yaml` writes to file
- [ ] `export --no-comments` omits comments
- [ ] Exported config can be re-imported (round-trip)

#### Pattern Matching
- [ ] Exact names match (case-insensitive)
- [ ] Wildcards: `*` matches any substring
- [ ] Regex: `^prefix.*` works
- [ ] Regex: `.*suffix$` works
- [ ] No matches generates warning

#### Error Handling
- [ ] No HomeKit access shows helpful error
- [ ] Network timeout shows retry suggestion
- [ ] Missing home shows setup instructions

---

### 5. Test Data Files

#### tests/fixtures/valid-config.yaml
```yaml
home: "Test Home"

rooms:
  - name: "Living Room"
    accessories:
      - "Test Light 1"
      - pattern: "Test *"
  
  - name: "Kitchen"
    accessories:
      - "Test Switch"

renames:
  - from: "old_name"
    to: "New Name"

scenes:
  - name: "Test Scene"
    actions:
      - accessory: "Test Light 1"
        service: "lightbulb"
        characteristics:
          on: true
          brightness: 50
```

#### tests/fixtures/invalid-duplicate-room.yaml
```yaml
rooms:
  - name: "Living Room"
  - name: "Living Room"  # Duplicate!
```

#### tests/fixtures/invalid-empty-name.yaml
```yaml
rooms:
  - name: ""  # Empty!
```

#### tests/fixtures/invalid-brightness.yaml
```yaml
scenes:
  - name: "Bad Scene"
    actions:
      - accessory: "Light"
        service: "lightbulb"
        characteristics:
          brightness: 150  # Invalid! Must be 0-100
```

---

### 6. Running Tests

#### Unit Tests
```bash
# When test target is added to project.yml
xcodegen generate
xcodebuild test -project HomeKitOrganizer.xcodeproj \
  -scheme homekit-organizer-tests \
  -destination 'platform=macOS,variant=Mac Catalyst'
```

#### Integration Tests
```bash
# Requires:
# 1. HomeKit Accessory Simulator running
# 2. Test accessories created
# 3. App signed with entitlements

xcodebuild test -project HomeKitOrganizer.xcodeproj \
  -scheme homekit-organizer-integration-tests \
  -destination 'platform=macOS,variant=Mac Catalyst'
```

#### E2E Tests
```bash
# Build release, sign, then run
./tests/e2e/test_cli.sh
```

---

### 7. CI/CD Considerations

#### What Can Run in CI (No HomeKit)
- Config parsing tests
- Config validation tests  
- AccessoryMatcher pattern tests
- Planner tests (with mock snapshots)
- Exporter tests

#### What Requires Manual Testing
- HomeKit API integration (needs real/simulator devices)
- Permission flows
- Actual room/accessory/scene operations

#### GitHub Actions Workflow (Unit Tests Only)
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Install xcodegen
        run: brew install xcodegen
      - name: Generate project
        run: xcodegen generate
      - name: Run unit tests
        run: |
          xcodebuild test \
            -project HomeKitOrganizer.xcodeproj \
            -scheme homekit-organizer-unit-tests \
            -destination 'platform=macOS,variant=Mac Catalyst' \
            CODE_SIGNING_REQUIRED=NO
```

---

## Next Steps to Implement Testing

1. **Add test target to project.yml**
2. **Create Tests/ directory structure**
3. **Write unit tests for ConfigParser, ConfigValidator, AccessoryMatcher, Planner**
4. **Add test fixtures**
5. **Create E2E test script**
6. **Document manual testing in releases**

