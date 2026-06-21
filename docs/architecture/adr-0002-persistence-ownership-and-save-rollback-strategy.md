# ADR-0002: Persistence Ownership and Save Rollback Strategy

## Status
Accepted

## Date
2026-06-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Persistence / FileAccess / JSON / Web storage |
| **Knowledge Risk** | MEDIUM |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None directly required by the architecture. Implementation must verify Godot 4.4+ `FileAccess.store_*` boolean returns and Godot 4.x typed signal / `await signal` syntax on the pinned engine. |
| **Verification Required** | Verify Web `JavaScriptBridge.eval()` storage wrappers, localStorage failure paths, non-Web `FileAccess` tmp/bak replacement, JSON parse/schema handling, bad-save overwrite lock, and save-failure rollback on Godot 4.6 exports. |

Godot 4.6 is post-LLM-cutoff for this project. The checked engine references do not list breaking changes to `JSON` parsing or the basic `FileAccess` open/read APIs, but Godot 4.4 changed `FileAccess.store_*` methods to return `bool`; persistence implementation must check these results rather than assuming writes succeed.

Deprecated APIs and patterns to avoid:

- Do not use `yield()`; use `await signal`.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not treat `FileAccess.store_*` as fire-and-forget on Godot 4.6.
- Do not expose mutable `SaveData` references to consumers.

Engine Specialist Validation: not spawned in this run because no engine-specialist delegation tool was available in the current session. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: Autoload Order and Boot Orchestration must be accepted before implementation stories depending on this ADR are marked ready. |
| **Enables** | Future ADRs for scene transition/state machine details, progression and unlock event contract, main menu/goodnight UI retry behavior, and presentation-to-gameplay communication. |
| **Blocks** | Save/Load implementation, Progress Management implementation, GOODNIGHT completion flow, BOOT save recovery, reset/new-game flow, and tests for save/progress rollback. |
| **Ordering Note** | This ADR should be accepted before stories implement `SaveManager`, `SaveData`, `ProgressManager.advance_day()`, BOOT recovery from persisted data, or GOODNIGHT save-failure UI. |

## Context

### Problem Statement

The project needs a clear ownership boundary between persistence and progression. `SaveManager` must reliably store and retrieve player data, but it must not become the authority for gameplay rules such as day repair, unlock computation, or whether the player has safely advanced. `ProgressManager` must own those rules, but it needs a transactional persistence boundary so save failures cannot show the player new progress that was not actually stored.

This decision is needed before implementing Save/Load and Progress Management because both systems touch the same fields: `current_day`, `highest_day_completed`, `unlock_progress`, `equipped_items`, and `scene_in_progress`. Without an ADR, implementation stories can easily split authority across `SaveManager`, `ProgressManager`, `GameState`, and UI code, creating contradictory recovery behavior and lost-progress bugs.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- MVP target includes Web, so browser storage failure and refresh recovery are first-class behavior.
- Save data is single-slot JSON under a stable save key for MVP.
- `SaveManager` is a Foundation Autoload and `ProgressManager` is a Core Autoload.
- ADR-0001 already fixes Autoload order and deferred BOOT checks.
- GDScript does not provide hard access modifiers; setter ownership must be enforced by API naming, tests, review, and architectural registry constraints.
- Player-facing flows must not display technical storage/schema errors directly.

### Requirements

- Must keep `SaveManager` as the owner of `SaveData`, load/save status, storage availability, and bad-save overwrite lock.
- Must keep `ProgressManager` as the owner of progression rules, day repair, unlock calculation, and progress signals.
- Must persist progress advancement only after `SaveManager.save()` succeeds.
- Must roll back both `ProgressManager` memory state and `SaveManager` progress fields if a GOODNIGHT progress save fails.
- Must not emit `day_completed`, `items_unlocked`, or `day_started` before persistence succeeds.
- Must preserve the last successful persisted state on failed saves.
- Must distinguish WARDROBE outfit save failure from GOODNIGHT progress commit failure.
- Must prevent UI and feature systems from directly mutating progress fields in `SaveManager`.

## Decision

The project will split persistence and progression ownership as follows:

- `SaveManager` owns persisted data transport and storage safety.
- `ProgressManager` owns progression meaning and progression commits.
- `GameState` owns scene flow coordination, but not progress rules.

