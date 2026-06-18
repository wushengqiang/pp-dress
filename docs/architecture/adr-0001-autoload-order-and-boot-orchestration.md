# ADR-0001: Autoload Order and Boot Orchestration

## Status
Proposed

## Date
2026-06-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / SceneTree / Boot orchestration |
| **Knowledge Risk** | MEDIUM |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None directly. This ADR relies on Godot Autoload ordering, `_ready()`, typed signal connections, `await signal`, and `SceneTree.change_scene_to_file()` semantics that must be verified in Godot 4.6. |
| **Verification Required** | Test Autoload registration order, deferred BOOT timing, `is_ready/load_error` startup gates, `SceneTree.change_scene_to_file()` readiness confirmation, transition timeout routing, and no same-frame `GameState._ready()` access to later Autoloads. |

Godot 4.6 is post-LLM-cutoff for this project. The relevant checked references do not list a breaking API change for `SceneTree.change_scene_to_file()`, Autoload `_ready()`, or signals, but scene switching remains a timing-sensitive SceneTree behavior and must be validated on the pinned engine version.

Deprecated APIs and patterns to avoid:

- Do not use `yield()`; use `await signal`.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections such as `some_signal.connect(_on_some_signal)`.
- Do not assume a scene is ready immediately after `change_scene_to_file()`.

Engine Specialist Validation: not spawned in this run because the current tool policy only allows sub-agent spawning when the user explicitly requests delegation. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Future ADRs for scene/state transition details, SaveManager/ProgressManager ownership, TextureCache loading policy, and InputManager event routing. |
| **Blocks** | Implementation stories that create or depend on Foundation Autoload startup order and BOOT routing. |
| **Ordering Note** | This is the first Foundation ADR and should be accepted before implementation stories for `WardrobeDatabase`, `GameState`, `SaveManager`, `TextureCache`, `InputManager`, or `ProgressManager` are marked ready. |

## Context

### Problem Statement

The project has several global Godot Autoload services that participate in startup: wardrobe data, save data, scene state, resources, input, and progression. If these services read each other during `_ready()` without a fixed order and a separate BOOT protocol, startup can become order-dependent, cyclic, or silently enter an interactive scene before required data is valid.

The scene/state GDD also requires safe handling of Godot scene switching. `SceneTree.change_scene_to_file()` must not be treated as immediate readiness; the new scene has to confirm readiness before `GameState` broadcasts `state_changed`.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- Target platform is Web, so startup must avoid unnecessary frame stalls.
- `WardrobeDatabase` must load synchronously in `_ready()` and must not `await`, preserving the Autoload ordering guarantee.
- `GameState._ready()` must not access Autoloads registered after `GameState` in the same frame.
- Startup failures must route to `ERROR` instead of entering a partially initialized playable state.
- `AudioManager` may exist as a Foundation service in the broader architecture, but this ADR only locks the six startup gates explicitly defined by current GDDs.

### Requirements

- Must register Foundation/Core Autoloads in the required order.
- Must separate Godot Autoload construction order from gameplay BOOT readiness checks.
- Must verify `is_ready` and `load_error` for startup-gated services.
- Must wait for scene readiness confirmation before emitting `state_changed`.
- Must preserve `equipped_items == []` as a valid explicit empty outfit where the GDD allows it.
- Must keep startup initialization entry work under the Scene/State GDD budget of `<10ms`, excluding WebAssembly compilation time.

## Decision

The project will use a fixed Godot Autoload registration order plus a deferred `GameState` BOOT orchestration step.

### Autoload Registration Order

Godot Project Settings must register Autoloads in this exact order:

1. `WardrobeDatabase`
2. `GameState`
3. `SaveManager`
4. `TextureCache`
5. `InputManager`
6. `ProgressManager`

This order is intentionally not the same as the BOOT business-readiness order. Registration order only determines when each Autoload's `_ready()` runs. `GameState` appears early so it can own the global state machine, but it must not read later Autoloads during the same `_ready()` frame.

### BOOT Orchestration

