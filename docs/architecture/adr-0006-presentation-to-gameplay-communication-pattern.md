# ADR-0006: Presentation to Gameplay Communication Pattern

## Status
Proposed

## Date
2026-06-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Input / Core |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0004-scene-transition-and-state-machine-contract.md`, `docs/architecture/adr-0005-input-gesture-ownership-and-ui-focus-model.md` |
| **Post-Cutoff APIs Used** | Godot 4.6 Control dual-focus behavior affects presentation state, but this ADR does not depend on a new communication API. |
| **Verification Required** | Verify typed signal connections, scene-level wiring order, no duplicate business action binding, result-before-UI-state updates, and Godot 4.6 mouse/touch versus keyboard/gamepad focus behavior in the pinned Web export. |

Godot 4.6 is post-LLM-cutoff for this project. The checked engine references flag UI/Input as HIGH risk because mouse/touch focus is separate from keyboard/gamepad focus. This ADR keeps presentation state local to UI owners and requires tests for both focus paths where player intent can originate from pointer, touch, or keyboard/gamepad focus confirmation.

Deprecated APIs and patterns to avoid:

- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not use `yield()`; use `await signal`.
- Do not use `$NodePath` lookups in high-frequency presentation-to-gameplay paths; cache references during scene setup.
- Do not rely on `InputManager` for standard Godot `Button.pressed` business actions.

Engine Specialist Validation: not spawned in this run because sub-agent delegation was not explicitly requested by the user. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004: Scene Transition and State Machine Contract; ADR-0005: Input Gesture Ownership and UI Focus Model |
| **Enables** | Implementation stories for `WardrobeUI`, `DragDressUp`, `SpriteLayeredRenderer` integration, dialogue presentation intents, main menu / goodnight transition requests, Daily Scene fallback UI, and presentation-result tests. |
| **Blocks** | Stories that connect wardrobe item intents to dress-up application, result synchronization back to wardrobe UI, UI transition buttons to GameState, and any feature where presentation needs gameplay confirmation before changing visible state. |
| **Ordering Note** | ADR-0004 and ADR-0005 should be accepted before this ADR is accepted. This ADR should be accepted before UI/gameplay integration stories wire signals or decide whether to introduce broader event routing. |

## Context

### Problem Statement

The GDDs define several boundaries where player-facing presentation must communicate with gameplay systems without taking ownership of gameplay state. The most immediate example is wardrobe interaction: `WardrobeUI` turns normalized input into `item_selected_for_equip(item_id)` or `item_drag_dropped(item_id, position)`, while `DragDressUp` decides whether the item can be applied, coordinates with `SpriteLayeredRenderer`, and returns `outfit_apply_result(item_id, accepted, equipped_items, reason)`.

Without a formal communication pattern, implementation could drift into UI code directly changing renderer state, gameplay systems reading UI internals, duplicate actions firing from both Godot native controls and gameplay signals, or a global event bus obscuring ownership. The project needs one consistent pattern for intent, authority, result, and presentation state synchronization before UI/gameplay integration stories begin.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- Target platform is Web with mouse and touch as MVP inputs.
- ADR-0004 makes `GameState.request_transition(...)` the only normal global state transition entry point.
- ADR-0005 makes `InputManager` identity-free and leaves standard GUI controls on native Godot Control paths.
- UI systems may own presentation state such as hover, selected, disabled, card visuals, drag preview, and local display caches.
- Gameplay/domain systems own authoritative gameplay outcomes such as whether an item was equipped, whether progress advanced, whether a scene transition committed, and whether a renderer state changed.
- GDScript cannot enforce private visibility strongly, so ownership must be enforced through APIs, scene wiring, tests, and code review.

### Requirements

- Must define how Presentation/UI sends player intent to gameplay/domain systems.
- Must define how gameplay/domain systems return confirmed results to Presentation/UI.
- Must prevent UI from optimistically rewriting authoritative gameplay state before confirmation.
- Must prevent gameplay systems from reading UI-internal presentation state.
- Must keep `InputManager` identity-free and avoid duplicating ordinary Godot GUI actions through gameplay signals.
- Must support wardrobe drag and click-apply flows using the existing GDD interface names.
- Must support global state transition requests through `GameState.request_transition(...)` without bypassing ADR-0004.
- Must avoid adding a global event bus for MVP unless a future ADR accepts that infrastructure.

## Decision

The project will use a typed local signal intent/result pattern for Presentation-to-Gameplay communication.

Presentation/UI systems emit typed intent signals that describe what the player requested in gameplay terms, but they do not commit authoritative gameplay state. Gameplay/domain systems connect to those signals through scene setup or explicit owner wiring, validate the request, perform or reject the operation, and emit typed result signals back to the relevant Presentation/UI owner.

The default flow is:

```text
Presentation owner
  -> emits typed intent signal

