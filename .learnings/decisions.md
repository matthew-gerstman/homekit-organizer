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
