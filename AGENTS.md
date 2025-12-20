# Agent Instructions for homekit-organizer

> **TL;DR**: Swift CLI for HomeKit automation. Check `PLAN.md` for milestones. Log mistakes in `.learnings/mistakes.md`. Update this file when you learn something important.

## Quick Start

```bash
# Build
swift build

# Run
swift run homekit-organizer

# Test (when tests exist)
swift test
```

## Project Overview

**What**: macOS CLI tool to programmatically organize Home Assistant devices exposed to Apple HomeKit.

**Why**: Home Assistant's HomeKit Bridge dumps all devices into "Default Room" with no bulk organization. This tool reads YAML configs and uses Apple's native HomeKit framework to organize accessories into rooms, rename them, and create scenes.

**Stack**:
- Swift 5.9+ / Swift Package Manager
- macOS 13.0+ (Ventura) required
- Dependencies: [Yams](https://github.com/jpsim/Yams) (YAML), [ArgumentParser](https://github.com/apple/swift-argument-parser) (CLI)
- Native: HomeKit.framework (HMHomeManager)

## Project Structure

```
homekit-organizer/
├── Package.swift              # SPM manifest - dependencies & targets
├── Sources/homekit-organizer/
│   └── main.swift             # Entry point (currently just prints version)
├── Examples/
│   └── sample-config.yaml     # Reference config format
├── PLAN.md                    # 📋 IMPLEMENTATION PLAN - check this first!
├── AGENTS.md                  # 📖 You are here
├── .learnings/                # 🧠 Accumulated knowledge (append-only)
│   ├── mistakes.md            # Things that went wrong and how to prevent
│   ├── decisions.md           # Architecture/design decisions with rationale
│   └── patterns.md            # Working patterns discovered
└── homekit-organizer.entitlements  # Required for HomeKit access
```

## Current Status

**Read `PLAN.md` for the authoritative milestone status.**

Quick reference:
- ✅ M1: Project scaffolding (complete)
- 🔲 M2: HomeKit manager & listing (ready - can start)
- 🔲 M3: Config parsing (ready - can start, parallel with M2)
- ⏳ M4-M8: Blocked on M2/M3

## How to Work on This Project

### Before Starting Any Milestone

1. **Read `PLAN.md`** - Full specs, acceptance criteria, and dependencies
2. **Check `.learnings/mistakes.md`** - Don't repeat past errors
3. **Check `.learnings/decisions.md`** - Understand why things are the way they are

### Development Workflow

```bash
# Always verify it compiles before committing
swift build

# Run to verify basic functionality
swift run homekit-organizer

# Check for Swift warnings
swift build 2>&1 | grep -i warning
```

### HomeKit-Specific Gotchas

⚠️ **These are critical - HomeKit is finicky:**

1. **Entitlements Required**: The app must be signed with `com.apple.developer.homekit` entitlement
2. **iCloud Required**: HomeKit syncs via iCloud - must be signed in
3. **Async Everything**: All HMHomeManager operations use completion handlers - wrap with `withCheckedContinuation`
4. **First Run**: User must grant HomeKit permission via system dialog
5. **Simulator Limitations**: Use HomeKit Accessory Simulator from Xcode Additional Tools for testing

### File Naming Conventions

- `*Manager.swift` - Wrapper classes for system frameworks
- `*Parser.swift` - Input parsing logic
- `*Builder.swift` - Construction/creation logic
- `Models/*.swift` - Data structures

## Completing Work

### When You Finish a Milestone

1. **Update `PLAN.md`**:
   - Change status to ✅ Complete
   - Add completion date
   - Add "Completion Notes" subsection with:
     - Summary of work
     - Key files created/modified
     - Commit hash
     - Any deviations from plan

2. **Update `.learnings/`** if you discovered:
   - A mistake worth preventing → `.learnings/mistakes.md`
   - A design decision worth documenting → `.learnings/decisions.md`
   - A useful pattern → `.learnings/patterns.md`

3. **Update this file** if:
   - Project structure changed
   - New commands needed
   - New gotchas discovered

### Commit Message Format

```
M{N}: {Brief description}

- {What was done}
- {Key files changed}

Closes #{issue} (if applicable)
```

Example:
```
M2: Implement HomeKit manager and accessory listing

- Add HomeKitManager.swift with async/await wrappers
- Implement list homes/rooms/accessories commands
- Handle authorization flow

Acceptance criteria verified:
- [x] HMHomeManager initializes
- [x] Lists all homes, rooms, accessories
```

## When You're Stuck

1. **Check `.learnings/mistakes.md`** - Someone may have hit this before
2. **Check Apple's HomeKit docs**: https://developer.apple.com/documentation/homekit
3. **Flag blockers clearly** - Add to `PLAN.md` under the milestone with:
   - What you tried
   - What failed
   - What decision is needed

## Self-Learning Protocol

This repo learns from mistakes. **Always update `.learnings/` when something goes wrong.**

### Adding a Mistake

```markdown
## YYYY-MM-DD: {Brief title}

**What happened**: {Describe the failure}
**Root cause**: {Why it happened}
**Prevention**: {Specific rule to follow}
**Milestone**: M{N} (if applicable)
```

### Adding a Decision

```markdown
## YYYY-MM-DD: {Decision title}

**Context**: {What prompted this decision}
**Options considered**: {What alternatives existed}
**Decision**: {What was chosen}
**Rationale**: {Why this option won}
**Revisit if**: {Conditions that would change this}
```

---

*Last updated: 2024-12-20 (M1 complete)*
