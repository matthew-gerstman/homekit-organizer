# HomeKit Organizer

A macOS CLI tool that programmatically organizes Home Assistant devices exposed to Apple HomeKit.

## The Problem

Home Assistant's HomeKit Bridge integration exposes entities to Apple Home, but all devices land in the "Default Room" with no way to:
- Assign them to rooms programmatically
- Rename them in bulk  
- Create scenes automatically
- Organize them without manual drag-and-drop

## The Solution

This tool reads a YAML configuration file and uses Apple's native HomeKit framework to:
- Create rooms
- Assign accessories to rooms (by exact name or pattern matching)
- Rename accessories
- Create scenes with actions

## Requirements

- macOS 14.0+ (Sonoma or later)
- Xcode 15+ (for building)
- iCloud account signed in (HomeKit syncs via iCloud)
- Home Assistant with HomeKit Bridge configured

## Installation

### From Source (Mac Catalyst Build)

HomeKit on macOS requires building as a Mac Catalyst app:

```bash
# Clone the repository
git clone https://github.com/matthew-gerstman/homekit-organizer.git
cd homekit-organizer

# Install xcodegen if needed
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Build for Mac Catalyst
xcodebuild -project HomeKitOrganizer.xcodeproj \
  -scheme homekit-organizer \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -configuration Release \
  build

# The app bundle is in DerivedData
# The CLI binary is at:
# ~/Library/Developer/Xcode/DerivedData/HomeKitOrganizer-*/Build/Products/Release-maccatalyst/homekit-organizer.app/Contents/MacOS/homekit-organizer
```

### Code Signing for HomeKit Access

The app must be code signed with HomeKit entitlements to access HomeKit APIs:

```bash
# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/HomeKitOrganizer-*/Build/Products/Release-maccatalyst -name "homekit-organizer.app" -type d | head -1)

# Sign with entitlements (ad-hoc for local use)
codesign --force --deep --sign - \
  --entitlements homekit-organizer.entitlements \
  "$APP_PATH"

# Or sign with Developer ID for distribution
codesign --force --deep \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --entitlements homekit-organizer.entitlements \
  "$APP_PATH"
```

### Creating an Alias

For easier CLI access:

```bash
# Add to your .zshrc or .bashrc
alias homekit-organizer='~/Library/Developer/Xcode/DerivedData/HomeKitOrganizer-*/Build/Products/Release-maccatalyst/homekit-organizer.app/Contents/MacOS/homekit-organizer'

# Or copy to a local bin
mkdir -p ~/bin
cp "$APP_PATH/Contents/MacOS/homekit-organizer" ~/bin/
# Note: The binary needs to be inside an app bundle with Info.plist for HomeKit access
```

## Usage

```bash
# Apply a configuration
homekit-organizer apply config.yaml

# Preview changes without applying
homekit-organizer apply config.yaml --dry-run

# Show verbose output
homekit-organizer apply config.yaml --dry-run -v

# List current HomeKit state
homekit-organizer list homes
homekit-organizer list rooms
homekit-organizer list accessories
homekit-organizer list accessories --unassigned

# Export current state to config
homekit-organizer export > current-config.yaml
homekit-organizer export --no-comments > minimal-config.yaml

# Show diff between current state and config
homekit-organizer diff config.yaml
```

## Configuration

See [Examples/sample-config.yaml](Examples/sample-config.yaml) for a complete example.

```yaml
# Target home (optional - uses first home if not specified)
home: "My Home"

# Room definitions
rooms:
  - name: "Living Room"
    accessories:
      - "Living Room Lamp"        # Exact match
      - pattern: "Living Room *"  # Wildcard (* = any)
      - pattern: "^LR_.*"         # Regex (starts with ^ or ends with $)

  - name: "Kitchen"
    accessories:
      - "Kitchen Overhead"
      - "Coffee Maker"

# Rename accessories (applied before room matching)
renames:
  - from: "light.living_room_lamp_1"
    to: "Living Room Lamp"
  - from: "switch.coffee_maker"
    to: "Coffee Maker"

# Scene definitions
scenes:
  - name: "Movie Night"
    actions:
      - accessory: "Living Room Lamp"
        service: "lightbulb"
        characteristics:
          on: true
          brightness: 20

  - name: "Good Morning"
    actions:
      - accessory: "Coffee Maker"
        service: "switch"
        characteristics:
          on: true
```

### Pattern Matching

- **Exact match**: `"Living Room Lamp"` - matches accessory with exactly that name
- **Wildcard**: `pattern: "Living Room *"` - `*` matches any substring
- **Regex**: `pattern: "^LR_.*"` - patterns starting with `^` or ending with `$` are treated as regex

### Supported Characteristics

v0.1 supports:
- `on` (Bool) - Power state
- `brightness` (Int 0-100) - Brightness level

## Development Status

| Milestone | Status | Description |
|-----------|--------|-------------|
| M1 | ✅ Complete | Project scaffolding |
| M2 | ✅ Complete | HomeKit manager & listing |
| M3 | ✅ Complete | Config parsing |
| M4 | ✅ Complete | Room creation & assignment |
| M5 | ✅ Complete | Pattern matching (wildcard & regex) |
| M6 | ✅ Complete | Scene creation |
| M7 | ✅ Complete | CLI polish (diff, export) |
| M8 | ✅ Complete | Distribution documentation |

## Technical Notes

### Why Mac Catalyst?

HomeKit.framework is not available as a native macOS framework. It's only accessible via Mac Catalyst (iOS apps running on Mac). This is why the project uses xcodegen to create an Xcode project that builds as a Mac Catalyst app rather than a pure SwiftPM CLI.

### Project Structure

```
homekit-organizer/
├── Package.swift              # SPM manifest (for dependencies only)
├── project.yml                # xcodegen project definition
├── Sources/homekit-organizer/
│   ├── main.swift             # CLI entry point (ArgumentParser)
│   ├── HomeKitManager.swift   # HomeKit API wrapper
│   ├── ConfigParser.swift     # YAML parsing
│   ├── ConfigValidator.swift  # Config validation
│   ├── Planner.swift          # Operation planning
│   ├── Executor.swift         # HomeKit operations
│   ├── AccessoryMatcher.swift # Pattern matching
│   ├── CharacteristicMapper.swift # Service/characteristic mapping
│   ├── Exporter.swift         # YAML export
│   └── Models/
│       ├── Config.swift       # Config data model
│       ├── HomeKitSnapshot.swift # HomeKit state snapshot
│       └── Operation.swift    # Operation types
├── Examples/
│   └── sample-config.yaml     # Example configuration
├── homekit-organizer.entitlements # HomeKit entitlements
└── .learnings/                # Project learnings (for AI agents)
```

## Troubleshooting

### "No HomeKit homes found"
- Ensure you're signed into iCloud
- Open the Home app and verify your home is set up
- Grant HomeKit permission when prompted

### Crash on startup (SIGABRT)
- The app needs to be code signed with entitlements for HomeKit access
- Run the codesign command from the installation instructions

### "HomeKit access not authorized"
- Go to System Settings > Privacy & Security > HomeKit
- Grant permission to homekit-organizer

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Check `.learnings/` for patterns, decisions, and mistakes to avoid.