`SaveManager` is a persistence pipe. It owns one in-memory `SaveData` value and the platform-specific backend used to read, write, reset, and detect the save. It may expose limited field setters because the JSON data lives inside `SaveData`, but those setters are not gameplay authority. They are write ports used by the owning systems.

`ProgressManager` is the normal authority for `current_day`, `highest_day_completed`, unlock repair, unlock cache, category visibility, and `advance_day()`. It reads `SaveManager` snapshots during initialization, repairs invalid progress values, and writes repaired or advanced progress back through `SaveManager`'s limited progress setters.

`GameState` coordinates the player flow. It may write `equipped_items` and `scene_in_progress` for scene recovery, and it calls `ProgressManager.advance_day()` during the GOODNIGHT completion flow. It does not call `SaveManager.set_current_day()`, `SaveManager.mark_day_completed()`, or `SaveManager.record_unlocks()` directly.

### Ownership Rules

`SaveManager` owns:

- `SaveData`
- `save_version`
- `equipped_items`
- `scene_in_progress`
- persisted `current_day`, `highest_day_completed`, and `unlock_progress` fields as stored data
- `last_load_status`
- `last_save_status`
- `storage_available`
- `default_overwrite_locked`
- platform storage wrappers and paths

`ProgressManager` owns:

- runtime `current_day`
- runtime `highest_day_completed`
- runtime unlock cache
- day/progress repair rules
- unlock calculation from `WardrobeDatabase`
- `advance_day()` transaction semantics
- `progress_loaded`, `day_completed`, `items_unlocked`, and `day_started` timing

`GameState` owns:

- when the WARDROBE confirmation flow writes outfit recovery data
- when the GOODNIGHT flow clears `scene_in_progress`
- whether the player remains in GOODNIGHT or transitions away after `advance_day()`
- BOOT recovery decisions after `SaveManager` and `ProgressManager` are ready

### Persistence Commit Contract

The GOODNIGHT completion flow is a transaction boundary:

1. `GameState` calls `SaveManager.set_scene_in_progress(false)`.
2. `GameState` calls `ProgressManager.advance_day()`.
3. `ProgressManager` snapshots its current runtime progress and the corresponding `SaveManager` progress fields.
4. `ProgressManager` computes the candidate completion and next-day/unlock state.
5. `ProgressManager` writes candidate progress fields through `SaveManager`.
6. `ProgressManager` calls `SaveManager.save()`.
7. If save succeeds, `ProgressManager` commits runtime state and emits progress signals.
8. If save fails, `ProgressManager` restores its runtime state and calls `SaveManager.replace_progress_fields(...)`.
9. If `advance_day()` returns `false`, `GameState` restores `scene_in_progress = true` in memory only and remains in GOODNIGHT with retry available.

On a GOODNIGHT save failure, `GameState` must not call `SaveManager.save()` again merely to persist the restored `scene_in_progress = true`. The last successful persisted save should remain the recovery source. A second save on the failure path can overwrite diagnostic status, repeat the same backend failure, or create misleading persistence state.

### WARDROBE Save Contract

WARDROBE confirmation writes outfit recovery data:

```gdscript
func on_outfit_confirmed(confirmed_items: Array[String]) -> void:
    var day := ProgressManager.get_current_day()
    GameState.context["current_day"] = day
    GameState.context["equipped_items"] = confirmed_items.duplicate()
    SaveManager.set_equipped_items(confirmed_items)
    SaveManager.set_scene_in_progress(true)
    var ok := SaveManager.save()
    # WARDROBE flow may continue with a low-pressure warning if save fails.
```

WARDROBE confirmation must not write `current_day`. The current day belongs to `ProgressManager`; WARDROBE only stores enough outfit recovery data to continue or recover the current scene.

### Bad-Save Protection

If an existing save cannot be read, parsed, or accepted by the schema:

- `SaveManager` loads default data into memory only.
- `SaveManager.last_load_status` records the failure category.
- `SaveManager.default_overwrite_locked` becomes `true` when overwriting the previous persisted save would be unsafe.
- Automatic saves return `false` with `SAVE_BLOCKED_DEFAULT_OVERWRITE` until the player explicitly acknowledges starting over through the approved flow.

`ProgressManager` may repair valid but inconsistent progress fields after load. It must not bypass the bad-save overwrite lock.

