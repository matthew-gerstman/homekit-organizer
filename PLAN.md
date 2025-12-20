# HomeKit Organizer CLI - Implementation Plan

**Status**: In Progress
**Target Platform**: macOS (native Swift)
**Purpose**: Programmatically organize Home Assistant devices exposed to HomeKit

---

## Problem Statement

Home Assistant's HomeKit Bridge integration exposes entities to Apple Home, but **all devices land in the "Default Room"** with no way to:

- Assign them to rooms programmatically
- Rename them in bulk
- Create scenes automatically
- Organize them without manual drag-and-drop in the Home app

This tool bridges that gap by leveraging Apple's native HomeKit framework on macOS.

---

## Solution Overview

A Swift command-line tool that:

1. Reads a YAML/JSON configuration file defining room assignments
2. Connects to HomeKit via `HMHomeManager`
3. Creates missing rooms
4. Matches accessories by name and assigns them to rooms
5. Optionally renames accessories and creates scenes

### Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Home Assistant  │────▶│  HomeKit Bridge  │────▶│   Apple Home    │
│    Entities     │     │   (HA Integration)│     │  (Default Room) │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │ HomeKit Organizer│
                                                 │   CLI (Swift)   │
                                                 └────────┬────────┘
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │  Config File    │
                                                 │  (YAML/JSON)    │
                                                 └─────────────────┘
