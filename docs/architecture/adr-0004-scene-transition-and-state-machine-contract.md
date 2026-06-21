# ADR-0004: Scene Transition and State Machine Contract

## Status
Accepted

## Date
2026-06-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / SceneTree / State machine |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0001-autoload-order-and-boot-orchestration.md`, `docs/architecture/adr-0002-persistence-ownership-and-save-rollback-strategy.md` |
| **Post-Cutoff APIs Used** | None directly required by the architecture. Implementation must verify `SceneTree.change_scene_to_file()`, typed signal connections, `await signal`, and `Time.get_ticks_msec()` / `Time.get_ticks_usec()` behavior on Godot 4.6. |
| **Verification Required** | Verify state transition table enforcement, scene readiness handshake timing, transition timeout, re-entrant request rejection, context defensive copies, GOODNIGHT commit failure behavior, and Web refresh recovery on the pinned Godot 4.6 Web export. |

Godot 4.6 is post-LLM-cutoff for this project. The checked engine references do not list a breaking API change for `SceneTree.change_scene_to_file()`, signals, or `Time`, but SceneTree state changes are timing-sensitive and must be validated in the pinned engine version.

Deprecated APIs and patterns to avoid:

- Do not use `yield()`; use `await signal`.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not use `OS.get_ticks_msec()`; use `Time.get_ticks_msec()` or `Time.get_ticks_usec()`.
- Do not emit `state_changed` immediately after `change_scene_to_file()`.

Engine Specialist Validation: not spawned in this run because sub-agent delegation was not explicitly requested by the user. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: Autoload Order and Boot Orchestration; ADR-0002: Persistence Ownership and Save Rollback Strategy |
| **Enables** | Implementation stories for `GameState`, Main Menu / Goodnight UI, Daily Scene entry/exit, BOOT recovery tests, replay flow decisions, and future presentation-to-gameplay communication ADRs. |
| **Blocks** | Stories that implement `GameState.request_transition()`, routable scene `_on_scene_ready()` callbacks, GOODNIGHT completion routing, BOOT recovery into `DAILY_SCENE`, and transition-lock UI retry behavior. |
| **Ordering Note** | ADR-0001 and ADR-0002 should be accepted before this ADR is accepted. This ADR should be accepted before scene, UI, and progression stories depend on state transition semantics. |

## Context

### Problem Statement

The GDDs define a small but strict game flow: BOOT, MAIN_MENU, WARDROBE, DAILY_SCENE, GOODNIGHT, ERROR, and QUIT. ADR-0001 already established the need for a safe SceneTree readiness handshake, and ADR-0002 established the GOODNIGHT persistence transaction boundary. The remaining decision is the exact contract that implementation stories must follow when requesting, validating, committing, observing, and recovering state transitions.

Without a formal contract, scene authors and UI systems could accidentally update state before a scene is ready, emit duplicate transition events, bypass progression rollback, mutate shared context, or allow illegal jumps such as `DAILY_SCENE -> WARDROBE`. The project needs one enforceable state machine contract before implementation begins.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- Target platform is Web, so transition code must avoid per-frame polling and heavy synchronous work.
- `GameState` is the single owner of `current_state`, `is_transitioning`, and transition context.
- ADR-0001 already requires scene readiness confirmation before `state_changed`.
- ADR-0002 already requires GOODNIGHT progress commits to go through `ProgressManager.advance_day()` and not through UI or direct SaveManager progress writes.
- UI systems are intent emitters and state consumers; they do not own game state.
- GDScript cannot enforce private methods, so ownership must be enforced through API shape, tests, and review.

### Requirements

- Must define a complete valid transition table.
- Must expose one normal transition request entry point.
- Must reject illegal transitions without changing state or emitting `state_changed`.
- Must prevent re-entrant scene transitions while `is_transitioning == true`.
- Must wait for target scene readiness before committing scene-backed state changes.
- Must keep current-state reads available for scenes that initialize after `state_changed` has already fired.
- Must preserve `context` as GameState-owned state and emit defensive copies.
- Must define BOOT recovery into `DAILY_SCENE`, including explicit empty outfit semantics.
- Must define GOODNIGHT success/failure routing around the persistence transaction.

## Decision

The project will implement scene flow as an explicit `GameState` state machine with a request/commit split.

`GameState.request_transition(to_state, transition_context := {}) -> bool` is the only normal entry point for design-level state transitions. It validates the requested transition against a static table plus any state-specific guard conditions. If validation passes, `GameState` prepares context, locks transition entry with `is_transitioning = true`, requests the scene change, and waits for the destination scene to call `_on_scene_ready(scene_state)`.

`GameState` commits the transition only after the destination scene confirms readiness. Commit means:

1. update `current_state`
2. clear `is_transitioning`
3. store or merge the approved context update
4. emit `state_changed(from_state, to_state, context.duplicate(true))`

If validation fails, the method returns `false`, leaves `current_state` unchanged, leaves context unchanged unless an explicitly documented failure path says otherwise, and emits no `state_changed`.

### Valid Transition Table

Normal design-level transitions are:

| From | To | Guard |
|------|----|-------|
| BOOT | MAIN_MENU | All startup-gated systems are ready; no resumable daily scene is selected. |
| BOOT | DAILY_SCENE | `scene_in_progress == true`, `ProgressManager.is_ready == true`, and `equipped_items` exists as `Array[String]`; the array may be empty. |
| BOOT | ERROR | Startup, recovery, or first route selection fails. |
| MAIN_MENU | WARDROBE | Player starts today and no transition is already active. |
| MAIN_MENU | QUIT | Player requests exit. |
| WARDROBE | MAIN_MENU | `outfit_confirmed == false`; player cancels before confirming outfit. |
| WARDROBE | DAILY_SCENE | Outfit has been confirmed and WARDROBE recovery context has been written. |
| DAILY_SCENE | GOODNIGHT | Daily scene dialogue or fallback end control has completed once. |
| GOODNIGHT | MAIN_MENU | `ProgressManager.advance_day() == true`. |
| GOODNIGHT | QUIT | Player requests exit from GOODNIGHT. |
| ERROR | BOOT | Player retries, and retry count is within the allowed policy. |

Runtime failure transitions are allowed from any non-terminal state to `ERROR` when scene loading or required route setup fails. These are engine/recovery transitions, not normal design-level choices, and they may bypass the normal transition table through a dedicated internal error path such as `_transition_to_error(reason)`.

All other design-level transitions are rejected.

### Transition Request Flow

```text
Caller
  -> GameState.request_transition(to_state, transition_context)
       if is_transitioning: return false
       if not valid transition: return false
       if guard fails: return false
       prepare context updates owned by this transition
       is_transitioning = true
       pending_from_state = current_state
       pending_to_state = to_state
       pending_context = approved context copy
       error = get_tree().change_scene_to_file(scene_path)
       if error != OK: route to ERROR
       return true