### Architecture Diagram

```text
Startup / BOOT

SaveManager._ready()
  -> read localStorage or user:// fallback
  -> parse JSON into SaveData
  -> set load status, storage availability, overwrite lock
  -> expose read-only snapshot

ProgressManager._ready()
  -> wait/check SaveManager and WardrobeDatabase
  -> read SaveManager snapshot
  -> repair current_day / highest_day_completed / unlock cache
  -> write repaired progress fields through SaveManager if needed
  -> emit progress_loaded

GOODNIGHT completion

GameState
  -> SaveManager.set_scene_in_progress(false)
  -> ProgressManager.advance_day()
       snapshot runtime + SaveManager progress fields
       compute candidate progress
       write candidate fields through SaveManager
       SaveManager.save()
       success:
         commit runtime progress
         emit day_completed/items_unlocked/day_started
       failure:
         restore runtime progress
         SaveManager.replace_progress_fields(snapshot...)
         return false
  -> if false: restore scene_in_progress true in memory only, remain GOODNIGHT
```

### Key Interfaces

```gdscript
signal loaded(data: SaveData)
signal saved()

var is_ready: bool
var last_load_status: int
var last_save_status: int
var storage_available: bool
var default_overwrite_locked: bool

func load() -> SaveData
func save() -> bool
func get_data_snapshot() -> SaveData
func reset() -> bool
func is_save_exists() -> bool
func acknowledge_default_overwrite() -> void

func set_equipped_items(items: Array[String]) -> void
func set_scene_in_progress(value: bool) -> void

func set_current_day(day: int) -> void
func mark_day_completed(day: int) -> void
func record_unlocks(day: int, item_ids: Array[String]) -> void
func replace_progress_fields(
    current_day: int,
    highest_day_completed: int,
    unlock_progress: Dictionary
) -> void
```

SaveManager caller ownership:

- `set_equipped_items()` and `set_scene_in_progress()` are for `GameState` flow ownership.
- `set_current_day()`, `mark_day_completed()`, `record_unlocks()`, and `replace_progress_fields()` are for `ProgressManager`.
- UI, `ClothingUnlock`, `DailyScene`, `WardrobeUI`, and `DialogueUI` must not call progress-field setters.

```gdscript
signal progress_loaded()
signal day_completed(day: int)
signal items_unlocked(item_ids: Array[String])
signal day_started(day: int)

func get_current_day() -> int
func get_highest_day_completed() -> int
func get_total_days() -> int
func is_day_available(day: int) -> bool
func is_day_completed(day: int) -> bool
func is_last_day() -> bool
func is_item_unlocked(item_id: String) -> bool
func get_unlocked_items(category: String = "") -> Array[String]
func get_items_for_day(day: int) -> Array[String]
func get_newly_unlocked_items() -> Array[String]
func is_category_visible(category: String) -> bool
func get_visible_categories() -> Array[String]
func advance_day() -> bool
func reset_progress() -> void
```

ProgressManager guarantees:

- `progress_loaded` is emitted after both SaveManager and WardrobeDatabase are usable and initial progress repair/cache calculation is complete.
- `advance_day()` returns `true` only when progress calculation and persistence both succeed.
- `day_completed`, `items_unlocked`, and `day_started` are emitted only after successful persistence.
- Save failure rolls back ProgressManager runtime state and SaveManager progress fields.

## Alternatives Considered

### Alternative 1: SaveManager Pure Persistence + ProgressManager Rule Authority

- **Description**: `SaveManager` owns storage and serialized data; `ProgressManager` owns day/unlock rules and performs transactional progress saves through limited SaveManager setters.
- **Pros**: Keeps state authority clear, matches the GDDs, localizes rollback behavior, prevents UI from seeing unpersisted progress, and makes bad-save protection independent from gameplay rules.
- **Cons**: Requires disciplined API ownership because GDScript cannot enforce private callers for each setter.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: SaveManager Interprets and Repairs Progress Rules

- **Description**: `SaveManager` would clamp day values, repair unlock data, compute valid progress, and persist repaired values during load.
- **Pros**: Fewer cross-system calls during startup and all persisted fields are corrected close to storage.
- **Cons**: Turns persistence into a gameplay authority, duplicates `ProgressManager` rules, and makes Save/Load changes risky whenever progression design changes.
- **Rejection Reason**: Rejected because `SaveManager` must remain a data pipe. Progress repair belongs to the progression domain.

