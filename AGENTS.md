# Agent Instructions for homekit-organizer

> **TL;DR**: iOS app to programmatically organize HomeKit. **MUST run on iPhone/iPad** - Mac doesn't support writes. Edit `config.yaml`, rebuild, tell user to run on their phone.

## 🚨 CRITICAL: HomeKit Write Limitations

**HomeKit write operations ONLY work on actual iOS devices (iPhone/iPad).**

| Platform | Read | Write |
|----------|------|-------|
| iPhone/iPad | ✅ | ✅ |
| Mac Catalyst | ✅ | ❌ (Error 2: "Request not handled") |
| Mac "Designed for iPad" | ✅ | ❌ (Same error) |
| iOS Simulator | ❌ | ❌ |

## Quick Start: Executing HomeKit Commands

When the user asks you to modify their HomeKit setup:

### Step 1: Edit config.yaml

```yaml
home: Syracuse  # User's home name

# Rooms to keep (all unlisted rooms will be DELETED)
rooms:
  - name: "Bedroom"
  - name: "Living Room"
  - name: "Office"

# Accessories to REMOVE from HomeKit
remove:
  - "Camera Name"
  - pattern: "Front*"

# Accessories to ASSIGN to rooms (optional)
rooms:
  - name: "Bedroom"
    accessories:
      - "Bedroom Light"
      - pattern: "Bedroom*"
```

### Step 2: Rebuild

```bash
cd /Users/matthew/src/homekit-organizer
xcodebuild -project HomeKitOrganizer.xcodeproj \
  -scheme homekit-organizer \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates build
```

### Step 3: Tell User to Run on iPhone

Say: "Run on your iPhone (`Cmd+R` in Xcode with your phone selected as destination)"

The app will automatically apply the bundled config.yaml.

## Config Reference

### Operations

| What | Config | Example |
|------|--------|---------|
| Keep specific rooms (delete others) | `rooms:` list | `rooms: [{name: "Bedroom"}, {name: "Office"}]` |
| Create zones (room groups) | `zones:` list | `zones: [{name: "Upstairs", rooms: ["Bedroom", "Office"]}]` |
| Remove accessory | `remove:` | `remove: ["Camera 1", {pattern: "Front*"}]` |
| Assign accessory to room | `rooms.[].accessories` | See below |
| Rename accessory | `renames:` | `renames: [{from: "old", to: "new"}]` |

### Patterns

```yaml
# Exact match
- "Living Room Light"

# Wildcard (matches any substring)
- pattern: "Bedroom*"      # Starts with Bedroom
- pattern: "*Light"        # Ends with Light
- pattern: "*Room*"        # Contains Room

# Regex (starts with ^ or ends with $)
- pattern: "^LR_.*"        # Regex: starts with LR_
```

### Full Example

```yaml
home: Syracuse

rooms:
  - name: "Bedroom"
    accessories:
      - "Bedroom Ceiling"
      - pattern: "Bedroom*"
  - name: "Living Room"
  - name: "Office"
  - name: "Kitchen"

# Zones group rooms together for easier control
# e.g., "Hey Siri, turn off the lights upstairs"
zones:
  - name: "Upstairs"
    rooms:
      - "Bedroom"
      - "Office"
  - name: "Downstairs"
    rooms:
      - "Living Room"
      - "Kitchen"

remove:
  - pattern: "*Camera*"
  - "Front Door"

renames:
  - from: "light.living_room_1"
    to: "Living Room Lamp"
```

## Name Rules

⚠️ **HomeKit names must start with a letter or number**

- ❌ `_TestRoom` → HMError 36 (invalid characters)
- ❌ `-MyRoom` → HMError 36
- ✅ `TestRoom` → Works
- ✅ `Room 1` → Works

## Project Structure

```
homekit-organizer/
├── config.yaml                    # 👈 EDIT THIS for operations
├── project.yml                    # xcodegen config
├── Sources/homekit-organizer/
│   ├── main.swift                 # CLI entry point
│   ├── HomeKitManager.swift       # HomeKit API wrapper
│   ├── Planner.swift              # Generates operation plan
│   ├── Executor.swift             # Executes operations
│   ├── ConfigParser.swift         # YAML parsing
│   └── Models/
│       ├── Config.swift           # Config data model
│       └── Operation.swift        # Operation types
├── .learnings/
│   ├── mistakes.md                # Past errors to avoid
│   ├── patterns.md                # Working patterns
│   └── decisions.md               # Architecture decisions
└── homekit-organizer.entitlements # HomeKit permission
```

## Common Tasks

### List current HomeKit state
User must run `list homes`, `list rooms`, or `list accessories` commands on their phone.
These are CLI subcommands - set them as launch arguments in Xcode scheme.

### Check what the app will do
Add `--dry-run` flag or just review the plan output in console.

### Debug issues
The app prints `[DEBUG]` lines showing exactly what's happening.

## Error Codes

| Code | Domain | Meaning |
|------|--------|---------|
| 2 | HMErrorDomain | "Request not handled" - Mac limitation, run on iPhone |
| 36 | HMErrorDomain | Invalid name (starts with special char) |
| 6 | HMErrorDomain | "Not found" - Home hub unreachable |

## Development

```bash
# Regenerate Xcode project after changing project.yml
xcodegen generate

# Build for iOS
xcodebuild -project HomeKitOrganizer.xcodeproj \
  -scheme homekit-organizer \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates build
```

## Learnings

Always check `.learnings/` before debugging:
- `mistakes.md` - Known issues and solutions
- `patterns.md` - Working code patterns
- `decisions.md` - Why things are built this way

---

*Last updated: 2024-12-22*