`GameState._ready()` enters BOOT and schedules `_boot()` with a deferred call or an equivalent next-frame wait. `_boot()` then performs readiness checks in this business order:

1. `WardrobeDatabase`
2. `SaveManager`
3. `ProgressManager`
4. `TextureCache`
5. `InputManager`

Each gated service exposes:

```gdscript
var is_ready: bool
var load_error: String
```

`GameState` checks these fields before allowing transition to an interactive state. If a service is not ready but has a supported completion signal, `GameState` may `await` that signal with a bounded timeout. If `load_error` is non-empty, or readiness does not resolve within the allowed startup/transition policy, `GameState` routes to `ERROR`.

Autoloads must not solve this by mutually calling each other from `_ready()`. Cross-system startup dependencies are expressed as readiness checks in BOOT, not as `_ready()` call chains.

### Scene Transition Readiness

Scene transitions use:

```gdscript
get_tree().change_scene_to_file(scene_path)
```

`GameState` sets `is_transitioning = true` before requesting the scene change. It must not emit `state_changed` immediately after `change_scene_to_file()`.

The newly loaded scene calls:

```gdscript
GameState._on_scene_ready(scene_state)
```

from its `_ready()` path after its minimal safe initialization is complete. Only then does `GameState` clear `is_transitioning`, update `current_state`, and emit:

```gdscript
state_changed(from_state: State, to_state: State, context: Dictionary)
```

The emitted context must be a defensive deep copy, such as `context.duplicate(true)`, so listeners cannot mutate `GameState` state.

If `is_transitioning` remains true for 5 seconds, `GameState` treats the transition as failed and routes to `ERROR`.

### Startup Recovery

During BOOT, `GameState` may recover into `DAILY_SCENE` only when all required conditions from the Scene/State GDD are satisfied:

- `SaveManager` reports `scene_in_progress == true`.
- `ProgressManager` is ready and has repaired/clamped progression state.
- `equipped_items` exists and can be filtered to an `Array[String]` of known, currently usable item IDs.

An empty filtered outfit array `[]` is a valid explicit empty outfit where the GDD allows it. BOOT must not automatically replace `[]` with a default outfit or treat it as invalid solely because it is empty.

### Architecture Diagram

```text
Godot Autoload _ready() order

WardrobeDatabase
  -> GameState
       enters BOOT, schedules deferred _boot()
  -> SaveManager
  -> TextureCache
  -> InputManager
  -> ProgressManager

Next frame / deferred BOOT

GameState._boot()
  -> check WardrobeDatabase.is_ready / load_error
  -> check SaveManager.is_ready / load_error
  -> check ProgressManager.is_ready / load_error
  -> check TextureCache.is_ready / load_error
  -> check InputManager.is_ready / load_error
  -> transition MAIN_MENU, WARDROBE, DAILY_SCENE, or ERROR

Scene transition

GameState.request_transition(target)
  -> is_transitioning = true
  -> SceneTree.change_scene_to_file(path)
  -> new_scene._ready()
  -> GameState._on_scene_ready(target)
  -> emit state_changed(from, target, context_copy)
```

### Key Interfaces

```gdscript
signal state_changed(from_state: State, to_state: State, context: Dictionary)

enum State { BOOT, MAIN_MENU, WARDROBE, DAILY_SCENE, GOODNIGHT, ERROR, QUIT }

var is_transitioning: bool
var current_state: State
var context: Dictionary

func request_transition(to_state: State, transition_context: Dictionary = {}) -> void
func _on_scene_ready(scene_state: State) -> void
func get_current_day() -> int
```

Startup-gated Autoload contract:

```gdscript
var is_ready: bool
var load_error: String
```

Implementation rules:

- `WardrobeDatabase._ready()` must complete synchronously and must not `await`.
- `GameState._ready()` must not read `SaveManager`, `TextureCache`, `InputManager`, or `ProgressManager` in the same frame.
- `TextureCache._ready()` may read `WardrobeDatabase` Tier 1 paths only after confirming `WardrobeDatabase.is_ready == true`.
- `InputManager` does not depend on other Autoloads but is still checked by BOOT before interactive WARDROBE entry.
- `ProgressManager` owns progression repair; `GameState` consumes the repaired result instead of repairing day/unlock rules itself.