### Alternative 3: GameState Directly Writes Progress Fields and Saves

- **Description**: `GameState` would own GOODNIGHT sequencing by calling `SaveManager` progress setters and `SaveManager.save()` directly, then notifying `ProgressManager`.
- **Pros**: The scene-flow owner controls the whole transition path.
- **Cons**: Splits progression authority, makes signal timing fragile, and encourages UI/flow code to mutate persistence fields without understanding unlock cache rollback.
- **Rejection Reason**: Rejected because `GameState` should coordinate scene flow, not compute or commit progression rules.

## Consequences

### Positive

- Save/load, progression, and scene flow each have one clear responsibility.
- Progress signals cannot announce unpersisted progress.
- GOODNIGHT save failure has a deterministic rollback path.
- Bad-save overwrite protection cannot be bypassed by normal progression code.
- BOOT recovery can rely on `ProgressManager` repaired state instead of duplicating repair logic in `GameState`.
- UI systems have query-oriented progress APIs and do not need persistence knowledge.

### Negative

- `SaveManager` still exposes several setters whose intended caller must be enforced by convention, tests, and registry constraints.
- `advance_day()` has more responsibility than a simple state increment because it owns the save/rollback boundary.
- Tests must cover both runtime state and persisted snapshot state for rollback paths.
- WARDROBE save failure and GOODNIGHT save failure intentionally have different user-flow behavior, which must be documented in UI stories.

### Risks

- **Risk**: UI or feature code directly calls `SaveManager` progress setters.  
  **Mitigation**: Register forbidden pattern `ui_direct_save_progress_write`, add static review evidence, and keep progress writes behind `ProgressManager`.
- **Risk**: A developer emits progress signals before `SaveManager.save()` succeeds.  
  **Mitigation**: Register `progress_events_after_persistence`, test signal ordering on success/failure, and make `advance_day()` the only normal commit path.
- **Risk**: GOODNIGHT failure path attempts another save after rollback.  
  **Mitigation**: Register forbidden pattern `goodnight_failure_second_save` and test that failure leaves the previous persisted `scene_in_progress = true` recovery source intact.
- **Risk**: `SaveManager` accidentally clamps or repairs progress fields during schema load.  
  **Mitigation**: Unit tests assert structurally valid but semantically odd values are preserved for `ProgressManager` repair.
- **Risk**: Web storage wrappers throw or return unparseable results.  
  **Mitigation**: JavaScript wrapper calls must return structured JSON result strings and implementation tests must cover quote, backslash, newline, Unicode, quota, and unavailable-storage paths.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `save-load.md` | `SaveManager` owns persistence and `SaveData`, but does not own progression rules. | Defines `SaveManager` as the persistence pipe and reserves progress interpretation for `ProgressManager`. |
| `save-load.md` | `ProgressManager` is the only normal writer for `current_day`, `highest_day_completed`, and `unlock_progress`. | Assigns progress-field writes and rollback to `ProgressManager` through limited SaveManager setters. |
| `save-load.md` | `GameState` writes `equipped_items` and `scene_in_progress` in flow-specific moments only. | Defines WARDROBE and GOODNIGHT GameState write boundaries. |
| `save-load.md` | Bad-save protection blocks automatic overwrite of default data after failed existing-save load. | Keeps `default_overwrite_locked` under `SaveManager` and requires explicit acknowledgement before overwrite. |
| `save-load.md` | `load()` is cached after readiness and test reload uses a separate path. | Keeps public load behavior as persistence lifecycle, not repeated backend polling. |
| `save-load.md` | Web and non-Web save failures must return status without crashing. | Requires storage wrapper/fallback validation and player-safe failure status fields. |
| `save-load.md` | GOODNIGHT save failure restores `scene_in_progress` in memory and does not run a second save. | Locks the failure path and forbids second-save retry inside the failed transaction. |
| `progress-management.md` | `ProgressManager.advance_day()` completes progress and persistence together. | Makes `advance_day()` the transaction boundary and returns `bool` based on save success. |
| `progress-management.md` | Progress signals emit only after successful persistence. | Defines post-persistence signal timing for `day_completed`, `items_unlocked`, and `day_started`. |
| `progress-management.md` | Save failure rolls back ProgressManager state and SaveManager progress fields. | Requires runtime snapshot restoration and `SaveManager.replace_progress_fields(...)`. |
| `progress-management.md` | `current_day = 99, highest_day_completed = 0` is repaired by ProgressManager, not SaveManager. | Keeps semantic progress repair out of the persistence layer. |
| `scene-state-management.md` | BOOT recovery waits for repaired progress before deciding recovery route. | Ensures `GameState` consumes `ProgressManager` repaired state, not raw save fields. |