Scene composition / owning scene
  -> connects intent to gameplay/domain handler

Gameplay/domain owner
  -> validates intent
  -> calls authoritative collaborators
  -> emits typed result signal

Presentation owner
  -> updates presentation state from confirmed result
```

Direct method calls are allowed only for narrow owner-to-owner commands where the caller already owns the target reference through scene composition and the callee is the authoritative owner of that operation. Even in that case, the callee must return or emit an explicit result before the UI changes authoritative-looking state.

Global event bus routing is rejected for MVP. A future ADR may introduce broader event routing for analytics, cross-scene notifications, or decoupled audio/FX, but gameplay authority must remain clear and local signal contracts remain the default for UI/gameplay interactions.

### Intent and Result Ownership

| Layer | Owns | May Do | Must Not Do |
|-------|------|--------|-------------|
| Input | Raw and normalized gesture streams | Emit identity-free input data for registered regions | Carry `item_id`, gameplay objects, Node references, or state mutations |
| Presentation/UI | Visual state and player intent translation | Emit typed intent signals; update visuals after confirmed results | Directly mutate gameplay authority or assume success before confirmation |
| Gameplay/domain | Rules and gameplay result authority | Validate intent, call renderer/progress/state owners, emit result signals | Read UI-only state or rely on presentation internals |
| Core managers | Global state, persistence, progression, resource ownership | Expose approved APIs and signals | Accept ad hoc writes from UI bypassing owner contracts |

### Wardrobe Communication Contract

`WardrobeUI` emits outfit intent signals:

```gdscript
signal item_selected_for_equip(item_id: String)
signal item_drag_dropped(item_id: String, position: Vector2)
```

`DragDressUp` consumes these intents. It owns the outfit-application decision for the WARDROBE scene and emits the result:

```gdscript
signal outfit_apply_result(
    item_id: String,
    accepted: bool,
    equipped_items: Array[String],
    reason: String
)
```

Rules:

- `WardrobeUI` may keep `selected_item_id`, drag preview state, and an equipped display cache.
- `WardrobeUI` must not treat an emitted intent as success.
- `WardrobeUI` updates equipped card state from `outfit_apply_result(...)`, not from its own intent.
- `DragDressUp` validates `item_id`, drop position, hotzone, renderer readiness, same-item no-op, and pending token freshness.
- `DragDressUp` calls `SpriteLayeredRenderer.equip_item(item_id)` only after intent validation passes.
- `DragDressUp` waits for `equip_item_completed(...)` or a defined timeout before emitting the final result.
- `SpriteLayeredRenderer.outfit_changed(...)` is a renderer success/visual-feedback signal, not a replacement for the UI-facing `outfit_apply_result(...)` contract.

### Global State Transition Contract

Presentation/UI systems that request a game-state transition must call the approved GameState entry point:

```gdscript
func request_transition(to_state: State, transition_context: Dictionary = {}) -> bool
```

Examples:

- Main menu buttons request `MAIN_MENU -> WARDROBE`.
- Wardrobe cancel confirmation requests `WARDROBE -> MAIN_MENU`.
- Wardrobe outfit confirmation requests `WARDROBE -> DAILY_SCENE` with confirmed `equipped_items`.
- Goodnight controls request `GOODNIGHT -> MAIN_MENU` through the guarded GameState path.

UI may disable buttons or show local pending state after `request_transition()` returns `true`, but it must observe `state_changed(...)` for committed state and must not call `SceneTree.change_scene_to_file()` directly.

### Standard GUI Boundary

Standard Godot GUI controls remain native:

- `Button.pressed`
- `Control.gui_input()`
- `ScrollContainer` scrolling
- dialogue confirmation controls
- main menu and goodnight buttons

A single business action must not be bound both to a native Godot GUI signal and to a custom gameplay intent signal. For example, a main menu start button uses `Button.pressed -> GameState.request_transition(...)`, not `Button.pressed` plus `InputManager.clicked`.

Gameplay gesture regions are only for interactions that need cross-Control pointer/touch semantics, such as wardrobe cards and character drop/application areas.

### Scene Wiring

The owning scene or composition root wires Presentation and Gameplay systems together. A UI script should not search the whole scene tree for arbitrary gameplay systems at runtime.

Preferred wiring:

```gdscript
func _ready() -> void:
    wardrobe_ui.item_drag_dropped.connect(drag_dress_up.on_item_drag_dropped)
    wardrobe_ui.item_selected_for_equip.connect(drag_dress_up.on_item_selected_for_equip)
    drag_dress_up.outfit_apply_result.connect(wardrobe_ui.on_outfit_apply_result)