```

---

## Milestones

### M1: Project Scaffolding & Basic Setup

**Goal**: Establish the foundational Swift Package Manager project structure and necessary macOS entitlements.

**Status**: ✅ Complete (2024-12-20)

**Acceptance Criteria**:
- `Package.swift` is correctly configured for a macOS executable.
- `homekit-organizer.entitlements` file exists with `com.apple.developer.homekit` set to true.
- `Info.plist` file exists with `NSHomeKitUsageDescription`.
- Project compiles successfully without errors.
- A basic `main.swift` exists and can print "Hello, HomeKit Organizer!".

**Inputs**: Project requirements document.
**Outputs**: A compilable Swift Package Manager project with basic structure and entitlement files.
**Complexity**: Small
**Dependencies**: None

#### Completion Notes
- GitHub repo created: https://github.com/matthew-gerstman/homekit-organizer
- Initial commit: a0ef9a3
- All acceptance criteria met
- Ready for M2 and M3 (which can run in parallel)

---

### M2: HomeKit Manager Initialization and Accessory Listing

**Goal**: Successfully initialize `HMHomeManager`, handle authorization, and list all available homes, rooms, and accessories.

**Status**: 🔲 Ready to Start

**Acceptance Criteria**:
- `HMHomeManager` initializes successfully.
- The tool prompts for HomeKit access if not already granted.
- Upon authorization, the tool lists all detected `HMHome` objects.
- For the primary home, it lists all `HMRoom` objects (excluding default) and all `HMAccessory` objects.
- Debug output clearly shows the names and unique identifiers of homes, rooms, and accessories.

**Inputs**: Compilable project from M1.
**Outputs**: `HomeKitManager.swift` wrapper class capable of initializing `HMHomeManager` and fetching home/room/accessory data, along with a `main.swift` demonstrating its use.
**Complexity**: Medium
**Dependencies**: M1

---

### M3: Configuration Parsing and Model Definition

**Goal**: Define the Swift data models for the configuration and implement robust parsing of the YAML configuration file.

**Status**: 🔲 Ready to Start

**Acceptance Criteria**:
- Swift `Codable` structs are defined for the entire configuration schema (Home, Rooms, Accessories, Renames, Scenes, Actions, Characteristics).
- `ConfigParser.swift` can successfully parse a valid `sample-config.yaml` into the Swift data model.
- Error handling is implemented for invalid YAML or missing required fields, providing clear messages.
- Parsed configuration can be printed to console for verification.

**Inputs**: Compilable project from M1, `sample-config.yaml` (provided in Examples/).
**Outputs**: `Config.swift` (data models), `ConfigParser.swift` (parsing logic), and updated `main.swift` to load and validate a config file.
**Complexity**: Medium
**Dependencies**: M1

---

### M4: Room Creation and Exact Accessory Assignment

**Goal**: Implement the logic to create rooms defined in the configuration and assign accessories using exact name matching.

**Status**: ⏳ Blocked (waiting on M2, M3)

**Acceptance Criteria**:
- The tool can identify rooms in the config that do not exist in HomeKit and create them.
- The tool can identify accessories in the config with exact name matches and assign them to the specified rooms.
- HomeKit operations (add room, assign accessory) are wrapped in async/await.
- A dry-run mode is available to preview room creation and accessory assignments without applying changes.
- Running the tool with a config containing exact matches correctly organizes accessories in the Home app.

**Inputs**: Compilable project from M2 and M3, `sample-config.yaml`.
**Outputs**: `RoomOrganizer.swift` (room creation, accessory assignment logic), updated `AccessoryMatcher.swift` (exact matching), and `main.swift` with `apply` command supporting dry-run.
**Complexity**: Medium
**Dependencies**: M2, M3

---

### M5: Advanced Accessory Matching (Wildcards & Regex)

**Goal**: Enhance accessory matching capabilities to include wildcard (`*`) and regular expression patterns.

**Status**: ⏳ Blocked (waiting on M4)

**Acceptance Criteria**:
- `AccessoryMatcher.swift` correctly interprets and applies wildcard patterns (e.g., "Living Room *") to match accessories.
- `AccessoryMatcher.swift` correctly interprets and applies regular expression patterns (e.g., "^LR_.*") to match accessories.
- The dry-run mode accurately shows which accessories would be matched by patterns.
- Running the tool with a config containing pattern matches correctly organizes accessories in the Home app.

**Inputs**: Compilable project from M4, `sample-config.yaml` with pattern examples.
**Outputs**: Enhanced `AccessoryMatcher.swift` with wildcard and regex matching logic.
**Complexity**: Medium
**Dependencies**: M4

---

### M6: Scene Creation and Characteristic Action Mapping

**Goal**: Implement the ability to create HomeKit scenes (action sets) and add actions to them based on the configuration.

**Status**: ⏳ Blocked (waiting on M5)

**Acceptance Criteria**:
- The tool can identify scenes in the config that do not exist in HomeKit and create them.
- For each scene, the tool can identify specified accessories and services.
- The tool can map characteristic names (e.g., "brightness", "on") to their corresponding HomeKit `HMCharacteristic` types.
- Actions are correctly added to the created scenes, modifying the specified characteristics.
- Running the tool with a scene config creates functional scenes in the Home app that can be triggered.

**Inputs**: Compilable project from M5, `sample-config.yaml` with scene definitions.
**Outputs**: `SceneBuilder.swift` (scene creation, action mapping logic), updated `main.swift` to process scenes.
**Complexity**: Large
**Dependencies**: M5

---

### M7: CLI Argument Parsing, Renaming, and Diff Mode

**Goal**: Implement robust command-line argument parsing, accessory renaming, and a diff mode to compare current HomeKit state with the desired configuration.

**Status**: ⏳ Blocked (waiting on M6)

**Acceptance Criteria**:
- `ArgumentParser` is integrated to handle `apply`, `list`, `export`, `diff` commands and options like `--dry-run`, `-v`.
- The tool can rename accessories as specified in the `renames` section of the config.
- `diff` command accurately displays differences between the current HomeKit state and the proposed changes from the config (rooms to add/remove, accessories to move/rename, scenes to create/modify).
- Verbose logging (`-v`) provides detailed execution information.

**Inputs**: Compilable project from M6, `sample-config.yaml` with renames.
**Outputs**: `main.swift` with full `ArgumentParser` integration, `AccessoryRenamer.swift` (or integrated into `RoomOrganizer.swift`), `DiffGenerator.swift` (or integrated into `HomeKitManager.swift`).
**Complexity**: Medium
**Dependencies**: M6

---

### M8: Distribution, Signing, and Notarization

**Goal**: Prepare the CLI tool for easy distribution, including code signing, notarization, and a Homebrew formula.

**Status**: ⏳ Blocked (waiting on M7)

**Acceptance Criteria**:
- The tool is correctly signed with developer ID.
- The tool is notarized by Apple.
- A Homebrew formula (`homekit-organizer.rb`) is created that successfully installs the tool.
- Documentation for manual signing and notarization is provided.

**Inputs**: Compilable and tested project from M7.
**Outputs**: Signed and notarized executable, Homebrew formula, and updated `README.md` with installation instructions.
**Complexity**: Large
**Dependencies**: M7

---

## Handoff Protocol

This section outlines the standard operating procedure for completing and handing off milestones to ensure smooth collaboration across AI agents.

### Documenting Completion

Upon successful completion of a milestone, the assigned agent must:

1. **Update the Milestone Status**: Mark the milestone as "Completed" in this document and commit the change.
2. **Generate a Completion Report**: Add a "Completion Notes" subsection to the milestone with:
   - Summary of work done
   - Key files created/modified
   - Commit hash
   - Any deviations from the plan

### Handoff Notes Content

The completion report and handoff notes should include:

- **Milestone Title**: Clearly state which milestone has been completed.
- **Summary of Work**: A concise description of what was implemented, referencing the acceptance criteria.
- **Key Outputs**: List the primary files or components delivered (e.g., `HomeKitManager.swift`, `Config.swift`, `main.swift` updates).
- **Verification Steps**: Instructions on how to verify the completion (e.g., "Run `swift run homekit-organizer list accessories` and confirm output matches expected format").
- **Known Issues/Limitations**: Any minor bugs, edge cases not fully handled, or design decisions made that might impact future milestones.
- **Next Steps/Recommendations**: Suggestions for the next agent, or any specific areas that might need extra attention in subsequent milestones.
- **Code Repository Link**: A direct link to the relevant commit or branch for review.

### Flagging Blockers or Decisions Needed

If an agent encounters a blocker or requires a decision to proceed:

1. **Immediate Notification**: Flag the issue immediately in the communication channel (e.g., chat, project management tool).
2. **Detailed Description**: Provide a clear, concise description of the blocker, including:
   - The specific task or sub-task being attempted.
   - The exact error message or unexpected behavior.
   - Steps taken to debug or resolve the issue.
   - The specific decision required (e.g., "Should we use library X or implement custom logic for Y?").
   - Any proposed solutions or workarounds.
3. **Impact Assessment**: Briefly explain the impact of the blocker on the current milestone and subsequent dependencies.

---

## Reference

### Core HomeKit APIs

| Operation | API | Notes |
| --- | --- | --- |
| Initialize | `HMHomeManager()` | Entry point, requires delegate |
| List homes | `homeManager.homes` | Array of `HMHome` |
| List rooms | `home.rooms` | Excludes default room |
| Default room | `home.roomForEntireHome()` | Where unassigned accessories live |
| Create room | `home.addRoom(withName:completionHandler:)` | Async with callback |
| List accessories | `home.accessories` | All accessories in home |
| Assign to room | `home.assignAccessory(_:to:completionHandler:)` | Move accessory to room |
| Rename accessory | `accessory.updateName(_:completionHandler:)` | Change display name |
| Create scene | `home.addActionSet(withName:completionHandler:)` | Creates empty scene |
| Add action | `actionSet.addAction(_:completionHandler:)` | Add characteristic change |

---

### Configuration Schema

```yaml
# homekit-config.yaml

