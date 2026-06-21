# ADR-0005: Input Gesture Ownership and UI Focus Model

## Status
Accepted

## Date
2026-06-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Input / UI |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0001-autoload-order-and-boot-orchestration.md`, `docs/architecture/adr-0004-scene-transition-and-state-machine-contract.md` |
| **Post-Cutoff APIs Used** | Godot 4.6 dual-focus behavior for Control nodes; Godot 4.5+ recursive Control mouse/focus disable behavior may be used for disabled UI hierarchies. |
| **Verification Required** | Verify mouse, touch, hover, drag, scroll, keyboard/gamepad focus, hidden/disabled focus paths, `Viewport.set_input_as_handled()` behavior, and Web canvas DOM default behavior on the pinned Godot 4.6 Web export. |

Godot 4.6 is post-LLM-cutoff for this project. The checked engine references flag UI/Input as HIGH risk because mouse/touch focus is separate from keyboard/gamepad focus. Implementation must not assume `grab_focus()` affects mouse hover or touch focus, and custom UI state drawing must test both focus paths.

Deprecated APIs and patterns to avoid:

- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not use `$NodePath` lookups in high-frequency input paths; cache Control references.
- Do not use untyped hot-path dictionaries when a typed local copy can be made at the consumer boundary.
- Do not rely on `Viewport.set_input_as_handled()` as a browser DOM default-behavior blocker.

Engine Specialist Validation: not spawned in this run because sub-agent delegation was not explicitly requested by the user. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: Autoload Order and Boot Orchestration; ADR-0004: Scene Transition and State Machine Contract |
| **Enables** | Implementation stories for `InputManager`, `WardrobeUI`, `DragDressUp`, `DialogueUI`, `MainMenuGoodnightUI`, `DailyScene` fallback controls, Web input smoke tests, and UI focus/accessibility validation. |
| **Blocks** | Stories that implement registered gesture regions, wardrobe drag/click interaction, drag-vs-scroll arbitration, UI dual-focus visuals, hidden/disabled focus path cleanup, and Web canvas touch/default-behavior validation. |
| **Ordering Note** | ADR-0001 and ADR-0004 should be accepted before this ADR is accepted. This ADR should be accepted before UI/Input stories rely on `InputManager` routing or Godot 4.6 focus semantics. |

## Context

### Problem Statement

The GDDs define mouse and touch as the MVP input methods, with wardrobe drag-and-drop as the most sensitive interaction. The project needs a unified way to recognize gameplay gestures without stealing ordinary Godot GUI behavior from buttons, scroll containers, dialogue controls, or menu controls.

Godot's input order means a global `_input()` handler can see events before GUI controls process them. If `InputManager` interprets every press as a gameplay click or drag candidate, the same action can trigger both a Godot `Button.pressed` path and an `InputManager.clicked` path. Scrollable wardrobe lists can also fight with drag gestures on touch devices. In Godot 4.6, this is further complicated by the dual-focus system: mouse/touch focus and keyboard/gamepad focus are separate and can be visible on different Controls at the same time.

The decision needed now is the ownership boundary between `InputManager`, standard Godot GUI Controls, and UI systems that translate player gestures into gameplay intents.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- Target platform is Web.
- MVP input methods are mouse and touch; gamepad is not supported for MVP, but keyboard/gamepad focus behavior still exists in Godot UI and must not be broken.
- `InputManager` is a Foundation Autoload registered after `TextureCache` and before `ProgressManager` per ADR-0001.
- `GameState` checks `InputManager.is_ready` during BOOT before entering interactive wardrobe flow.
- `InputManager` must not know wardrobe item identity, progression state, Control node references, resources, or clothing data.
- Standard Godot GUI Controls must remain usable without routing every interaction through `InputManager`.
- Web browser default behaviors require validation outside Godot's event propagation model.

### Requirements

- Must normalize mouse and touch into common gameplay gesture semantics for registered game gesture regions.
- Must keep normal buttons, dialogue controls, and scroll containers on Godot's native GUI path unless a UI explicitly registers a gameplay gesture region.
- Must define the ownership boundary for `region_id -> item_id`.
- Must prevent the same UI action from firing both Godot `Button.pressed` and `InputManager.clicked` for the same business action.
- Must arbitrate touch scroll versus drag before entering active drag.
- Must define when `Viewport.set_input_as_handled()` is used and what it does not guarantee.
- Must define how Godot 4.6 hover, pressed, and keyboard/gamepad focus states are represented and tested.
- Must keep high-frequency input processing within the input-management GDD performance budgets.

## Decision

The project will use a registered gesture region plus active gesture ownership model.

`InputManager` owns only normalized gameplay gesture streams that begin inside explicitly registered gesture regions. UI owners register these regions after layout is known, using root viewport coordinates. If a press/touch start does not hit a registered gameplay gesture region, `InputManager` emits no gameplay signal and leaves the event to Godot GUI systems.

Standard `Button`, `ScrollContainer`, `OptionButton`, dialogue advancement controls, main menu buttons, goodnight buttons, and ordinary UI confirmation controls use Godot native `Control.gui_input()`, `pressed`, focus, and scroll behavior. They must not also bind `InputManager.clicked` for the same business action.

`WardrobeUI` owns `region_id -> item_id` mapping. `InputManager` emits `region_id`, `owner_id`, source, position, offset, and interruption data, but never emits `item_id`, `Node`, `Control`, `Resource`, wardrobe dictionaries, or clothing references.

`InputManager` calls `mark_input_handled()` only after it has accepted ownership of an active drag stream. `mark_input_handled()` wraps `get_viewport().set_input_as_handled()` for test spying and Godot event propagation control. This does not guarantee browser-level default behavior suppression; the Web shell or exported HTML/CSS must separately validate canvas behavior such as page scrolling, text selection, context menu, and pinch zoom.

### Gesture Ownership Model

Input ownership has four levels:

| Level | Owner | Examples | Rule |
|-------|-------|----------|------|
| Standard GUI | Godot Control owner | Main menu buttons, dialogue continue, cancel confirmation, standard scroll areas | Uses native `Control` / `Button` / `ScrollContainer`; no `InputManager.clicked` business binding. |
| Registered gameplay gesture | InputManager + registering UI | Wardrobe cards, character drop/application area, future gameplay swipe regions | UI registers explicit regions; `InputManager` emits normalized gesture data. |
| Gameplay identity mapping | Registering UI | `WardrobeUI` maps `wardrobe_card:top_a` to `top_a` | UI resolves identity from `region_id`; input layer remains identity-free. |
| Gameplay result authority | Feature/Core system | `DragDressUp`, `SpriteLayeredRenderer`, `GameState` | Gesture consumers emit intents; domain owners confirm results. |

### Registered Region Contract

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
func set_mouse_drag_threshold(px: float) -> void
func set_touch_drag_threshold(px: float) -> void
func set_click_timeout(seconds: float) -> void
```

