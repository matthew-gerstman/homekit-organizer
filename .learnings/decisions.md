# Architecture & Design Decisions

> Document significant decisions with context so future agents understand *why* things are the way they are.

---

## Template

```markdown
## YYYY-MM-DD: {Decision title}

**Context**: {What prompted this decision}
**Options considered**:
1. {Option A} - {pros/cons}
2. {Option B} - {pros/cons}

**Decision**: {What was chosen}
**Rationale**: {Why this option won}
**Revisit if**: {Conditions that would change this decision}
```

---

## Logged Decisions

### 2024-12-20: Use Swift Concurrency over Combine/DispatchGroup

**Context**: HomeKit APIs use completion handlers. Need to choose async pattern.

**Options considered**:
1. **Swift Concurrency (async/await)** - Modern, clean syntax, good error handling
2. **Combine** - Reactive, good for streams, more complex
3. **DispatchGroup** - Simple but verbose, callback hell risk

**Decision**: Swift Concurrency with `withCheckedContinuation` wrappers

**Rationale**: 
- Cleaner code that reads sequentially
- Better error propagation
- Native Swift feature (no dependencies)
- Recommended in PLAN.md

**Revisit if**: Need reactive streams for real-time HomeKit updates

---

### 2024-12-20: Yams for YAML parsing

**Context**: Need to parse user config files. YAML vs JSON.

**Options considered**:
1. **YAML (Yams)** - Human-friendly, comments allowed, widely used for config
2. **JSON (Foundation)** - No dependency, but no comments, less readable

**Decision**: YAML via Yams library

**Rationale**:
- Config files benefit from comments
- More readable for end users
- Yams is well-maintained and Codable-compatible

**Revisit if**: JSON-only requirement emerges or Yams becomes unmaintained

---

### 2024-12-20: Milestone-based development with handoff protocol

**Context**: Project may be worked on by multiple agents over time.

**Decision**: Structured milestones in PLAN.md with explicit handoff notes

**Rationale**:
- Clear acceptance criteria prevent scope creep
- Handoff protocol ensures continuity between agents
- Blocked/ready status prevents wasted work on dependencies

**Revisit if**: Single developer takes over and prefers different workflow

---

### 2024-12-19: Mac Catalyst for HomeKit CLI tool

**Context**: HomeKit framework is not available as a native macOS framework. It only exists in iOSSupport for Mac Catalyst apps.

**Options considered**:
1. **Mac Catalyst app bundle** - Build as iOS app with SUPPORTS_MACCATALYST, distribute as .app
2. **Pure SwiftPM CLI** - Would require private framework linking (unsupported, fragile)
3. **Alternative approach** - Use HomeKit REST/mDNS directly (massive effort, reinventing wheel)

**Decision**: Build as Mac Catalyst app using xcodegen-generated Xcode project

**Rationale**:
- Only officially supported way to access HomeKit on macOS
- App bundle can still be invoked as CLI via `MyApp.app/Contents/MacOS/MyApp`
- Entitlements and code signing work correctly with app bundles
- xcodegen keeps project config in version control as YAML

**Revisit if**: Apple adds native macOS HomeKit SDK support

---

### 2024-12-19: xcodegen for Xcode project management

**Context**: Mac Catalyst builds require an Xcode project, but .xcodeproj files are notoriously hard to version control.

**Options considered**:
1. **xcodegen** - YAML config, generates .xcodeproj on demand
2. **Tuist** - More features but heavier weight
3. **Manual Xcode project** - Hard to review changes, merge conflicts
4. **SPM only** - Doesn't support Mac Catalyst properly

**Decision**: Use xcodegen with project.yml in repo, .xcodeproj in .gitignore

**Rationale**:
- project.yml is human-readable and diffable
- Regenerate with `xcodegen generate` anytime
- Lighter weight than Tuist for our needs
- CI can regenerate project before building

**Revisit if**: Project complexity requires Tuist features (caching, modules)

---

### 2024-12-19: Use first home instead of deprecated primaryHome

**Context**: `HMHomeManager.primaryHome` is deprecated in Mac Catalyst 16.1. Need alternative approach for selecting "default" home.

**Options considered**:
1. **Use first home** - Simple, works for most users (single home)
2. **Require explicit home in config** - More explicit but worse UX for simple cases
3. **Suppress deprecation warning** - Keeps using deprecated API

**Decision**: Use `homeManager.homes.first` as the default home; mark it as "primary" for display purposes

**Rationale**:
- Most users have a single home anyway
- Avoids deprecated API warnings
- Config can still specify explicit home name if needed
- Simpler code without optional chaining on `primaryHome`

**Revisit if**: Apple provides a new recommended way to identify the user's main home

---

### 2024-12-19: Snapshot-based HomeKit data model

**Context**: Need to pass HomeKit state around the app (to CLI commands, planners, etc.) without holding references to live HM* objects.

**Options considered**:
1. **Snapshot structs** - Copy data into plain Swift structs (HomeInfo, RoomInfo, AccessoryInfo)
2. **Pass HM* objects directly** - Simpler but couples everything to HomeKit
3. **Protocol abstractions** - More flexible but more complex

**Decision**: Create snapshot structs that capture UUIDs, names, and relevant properties from HM* objects

**Rationale**:
- Decouples business logic from HomeKit framework
- Easier to test (can create mock snapshots)
- Thread-safe (structs are value types)
- Can serialize/display without holding live references

**Revisit if**: Need real-time updates from HomeKit (would need different approach)

---

### 2024-12-19: All milestones complete - Implementation Summary

**Context**: Project implemented M2-M8 in a single session.

**Key architectural decisions that worked well**:
1. **Mac Catalyst + xcodegen** - Only viable path for HomeKit on macOS CLI
2. **Snapshot-based state model** - Clean separation from HomeKit framework
3. **Planner → Executor pattern** - Enables dry-run, diff, and actual execution
4. **AccessorySelector enum with Codable** - Handles both string and pattern YAML gracefully
5. **CharacteristicMapper** - Centralizes HomeKit type mappings

**Files created** (in order of dependency):
- Models: HomeKitSnapshot.swift, Config.swift, Operation.swift
- Core: HomeKitManager.swift, ConfigParser.swift, ConfigValidator.swift
- Logic: Planner.swift, Executor.swift, AccessoryMatcher.swift
- Support: CharacteristicMapper.swift, Exporter.swift
- Entry: main.swift (ArgumentParser CLI)
