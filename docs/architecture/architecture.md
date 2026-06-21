# Dress Up Daily - Master Architecture

## Document Status

- Version: 0.1
- Last Updated: 2026-06-20
- Engine: Godot 4.6
- Review Mode: lean
- GDDs Covered: game-concept.md; systems-index.md; wardrobe-database.md; save-load.md; input-management.md; audio-management.md; resource-loader.md; scene-state-management.md; progress-management.md; sprite-layered-rendering.md; wardrobe-ui.md; dialogue-ui.md; main-menu-goodnight-ui.md; drag-dress-up.md; daily-scene.md; light-narrative-dialogue.md; clothing-unlock.md
- ADRs Referenced: ADR-0001; ADR-0002; ADR-0003; ADR-0004; ADR-0005; ADR-0006; ADR-0007; ADR-0008; ADR-0009; ADR-0010; ADR-0011
- Status: Reviewed - APPROVED WITH CONDITIONS
- Technical Director Sign-Off: 2026-06-20 - APPROVED WITH CONDITIONS
- Lead Programmer Feasibility: SKIPPED - Lean mode

### Sign-Off Notes

Technical Director self-review applied gate `TD-ARCHITECTURE` from `.Codex/docs/director-gates.md`, then the 2026-06-20 architecture review validated traceability against ADR-0001 through ADR-0011.

| Criterion | Assessment |
|-----------|------------|
| Every technical requirement covered by an architectural decision | APPROVED: 15/15 requirements are covered by ADR-0001 through ADR-0011. |
| HIGH risk engine domains addressed or flagged | APPROVED: UI/Input, Resources, Rendering, SceneTree, FileAccess/JSON, Audio, and Web platform risks remain explicitly flagged. |
| API boundaries clean, minimal, implementable | APPROVED WITH CONDITIONS: boundaries are consistent, but Web and dual-focus behavior still require runtime verification. |
| Foundation ADR gaps resolved before implementation | APPROVED: foundation ADRs are written and accepted; implementation can proceed after test and UX gate prep. |

Verdict: APPROVED WITH CONDITIONS. Proceed to test/UX gate preparation before implementation.

## Engine Knowledge Gap Summary

Godot 4.6 is post-cutoff for the model and must be treated as version-sensitive. The architecture flags all HIGH and MEDIUM risk domains at the module and API boundary level.

| Domain | Risk | Project Impact |
|--------|------|----------------|
| UI / Input | HIGH | Godot 4.6 separates mouse/touch focus from keyboard/gamepad focus. All Control-based UI must test both focus paths. |
| Resources | HIGH | Resource duplication and texture lifecycle rules must be explicit; runtime code must avoid relying on undocumented engine cache eviction. |
| Rendering | HIGH | Windows defaults to D3D12, shader texture types changed after 4.3, and Web texture memory is a primary budget risk. |
| GDScript | HIGH | Godot 4.5+ adds language features and release backtracing; contracts should stay typed and version-aware. |
| Web Platform | MEDIUM | localStorage, audio unlock, canvas input behavior, and Web threaded loading require target-browser validation. |
| SceneTree | MEDIUM | Scene changes are deferred; state transitions must wait for the new scene to confirm readiness. |
| FileAccess / JSON | MEDIUM | File reads, parse errors, and Web export inclusion must be checked explicitly. |
| Audio | LOW | Core audio APIs are stable, but browser unlock and background behavior remain platform concerns. |
| 2D Physics / Navigation / Networking | LOW | MVP does not depend on these domains. |

## Technical Requirements Baseline

Technical requirement IDs are now stable in `docs/registry/architecture.yaml`. The architecture covers the following GDD-derived requirement groups:

| Req ID Range | GDD | System | Requirement Group | Domain |
|--------------|-----|--------|-------------------|--------|
| TR-wardrobe-database-* | wardrobe-database.md | Wardrobe Database | JSON schema, read-only query API, z-index resolution, unlock day metadata | Data |
| TR-save-load-* | save-load.md | Save/Load | Web/local file persistence, SaveData schema, bad-save protection, bounded write ownership | Persistence |
| TR-input-management-* | input-management.md | Input Management | Mouse/touch normalization, registered gesture regions, drag/click/scroll arbitration | Input |
| TR-audio-management-* | audio-management.md | Audio Management | Event-driven audio playback, buses, pools, Web unlock, non-blocking failures | Audio |
| TR-resource-loader-* | resource-loader.md | Resource Loader | TextureCache, tiered loading, threaded requests, hot/warm cache, LRU eviction | Resources |
| TR-scene-state-* | scene-state-management.md | Scene/State Management | GameState finite state machine, boot orchestration, scene readiness confirmation | State |
| TR-progress-* | progress-management.md | Progress Management | Current day authority, unlock computation, save-failure rollback, progress signals | Progression |
| TR-sprite-rendering-* | sprite-layered-rendering.md | Sprite Layered Rendering | Layered Sprite2D renderer, z-index ordering, async callback generation guards | Rendering |
| TR-wardrobe-ui-* | wardrobe-ui.md | Wardrobe UI | Clothing grid, category visibility, thumbnails, drag regions, outfit confirmation | UI |
| TR-dialogue-ui-* | dialogue-ui.md | Dialogue UI | Typewriter text, input advancement, end confirmation, completion signal | UI |
| TR-main-menu-goodnight-* | main-menu-goodnight-ui.md | Main Menu / Goodnight UI | Start, goodnight closure, retry paths, completion/replay entry points | UI |
| TR-drag-dress-up-* | drag-dress-up.md | Drag Dress-Up | Drop validation, click alternative, equip request tokening, soft feedback | Gameplay |
| TR-daily-scene-* | daily-scene.md | Daily Scene | Day/context consumption, character/background/dialogue hosting, goodnight request | Gameplay |
| TR-light-narrative-* | light-narrative-dialogue.md | Light Narrative Dialogue | Seven-day sequence provider, localization keys, non-scoring flavor lines | Narrative |
| TR-clothing-unlock-* | clothing-unlock.md | Clothing Unlock | Unlock presentation only, item validation, prompt timing, wardrobe highlight handoff | Progression/UI |