Required region option keys are:

| Key | Type | Rule |
|-----|------|------|
| `owner_id` | `StringName` | Required. Used for cleanup and signal routing. |
| `gesture_kind` | `String` | One of `"drag_click"`, `"click_only"`, `"hover_only"`, `"exclude"`, `"scroll_priority"`. |
| `drag_axis` | `String` | One of `"any"`, `"horizontal"`, `"vertical"`. |
| `scroll_axis` | `String` | One of `"none"`, `"horizontal"`, `"vertical"`. |
| `allow_click` | `bool` | Enables click emission within threshold and timeout. |
| `allow_drag` | `bool` | Enables drag ownership after threshold and arbitration pass. |
| `allow_hover` | `bool` | Enables desktop hover emission. |

Unknown options are ignored with debug warnings. Type errors fall back to defaults and log warnings in debug builds.

### Gesture Data Contract

Gesture dictionaries must use root viewport coordinates and may contain only:

| Key | Type | Notes |
|-----|------|-------|
| `position` | `Vector2` | Current root viewport position. |
| `start_position` | `Vector2` | Press/touch start position. |
| `offset` | `Vector2` | `position - start_position`. |
| `total_distance` | `float` | Chord-length accumulation observed by Godot. |
| `source_type` | `String` | `"mouse"` or `"touch"`. |
| `source_index` | `int` | Mouse uses `0`; touch uses Godot touch index. |
| `source_key` | `String` | Stable stream key such as `"mouse:0"` or `"touch:2"`. |
| `region_id` | `StringName` | Registered region identity. |
| `owner_id` | `StringName` | Registering UI owner. |
| `interrupted` | `bool` | Present on `drag_ended`; false for normal release. |
| `cancel_reason` | `String` | Present on interrupted drag endings. |