# Target home (optional - uses primary if not specified)
home: "My Home"

# Room definitions and accessory assignments
rooms:
  - name: "Living Room"
    accessories:
      - "Living Room Lamp"           # Exact match
      - pattern: "Living Room *"     # Wildcard match
      - pattern: "^LR_.*"            # Regex match
    
  - name: "Kitchen"
    accessories:
      - "Kitchen Overhead"
      - "Coffee Maker"
      - "Kitchen Motion Sensor"

  - name: "Bedroom"
    accessories:
      - pattern: "Bedroom *"

# Optional: Rename accessories
renames:
  - from: "light.living_room_lamp_1"
    to: "Living Room Lamp"
  - from: "switch.coffee_maker"
    to: "Coffee Maker"

# Optional: Scene definitions
scenes:
  - name: "Movie Night"
    actions:
      - accessory: "Living Room Lamp"
        service: "lightbulb"
        characteristics:
          brightness: 20
          on: true
      - accessory: "TV Backlight"
        service: "lightbulb"
        characteristics:
          on: true
          
  - name: "Good Morning"
    actions:
      - accessory: "Bedroom Light"
        service: "lightbulb"
        characteristics:
          brightness: 100
          on: true
      - accessory: "Coffee Maker"
        service: "switch"
        characteristics:
          on: true