Destination scene _ready()
  -> perform minimal safe initialization
  -> GameState._on_scene_ready(scene_state)

GameState._on_scene_ready(scene_state)
  -> verify scene_state == pending_to_state
  -> current_state = pending_to_state
  -> context = pending_context
  -> is_transitioning = false
  -> emit state_changed(pending_from_state, pending_to_state, context.duplicate(true))
```

### Scene Readiness Contract

Every routable scene must call:

```gdscript
GameState._on_scene_ready(scene_state: State) -> void
```

exactly once, after minimal safe initialization is complete.

Minimal safe initialization means the destination scene can safely be observed as the active state. It does not require all animations, dialogue, audio, or texture callbacks to finish. Each scene GDD or story must define its own minimal readiness criteria.

Examples:

- MAIN_MENU is minimally ready when the root UI can read `GameState.current_state` / `GameState.get_current_day()` and show the correct menu mode or safe fallback.
- DAILY_SCENE is minimally ready when it has verified `current_state`, resolved `scene_day`, selected a valid scene config or safe fallback, and its root node can safely display.
- GOODNIGHT is minimally ready when the summary UI can render the current day and a safe continue/retry state.

If a scene calls `_on_scene_ready()` with a state that does not match `pending_to_state`, `GameState` must reject the ready callback, log a warning or error, and keep the transition locked until the normal timeout path resolves it.

### Transition Timeout

If `is_transitioning` remains true for 5 seconds after a scene change request, `GameState` treats the transition as failed and routes to `ERROR`.

The timeout route must:

- clear or replace the pending transition state
- avoid emitting the original transition's `state_changed`
- record enough diagnostic context for logs
- show only player-safe ERROR UI

Implementation may use a `Timer`, a bounded `await`, or another Godot-supported one-shot mechanism. It must not rely on `_process()` polling.

### Context Ownership

`GameState.context` is owned by `GameState`. Other systems may read it, but normal writes occur only through:

- `request_transition(..., transition_context)` for data needed by the destination state
- WARDROBE confirmation flow writing `current_day` and `equipped_items` through the approved GameState flow
- BOOT recovery flow reconstructing `current_day` and `equipped_items` after SaveManager and ProgressManager are ready
- explicit future ADRs that add new context keys

Current context keys are:

| Key | Type | Owner / Writer | Reader |
|-----|------|----------------|--------|
| `current_day` | int | GameState facade from ProgressManager during WARDROBE confirm or BOOT recovery | Main Menu UI, Goodnight UI, Daily Scene, Dialogue UI |
| `equipped_items` | `Array[String]` | WARDROBE confirmation or BOOT recovery | Daily Scene, Goodnight UI, Sprite layered renderer |
| `scene_in_progress` | bool | SaveManager persisted state, consumed by GameState BOOT | GameState BOOT only |

`state_changed` must emit a defensive deep copy:

```gdscript
signal state_changed(from_state: State, to_state: State, context: Dictionary)