Gesture dictionaries must not contain `item_id`, `Node`, `Control`, `Resource`, texture references, wardrobe item dictionaries, or other gameplay object references.

`get_current_drag()` returns a top-level copy. Callers mutating the returned dictionary must not mutate `InputManager` internal state.

### Drag, Click, and Scroll Arbitration

`InputManager` supports one active source at a time for MVP. A second mouse/touch source while another source is active is ignored until the active source ends.

Mouse uses `mouse_drag_threshold = 5.0` design-resolution px. Touch uses `touch_drag_threshold = 12.0` design-resolution px. Click timeout defaults to `0.5` seconds. The exact tuning ranges remain owned by `input-management.md`.

Touch starts in scrollable regions must be arbitrated before active drag:

1. If the start point is not in a registered gameplay gesture region, ignore it and leave it to Godot GUI.
2. If the start point is in a `scroll_priority` or scroll-arbitrated region, inspect early movement direction.
3. If movement clearly follows the declared scroll axis, release the stream to `ScrollContainer` and do not later promote that same stream to drag.
4. If movement passes drag threshold and drag intent wins arbitration, enter active drag and call `mark_input_handled()` for the current and following active drag events.

Once active drag begins, release, cancellation, window blur, scene exit, and layout rebuild must end or cancel the active gesture exactly once.

### Godot GUI Boundary

Standard GUI is the default. A UI element must not execute one business action from both:

- Godot `Button.pressed`, `Control.gui_input()`, or equivalent native Control path
- `InputManager.clicked`

Allowed examples:

- Wardrobe category tabs use Godot native button/Control behavior.
- Wardrobe cards register gameplay regions for drag/click because they need cross-node gesture semantics.
- Dialogue UI advancement uses native GUI confirmation and optional input actions, not `InputManager.clicked`.
- Main Menu / Goodnight buttons use Godot `Button.pressed`.
- Scroll containers own normal scrolling unless a registered card drag wins arbitration.

### Godot 4.6 Focus Model

UI systems must model these states separately:

| State | Meaning | Notes |
|-------|---------|-------|
| `hover` | Mouse pointer is over a Control or registered hover region. | Touch devices may never produce this state. |
| `pressed` | Pointer/touch/confirm is actively pressing a Control. | Must be temporary and source-specific. |
| `selected` | UI-level selection state, such as a chosen wardrobe card. | Owned by the UI system, not by Godot focus. |
| `keyboard_focus` | Keyboard/gamepad focus held by a Control. | `grab_focus()` affects this path, not mouse hover. |
| `disabled` | Control or region is not interactive. | Must not accept click, drag, or keyboard confirm. |
| `hidden` | Control is not visible/usable. | Must be removed from focus paths. |

Mouse hover and keyboard/gamepad focus may exist on different Controls at the same time. UI themes and custom drawing must avoid one state overwriting the other. Hidden or disabled Controls must not remain reachable via keyboard/gamepad focus neighbors.

Although MVP does not support gamepad as an input method, Godot's keyboard/gamepad focus system still affects Control behavior and must be validated for UI consistency and future accessibility.

### Web Canvas Default Behavior

Godot-level input handling and browser-level DOM behavior are separate.

`InputManager.mark_input_handled()` means:

- active drag events should not continue into unrelated Godot `_unhandled_input()` paths
- tests can spy how often active drag ownership handled Godot propagation

It does not mean:

- browser page scroll is suppressed
- canvas text selection is suppressed
- context menu is suppressed
- pinch zoom is suppressed
- mobile browser gestures are fully controlled

Web export validation must check the exported shell or host page for canvas behavior, including appropriate CSS/HTML policy such as touch behavior, text selection, and context menu handling.

### Architecture Diagram