```

Implementation may use exported `NodePath`, scene-owned references, or constructor/setup injection when available. The key rule is that composition owns wiring; UI and gameplay systems do not create hidden global dependencies on each other.

### Architecture Diagram

```text
Godot Control / InputManager
  -> Presentation owner
       native button action OR registered gesture interpretation
       emits typed player intent

Scene composition root
  -> connects typed signals

Gameplay/domain owner
  -> validates intent
  -> calls authoritative systems
  -> emits confirmed result

Presentation owner
  -> updates visible state from result
```

### Key Interfaces

```gdscript
# WardrobeUI -> DragDressUp
signal item_selected_for_equip(item_id: String)
signal item_drag_dropped(item_id: String, position: Vector2)

func on_outfit_apply_result(
    item_id: String,
    accepted: bool,
    equipped_items: Array[String],
    reason: String
) -> void
```

```gdscript
# DragDressUp
signal outfit_apply_result(
    item_id: String,
    accepted: bool,
    equipped_items: Array[String],
    reason: String
)

func on_item_selected_for_equip(item_id: String) -> void
func on_item_drag_dropped(item_id: String, position: Vector2) -> void
```

```gdscript
# Global state requests still use GameState
func request_transition(to_state: State, transition_context: Dictionary = {}) -> bool
signal state_changed(from_state: State, to_state: State, context: Dictionary)
```

Implementation rules:

- Intent signal names should describe player intent, not internal UI mechanics.
- Result signal names should describe confirmed gameplay outcomes and include a reason/status field.
- Result payloads must include enough state for UI to synchronize without querying private gameplay internals.
- UI-only state names should not appear in gameplay API requirements unless explicitly passed as player intent.
- Cross-system signals should use typed GDScript signatures where practical.
- Scene-exit cleanup must disconnect or invalidate pending result paths so stale results do not update freed UI.

## Alternatives Considered

### Alternative 1: Typed Local Signal Intent/Result Pattern

- **Description**: Presentation emits typed intent signals; gameplay/domain systems validate and emit typed result signals; scene composition wires both sides.
- **Pros**: Fits Godot idioms, preserves ownership, keeps communication testable, supports wardrobe contracts already approved in GDDs, and avoids global routing infrastructure for MVP.
- **Cons**: Requires explicit scene wiring and careful stale-result cleanup on scene exit.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: Direct UI-to-Gameplay Method Calls Everywhere

- **Description**: UI scripts hold gameplay system references and call methods directly for each action.
- **Pros**: Simple in small scenes and easy to follow for one-off commands.
- **Cons**: Encourages UI to know too much about gameplay internals, makes result synchronization inconsistent, and can tempt UI to mutate state immediately after calling a method.
- **Rejection Reason**: Rejected as the default. Narrow direct calls are allowed only when ownership is explicit and result confirmation remains clear.

### Alternative 3: Global Event Bus

- **Description**: All presentation and gameplay systems publish and subscribe through a shared event dispatcher.
- **Pros**: Decouples producers and consumers and can help analytics, audio, or cross-scene notifications later.
- **Cons**: Adds infrastructure before MVP needs it, hides ownership, makes event ordering harder to test, and can duplicate existing Godot signals.
- **Rejection Reason**: Rejected for MVP. Future event routing requires a separate ADR.

### Alternative 4: UI Owns Optimistic State and Gameplay Catches Up

- **Description**: UI immediately changes visible equipped/progress/state displays after player actions, while gameplay later resolves success or failure.
- **Pros**: Can feel instant when operations almost always succeed.
- **Cons**: Conflicts with the GDD requirement that outfit state comes from confirmed downstream results, risks showing unpersisted progress, and makes rollback visible to the player.
- **Rejection Reason**: Rejected because the project values gentle, reliable feedback over speculative UI state.

## Consequences

### Positive

- UI can stay expressive without owning gameplay authority.
- Gameplay results become testable contracts rather than implicit side effects.
- Wardrobe interactions use the exact GDD-approved interface names.
- Standard Godot GUI remains idiomatic and avoids duplicate business actions.
- The project avoids a global event bus until a concrete need exists.
- Scene composition owns dependencies, making integration wiring visible in reviews.

### Negative

- Every scene that combines UI and gameplay must wire signals deliberately.
- Result signals need enough payload to keep UI from querying internals.
- Stale pending results after scene exit require token or lifecycle guards.
- Some very small interactions may feel heavier than a direct method call.

### Risks

- **Risk**: UI updates equipped state after emitting an intent but before result confirmation.  
  **Mitigation**: UI stories must include acceptance criteria that equipped display changes only after `outfit_apply_result(...)`.
- **Risk**: Scene wiring accidentally creates duplicate connections.  
  **Mitigation**: Composition code must connect once during setup and tests should assert one result per intent.
- **Risk**: A stale result arrives after the UI has rebuilt, exited, or changed selection.  
  **Mitigation**: Use scene-exit disconnects, owner cleanup, and pending token checks in gameplay systems.
- **Risk**: Gameplay reads UI-local fields such as `selected_item_id`.  
  **Mitigation**: Gameplay receives all required input through intent payloads and must not query UI internals.
- **Risk**: Teams introduce a global event bus for convenience.  
  **Mitigation**: Event bus use is a forbidden MVP pattern unless superseded by a future ADR.
- **Risk**: Keyboard/gamepad focus confirmation and pointer/touch paths diverge.  
  **Mitigation**: Godot 4.6 dual-focus tests must cover both pointer/touch and keyboard/gamepad confirmation paths where supported.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `wardrobe-ui.md` | Wardrobe UI outputs `item_drag_dropped(item_id, position)` and `item_selected_for_equip(item_id)`. | Makes those typed intent signals the approved Presentation-to-Gameplay contract. |
| `wardrobe-ui.md` | Wardrobe UI waits for `outfit_apply_result(item_id, accepted, equipped_items, reason)` before updating equipped state. | Makes confirmed result signals the only source for authoritative-looking equipped UI state. |
| `drag-dress-up.md` | Drag Dress-Up consumes wardrobe UI intents and returns `outfit_apply_result(...)`. | Defines DragDressUp as the gameplay/domain owner for outfit application decisions. |
| `drag-dress-up.md` | Drag Dress-Up does not directly modify ProgressManager, SaveManager, or GameState. | Keeps gameplay application local to WARDROBE session and routes global state through owner APIs. |
| `sprite-layered-rendering.md` | Renderer exposes `equip_item_completed(...)`, `outfit_changed(...)`, and `outfit_applied(...)` as result/visual readiness signals. | Clarifies renderer signals feed gameplay confirmation and visual feedback, while UI synchronization uses `outfit_apply_result(...)`. |
| `input-management.md` | InputManager emits identity-free gesture data only for registered gameplay gesture regions. | Preserves InputManager as the input layer, not a presentation/gameplay command bus. |
| `main-menu-goodnight-ui.md` | Main menu and goodnight UI request transitions but do not own progression or persistence. | Requires UI transition actions to call `GameState.request_transition(...)` and observe committed results. |
| `dialogue-ui.md` | Dialogue UI emits completion/choice intent without owning progression or direct state transition. | Applies the same intent/result boundary to dialogue presentation. |
| `daily-scene.md` | Daily Scene fallback controls and scene UI should not compete with dialogue or state ownership. | Keeps presentation controls as intent sources and GameState/domain owners as authorities. |
| `scene-state-management.md` | Global scene changes and committed state are owned by GameState. | Reaffirms `request_transition(...)` and `state_changed(...)` as the global state contract. |

## Performance Implications

- **CPU**: Signal dispatch and small result payload handling should be negligible. Presentation-to-gameplay event handling should stay under 0.5ms per player intent, excluding renderer texture loading.
- **Memory**: Payloads should be small typed values such as `String`, `Vector2`, `bool`, and `Array[String]`. Do not pass Node, Control, Resource, Texture, or large dictionaries through presentation/gameplay contracts unless a future ADR approves it.
- **Load Time**: No direct load-time cost beyond scene wiring.
- **Network**: Not applicable.

## Migration Plan

This ADR is written before implementation. Implementation stories should:

1. Implement `WardrobeUI` intent signals exactly as named in this ADR and the GDDs.
2. Implement `DragDressUp` handlers for wardrobe intent signals.
3. Implement `DragDressUp.outfit_apply_result(...)` and connect it back to `WardrobeUI`.
4. Ensure `WardrobeUI` updates equipped display state only from `outfit_apply_result(...)`.
5. Connect `DragDressUp` to `SpriteLayeredRenderer.equip_item(...)` and `equip_item_completed(...)`.
6. Route global transition buttons through `GameState.request_transition(...)`.
7. Keep standard Godot buttons on native `Button.pressed` paths and do not bind the same action to `InputManager.clicked`.
8. Add stale-result cleanup on scene exit and UI rebuild.
9. Add tests for one intent producing one result, duplicate-connection prevention, no optimistic equipped UI state, and stale-result discard.

## Validation Criteria

- Unit tests confirm `WardrobeUI` emits `item_drag_dropped(item_id, position)` after a valid drag end and does not update equipped state immediately.
- Unit tests confirm `WardrobeUI` emits `item_selected_for_equip(item_id)` for click-apply and waits for result before clearing or changing selected/equipped state according to the result.
- Unit tests confirm `DragDressUp` emits exactly one `outfit_apply_result(...)` per current accepted intent path.
- Unit tests confirm `outfit_apply_result(..., true, equipped_items, "equipped")` causes WardrobeUI to overwrite equipped display state with the returned `equipped_items`.
- Unit tests confirm `outfit_apply_result(..., false, ..., reason)` does not optimistically overwrite equipped display state.
- Integration tests confirm `DragDressUp` calls `SpriteLayeredRenderer.equip_item(item_id)` only after intent validation passes.
- Integration tests confirm renderer result signals are mapped to UI-facing `outfit_apply_result(...)`.
- Integration tests confirm scene-exit or UI-rebuild stale results do not update freed or rebuilt UI.
- Integration tests confirm native Godot buttons trigger their business action once and are not also bound through `InputManager.clicked`.
- Integration tests confirm global transitions are requested through `GameState.request_transition(...)` and committed observation happens through `state_changed(...)`.
- Static review confirms UI does not call SaveManager progress setters, ProgressManager mutation APIs, SpriteLayeredRenderer private state, or `SceneTree.change_scene_to_file()` directly.
- Static review confirms gameplay systems do not read UI-only fields such as `selected_item_id`, hover state, or card visuals.
- Web smoke tests confirm mouse/touch and keyboard/gamepad focus confirmation paths produce equivalent gameplay intents where both paths are supported.

## Related Decisions

- ADR-0002: Persistence Ownership and Save Rollback Strategy
- ADR-0003: Texture Loading Cache and Web Fallback Strategy
- ADR-0004: Scene Transition and State Machine Contract
- ADR-0005: Input Gesture Ownership and UI Focus Model
- Future ADR: Audio event routing and feedback ownership
- Future ADR: UI accessibility and localization interaction conventions

## Related Documents

- `docs/architecture/architecture.md`
- `docs/registry/architecture.yaml`
- `docs/engine-reference/godot/VERSION.md`
- `docs/engine-reference/godot/modules/ui.md`
- `docs/engine-reference/godot/modules/input.md`
- `docs/engine-reference/godot/breaking-changes.md`
- `docs/engine-reference/godot/deprecated-apis.md`
- `design/gdd/wardrobe-ui.md`
- `design/gdd/drag-dress-up.md`
- `design/gdd/sprite-layered-rendering.md`
- `design/gdd/input-management.md`
- `design/gdd/main-menu-goodnight-ui.md`
- `design/gdd/dialogue-ui.md`
- `design/gdd/daily-scene.md`
- `design/gdd/scene-state-management.md`