```

---

### Technical Considerations

#### Authorization
- First run requires user to grant HomeKit access
- macOS will prompt with the `NSHomeKitUsageDescription` from Info.plist
- Must be signed with appropriate entitlements

#### Entitlements Required
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.developer.homekit</key>
    <true/>
</dict>
</plist>
```

#### Info.plist Required
```xml
<key>NSHomeKitUsageDescription</key>
<string>HomeKit Organizer needs access to organize your smart home devices into rooms.</string>
```

#### Async Handling
All HomeKit operations are async with completion handlers. Options:
1. **Swift Concurrency** (async/await wrappers) - Preferred for modern Swift
2. **Combine** - Good for reactive patterns
3. **DispatchGroup** - Simple but verbose

Recommendation: Use Swift Concurrency with `withCheckedContinuation` wrappers.

#### Error Handling
Common failure modes:
- HomeKit not available (no iCloud account)
- Authorization denied
- Accessory not found (name mismatch)
- Room already exists (handle gracefully)
- Network timeout (HomeKit syncs via iCloud)

#### Testing
- Use HomeKit Accessory Simulator (from Xcode Additional Tools)
- Create mock accessories for development
- Test against real Home Assistant bridge for integration

---

### Project Structure

```
homekit-organizer/
├── Package.swift
├── Sources/
│   └── homekit-organizer/
│       ├── main.swift              # Entry point, argument parsing
│       ├── HomeKitManager.swift    # HMHomeManager wrapper
│       ├── ConfigParser.swift      # YAML/JSON parsing
│       ├── AccessoryMatcher.swift  # Name/pattern matching logic
│       ├── RoomOrganizer.swift     # Room creation & assignment
│       ├── SceneBuilder.swift      # Scene/action set creation
│       └── Models/
│           ├── Config.swift        # Config file model
│           └── MatchResult.swift   # Matching results
├── Resources/
│   └── Info.plist
├── homekit-organizer.entitlements
└── Examples/
    └── sample-config.yaml
```

---

### CLI Interface

```bash
# Basic usage - apply config
homekit-organizer apply config.yaml

# Dry run - preview changes
homekit-organizer apply config.yaml --dry-run

# List current state
homekit-organizer list homes
homekit-organizer list rooms
homekit-organizer list accessories
homekit-organizer list accessories --unassigned

# Generate config from current state
homekit-organizer export > current-config.yaml

# Diff current vs desired
homekit-organizer diff config.yaml

# Verbose output
homekit-organizer apply config.yaml -v
```

---

### Dependencies

| Package | Purpose |
| --- | --- |
| [Yams](https://github.com/jpsim/Yams) | YAML parsing |
| [ArgumentParser](https://github.com/apple/swift-argument-parser) | CLI argument handling |
| HomeKit.framework | Native Apple framework (system) |

---

### Risks & Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| HomeKit API changes | Breaking changes | Pin to macOS version, test on betas |
| Accessory name drift | Mismatches after HA restarts | Use pattern matching, re-run periodically |
| iCloud sync delays | Changes not immediate | Add retry logic, document behavior |
| Code signing complexity | Distribution friction | Document signing, consider notarization |

---

### Open Questions

1. **Config location**: Should we support `~/.config/homekit-organizer/config.yaml` as default?
2. **Multiple homes**: How common is this? Should we support it in Phase 1?
3. **Home Assistant integration**: Should we pull entity names directly from HA API instead of manual config?
4. **Zones**: HomeKit supports grouping rooms into zones—worth supporting?