```text
Raw Godot InputEvent
  -> InputManager
       if no registered gesture hit:
          emit nothing; leave to Godot GUI
       if registered scroll-priority area:
          arbitrate scroll vs drag
       if registered drag/click/hover area:
          emit identity-free gesture data

Godot Control path
  -> Button / ScrollContainer / dialogue controls / menu controls
       own ordinary UI input

WardrobeUI
  -> registers wardrobe card gesture regions
  -> maps region_id to item_id
  -> emits item_selected_for_equip(item_id)
  -> emits item_drag_dropped(item_id, position)

DragDressUp / downstream systems
  -> validate apply intent
  -> return outfit_apply_result(...)
```

### Key Interfaces

```gdscript
# InputManager
signal drag_started(data: Dictionary)
signal drag_updated(data: Dictionary)
signal drag_ended(data: Dictionary)
signal clicked(data: Dictionary)
signal hovered(data: Dictionary)
signal unhovered(data: Dictionary)

var is_ready: bool
var load_error: String

func register_gesture_region(id: StringName, rect: Rect2, options: Dictionary) -> void
func unregister_gesture_region(id: StringName) -> void
func clear_gesture_regions(owner_id: StringName) -> void
func cancel_active_gesture(reason: String) -> void
func is_dragging() -> bool
func get_current_drag() -> Dictionary
func mark_input_handled() -> void
```

```gdscript
# WardrobeUI ownership boundary
var region_to_item_id: Dictionary[StringName, String]

func _on_input_drag_started(data: Dictionary) -> void
func _on_input_drag_updated(data: Dictionary) -> void
func _on_input_drag_ended(data: Dictionary) -> void
func _on_input_clicked(data: Dictionary) -> void

signal item_selected_for_equip(item_id: String)
signal item_drag_dropped(item_id: String, position: Vector2)
```

Implementation rules:

- `InputManager` emits gesture data only for registered gameplay regions.
- `WardrobeUI` resolves `item_id` from `region_id`.
- Invalid or stale `region_id` values are ignored; UI must not guess identity from coordinates.
- `InputManager` never writes `GameState.context`, save data, progress state, outfit state, or renderer state.
- `InputManager` does not call `GameState.request_transition()`.
- `cancel_active_gesture(reason)` is required during scene exit, layout rebuild, viewport resize, window blur, and touch cancellation.

## Alternatives Considered

### Alternative 1: Registered Gesture Regions + Native GUI Separation

- **Description**: `InputManager` owns only explicitly registered gameplay gesture regions. Standard Godot GUI remains native. UI owners map region identities to gameplay identities.
- **Pros**: Prevents double-triggered actions, keeps input layer identity-free, supports wardrobe drag/click, preserves `ScrollContainer`, and matches the GDDs.
- **Cons**: Requires UI owners to maintain region registration and cleanup carefully after layout rebuilds.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: Global InputManager Capture

- **Description**: `InputManager` interprets all press/touch events globally and routes them to UI or gameplay.
- **Pros**: Centralizes all input logic and could make cross-screen gestures uniform.
- **Cons**: Conflicts with Godot GUI propagation, risks Button/click double triggers, makes scroll arbitration fragile, and tempts `InputManager` to know UI/control/gameplay identity.
- **Rejection Reason**: Rejected because ordinary UI should remain native and gameplay gestures must be explicit.

### Alternative 3: Pure Godot Native GUI Without InputManager

- **Description**: Each UI Control handles its own mouse/touch/drag logic using native Godot callbacks.
- **Pros**: Simple for buttons and avoids a global Autoload for input.
- **Cons**: Duplicates drag thresholds, touch cancellation, Web handling, active-source rules, and drag-vs-scroll arbitration across UI classes.
- **Rejection Reason**: Rejected because wardrobe drag needs a single tested mouse/touch normalization layer.

### Alternative 4: Event Bus for All UI Input

- **Description**: All UI input is converted to events on a shared bus, then consumed by UI and gameplay systems.
- **Pros**: Decouples producers and consumers and may scale for complex UI analytics or remapping.
- **Cons**: Adds infrastructure before MVP needs it, obscures ownership, and risks unordered or duplicate UI reactions.
- **Rejection Reason**: Rejected for MVP. Future presentation-to-gameplay communication ADR may define broader event routing, but this ADR keeps input ownership local and explicit.