state_changed.emit(from_state, to_state, context.duplicate(true))
```

Listeners must treat the signal context as read-only. Mutating the received dictionary must not affect `GameState.context`.

### BOOT Recovery Contract

`BOOT -> DAILY_SCENE` recovery is allowed only after:

- SaveManager is ready.
- ProgressManager is ready and has repaired progression state.
- SaveManager reports `scene_in_progress == true`.
- Saved `equipped_items` exists and is an `Array[String]`.

`equipped_items == []` is a valid explicit empty outfit. It must not be treated as missing data and must not be replaced with a default outfit by GameState. Daily Scene must receive and apply `[]` as an empty confirmed outfit.

Invalid recovery cases include:

- `equipped_items` field is missing
- `equipped_items == null`
- `equipped_items` is not an array
- `equipped_items` contains values that cannot be normalized to strings
- required recovery systems are not ready or report load errors

When recovery is invalid, GameState should clear `scene_in_progress` through SaveManager when safe, persist that repair if storage is available, and route to MAIN_MENU or ERROR according to the failure type. It must not enter DAILY_SCENE with an undefined context.

### GOODNIGHT Commit Contract

`GOODNIGHT -> MAIN_MENU` is a guarded transition. The guard is the persistence transaction defined by ADR-0002:

1. `GameState` calls `SaveManager.set_scene_in_progress(false)`.
2. `GameState` calls `ProgressManager.advance_day()`.
3. If `advance_day()` returns `true`, `GameState` may request the scene transition to MAIN_MENU.
4. If `advance_day()` returns `false`, `GameState` restores `scene_in_progress = true` in memory only, stays in GOODNIGHT, and returns `false` from the transition request.

On failure, GameState must not:

- call `SaveManager.save()` a second time
- enter MAIN_MENU
- show a new day
- show new unlocks
- emit `state_changed(GOODNIGHT, MAIN_MENU, ...)`

The GOODNIGHT UI may show a low-pressure retry affordance. The player-facing message must not expose technical storage details.

### Current State Reads

Scenes and UI must not rely only on `state_changed` for initial state. A destination scene may connect to `state_changed` after the signal has already been emitted for its own entry. Therefore, scene `_ready()` implementations must read:

```gdscript
GameState.current_state
GameState.context
```

or the relevant query facade such as:

```gdscript
GameState.get_current_day()
```

to determine their initial rendering mode. `state_changed` is for observing future transitions, not for discovering all current state.

### Architecture Diagram

```text
UI / Scene intent
  -> GameState.request_transition(...)
       -> explicit transition table
       -> guard checks
       -> context preparation
       -> SceneTree.change_scene_to_file()
       -> pending transition lock

Destination scene
  -> _ready()
  -> minimal safe initialization
  -> GameState._on_scene_ready(scene_state)

GameState commit
  -> current_state = to_state
  -> context = pending_context
  -> is_transitioning = false
  -> state_changed(from, to, context_copy)

Failure path
  -> illegal request: return false, emit nothing
  -> load failure / timeout: route to ERROR
  -> GOODNIGHT save failure: stay GOODNIGHT, emit nothing
```

### Key Interfaces

```gdscript
enum State {
    BOOT,
    MAIN_MENU,
    WARDROBE,
    DAILY_SCENE,
    GOODNIGHT,
    ERROR,
    QUIT,
}

signal state_changed(from_state: State, to_state: State, context: Dictionary)
signal transition_failed(from_state: State, to_state: State, reason: String)

var current_state: State
var is_transitioning: bool
var context: Dictionary