## Alternatives Considered

### Alternative 1: Fixed Autoload Order + Deferred GameState BOOT

- **Description**: Register Autoloads in a fixed order, let `GameState` defer BOOT until later Autoloads have run `_ready()`, then perform explicit readiness checks.
- **Pros**: Matches the GDDs, keeps ownership clear, prevents same-frame order bugs, and makes startup testable.
- **Cons**: Requires discipline: developers must not add direct `_ready()` call chains or treat registration order as business readiness.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: Each Autoload Initializes Asynchronously and Chains Signals

- **Description**: Every Autoload emits ready/error signals and downstream Autoloads connect to whatever they need.
- **Pros**: Flexible and can support long-running initialization.
- **Cons**: Early `_ready()` signals can fire before consumers connect; arbitrary signal chains hide dependencies and make startup order hard to test.
- **Rejection Reason**: Rejected because the GDD explicitly avoids dead ready signals for synchronous startup data and favors property checks for one-time boot gates.

### Alternative 3: Dedicated BootScene or Bootstrapper Owns All Initialization

- **Description**: A separate scene/node performs all startup checks, then hands control to `GameState`.
- **Pros**: Keeps `GameState` smaller and can present startup UI directly.
- **Cons**: Splits state authority between Bootstrapper and `GameState`, complicating ERROR retry and scene recovery flow.
- **Rejection Reason**: Rejected for now because current architecture assigns BOOT orchestration and scene transition safety to Scene/State Management.

## Consequences

### Positive

- Startup order is deterministic and visible in project settings.
- `GameState` remains the single owner of global state routing and transition safety.
- Foundation systems can be tested through simple readiness contracts.
- Scene readiness is explicit and does not depend on fragile timing assumptions after `change_scene_to_file()`.
- Startup failure behavior is centralized through `ERROR`.

### Negative

- Adding a new startup-gated Autoload requires revisiting this ADR or writing a superseding ADR.
- Deferred BOOT introduces one deliberate frame boundary before normal startup routing.
- Scene authors must remember to call `GameState._on_scene_ready()` exactly once when minimal safe initialization is complete.

### Risks

- **Risk**: A developer reads `SaveManager` or `ProgressManager` in `GameState._ready()` and reintroduces same-frame ordering bugs.  
  **Mitigation**: Add an automated test or lint-style review checklist for `GameState._ready()` access patterns.
- **Risk**: A scene forgets to call `_on_scene_ready()`, leaving `is_transitioning` stuck.  
  **Mitigation**: Keep the 5 second timeout and test each routable scene.
- **Risk**: A scene calls `_on_scene_ready()` before its required nodes are safe to receive state data.  
  **Mitigation**: Define per-scene minimal readiness in each scene GDD/story acceptance criteria.
- **Risk**: `equipped_items == []` is mistakenly treated as missing data.  
  **Mitigation**: Add BOOT recovery tests for explicit empty outfit and invalid/missing outfit fields separately.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `scene-state-management.md` | Autoload registration order is `WardrobeDatabase -> GameState -> SaveManager -> TextureCache -> InputManager -> ProgressManager`. | Locks the exact Godot project Autoload order. |