## System Layer Map

| Architecture Layer | Systems | Primary Responsibility |
|--------------------|---------|------------------------|
| Platform | Godot 4.6 Web export, Browser localStorage / DOM, Godot ResourceLoader / SceneTree / Control / AudioServer | Engine and browser capability boundary. |
| Foundation | Wardrobe Database, Save/Load, Scene/State Management, Resource Loader, Input Management, Audio Management | Global Autoload services, boot orchestration, persistence, resources, input, and audio infrastructure. |
| Core | Progress Management, Sprite Layered Rendering | Core gameplay state rules and character visual state. These modules are not UI flow owners. |
| Feature | Drag Dress-Up, Daily Scene, Light Narrative Dialogue, Clothing Unlock | Player-facing gameplay flow, daily content, non-scoring narrative, and unlock presentation. |
| Presentation | Wardrobe UI, Dialogue UI, Main Menu / Goodnight UI | Visible interface, controls, prompts, and player interaction surfaces. |

### Boundary Rules

- GameState owns state routing and scene transition safety; it does not own progress rules.
- ProgressManager is the authority for current day, completed days, and unlock results.
- SaveManager is a persistence pipe; it does not interpret gameplay rules.
- WardrobeDatabase owns static clothing definitions only; it does not equip, unlock, or render clothing.
- TextureCache owns texture loading and cache lifecycle only; it does not decide outfits.
- InputManager emits gesture semantics only; it does not carry item IDs or gameplay objects.
- SpriteLayeredRenderer owns the character's current visual outfit state; it does not restore scenes by itself.
- UI systems consume formal interfaces and must not bypass Foundation/Core modules to write saves or advance days.

### Layer Risk Notes

| System | Engine Risk Domain | Required Handling |
|--------|--------------------|-------------------|
| Input Management; Wardrobe UI; Dialogue UI; Main Menu / Goodnight UI; Clothing Unlock | UI / Input HIGH | Verify Godot 4.6 dual-focus behavior with mouse/touch and keyboard/gamepad. |
| Resource Loader; Sprite Layered Rendering; Daily Scene | Rendering / Resources HIGH | Verify texture loading, cache lifecycle, draw calls, and Web memory budgets against Godot 4.6 references. |
| Save/Load; Wardrobe Database | FileAccess / JSON MEDIUM | Explicitly check file open, parse, schema, export inclusion, and Web backend failures. |
| Audio Management | Web Platform MEDIUM | Treat browser audio unlock and background behavior as platform state. |
| Scene/State Management | SceneTree MEDIUM | Confirm scene readiness after `change_scene_to_file()` before broadcasting state changes. |

## Module Ownership

