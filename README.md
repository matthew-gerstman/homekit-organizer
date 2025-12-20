# HomeKit Organizer

A macOS CLI tool that programmatically organizes Home Assistant devices exposed to Apple HomeKit.

> **🤖 Agent Note**: This project is managed via the implementation plan in Obvious. If you're an AI agent picking this up, check the **HomeKit Organizer CLI - Implementation Plan** document for current status, milestone details, and handoff protocol. Continue from the next incomplete milestone.

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

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for building)
- iCloud account signed in (HomeKit syncs via iCloud)
- Home Assistant with HomeKit Bridge configured

## Installation

### From Source

```bash
git clone https://github.com/matthew-gerstman/homekit-organizer.git
cd homekit-organizer
swift build -c release
```

The binary will be at `.build/release/homekit-organizer`.

### Homebrew (coming soon)

```bash
brew install homekit-organizer
```

## Usage

```bash
# Apply a configuration
homekit-organizer apply config.yaml

# Preview changes without applying
homekit-organizer apply config.yaml --dry-run

# List current HomeKit state
homekit-organizer list homes
homekit-organizer list rooms
homekit-organizer list accessories
homekit-organizer list accessories --unassigned

# Export current state to config
homekit-organizer export > current-config.yaml

# Show diff between current state and config
homekit-organizer diff config.yaml
```

## Configuration

See [Examples/sample-config.yaml](Examples/sample-config.yaml) for a complete example.

```yaml
home: "My Home"

rooms:
  - name: "Living Room"
    accessories:
      - "Living Room Lamp"        # Exact match
      - pattern: "Living Room *"  # Wildcard
      - pattern: "^LR_.*"         # Regex

renames:
  - from: "light.living_room_lamp_1"
    to: "Living Room Lamp"

scenes:
  - name: "Movie Night"
    actions:
      - accessory: "Living Room Lamp"
        service: "lightbulb"
        characteristics:
          brightness: 20
          on: true
```

## Development Status

This project follows a milestone-based development plan. See the implementation plan document for full details.

| Milestone | Status | Description |
|-----------|--------|-------------|
| M1 | ✅ Complete | Project scaffolding |
| M2 | 🔲 Ready | HomeKit manager & listing |
| M3 | 🔲 Ready | Config parsing |
| M4 | ⏳ Blocked | Room creation & assignment |
| M5 | ⏳ Blocked | Pattern matching |
| M6 | ⏳ Blocked | Scene creation |
| M7 | ⏳ Blocked | CLI polish |
| M8 | ⏳ Blocked | Distribution |

**Note**: M2 and M3 can be developed in parallel. M4+ require their dependencies.

## Code Signing

HomeKit requires proper entitlements. When building for distribution:

```bash
codesign --entitlements homekit-organizer.entitlements -s "Developer ID Application: Your Name" .build/release/homekit-organizer
```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Please read the implementation plan document for architecture details and milestone specifications.