| `scene-state-management.md` | BOOT checks initialize/readiness order as database, save, progress, resources, input. | Defines the deferred BOOT business-readiness order. |
| `scene-state-management.md` | `GameState._ready()` must not access later Autoloads in the same frame. | Requires deferred/next-frame `_boot()` and forbids same-frame later-Autoload reads. |
| `scene-state-management.md` | Scene changes must wait for new scene `_ready()` and `GameState._on_scene_ready()` before `state_changed`. | Defines the scene readiness handshake and signal timing. |
| `scene-state-management.md` | `is_transitioning` timeout routes to `ERROR`. | Requires a 5 second transition timeout and ERROR routing. |
| `scene-state-management.md` | BOOT recovery must filter `equipped_items` and allow explicit empty outfit where valid. | Preserves `[]` as meaningful explicit empty outfit instead of treating it as missing by default. |
| `wardrobe-database.md` | `WardrobeDatabase` is first Autoload, loads synchronously, exposes `is_ready/load_error`. | Places `WardrobeDatabase` first and uses property-based BOOT checks. |
| `resource-loader.md` | `TextureCache` depends on `WardrobeDatabase.is_ready` for Tier 1 data and is checked by BOOT. | Allows `TextureCache` to read wardrobe paths only after readiness and includes it as a startup gate. |
| `input-management.md` | `InputManager` follows project Autoload chain and must be ready before interactive WARDROBE. | Includes `InputManager` in registration order and BOOT readiness checks. |
| `progress-management.md` | `ProgressManager` owns day/progress repair; `GameState` acts as facade/trigger. | BOOT waits for repaired progress state and does not make `GameState` the progression authority. |
| `systems-index.md` | Scene/state and resource loading have an intentional BOOT/check relationship, not mutual `_ready()` coupling. | Bans mutual `_ready()` call chains and centralizes readiness checks in BOOT. |

## Performance Implications

- **CPU**: BOOT checks are expected to be constant-time property reads plus bounded waits for systems that support readiness completion signals.
- **Memory**: No additional persistent memory ownership beyond existing Autoload state. Context emitted through `state_changed` uses defensive copies, so large context payloads should be avoided.
- **Load Time**: The BOOT entry path must stay under `<10ms`, excluding WebAssembly compilation time. Heavy resource work belongs in TextureCache tiered loading, not in `GameState._boot()`.
- **Network**: Not applicable.

## Migration Plan

This ADR is written before implementation. Implementation stories should:

1. Configure Godot Autoloads in the exact order defined here.
2. Implement `WardrobeDatabase`, `SaveManager`, `TextureCache`, `InputManager`, and `ProgressManager` with `is_ready/load_error` startup fields where applicable.
3. Implement `GameState._ready()` as BOOT entry plus deferred `_boot()`, with no same-frame reads of later Autoloads.
4. Implement `request_transition()` through `SceneTree.change_scene_to_file()` and `_on_scene_ready()` confirmation.
5. Add startup, recovery, and scene transition tests before implementation handoff is considered complete.

## Validation Criteria

- A test confirms Godot Autoload order is configured as `WardrobeDatabase`, `GameState`, `SaveManager`, `TextureCache`, `InputManager`, `ProgressManager`.
- A test or instrumentation confirms `GameState._ready()` does not read later Autoload state in the same frame.
- BOOT enters `ERROR` when any startup-gated service has `load_error != ""`.
- BOOT waits for or verifies readiness before entering `MAIN_MENU`, `WARDROBE`, or `DAILY_SCENE`.
- `state_changed` is not emitted until the destination scene has called `_on_scene_ready()`.
- Transition timeout after 5 seconds routes to `ERROR`.
- BOOT recovery distinguishes valid explicit empty outfit `[]` from missing or invalid outfit data.
- Deprecated Godot APIs listed in this ADR do not appear in startup and scene transition implementation.

## Related Decisions

- Future ADR: SaveManager and ProgressManager ownership boundaries.
- Future ADR: Scene/state transition details and context ownership.
- Future ADR: TextureCache tiered loading and Web threaded-loading fallback.
- Future ADR: InputManager registered-region routing and Godot UI/input separation.

## Related Documents

- `docs/architecture/architecture.md`
- `docs/registry/architecture.yaml`
- `docs/engine-reference/godot/VERSION.md`
- `docs/engine-reference/godot/breaking-changes.md`
- `docs/engine-reference/godot/deprecated-apis.md`
- `design/gdd/scene-state-management.md`
- `design/gdd/systems-index.md`
- `design/gdd/wardrobe-database.md`
- `design/gdd/save-load.md`
- `design/gdd/progress-management.md`
- `design/gdd/resource-loader.md`
- `design/gdd/input-management.md`