| Layer | Module | Owns | Exposes | Consumes | Engine APIs / Risk |
|-------|--------|------|---------|----------|--------------------|
| Foundation | `WardrobeDatabase` | Parsed `wardrobe.json`, category table, item index, `is_ready`, `load_error` | `get_item_by_id()`, `get_all_items()`, `get_categories()`, `get_z_index()`, `get_unlocked_items()` | `res://assets/data/wardrobe.json` | `FileAccess`, `JSON` - MEDIUM |
| Foundation | `SaveManager` | `SaveData`, load/save status, storage availability, bad-save overwrite lock | `load()`, `save()`, `get_data_snapshot()`, limited setters, `loaded`, `saved` | Browser `localStorage` or `user://` fallback | `JavaScriptBridge`, `FileAccess`, `JSON` - MEDIUM |
| Foundation | `GameState` | Finite state machine, scene transition guard, cross-scene `context`, BOOT orchestration | `request_transition()`, `get_current_day()`, `state_changed`, `_on_scene_ready()` | `WardrobeDatabase`, `SaveManager`, `ProgressManager`, `TextureCache`, `InputManager` | `SceneTree.change_scene_to_file()` - MEDIUM |
| Foundation | `TextureCache` | Hot/warm texture caches, pending requests, Tier 1/2/3 queues, memory estimate | `get_texture_or_request()`, `request_texture()`, `preload_outfit()`, `evict_full_textures()`, `texture_loaded` | `WardrobeDatabase` texture paths | `ResourceLoader.load_threaded_request()` - HIGH |
| Foundation | `InputManager` | Registered gesture regions, active source, drag/click/hover state | `register_gesture_region()`, `drag_started`, `drag_updated`, `drag_ended`, `clicked`, `hovered` | Godot input events | `InputEvent*`, `Viewport.set_input_as_handled()` - HIGH |
| Foundation | `AudioManager` | Audio event map, bus volume state, SFX pool, music transitions, Web unlock queue | `play_event()`, mute/volume controls, audio state | Player gesture unlock, downstream event keys | `AudioServer`, `AudioStreamPlayer` - MEDIUM |
| Core | `ProgressManager` | `current_day`, `highest_day_completed`, `unlock_progress`, new unlock diff | `get_current_day()`, `advance_day()`, `is_item_unlocked()`, `items_unlocked` | `SaveManager`, `WardrobeDatabase` | GDScript state and save rollback boundary |
| Core | `SpriteLayeredRenderer` | Character outfit visual state, category sprites, equip generations/tokens | `equip_item()`, `apply_outfit()`, `clear_outfit()`, `get_equipped_items()`, result signals | `TextureCache`, `WardrobeDatabase` | `Sprite2D.z_index`, CanvasItem ordering - HIGH |
| Feature | `DragDressUp` | Drop validation state, active equip token, soft result classification | `item_drag_dropped` consumer, `outfit_apply_result` | `WardrobeUI`, `SpriteLayeredRenderer`, `AudioManager` | Drag path depends on UI/Input - HIGH |
| Feature | `DailyScene` | Day scene context, background/character host, dialogue completion routing | Scene entry setup, `dialogue_sequence_finished` handling | `GameState.context`, `SpriteLayeredRenderer`, `DialogueUI` | Rendering composition - HIGH |
| Feature | `LightNarrativeDialogue` | Seven-day dialogue table, sequence/line validation, fallback selection | `request_dialogue_sequence(day, context)` | `DailyScene` context | Localization through `tr()` path |
| Feature | `ClothingUnlock` | Pending unlock presentation queue, session-only new highlights | Unlock prompt handoff, wardrobe highlight IDs | `ProgressManager`, `WardrobeDatabase`, `WardrobeUI`, `MainMenuGoodnightUI` | Control focus/input - HIGH |
| Presentation | `WardrobeUI` | Clothing grid UI state, category selection, `region_id -> item_id` map, confirmation flow | `item_selected_for_equip`, `item_drag_dropped`, final outfit submit | `InputManager`, `WardrobeDatabase`, `TextureCache`, `ProgressManager` | `Control` focus, `TextureRect` - HIGH |
| Presentation | `DialogueUI` | Dialogue panel state, current line index, typewriter progress, end confirmation | `dialogue_sequence_finished(day)` | `GameState`, `LightNarrativeDialogue` | `Control` focus/input - HIGH |
| Presentation | `MainMenuGoodnightUI` | Main menu view, goodnight retry/continue view, completion/replay UI | Start today, continue, retry, quit intents | `GameState`, `ProgressManager`, `ClothingUnlock` | `Control` focus - HIGH |

### Dependency Diagram

```text
Platform
  -> WardrobeDatabase
  -> SaveManager
  -> TextureCache
  -> InputManager
  -> AudioManager
  -> GameState

WardrobeDatabase -> TextureCache
WardrobeDatabase -> ProgressManager
WardrobeDatabase -> SpriteLayeredRenderer
WardrobeDatabase -> WardrobeUI
WardrobeDatabase -> ClothingUnlock

SaveManager -> ProgressManager
SaveManager -> GameState

ProgressManager -> GameState facade
ProgressManager -> WardrobeUI
ProgressManager -> DialogueUI
ProgressManager -> ClothingUnlock

TextureCache -> SpriteLayeredRenderer
TextureCache -> WardrobeUI

InputManager -> WardrobeUI -> DragDressUp -> SpriteLayeredRenderer
AudioManager <- UI / DragDressUp / DailyScene / ClothingUnlock event intents

GameState -> MainMenuGoodnightUI
GameState -> WardrobeUI
GameState -> DailyScene -> DialogueUI -> LightNarrativeDialogue
DailyScene -> SpriteLayeredRenderer
```

### Ownership Decisions

- `Scene/State Management` remains in the Foundation layer because it owns BOOT orchestration and scene transition safety. Gameplay rules stay in Core and Feature modules.
- `ProgressManager` is the only normal owner of day progression and unlock calculation.
- `SaveManager` persists progress fields but does not interpret or repair progression rules.
- `WardrobeUI` maps gesture regions to item IDs; `InputManager` intentionally does not know clothing identity.
- `SpriteLayeredRenderer` owns visual outfit state for a character instance, while `GameState.context` owns cross-scene outfit transfer.
- Audio is event-intent based. Downstream systems do not create players or play raw assets directly.