## Consequences

### Positive

- Standard UI controls remain idiomatic Godot Controls.
- Wardrobe drag/click uses a single tested mouse/touch normalization path.
- Input layer cannot accidentally own wardrobe identity or gameplay state.
- Scroll containers and drag regions have a documented arbitration boundary.
- Godot 4.6 dual-focus behavior is explicit in implementation and tests.
- Web DOM behavior validation is not falsely assumed from Godot event handling.

### Negative

- Every registered UI owner must keep region rectangles in sync with layout changes.
- UI code must maintain cleanup discipline on scene exit, resize, and list rebuild.
- Focus styling is more complex because hover and keyboard focus are separate states.
- Web behavior requires export-template or host-page tests in addition to Godot tests.

### Risks

- **Risk**: A UI forgets to unregister stale regions after layout rebuild.  
  **Mitigation**: UI stories must call `clear_gesture_regions(owner_id)` during rebuild and ignore stale `region_id` values.
- **Risk**: A card click also triggers a Godot button path.  
  **Mitigation**: Same business action must not bind both native `pressed` and `InputManager.clicked`; static review and UI tests enforce this.
- **Risk**: Touch scrolling feels like accidental drag.  
  **Mitigation**: Scroll-priority regions and axis arbitration release early scroll intent to `ScrollContainer`.
- **Risk**: Browser page scroll or pinch zoom interrupts wardrobe drag.  
  **Mitigation**: Web export smoke tests validate canvas DOM behavior separately from `set_input_as_handled()`.
- **Risk**: Keyboard focus visual overwrites mouse hover visual.  
  **Mitigation**: UI themes must support independent state composition, and tests must place hover and keyboard focus on different Controls.
- **Risk**: High-frequency `drag_updated` processing exceeds budget.  
  **Mitigation**: `InputManager` remains O(1), does no data lookup/resource work, and consumers may coalesce visual updates per frame.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `input-management.md` | InputManager normalizes mouse/touch into click, drag, and hover for explicit game gesture regions only. | Defines registered region ownership and native GUI separation. |
| `input-management.md` | Standard Button, ScrollContainer, dialogue options, and main menu buttons continue to use Godot native GUI paths. | Forbids binding the same business action to both native GUI and `InputManager.clicked`. |
| `input-management.md` | Drag/click/scroll arbitration uses thresholds, active source, and `mark_input_handled()` only after active drag ownership. | Defines drag ownership, scroll-priority release, and handled-call meaning. |
| `input-management.md` | Gesture dictionaries do not include `item_id`, Control, Node, Resource, or clothing references. | Defines an identity-free gesture data contract. |
| `input-management.md` | Web DOM default behavior must be handled by Web shell/export template validation. | Separates Godot event propagation from browser default behavior. |
| `wardrobe-ui.md` | Wardrobe UI registers card regions and owns `region_id -> item_id`. | Makes `WardrobeUI` the gameplay identity mapper. |
| `wardrobe-ui.md` | Stale regions after card rebuild or category switch must be ignored. | Requires cleanup and no coordinate-based guessing. |
| `wardrobe-ui.md` | Godot 4.6 hover and keyboard focus must be visually distinct. | Defines separate `hover`, `pressed`, `selected`, and `keyboard_focus` states. |
| `drag-dress-up.md` | DragDressUp consumes wardrobe UI intents, not raw input. | Keeps raw input in `InputManager`, identity in `WardrobeUI`, and apply authority in `DragDressUp`. |
| `drag-dress-up.md` | UI controls overlapping character hotzone have priority over accidental outfit application. | Keeps standard GUI/control ownership ahead of gameplay drop application. |
| `dialogue-ui.md` | Dialogue UI handles confirmation input without owning progression or direct state transition. | Keeps dialogue controls on native UI paths and outside `InputManager` gameplay gestures. |
| `main-menu-goodnight-ui.md` | Main menu and goodnight buttons request GameState transitions and must distinguish hover/focus. | Keeps buttons native and requires dual-focus testing. |
| `daily-scene.md` | Fallback controls must not compete with dialogue UI and must distinguish hover/focus. | Requires hidden/disabled focus cleanup and independent Control states. |

