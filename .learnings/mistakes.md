# Mistakes Log

> Append-only log of things that went wrong. Learn from these to avoid repeating them.

---

## 🚨 CRITICAL MISTAKES (Read First!)

### HomeKit writes FAIL on Mac - MUST use iPhone/iPad

**What happens**: All HomeKit write operations fail with "Request not handled" (HMError code 2) on Mac, even though reads work fine.

**Applies to**: Mac Catalyst AND "Designed for iPad" mode on Apple Silicon

**Solution**: Run the app on an actual iPhone or iPad. Writes work fine there.

**Error signature**:
```
Error domain: HMErrorDomain
Error code: 2
Error description: Request not handled.
```

---

### HomeKit names cannot start with special characters

**What happens**: Creating room/scene fails with HMError code 36.

**Root cause**: Error 36 = `NameDoesNotStartWithValidCharacters`. HomeKit requires names start with letter or number.

**Examples**:
- ❌ `_TestRoom` → Error 36
- ❌ `-MyRoom` → Error 36  
- ✅ `TestRoom` → Works
- ✅ `Room 1` → Works

---

## Other Mistakes

### 2024-12-19: HomeKit is NOT a native macOS framework

**What happened**: `import HomeKit` failed in standard SwiftPM macOS CLI.

**Root cause**: HomeKit.framework only available via Mac Catalyst.

**Prevention**: 
- Build as iOS app with `SUPPORTS_MACCATALYST=YES`
- Use xcodegen, not pure SwiftPM
- Use `xcodebuild` not `swift build`

---

### 2024-12-19: HMHomeManager.authorizationStatus is instance property

**What happened**: `HMHomeManager.authorizationStatus` compile error.

**Prevention**: Use `homeManager.authorizationStatus` (on instance, not type)

---

### 2024-12-19: @MainActor isolation in async CLI commands

**What happened**: Can't call HomeKitManager methods from `AsyncParsableCommand.run()`.

**Prevention**: Mark command's `run()` method with `@MainActor`:
```swift
@MainActor
func run() async throws { ... }
```

---

### 2024-12-19: HMHomeManager.primaryHome is deprecated

**What happened**: Deprecation warning in Mac Catalyst 16.1.

**Prevention**: Use `homeManager.homes.first` instead.

---

### 2024-12-19: @main requires -parse-as-library with xcodebuild

**What happened**: Build failed with "main attribute cannot be used in module with top-level code".

**Prevention**: Add to project.yml:
```yaml
OTHER_SWIFT_FLAGS: "-parse-as-library"
```

---

### 2024-12-19: ArgumentParser flags can't default to true

**What happened**: Validation error when `@Flag` has `= true`.

**Prevention**: Use inversion parameter:
```swift
@Flag(inversion: .prefixedNo, help: "...")
var deleteUnlisted = true
```

---

### 2024-12-20: Xcode passes debug arguments that break ArgumentParser

**What happened**: App crashed with "Unknown option '-NSDocumentRevisionsDebugMode'".

**Prevention**: Filter Xcode args before parsing:
```swift
private func filterXcodeArgs() -> [String] {
    var args = Array(CommandLine.arguments.dropFirst())
    return args.filter { !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple") }
}
```