## Data Flow

### BOOT Initialization Path

```text
Game starts
  -> WardrobeDatabase._ready()
       reads wardrobe.json, validates schema
  -> SaveManager._ready()
       reads localStorage / fallback, builds SaveData
  -> TextureCache._ready()
       reads WardrobeDatabase day-1 items, preloads THUMB
  -> InputManager._ready()
       initializes gesture registry
  -> AudioManager._ready()
       creates buses/pools, may wait for Web gesture
  -> GameState._boot() deferred
       checks WardrobeDatabase
       checks SaveManager
       waits/reads ProgressManager repaired state
       checks TextureCache
       checks InputManager
       chooses MAIN_MENU or DAILY_SCENE recovery
```

| Data | Producer | Consumer | Mode | Notes |
|------|----------|----------|------|-------|
| `is_ready`, `load_error` | Foundation Autoloads | `GameState` | Synchronous property check, optional signal wait | BOOT must not assume later Autoloads have completed in the same frame. |
| `SaveData` | `SaveManager` | `ProgressManager`, `GameState` | Snapshot read | Progress fields are repaired by `ProgressManager`, not by `GameState`. |
| `current_day` | `ProgressManager` | `GameState` facade, UI | Direct read through facade | `GameState.get_current_day()` is the public route. |
| Day-1 thumbnail textures | `TextureCache` | `WardrobeUI` | Cache read | Resource loading is HIGH risk and must be verified on target Web builds. |

### Drag Dress-Up Interaction Path

```text
InputEvent
  -> InputManager
       classifies registered region gesture
       emits drag/click data with region_id
  -> WardrobeUI
       maps region_id -> item_id
       emits equip/drop intent
  -> DragDressUp
       validates drop / click alternative
       requests renderer equip with active token
  -> SpriteLayeredRenderer
       asks TextureCache for FULL texture
       applies only latest valid generation
       emits equip result
  -> WardrobeUI
       updates card/preview/confirmation state
  -> AudioManager
       plays soft event if available
```

| Data | Producer | Consumer | Mode | Notes |
|------|----------|----------|------|-------|
| `region_id` gesture data | `InputManager` | `WardrobeUI` | Signal | InputManager must not carry `item_id`, node references, or resources. |
| `item_id`, drop position | `WardrobeUI` | `DragDressUp` | Signal / direct handoff | WardrobeUI owns region-to-item mapping. |
| Equip token/generation | `DragDressUp`, `SpriteLayeredRenderer` | Local callback guards | Local state | Late callbacks must not overwrite newer outfits. |
| `Texture2D` | `TextureCache` | `SpriteLayeredRenderer` | Callback and cache read | HIGH risk: threaded loading and cache lifecycle must be version-checked. |
| Audio event key | Gameplay/UI modules | `AudioManager` | Event intent | Audio failure never blocks equip result. |

### Wardrobe Confirm To Daily Scene

```text
WardrobeUI confirm outfit
  -> reads SpriteLayeredRenderer.get_equipped_items()
  -> writes GameState.context["equipped_items"]
  -> SaveManager.set_equipped_items(...)
  -> SaveManager.set_scene_in_progress(true)
  -> SaveManager.save()
  -> GameState.request_transition(DAILY_SCENE)
  -> SceneTree.change_scene_to_file(...)
  -> DailyScene._ready()
  -> GameState._on_scene_ready()
  -> GameState emits state_changed
  -> DailyScene applies outfit and starts DialogueUI
```

| Data | Producer | Consumer | Mode | Notes |
|------|----------|----------|------|-------|
| `equipped_items` | `SpriteLayeredRenderer` / `WardrobeUI` | `GameState.context`, `SaveManager` | Snapshot write | Empty array is meaningful only where the relevant GDD allows it. |
| `scene_in_progress = true` | `WardrobeUI` via `SaveManager` | BOOT recovery | Save write | `current_day` is not written by WardrobeUI. |
| Scene readiness | New scene | `GameState` | `_on_scene_ready()` callback | SceneTree changes are deferred; `state_changed` waits for readiness. |

### Daily Scene To Goodnight And Progress Advance

```text
DialogueUI finishes sequence
  -> emits dialogue_sequence_finished(day)
  -> DailyScene requests GOODNIGHT
  -> Goodnight UI displays closure
  -> player continues
  -> GameState sets SaveManager.scene_in_progress(false)
  -> ProgressManager.advance_day()
       computes completed day and new unlocks
       writes SaveManager progress fields
       calls SaveManager.save()
       on success emits day/items signals
       on failure rolls back progress fields
  -> if success: GameState transitions MAIN_MENU
  -> if failure: remain GOODNIGHT with retry
```