## Performance Implications

- **CPU**: `InputManager` region hit checks and active gesture updates must remain O(1) or bounded by registered-region counts acceptable for the current UI. Single-event processing target remains p95 < 0.5ms in Godot 4.6 Web release export.
- **Memory**: Gesture dictionaries are small transient payloads. They must not hold node/resource references that extend lifetimes.
- **Load Time**: No direct load-time cost beyond `InputManager` Autoload readiness and empty registry initialization.
- **Network**: Not applicable.

High-frequency `drag_updated` consumers should avoid texture loading, file I/O, node-tree searches, or expensive layout rebuilds per event. If rendering cost becomes visible, UI consumers should cache latest drag state and update visuals once per frame.

## Migration Plan

This ADR is written before implementation. Implementation stories should:

1. Implement `InputManager` as a Godot Autoload with `is_ready` and `load_error`.
2. Implement registered region storage and cleanup by `owner_id`.
3. Implement mouse/touch source keys and one active source for MVP.
4. Implement drag/click thresholds, click timeout, touch cancel, window blur, scene exit, and layout-change cancellation.
5. Implement scroll-priority arbitration before active drag ownership.
6. Implement `mark_input_handled()` wrapper and tests for active drag handled calls.
7. Implement identity-free gesture dictionaries in root viewport coordinates.
8. Update `WardrobeUI` to register card regions and own `region_id -> item_id`.
9. Keep standard buttons, dialogue controls, and menu controls on native Godot GUI paths.
10. Add UI focus tests for separated hover, pressed, selected, and keyboard focus states.
11. Add Web export smoke tests for canvas scroll/text/context/pinch behavior.

## Validation Criteria

- Unit tests confirm unregistered press/touch streams emit no `clicked` or `drag_*` signals.
- Unit tests confirm registered click regions emit one `clicked` inside threshold and timeout.
- Unit tests confirm mouse and touch drag thresholds differ and exact-threshold movement does not start drag.
- Unit tests confirm active drag emits `drag_started`, `drag_updated`, and `drag_ended` in fixed order.
- Unit tests confirm `mark_input_handled()` is called only after active drag ownership and not for unregistered or potential streams.
- Unit tests confirm gesture dictionaries contain no gameplay identity or node/resource references.
- Unit tests confirm `get_current_drag()` returns a top-level copy.
- Integration tests confirm native Godot buttons still work for main menu, goodnight, dialogue, and cancel confirmation without `InputManager.clicked`.
- Integration tests confirm a business action is not bound to both native `pressed` and `InputManager.clicked`.
- Integration tests confirm ScrollContainer vertical touch scroll does not emit wardrobe drag when scroll intent wins arbitration.
- Integration tests confirm stale `region_id` values after WardrobeUI rebuild are ignored.
- UI tests confirm hover and keyboard focus can appear on different Controls without visual overwrite.
- UI tests confirm hidden or disabled Controls cannot receive keyboard/gamepad confirm.
- Web smoke tests confirm active wardrobe drag does not cause canvas page scroll, text selection, context menu, or unintended pinch behavior in the target host/export setup.
- Performance tests confirm InputManager single-event p95 < 0.5ms and high-frequency input aggregate p95 < 1.5ms in the fixed Web release test scene.

## Related Decisions

- ADR-0001: Autoload Order and Boot Orchestration
- ADR-0004: Scene Transition and State Machine Contract
- Future ADR: Presentation-to-gameplay communication pattern
- Future ADR: UI accessibility and localization interaction conventions

## Related Documents

- `docs/architecture/architecture.md`
- `docs/registry/architecture.yaml`
- `docs/engine-reference/godot/VERSION.md`
- `docs/engine-reference/godot/modules/input.md`
- `docs/engine-reference/godot/modules/ui.md`
- `docs/engine-reference/godot/breaking-changes.md`
- `docs/engine-reference/godot/deprecated-apis.md`
- `design/gdd/input-management.md`
- `design/gdd/wardrobe-ui.md`
- `design/gdd/drag-dress-up.md`
- `design/gdd/dialogue-ui.md`
- `design/gdd/main-menu-goodnight-ui.md`
- `design/gdd/daily-scene.md`
