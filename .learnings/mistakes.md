# Mistakes Log

> Append-only log of things that went wrong. Learn from these to avoid repeating them.

---

## Template

```markdown
## YYYY-MM-DD: {Brief title}

**What happened**: {Describe the failure}
**Root cause**: {Why it happened}  
**Prevention**: {Specific rule to follow going forward}
**Milestone**: M{N} (if applicable)
```

---

## Logged Mistakes

<!-- Add new mistakes above this line, newest first -->

## 2024-12-19: HomeKit is NOT a native macOS framework

**What happened**: Tried to use `import HomeKit` in a standard SwiftPM macOS CLI tool. Build failed with "no such module 'HomeKit'".

**Root cause**: HomeKit.framework is only available on macOS via **Mac Catalyst** (iOS apps running on Mac). It exists under `/System/iOSSupport/` path, not the regular macOS frameworks. The framework in `/System/Library/PrivateFrameworks/HomeKit.framework` has no Swift modules.

**Prevention**: 
- HomeKit on macOS REQUIRES Mac Catalyst (build as iOS app with `SUPPORTS_MACCATALYST=YES`)
- Use Xcode project (xcodegen) instead of pure SwiftPM for HomeKit builds
- Cannot use `swift build` directly - must use `xcodebuild` with Mac Catalyst destination

**Milestone**: M2

---

## 2024-12-19: HMHomeManager.authorizationStatus is instance, not static

**What happened**: Code `HMHomeManager.authorizationStatus` failed to compile with "instance member cannot be used on type".

**Root cause**: The `authorizationStatus` property is an instance property on `HMHomeManager`, not a static/class property. Must call it on the instance.

**Prevention**: Use `homeManager.authorizationStatus` not `HMHomeManager.authorizationStatus`

**Milestone**: M2

---

## 2024-12-19: @MainActor isolation requires careful handling in async CLI commands

**What happened**: CLI command `run()` functions couldn't call `HomeKitManager` methods, getting "main actor-isolated method cannot be called from outside of the actor" errors.

**Root cause**: `HomeKitManager` is marked `@MainActor` but `AsyncParsableCommand.run()` doesn't automatically run on main actor.

**Prevention**: Either mark the command struct methods with `@MainActor` or use `await MainActor.run { }` blocks when calling main actor-isolated code.

**Milestone**: M2

---

## 2024-12-19: HMHomeManager.primaryHome is deprecated in Mac Catalyst

**What happened**: Using `homeManager.primaryHome` triggered deprecation warnings: "'primaryHome' was deprecated in Mac Catalyst 16.1: No longer supported."

**Root cause**: Apple deprecated the `primaryHome` property in Mac Catalyst 16.1. The property still exists but shouldn't be used.

**Prevention**: 
- Use `homeManager.homes.first` instead of `homeManager.primaryHome`
- For display purposes, mark the first home as "primary"
- Allow explicit home selection via config file for multi-home users

**Milestone**: M2

---

## 2024-12-19: SwiftPM resources can't include Info.plist directly

**What happened**: Build failed with "resource 'Resources/Info.plist' in target is forbidden; Info.plist is not supported as a top-level resource file".

**Root cause**: SwiftPM has special handling for Info.plist and doesn't allow it as a regular resource.

**Prevention**: 
- For Mac Catalyst apps, don't use SPM resource bundles for Info.plist
- Instead, use xcodegen's `INFOPLIST_FILE` setting to point to the plist
- Remove the `resources:` section from Package.swift when using xcodegen

**Milestone**: M2

---

## 2024-12-19: @main requires -parse-as-library flag with xcodebuild

**What happened**: Build failed with "'main' attribute cannot be used in a module that contains top-level code".

**Root cause**: When building with xcodebuild (vs swift build), the compiler doesn't automatically treat the entry point as a library. The `@main` attribute conflicts with perceived "top-level code".

**Prevention**: Add `OTHER_SWIFT_FLAGS: "-parse-as-library"` to project.yml settings for the target.

**Milestone**: M2

---

## 2024-12-19: Unsigned Mac Catalyst apps crash (SIGABRT) when accessing HomeKit

**What happened**: Running the built app with `--dry-run` (which calls HomeKit APIs) crashed with exit code 134 (SIGABRT).

**Root cause**: Mac Catalyst apps require proper code signing with entitlements to access HomeKit. Building with `CODE_SIGNING_REQUIRED=NO` produces a working binary for non-HomeKit code, but crashes when HMHomeManager is instantiated.

**Prevention**: 
- For development testing of HomeKit features, need to sign the app (or test parsing/validation separately first)
- Non-HomeKit code paths (like config parsing without `--dry-run`) work fine unsigned
- For full testing, use `codesign` to ad-hoc sign with entitlements

**Milestone**: M3