| Data | Producer | Consumer | Mode | Notes |
|------|----------|----------|------|-------|
| `dialogue_sequence_finished(day)` | `DialogueUI` | `DailyScene` | Signal | DialogueUI emits intent only; it does not transition GameState directly. |
| `scene_in_progress = false` | `GameState` | `SaveManager` | Direct setter before progress advance | Failure path restores only in-memory safe state as defined by Save/Load GDD. |
| `current_day`, `highest_day_completed`, `unlock_progress` | `ProgressManager` | `SaveManager` | Limited setters + save | Signals are emitted only after successful persistence. |
| `items_unlocked` | `ProgressManager` | `ClothingUnlock` | Signal | ClothingUnlock presents only; it does not compute or persist unlocks. |

### Refresh / Recovery Path

```text
Browser refresh
  -> BOOT repeats
  -> SaveManager loads last snapshot
  -> ProgressManager repairs day/progress fields
  -> GameState checks scene_in_progress
  -> filters equipped_items through current valid/unlocked data
  -> if recoverable non-empty outfit:
       context current_day/equipped_items
       transition DAILY_SCENE from beginning
     else:
       clear scene_in_progress
       save repair
       transition MAIN_MENU
```

| Data | Producer | Consumer | Mode | Notes |
|------|----------|----------|------|-------|
| Persisted `SaveData` | `SaveManager` | `ProgressManager`, `GameState` | Snapshot read | Bad-save lock prevents accidental overwrite of default data. |
| Filtered `equipped_items` | `GameState` with `ProgressManager` / `WardrobeDatabase` | `DailyScene` | Context write | `scene_in_progress` alone is not enough to recover. |
| Repair save | `GameState` | `SaveManager` | Direct setter + save | Used when recovery flag is invalid or empty after filtering. |

### Unlock Presentation Path

```text
ProgressManager emits items_unlocked(ids)
  -> ClothingUnlock validates ids via WardrobeDatabase
  -> waits for MAIN_MENU stable UI timing
  -> shows prompt or hands off directly to WardrobeUI
  -> WardrobeUI highlights newly_unlocked_item_ids once
  -> AudioManager optionally plays progress.items_unlocked
```

| Data | Producer | Consumer | Mode | Notes |
|------|----------|----------|------|-------|
| New item IDs | `ProgressManager` | `ClothingUnlock` | Signal | Initial day-1 items are not new unlock prompts. |
| Valid display item dictionaries | `WardrobeDatabase` | `ClothingUnlock` | Read-only query | Invalid IDs are skipped without blocking valid items. |
| `newly_unlocked_item_ids` | `ClothingUnlock` | `WardrobeUI` | Handoff / session state | Highlight queue is session-only and non-persistent. |
| `progress.items_unlocked` | `ClothingUnlock` | `AudioManager` | Event intent | Audio is optional and non-blocking. |

## API Boundaries

### `WardrobeDatabase`

```gdscript
var is_ready: bool
var load_error: String

func get_item_by_id(id: String) -> Dictionary
func get_all_items() -> Array[Dictionary]
func get_items_by_category(category: String) -> Array[Dictionary]
func get_items_by_tag(tag: String) -> Array[Dictionary]
func get_unlocked_items(day: int) -> Array[Dictionary]
func get_categories() -> Dictionary
func get_z_index(item: Dictionary) -> int
```

Caller invariants:

- Callers must check `is_ready` before using wardrobe data in normal flow.
- Callers must treat returned dictionaries and arrays as snapshots.
- Callers must not expect invalid IDs or categories to throw.

Module guarantees:

- Returned `Dictionary` / `Array` values are defensive copies.
- Invalid queries return empty values and do not modify internal state.
- `get_z_index()` always returns a value in `1..10`.
- JSON schema failures set `is_ready = false` and populate `load_error`.

Engine-specific types and risk:

- Uses `FileAccess` and `JSON` - Godot 4.6 MEDIUM risk. File open, parse, export inclusion, and line-numbered errors must be explicit.

### `SaveManager`

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

Caller invariants:

- `set_equipped_items()` and `set_scene_in_progress()` are for `GameState` flow only.
- `set_current_day()`, `mark_day_completed()`, `record_unlocks()`, and `replace_progress_fields()` are for `ProgressManager` only.
- Gameplay/UI modules must not call `save()`, `load()`, or `is_save_exists()` in `_process()`, drag hover, animation loops, or high-frequency UI paths.

Module guarantees:

- `SaveManager` persists fields but does not repair or interpret progression rules.
- Bad-save overwrite lock prevents automatic default-save overwrite.
- `load()` does not repeatedly read backend once ready unless test-only reload is used.
- `save()` returns success/failure and emits `saved` only after success.

Engine-specific types and risk:

- Uses `JavaScriptBridge`, `FileAccess`, and `JSON` - Godot/Web MEDIUM risk. Browser failure states must be represented without throwing unhandled exceptions.

### `GameState`

```gdscript
signal state_changed(from_state: State, to_state: State, context: Dictionary)

enum State { BOOT, MAIN_MENU, WARDROBE, DAILY_SCENE, GOODNIGHT, ERROR, QUIT }

var current_state: State
var context: Dictionary
var is_transitioning: bool

func request_transition(to_state: State, next_context: Dictionary = {}) -> bool
func get_current_day() -> int
func _on_scene_ready(scene_state: State) -> void
```