func request_transition(to_state: State, transition_context: Dictionary = {}) -> bool
func _on_scene_ready(scene_state: State) -> void
func get_current_day() -> int
func is_transition_valid(from_state: State, to_state: State) -> bool
```

Implementation rules:

- `request_transition()` returns `true` only when the request was accepted and a transition path has started or completed.
- Illegal transitions return `false` and do not emit `state_changed`.
- A duplicate transition request while `is_transitioning == true` returns `false`.
- `_on_scene_ready()` must ignore stale or mismatched callbacks.
- `transition_failed` is optional for internal/UI recovery feedback, but it must not replace `state_changed` for successful transitions.
- Scene path lookup must be data-driven or table-driven inside GameState, not hardcoded across UI systems.

## Alternatives Considered

### Alternative 1: Explicit GameState Transition Table + Scene Ready Handshake

- **Description**: `GameState` owns valid transitions, guard checks, context, scene change requests, and state commit after destination scene readiness.
- **Pros**: Matches existing GDDs and ADRs, centralizes authority, makes illegal transitions testable, and prevents state events before scene readiness.
- **Cons**: `GameState` remains a central coordinator and must stay disciplined to avoid accumulating unrelated gameplay logic.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: Scene-Owned Navigation

- **Description**: Each scene decides where it can go next and calls Godot scene loading APIs directly, with `GameState` observing or updating after the fact.
- **Pros**: Each scene is locally simple and can own its own user flow.
- **Cons**: Splits state authority, makes illegal transitions harder to reject consistently, risks duplicate scene loading code, and contradicts ADR-0001's GameState-owned scene readiness contract.
- **Rejection Reason**: Rejected because state ownership and scene safety must be centralized.

### Alternative 3: Separate SceneTransitionManager

- **Description**: Introduce a dedicated Autoload for scene loading, transition locks, readiness callbacks, and timeout handling, while `GameState` owns only state values.
- **Pros**: Separates SceneTree mechanics from game state rules and could become useful if transitions gain visual loading screens or complex async preloading.
- **Cons**: Adds a new Foundation service before the MVP needs it, creates a second transition authority, and requires another ADR for ownership boundaries.
- **Rejection Reason**: Rejected for MVP. Future visual transition systems may be added, but they must consume GameState events rather than own state routing.

## Consequences

### Positive

- All legal state transitions are visible in one table.
- Scene readiness timing is enforceable and testable.
- UI systems can issue intents without owning state or persistence.
- GOODNIGHT rollback cannot accidentally look like a completed day.
- BOOT recovery handles explicit empty outfits without corrupting player intent.
- Downstream scenes can safely initialize from current state even if they miss the entry signal.

### Negative

- `GameState` becomes a high-value integration point and needs careful tests.
- Every routable scene must implement the readiness callback correctly.
- Future transition visuals must be integrated without taking over state ownership.
- Context schema changes require ADR/GDD updates instead of ad hoc dictionary keys.

### Risks

- **Risk**: A scene forgets to call `_on_scene_ready()`.  
  **Mitigation**: Transition timeout routes to ERROR and every routable scene story must include a readiness callback acceptance criterion.
- **Risk**: A stale callback from an unloading scene commits the wrong state.  
  **Mitigation**: `_on_scene_ready(scene_state)` must match `pending_to_state`; stale or mismatched callbacks are ignored.
- **Risk**: UI calls `request_transition()` repeatedly through rapid clicks/taps.  
  **Mitigation**: `is_transitioning` rejects duplicates and UI buttons also lock locally after first accepted request.
- **Risk**: Context becomes an untyped dumping ground.  
  **Mitigation**: Keep context schema in ADR/GDD, use typed local variables after reading, and register new cross-system keys through future ADRs.
- **Risk**: GOODNIGHT save failure still emits success-like UI.  
  **Mitigation**: `GOODNIGHT -> MAIN_MENU` guard returns false on `advance_day()` failure and emits no success transition.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `scene-state-management.md` | State machine contains BOOT, MAIN_MENU, WARDROBE, DAILY_SCENE, GOODNIGHT, ERROR, and QUIT. | Defines the enum and full valid transition table. |
| `scene-state-management.md` | Illegal transitions are rejected and do not emit `state_changed`. | Requires `is_transition_valid()` and no signal on rejected requests. |
| `scene-state-management.md` | Scene changes wait for `_on_scene_ready()` before `state_changed`. | Defines request/commit split and readiness callback contract. |
| `scene-state-management.md` | `is_transitioning` prevents second transition and times out after 5 seconds. | Defines duplicate rejection and timeout-to-ERROR behavior. |
| `scene-state-management.md` | `context` is deep-copied in `state_changed`. | Makes context GameState-owned and requires `context.duplicate(true)`. |
| `scene-state-management.md` | BOOT recovery allows explicit empty outfit arrays. | Defines `equipped_items == []` as valid explicit empty outfit. |
| `daily-scene.md` | Daily Scene reads `GameState.current_state` and context in `_ready()` and calls ready after minimal safe initialization. | Defines current-state reads and per-scene readiness criteria. |
| `daily-scene.md` | Daily Scene requests GOODNIGHT once after dialogue/fallback completion. | Keeps `DAILY_SCENE -> GOODNIGHT` as a guarded valid transition. |
| `main-menu-goodnight-ui.md` | UI requests transitions but does not call `ProgressManager.advance_day()`. | Makes UI an intent source and keeps GOODNIGHT commit inside GameState. |
| `main-menu-goodnight-ui.md` | Rapid repeated clicks must not duplicate transition requests. | Requires duplicate rejection through `is_transitioning` and local UI locks. |
| `progress-management.md` | GOODNIGHT advancement uses `ProgressManager.advance_day()` and emits progress only after save success. | Makes `advance_day() == true` the guard for `GOODNIGHT -> MAIN_MENU`. |
| `save-load.md` | GameState writes `scene_in_progress` and handles GOODNIGHT save failure without a second save. | Defines the GOODNIGHT failure path and no-success-transition rule. |

## Performance Implications

- **CPU**: Transition validation is constant-time table lookup plus small guard checks. It must not run in `_process()` or per-frame loops.
- **Memory**: `context.duplicate(true)` is expected to copy a small dictionary. Large payloads must not be stored in transition context.
- **Load Time**: Scene transition latency depends on Godot scene loading and destination scene minimal initialization. The GameState coordination path should stay under 1ms excluding actual scene/resource load.
- **Network**: Not applicable.

## Migration Plan

This ADR is written before implementation. Implementation stories should:

1. Implement `GameState.State` with the exact states listed here.
2. Implement a table-driven `is_transition_valid(from_state, to_state)`.
3. Implement `request_transition()` with guard checks, pending transition state, and duplicate rejection.
4. Implement SceneTree scene path routing inside GameState.
5. Implement `_on_scene_ready(scene_state)` with pending-state verification.
6. Add a one-shot 5 second transition timeout.
7. Update every routable scene to call `_on_scene_ready()` exactly once after minimal safe initialization.
8. Implement GOODNIGHT transaction guard using ADR-0002's `SaveManager` and `ProgressManager` contract.
9. Add unit and integration tests for transition table, readiness timing, duplicate rejection, timeout, context copy, BOOT recovery, and GOODNIGHT save failure.

## Validation Criteria

- Unit tests confirm every valid transition in the table is accepted when its guard passes.
- Unit tests confirm representative invalid transitions are rejected and emit no `state_changed`.
- Unit tests confirm duplicate requests while `is_transitioning == true` return false.
- Integration tests confirm `state_changed` is emitted only after destination `_on_scene_ready()`.
- Integration tests confirm `_on_scene_ready()` with mismatched `scene_state` does not commit the transition.
- Integration tests confirm transition timeout routes to ERROR without emitting the original transition success.
- Unit tests confirm `state_changed` context is a deep copy and listener mutation does not alter `GameState.context`.
- BOOT recovery tests confirm `equipped_items == []` enters DAILY_SCENE as explicit empty outfit.
- BOOT recovery tests confirm missing, null, or non-array `equipped_items` does not enter DAILY_SCENE.
- GOODNIGHT tests confirm `advance_day() == false` keeps state in GOODNIGHT, emits no `state_changed(GOODNIGHT, MAIN_MENU, ...)`, does not call a second save, and shows no new-day/unlock success.
- Static review confirms UI and scene systems do not call `SceneTree.change_scene_to_file()` directly for global state transitions.

## Related Decisions

- ADR-0001: Autoload Order and Boot Orchestration
- ADR-0002: Persistence Ownership and Save Rollback Strategy
- Future ADR: Progression and unlock event contract
- Future ADR: Presentation-to-gameplay communication pattern
- Future ADR: Replay day routing and completed-week flow

## Related Documents

- `docs/architecture/architecture.md`
- `docs/registry/architecture.yaml`
- `docs/engine-reference/godot/VERSION.md`
- `docs/engine-reference/godot/breaking-changes.md`
- `docs/engine-reference/godot/deprecated-apis.md`
- `design/gdd/scene-state-management.md`
- `design/gdd/daily-scene.md`
- `design/gdd/main-menu-goodnight-ui.md`
- `design/gdd/progress-management.md`
- `design/gdd/save-load.md`