## Performance Implications

- **CPU**: Save/load and progress commits are low-frequency operations. `advance_day()` may perform small array/dictionary comparisons for unlocks and one save operation; it must not run in `_process()`, hover, drag, or animation loops.
- **Memory**: `SaveData` and progress caches are expected to remain under MVP save-size budgets. Snapshot/rollback copies are short-lived and limited to small dictionaries and arrays.
- **Load Time**: Startup must read/parse save data and compute progress cache during BOOT. Web release measurements must report P50/P95/max for load and save, excluding or clearly identifying first-time WASM startup cost.
- **Network**: Not applicable for MVP; persistence is local Web storage or local file fallback.

## Migration Plan

This ADR is written before implementation. Implementation stories should:

1. Implement `SaveData` with `to_dict()` / `from_dict()` and defensive copies for arrays/dictionaries.
2. Implement `SaveManager` load/save/reset/status behavior without semantic progress repair.
3. Implement platform storage adapters for Web `localStorage` and non-Web `user://` fallback.
4. Implement `ProgressManager` initialization from `SaveManager` snapshot and `WardrobeDatabase`.
5. Implement progress repair in `ProgressManager`, writing repaired progress fields through limited SaveManager setters.
6. Implement `ProgressManager.advance_day()` as the only normal progression commit path.
7. Implement GOODNIGHT flow in `GameState` using the required `scene_in_progress` and `advance_day()` ordering.
8. Add unit and integration tests for successful save, bad-save lock, WARDROBE save failure, GOODNIGHT save failure rollback, BOOT recovery, and no signal-before-persistence behavior.

## Validation Criteria

- Unit tests confirm `SaveManager` preserves structurally valid but semantically invalid progress fields for `ProgressManager` repair.
- Unit tests confirm `SaveManager.get_data_snapshot()` and public getters do not expose mutable internal references.
- Unit tests confirm `SaveManager.save()` returns `false` and does not emit `saved` on storage/write/default-overwrite-lock failures.
- Unit tests confirm `default_overwrite_locked` blocks automatic saves until explicit acknowledgement.
- Unit tests confirm `ProgressManager.advance_day()` emits `day_completed`, `items_unlocked`, and `day_started` only after `SaveManager.save()` succeeds.
- Unit tests confirm `advance_day()` failure restores `ProgressManager` runtime state and calls `SaveManager.replace_progress_fields(...)`.
- Integration tests confirm GOODNIGHT failure leaves the player in GOODNIGHT and does not display new-day or unlock success.
- Integration tests confirm GOODNIGHT failure does not run a second save on the failure path.
- Integration tests confirm browser refresh after a failed GOODNIGHT save recovers from the last successful `scene_in_progress = true` save.
- Static review confirms `save()`, `load()`, and `is_save_exists()` are not called from high-frequency UI or frame-loop paths.
- Static review confirms UI and feature modules do not directly write SaveManager progress fields.
- Web storage tests verify key/value JavaScript string literal escaping and unavailable/quota/security failure behavior.
- Non-Web file tests verify tmp/bak replacement, restore, and reset cleanup paths.

## Related Decisions

- ADR-0001: Autoload Order and Boot Orchestration
- Future ADR: Scene transition and state machine contract
- Future ADR: Progression and unlock event contract
- Future ADR: Presentation to gameplay communication pattern

## Related Documents

- `docs/architecture/architecture.md`
- `docs/registry/architecture.yaml`
- `docs/engine-reference/godot/VERSION.md`
- `docs/engine-reference/godot/breaking-changes.md`
- `docs/engine-reference/godot/deprecated-apis.md`
- `design/gdd/save-load.md`
- `design/gdd/progress-management.md`
- `design/gdd/scene-state-management.md`