Caller invariants:

- Scenes must call `_on_scene_ready()` from their `_ready()` path after they can safely receive state data.
- UI and scene modules request transitions; they do not mutate `current_state` directly.
- Callers must treat `context` received from `state_changed` as their private copy.

Module guarantees:

- `state_changed` is emitted only after `SceneTree.change_scene_to_file()` has completed and the new scene confirms readiness.
- `context` emitted with `state_changed` is a defensive deep copy.
- `GameState` does not repair `current_day`; it delegates day authority to `ProgressManager`.

Engine-specific types and risk:

- Uses `SceneTree.change_scene_to_file()` - Godot 4.6 MEDIUM risk. Scene changes are deferred and must be readiness-confirmed.

### `TextureCache`

```gdscript
signal texture_loaded(item_id: String, resolution: int)
signal batch_completed(item_ids: Array[String])

const THUMB := 0
const FULL := 1

var is_ready: bool
var load_error: String

func get_texture(item_id: String, resolution: int) -> Texture2D
func get_texture_or_request(item_id: String, resolution: int, callback: Callable) -> void
func request_texture(item_id: String, resolution: int) -> void
func preload_outfit(item_ids: Array[String]) -> void
func preload_category_thumbnails(category: String) -> void
func preload_day_thumbnails(day: int) -> void
func is_cached(item_id: String, resolution: int) -> bool
func evict_full_textures() -> void
func cancel_request(item_id: String, resolution: int) -> void
func get_memory_estimate() -> int
```

Caller invariants:

- Callers must handle `null` texture callbacks.
- Callers that only need to cancel their own instance must use local token/generation guards, not shared `cancel_request()`.
- Callers must not assume cold loads complete in the same frame.

Module guarantees:

- Same texture requests are deduplicated.
- `cancel_request()` notifies all waiters with `callback(null)`.
- `evict_full_textures()` clears held FULL references and pending FULL requests.
- Implementation must not call non-existent `ResourceLoader.remove_resource_from_cache()`.

Engine-specific types and risk:

- Uses `Texture2D` and `ResourceLoader.load_threaded_request()` - Godot 4.6 Resources HIGH risk. Target Web builds must verify threaded loading and memory behavior.

### `InputManager`

```gdscript
signal drag_started(data: Dictionary)
signal drag_updated(data: Dictionary)
signal drag_ended(data: Dictionary)
signal clicked(data: Dictionary)
signal hovered(data: Dictionary)
signal unhovered(data: Dictionary)

func register_gesture_region(id: StringName, rect: Rect2, options: Dictionary) -> void
func unregister_gesture_region(id: StringName) -> void
func clear_gesture_regions(owner_id: StringName) -> void
func cancel_active_gesture(reason: String) -> void
func is_dragging() -> bool
func get_current_drag() -> Dictionary
```

Caller invariants:

- UI owners must register only gameplay gesture regions, not standard buttons.
- `WardrobeUI` owns the `region_id -> item_id` mapping.
- Consumers must tolerate interrupted drags.

Module guarantees:

- Gesture dictionaries never contain `item_id`, `Node`, `Control`, `Resource`, or clothing references.
- Unregistered regions do not emit gameplay gesture signals.
- Standard Godot GUI controls remain responsible for ordinary button/list input.

Engine-specific types and risk:

- Uses `InputEvent*`, `Control`, `Rect2`, `StringName`, and `Viewport.set_input_as_handled()` - Godot 4.6 UI/Input HIGH risk because dual-focus behavior must be tested across mouse/touch and keyboard/gamepad.

### `ProgressManager`

```gdscript
signal progress_loaded()
signal day_completed(day: int)
signal day_started(day: int)
signal items_unlocked(item_ids: Array[String])

func get_current_day() -> int
func get_highest_day_completed() -> int
func advance_day() -> bool
func is_item_unlocked(item_id: String) -> bool
func get_newly_unlocked_items() -> Array[String]
```

Caller invariants:

- Only `GameState` calls `advance_day()` in the GOODNIGHT completion flow.
- UI reads progress through public queries, not through `SaveManager` fields.

Module guarantees:

- `advance_day()` emits progress/unlock signals only after successful persistence.
- Save failure rolls back ProgressManager memory state and SaveManager progress fields.
- `current_day` is clamped/repaired here, not in `GameState`.

### `SpriteLayeredRenderer`

```gdscript
signal renderer_ready()
signal outfit_changed(item_id: String, category: String, equipped_items: Array[String])
signal equip_item_completed(item_id: String, result: String, equipped_items: Array[String])
signal outfit_applied(equipped_items: Array[String])

func equip_item(item_id: String) -> void
func apply_outfit(item_ids: Array[String]) -> void
func unequip_category(category: String) -> void
func clear_outfit() -> void
func get_equipped_items() -> Array[String]
```

Caller invariants:

- Callers must wait for `renderer_ready` or equivalent ready state before normal use.
- Callers must not assume async equip succeeds until result signal/callback returns success.
- Scene owners must not ask shared `TextureCache` to cancel requests merely because one renderer instance exits.

Module guarantees:

- Each category has at most one equipped item.
- Late texture callbacks are discarded via generation/token checks.
- Scene exit, `queue_free()`, or `_exit_tree()` prevents stale callbacks from committing state.

Engine-specific types and risk:

- Uses `Sprite2D`, `CanvasItem.z_index`, and `Texture2D` - Rendering HIGH risk. Godot z-index ordering requires clothing sprites to share the same parent.

### `LightNarrativeDialogue` And `DialogueUI`

```gdscript
func request_dialogue_sequence(day: int, context: Dictionary) -> Dictionary

signal dialogue_sequence_finished(day: int)
```

Caller invariants:

- `DialogueUI` is the normal caller for `request_dialogue_sequence()`.
- `DialogueUI` emits completion intent; `DailyScene` / `GameState` handles routing.

Module guarantees:

- Light narrative dialogue does not output state-transition commands.
- Light narrative dialogue does not write progress or saves.
- Dialogue UI does not call `ProgressManager.advance_day()` or directly force GOODNIGHT.

### `AudioManager`

```gdscript
func play_event(event_key: String, context: Dictionary = {}) -> void
```

Caller invariants:

- Callers pass event intent keys, not raw audio resources.
- Callers must not depend on audio playback for gameplay success.

Module guarantees:

- Unknown events do not crash and only produce diagnostics.
- Audio resource failures do not block UI, gameplay, or progression.
- Web audio unlock is handled internally.

### ADR-Required Boundary Decisions

- Decide whether `DragDressUp`, `ClothingUnlock`, and Presentation-to-Core communication uses direct calls, signals, or a light event bus.
- Lock Autoload order and BOOT protocol as a Foundation ADR.
- Define how limited SaveManager setters are enforced in GDScript.
- Define TextureCache cache policy and Web threaded-loading fallback in a dedicated ADR.
- Define UI focus/accessibility conventions for Godot 4.6 Control nodes.

## ADR Audit

One ADR file currently exists under `docs/architecture/`:

- `docs/architecture/adr-0001-autoload-order-and-boot-orchestration.md`
  - Status: Proposed
  - Date: 2026-06-18
  - Domain: Core / SceneTree / Boot orchestration
  - Engine: Godot 4.6
  - Covers: Autoload registration order, deferred BOOT orchestration, startup readiness gates, scene readiness confirmation before `state_changed`, transition timeout routing, and explicit empty outfit recovery semantics.

| Check | Result |
|-------|--------|
| Existing ADR count | 1 |
| Engine Compatibility sections | 1 / 1 |
| Engine version recorded | Godot 4.6 in ADR-0001 |
| Post-cutoff APIs flagged | ADR-0001 flags Autoload `_ready()`, typed signals / `await signal`, and `SceneTree.change_scene_to_file()` timing for verification |
| GDD Requirements Addressed sections | 1 / 1 |
| Conflicts with current layer/ownership decisions | No conflicts found; ADR-0001 matches the current Foundation ownership model |
| TR coverage by ADRs | Partial: scene/state boot orchestration covered; most other requirement groups still uncovered by ADRs |

### Traceability Coverage Check

ADR-0001 through ADR-0011 cover the current baseline. The architecture now has complete traceability for the 15 grouped technical requirements reviewed on 2026-06-20.

| Req ID Range | Requirement Group | ADR Coverage | Status |
|--------------|-------------------|--------------|--------|
| TR-wardrobe-database-* | JSON schema, read-only query API, z-index resolution, unlock day metadata | ADR-0010 | COVERED |
| TR-save-load-* | Web/local file persistence, SaveData schema, bad-save protection, bounded write ownership | ADR-0002, ADR-0004 | COVERED |
| TR-input-management-* | Mouse/touch normalization, registered gesture regions, drag/click/scroll arbitration | ADR-0005 | COVERED |
| TR-audio-management-* | Event-driven audio playback, buses, pools, Web unlock, non-blocking failures | ADR-0009 | COVERED |
| TR-resource-loader-* | TextureCache, tiered loading, threaded requests, hot/warm cache, LRU eviction | ADR-0003 | COVERED |
| TR-scene-state-* | GameState finite state machine, boot orchestration, scene readiness confirmation | ADR-0001, ADR-0004 | COVERED |
| TR-progress-* | Current day authority, unlock computation, save-failure rollback, progress signals | ADR-0002, ADR-0004, ADR-0008 | COVERED |
| TR-sprite-rendering-* | Layered Sprite2D renderer, z-index ordering, async callback generation guards | ADR-0003, ADR-0007 | COVERED |
| TR-wardrobe-ui-* | Clothing grid, category visibility, thumbnails, drag regions, outfit confirmation | ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0010 | COVERED |
| TR-dialogue-ui-* | Typewriter text, input advancement, end confirmation, completion signal | ADR-0005, ADR-0006, ADR-0011 | COVERED |
| TR-main-menu-goodnight-* | Start, goodnight closure, retry paths, completion/replay entry points | ADR-0004, ADR-0005, ADR-0006, ADR-0009 | COVERED |
| TR-drag-dress-up-* | Drop validation, click alternative, equip request tokening, soft feedback | ADR-0005, ADR-0006, ADR-0007, ADR-0009 | COVERED |
| TR-daily-scene-* | Day/context consumption, character/background/dialogue hosting, goodnight request | ADR-0004, ADR-0006, ADR-0007, ADR-0009, ADR-0011 | COVERED |
| TR-light-narrative-* | Seven-day sequence provider, localization keys, non-scoring flavor lines | ADR-0011 | COVERED |
| TR-clothing-unlock-* | Unlock presentation only, item validation, prompt timing, wardrobe highlight handoff | ADR-0008, ADR-0009, ADR-0010 | COVERED |

## Required ADRs

### Accepted ADR Set

1. `docs/architecture/adr-0001-autoload-order-and-boot-orchestration.md`
   - Accepted.
   - Covers initialization order for `WardrobeDatabase`, `GameState`, `SaveManager`, `TextureCache`, `InputManager`, and `ProgressManager`.

2. `docs/architecture/adr-0002-persistence-ownership-and-save-rollback-strategy.md`
   - Accepted.
   - Covers `SaveManager` boundaries, `ProgressManager` authority, bad-save protection, GOODNIGHT rollback, and limited setter ownership.

3. `docs/architecture/adr-0003-texture-loading-cache-and-web-fallback-strategy.md`
   - Accepted.
   - Covers `TextureCache` tiered loading, threaded requests, HOT/WARM LRU, Web validation, memory budgets, and fallback strategy.

4. `docs/architecture/adr-0004-scene-transition-and-state-machine-contract.md`
   - Accepted.
   - Covers `GameState`, scene readiness, transition timing, recovery routing, and context ownership.

5. `docs/architecture/adr-0005-input-gesture-ownership-and-ui-focus-model.md`
   - Accepted.
   - Covers `InputManager` region ownership, Godot GUI separation, dual-focus behavior, and gesture arbitration.

6. `docs/architecture/adr-0006-presentation-to-gameplay-communication-pattern.md`
   - Accepted.
   - Covers communication boundaries between UI, `DragDressUp`, `ClothingUnlock`, `DailyScene`, and core modules.

7. `docs/architecture/adr-0007-sprite-layered-renderer-and-outfit-state-ownership.md`
   - Accepted.
   - Covers Sprite2D layout, z-index ordering, outfit ownership, async generation guards, and cross-scene transfer.

8. `docs/architecture/adr-0008-progression-and-unlock-event-contract.md`
   - Accepted.
   - Covers seven-day progression, unlock calculation, `items_unlocked`, and unlock presentation boundary.

9. `docs/architecture/adr-0009-audio-event-routing-and-web-unlock-behavior.md`
   - Accepted.
   - Covers audio event keys, buses, SFX pool, Web audio unlock, suspended states, and non-blocking failure rules.

10. `docs/architecture/adr-0010-wardrobe-database-schema-and-read-only-query-contract.md`
    - Accepted.
    - Covers wardrobe schema, query API, z-index resolution, unlock metadata, and defensive-copy behavior.

11. `docs/architecture/adr-0011-dialogue-content-provider-and-localization-contract.md`
    - Accepted.
    - Covers dialogue content provider boundaries, localization keys, fallback sequences, and layout constraints.

### Can Defer To Implementation Or Asset Pipeline

- Placeholder and empty-slot visual policy.
- Basis Universal texture compression adoption.
- Unlock prompt exact layout and animation.
- Per-day music variation strategy.
- Debug tool panels and profiling evidence format.

## Architecture Principles

1. **Single authority per state domain**: Each state category has exactly one normal owner. `ProgressManager` owns day and unlock rules, `SaveManager` persists data, and `GameState` routes states.
2. **UI does not bypass domain owners**: Presentation modules emit intents and display results. They do not write saves, advance days, or reinterpret wardrobe/progression rules directly.
3. **Async results must be discardable**: Texture loading, equip requests, and scene transitions must use readiness checks, tokens, or generations so late results cannot commit stale state.
4. **Web failures preserve the companion tone**: Save, audio, texture, and input failures should provide soft recovery paths and avoid exposing technical failure language to players.
5. **Godot 4.6 risk is explicit**: UI/Input, Resources, Rendering, SceneTree, and Web-platform behavior must be flagged in ADRs and verified with test evidence before implementation reliance.

## Open Questions

- OQ-001: `.Codex/docs/technical-preferences.md` is referenced by AGENTS.md but was not found in the workspace.
- OQ-002: Several older design documents render with mojibake in PowerShell output; architecture extraction relies on readable sections and newer reviewed GDDs.
- OQ-003: Web drag feel validation is complete. `/prototype drag-dress-up` passed on 2026-06-18; remaining work is to translate findings into implementation stories and ADR decisions.
- OQ-004: Character drop-hotzone source is not final.
- OQ-005: Basis Universal texture compression adoption is not final.
