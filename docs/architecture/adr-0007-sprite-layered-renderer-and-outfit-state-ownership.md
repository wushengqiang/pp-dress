# ADR-0007: Sprite Layered Renderer and Outfit State Ownership

## Status
Accepted

## Date
2026-06-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / Core State |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0002-persistence-ownership-and-save-rollback-strategy.md`, `docs/architecture/adr-0003-texture-loading-cache-and-web-fallback-strategy.md`, `docs/architecture/adr-0006-presentation-to-gameplay-communication-pattern.md` |
| **Post-Cutoff APIs Used** | None. This decision uses established Godot 4.x `Node2D`, `Sprite2D`, `CanvasItem.z_index`, typed signals, and local request tokens. |
| **Verification Required** | Verify same-parent `Sprite2D` layering with `CanvasItem.z_index`, fixed category tie-break ordering, typed signal connections, local generation/token guards around synchronous and asynchronous `TextureCache` callbacks, and that `SpriteLayeredRenderer` never reads or writes `GameState.context`. |

Godot 4.6 is post-LLM-cutoff for this project. Rendering carries HIGH knowledge risk because the checked references flag post-cutoff rendering changes such as D3D12 as the Windows default, glow processing before tonemapping, AgX controls, and shader texture type changes. This ADR does not depend on those changed APIs. It constrains 2D sprite composition and state ownership only.

Deprecated APIs and patterns to avoid:

- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not use `yield()`; use `await signal` where coroutine behavior is needed.
- Do not use `$NodePath` lookups in high-frequency outfit paths; cache the six `Sprite2D` references during `_ready()`.
- Do not call `TextureCache.cancel_request()` for instance-level renderer disposal or outfit replacement.
- Do not call `ResourceLoader` directly for clothing textures from the renderer.

Engine Specialist Validation: completed in this authoring run. The Godot specialist found no blocking Godot 4.6 API issue. They confirmed that per-instance renderer ownership is idiomatic and that same-parent `Sprite2D` nodes using `CanvasItem.z_index` are appropriate. Non-blocking notes were incorporated below: `equip_item_completed(...)` is the result truth source, pending token/generation state must be registered before `TextureCache.get_texture_or_request(...)`, `get_equipped_items()` must return a copy, all clothing `Sprite2D` nodes must remain direct siblings under one parent, and signal wiring must use typed callable connections.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002: Persistence Ownership and Save Rollback Strategy; ADR-0003: Texture Loading Cache and Web Fallback Strategy; ADR-0006: Presentation to Gameplay Communication Pattern |
| **Enables** | Implementation stories for `SpriteLayeredRenderer`, WARDROBE character outfit application, Daily Scene restored/default outfit application, renderer result tests, and visual layering screenshot evidence. |
| **Blocks** | Stories that implement `Character` outfit rendering, `DragDressUp` to renderer integration, WARDROBE outfit confirmation from confirmed renderer state, Daily Scene visual readiness gating, and z-index override validation. |
| **Ordering Note** | ADR-0003 must be accepted before cold texture request integration. ADR-0006 must be accepted before UI/gameplay signal wiring relies on renderer result signals. This ADR should be accepted before implementing renderer-owned `_equipped_items` or outfit restore flows. |

## Context

### Problem Statement

The project needs a clear authority boundary for clothing that is currently visible on a character. Several systems touch the same concept from different angles:

- `WardrobeUI` shows local selected/equipped presentation state.
- `DragDressUp` translates wardrobe intent into an outfit application attempt.
- `SpriteLayeredRenderer` changes `Sprite2D.texture` and `Sprite2D.z_index` after texture loading completes.
- `GameState.context["equipped_items"]` carries a scene transition and recovery snapshot.
- `SaveManager` persists confirmed outfit recovery data.

Without an ADR, implementation could easily let UI state become the source of truth, let the renderer read `GameState.context` during `_ready()`, write `z_index` before texture success, or allow stale asynchronous texture callbacks to overwrite newer outfits. The result would be half-applied outfits, inconsistent WARDROBE cards, or Daily Scene entering before the actual visual outfit is settled.

This decision is needed before implementing `SpriteLayeredRenderer` and before wiring WARDROBE / Daily Scene flows to restored outfit data.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- MVP character rendering uses six direct-child `Sprite2D` nodes under one `Node2D` character root.
- `WardrobeDatabase` owns item metadata, category definitions, and z-index calculation.
- `TextureCache` owns clothing texture loading, caching, pending request fan-out, and shared cancellation semantics.
- `GameState` owns scene flow and context writes; `SpriteLayeredRenderer` must not interpret global scene context.
- `SaveManager` stores confirmed outfit recovery data but does not decide whether a renderer has visually applied it.
- `WardrobeUI` cannot update authoritative-looking equipped display state until gameplay returns a confirmed result.
- GDScript cannot strongly enforce private state, so ownership must be protected through public APIs, naming, tests, and code review.

### Requirements

- Must define which system owns runtime per-character outfit state.
- Must define how outfit state becomes visible and observable.
- Must support synchronous HOT/WARM texture callbacks and asynchronous COLD callbacks from `TextureCache`.
- Must prevent stale callbacks from modifying current visuals or emitting stale completion signals.
- Must keep texture assignment, `z_index`, and `_equipped_items` changes atomic on success.
- Must keep old texture, old `z_index`, and old `_equipped_items` on texture failure.
- Must distinguish explicit empty outfit `[]` from missing/null restore context.
- Must let WARDROBE confirmation persist only confirmed renderer state.
- Must let Daily Scene wait for visual settlement through `outfit_applied(...)`.

## Decision

The project will make `SpriteLayeredRenderer` the authoritative runtime owner of per-instance outfit visual state.

This ownership is local to one `Character` instance. It does not make the renderer a global outfit authority and it does not make `_equipped_items` persistent data. It means that, for one live character scene instance, the renderer is the only system allowed to decide which item is actually visible in each render slot after texture loading and layer assignment have succeeded.

`SpriteLayeredRenderer` owns:

- `_equipped_items: Dictionary[String, String]` mapping category to currently visible item id.
- `_pending_target_by_category` for in-flight requests.
- `_request_generation` for stale single-request rejection.
- `_active_batch_token` for stale batch rejection.
- `_is_disposed` for exit-tree callback rejection.
- The six cached `Sprite2D` references and their assigned `texture` / `z_index` values.

All six clothing `Sprite2D` nodes must remain direct siblings under the same `Node2D` parent. Their `z_index` values provide the primary draw order; when two effective z values match, the fixed category order and matching node tree order provide the deterministic tie-break.

`SpriteLayeredRenderer` must not own:

- `GameState.context` or its `equipped_items` value.
- `SaveData.equipped_items`.
- Wardrobe card selected/equipped presentation state.
- Item metadata, category definitions, unlock rules, or texture cache lifecycle.
- Scene transitions into or out of WARDROBE / DAILY_SCENE.

### Runtime State Contract

The renderer initializes to an explicit empty visual outfit: six direct-child `Sprite2D` nodes use `EMPTY_SLOT_FULL`, category default `z_index`, and `_equipped_items` is empty.

Every public mutation path must preserve the same state contract:

- `equip_item(item_id)` attempts one category change.
- `apply_outfit(item_ids)` applies a normalized full target outfit and unequips categories not present in the final target set.
- `unequip_category(category)` clears one category.
- `clear_outfit()` clears all categories.
- `equip_default_outfit(day)` resolves default ids through `WardrobeDatabase` and then delegates to `apply_outfit(...)`.

A successful item application commits these three changes in the same callback turn:

1. `sprite.texture = texture`
2. `sprite.z_index = effective_z`
3. `_equipped_items[category] = item_id`

The renderer then emits `outfit_changed(category, old_item_id, item_id)` and the relevant completion signal.

Texture failure, invalid item data, stale generation, stale batch token, disposal, or shared `TextureCache` cancellation must not partially apply new state. In those cases the renderer keeps the old texture, old `z_index`, and old `_equipped_items` for that category unless the active API call explicitly unequipped the category as part of the current valid request.

### GameState and Persistence Boundary

`GameState.context["equipped_items"]` is a scene-flow restore snapshot, not the renderer's source of truth.

Rules:

- `SpriteLayeredRenderer._ready()` must not read `GameState.context`.
- `SpriteLayeredRenderer` must not write `GameState.context`.
- Parent scenes decide whether to call `apply_outfit(...)`, `equip_default_outfit(day)`, or `clear_outfit()` after `renderer_ready`.
- Missing or null `GameState.context["equipped_items"]` means no saved restore context; the parent scene chooses a default or current-scene fallback.
- `GameState.context["equipped_items"] == []` means an explicit empty outfit; the parent scene must call `apply_outfit([])` if that empty outfit is the intended restore target.
- Non-empty context arrays must be validated as `Array[String]` by the caller before being passed to `apply_outfit(...)`.

WARDROBE confirmation persists only confirmed renderer state. The confirming flow reads `SpriteLayeredRenderer.get_equipped_items()`, writes that snapshot through the approved `GameState` / `SaveManager` flow from ADR-0002, and then requests the scene transition. UI-local equipped caches are not valid persistence sources.

### TextureCache Boundary

The renderer consumes `TextureCache.get_texture_or_request(item_id, FULL, callback)` for clothing FULL textures.

Because ADR-0003 allows HOT/WARM hits to invoke callbacks synchronously, the renderer must create all local pending state, generation values, and batch records before calling `get_texture_or_request(...)`. Register first, then call the cache. Reversing that order is a race condition.

The renderer must not use `TextureCache.cancel_request(...)` for instance-level cancellation. Instance disposal, outfit replacement, batch replacement, or scene exit must invalidate local generation/token state and ignore late callbacks. Shared texture-level cancellation remains a `TextureCache` concern.

### Result Signal Boundary

Renderer signals expose visual and runtime outfit results to gameplay/domain collaborators:

- `renderer_ready` means dependencies, six sprite nodes, empty texture, and base layer configuration are ready. It does not mean an outfit has been applied.
- `outfit_changed(category, old_item_id, new_item_id)` means one category's visible texture/layer state changed successfully.
- `equip_item_completed(item_id, category, status, equipped_items)` means one equip request has reached a current, observable result.
- `outfit_applied(applied_item_ids)` means the current active batch settled and the payload is `get_equipped_items()` after settlement.

`equip_item_completed(...)` is the single-item result truth source for `DragDressUp`. `outfit_changed(...)` is only a visual/audio feedback hook and must not replace result handling. ADR-0006 remains authoritative: `DragDressUp` maps renderer results into `outfit_apply_result(item_id, accepted, equipped_items, reason)` for `WardrobeUI`.

### Architecture Diagram

```text
WardrobeDatabase
  owns item/category/z-index data
       |
       v
TextureCache  <------------------------+
  owns texture loading/cache/pending     |
       | callback(texture or null)       |
       v                                |
SpriteLayeredRenderer                    |
  owns per-instance visual outfit state  |
  _equipped_items + Sprite2D texture/z   |
       | renderer signals               |
       v                                |
DragDressUp                              |
  maps intent to renderer attempt        |
  emits outfit_apply_result              |
       |                                |
       v                                |
WardrobeUI                               |
  owns selected/equipped presentation    |

WARDROBE confirm flow:
SpriteLayeredRenderer.get_equipped_items()
  -> GameState.context restore snapshot
  -> SaveManager.set_equipped_items(...)
  -> GameState.request_transition(DAILY_SCENE, context)

DAILY_SCENE restore flow:
GameState.context snapshot
  -> parent scene validates/interprets
  -> SpriteLayeredRenderer.apply_outfit(...)
  -> wait for outfit_applied(...)
```

### Key Interfaces

```gdscript
signal renderer_ready()
signal outfit_changed(category: String, old_item_id: Variant, new_item_id: Variant)
signal equip_item_completed(
    item_id: String,
    category: Variant,
    status: String,
    equipped_items: Array[String]
)
signal outfit_applied(applied_item_ids: Array[String])

var is_ready: bool

func equip_item(item_id: String) -> void
func apply_outfit(item_ids: Array[String]) -> void
func unequip_category(category: String) -> void
func clear_outfit() -> void
func equip_default_outfit(day: int) -> void
func get_equipped_items() -> Array[String]
func get_equipped_item_for_category(category: String) -> Variant
```

Implementation rules:

- `category` and item ids use `String`; nullable payload positions use `Variant` because GDScript typed signals do not express `String | null` as a concrete type.
- `status` must be one of the GDD-defined strings: `"equipped"`, `"same_item"`, `"invalid_item"`, `"invalid_category"`, `"texture_failed"`, `"renderer_not_ready"`, or `"cancelled_stale"`.
- `get_equipped_items()` returns a new `Array[String]` copy ordered by current effective `z_index` from bottom to top, with fixed category order as same-z tie-break. Callers must never receive a mutable reference to renderer-owned internal state.
- Public mutation APIs must be idempotent and must settle with an explicit result rather than leaving callers to rely on timeout.
- The renderer may log warnings/errors for invalid use, but caller-visible completion signals remain the integration contract.
- Signal wiring must use Godot 4 typed callable connection style, for example `renderer.equip_item_completed.connect(_on_equip_item_completed)`, not string-based `connect(...)`.

## Alternatives Considered

### Alternative 1: Renderer Owns Per-Instance Visual Outfit State

- **Description**: `SpriteLayeredRenderer` owns local `_equipped_items`, pending request tokens, and the actual `Sprite2D` visual state. Other systems call public APIs and observe result signals.
- **Pros**: Keeps visual truth adjacent to texture/z-index assignment; handles async texture callbacks locally; supports multiple character instances; avoids global state reads during `_ready()`; aligns with ADR-0003 and ADR-0006.
- **Cons**: Requires careful token/generation implementation and tests because GDScript cannot enforce private state strongly.
- **Rejection Reason**: Accepted.

### Alternative 2: GameState Owns Active Outfit and Renderer Mirrors It

- **Description**: `GameState.context["equipped_items"]` or a similar GameState field would be the active outfit source. The renderer would read it during `_ready()` or subscribe to it.
- **Pros**: Provides a single global place to inspect current outfit across scene transitions.
- **Cons**: Mixes persistent/restore snapshot with live visual state; makes multiple Character instances ambiguous; duplicates scene restore interpretation; risks renderer applying context before dependencies are ready.
- **Rejection Reason**: Rejected because ADR-0002 makes GameState the scene-flow coordinator, not the per-instance renderer authority. Context is a snapshot handed to a parent scene, not a renderer-owned control channel.

### Alternative 3: WardrobeUI Owns Equipped State and Pushes It Into Renderer

- **Description**: Wardrobe UI would update its equipped state when the player acts and then push that state into the renderer and persistence flow.
- **Pros**: Simple to implement for happy-path wardrobe interaction; UI already needs an equipped display cache.
- **Cons**: Conflicts with ADR-0006; lets presentation assume success before renderer texture loading is confirmed; makes texture failures and stale callbacks visible as rollbacks.
- **Rejection Reason**: Rejected because UI state is presentation only. Confirmed gameplay/visual results must come back through `outfit_apply_result(...)`.

### Alternative 4: SaveManager SaveData Owns Current Outfit During Play

- **Description**: Runtime code would treat `SaveData.equipped_items` as the current outfit state and update it during each outfit change.
- **Pros**: Browser refresh recovery would always have the latest attempted outfit.
- **Cons**: Turns persistence into gameplay state authority, increases save frequency, makes texture failure rollback interact with storage, and conflicts with ADR-0002's persistence-pipe boundary.
- **Rejection Reason**: Rejected because persistence stores confirmed recovery snapshots, not every pending visual attempt.

## Consequences

### Positive

- The currently visible outfit has one owner per character instance.
- Texture failure cannot create "new layer order with old texture" or "new item id with failed texture" half-state.
- WARDROBE and Daily Scene can wait on explicit renderer signals instead of guessing with timeouts.
- UI remains responsive and expressive without becoming gameplay authority.
- Multiple `Character` instances can exist without fighting over a global equipped state.
- Restored outfits and explicit empty outfits have deterministic semantics.

### Negative

- Renderer implementation must maintain local generation/token state carefully.
- Integration tests must cover stale callbacks and same-frame HOT/WARM callbacks, not only successful cold loads.
- Parent scenes carry the responsibility to interpret `GameState.context` correctly before calling renderer APIs.
- `get_equipped_items()` ordering depends on current effective `z_index`, so tests must include override items and tie-breaks.

### Risks

- **Risk**: A synchronous HOT/WARM callback fires before pending state is registered.  
  **Mitigation**: Require pending records and generation/token values to be created before every `TextureCache.get_texture_or_request(...)` call; add a HOT cache test.

- **Risk**: A stale callback from an older outfit request overwrites a newer visible outfit.  
  **Mitigation**: Check `_is_disposed`, tree validity, request generation, pending category target, and active batch token before committing.

- **Risk**: UI or scene code reads `_equipped_items` directly instead of using public result APIs.  
  **Mitigation**: Prefix internal fields with `_`, expose `get_equipped_items()` as a copy-returning API, register forbidden direct renderer state reads, and include static review evidence.

- **Risk**: Parent scenes confuse missing/null context with explicit empty outfit.  
  **Mitigation**: Keep context interpretation in scene/flow code and test missing, null, empty array, and non-empty restore cases.

- **Risk**: `z_index_override` visually collides with content combinations even when numeric ordering is correct.  
  **Mitigation**: Require screenshot matrix evidence for override items before content acceptance.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `sprite-layered-rendering.md` | Renderer owns `_equipped_items`, pending targets, generation/token state, and emits `renderer_ready`, `equip_item_completed`, `outfit_changed`, and `outfit_applied`. | Defines renderer as the per-instance runtime visual outfit owner and locks public API/signal semantics. |
| `sprite-layered-rendering.md` | Successful texture load atomically commits `texture`, `z_index`, and `_equipped_items`; failure preserves old state. | Makes atomic visual-state commit the core decision and requires failure paths to avoid partial mutation. |
| `sprite-layered-rendering.md` | Renderer does not read `GameState.context`; parent scenes call `apply_outfit(...)` / default / clear explicitly. | Separates scene restore snapshots from renderer state authority. |
| `sprite-layered-rendering.md` | `apply_outfit([])`, all-invalid inputs, and normalized-empty targets settle and emit `outfit_applied([])`. | Requires public mutation APIs to settle with explicit results rather than leaving callers to timeout. |
| `drag-dress-up.md` | Drag Dress-Up waits for `equip_item_completed(...)` and maps renderer result to `outfit_apply_result(...)`. | Keeps `DragDressUp` as the gameplay/domain adapter between UI intent and renderer result. |
| `wardrobe-ui.md` | Wardrobe UI updates equipped state only after `outfit_apply_result(...)`; `[]` is a valid explicit empty outfit on confirmation. | Prevents UI optimistic authority and ties persistence to confirmed renderer state. |
| `wardrobe-database.md` | `get_z_index(item)` resolves category default or override and renderer must keep all clothing sprites under the same parent for z ordering. | Keeps z-index calculation in `WardrobeDatabase` and requires renderer to apply effective z-index only on successful texture commit. |
| `save-load.md` | GameState writes `equipped_items` and `scene_in_progress` for flow recovery; SaveManager persists confirmed outfit recovery data. | Defines renderer output as the source used by the confirming flow, while persistence remains a snapshot boundary. |
| `scene-state-management.md` | Daily Scene and WARDROBE scene flow use GameState context but scene systems own readiness/application details. | Makes parent scenes responsible for interpreting context and waiting for `outfit_applied(...)` before treating visuals as ready. |

## Performance Implications

- **CPU**: Hot-cache single item application should remain same-frame or under 16ms including texture assignment and signal dispatch. Batch bookkeeping is O(number of MVP categories), fixed at six categories.
- **Memory**: Renderer holds six `Sprite2D` texture references plus local dictionaries/tokens. Texture memory is owned and budgeted by `TextureCache`, not duplicated by this ADR.
- **Load Time**: Renderer does not add startup loading beyond validating six sprite nodes and empty slot texture. Cold outfit load time is governed by `TextureCache` and scene preload strategy.
- **Network**: None directly. Web texture fetch/loading behavior remains under ADR-0003 and export-host validation.

## Migration Plan

1. Implement `character.tscn` with one `Node2D` root and six direct-child `Sprite2D` nodes in fixed category order.
2. Implement `sprite_layered_renderer.gd` with cached sprite references, readiness checks, and `renderer_ready`.
3. Implement empty-slot initialization and category default `z_index` assignment from `WardrobeDatabase`.
4. Implement `equip_item(...)` with generation registration before `TextureCache.get_texture_or_request(...)`.
5. Implement `apply_outfit(...)` with category normalization, active batch token, per-target settlement, and stale batch discard.
6. Implement `unequip_category(...)`, `clear_outfit()`, and `equip_default_outfit(day)` as wrappers that preserve the same settlement semantics.
7. Wire `DragDressUp` to renderer public APIs and result signals.
8. Wire WARDROBE confirmation to read `get_equipped_items()` and use the ADR-0002 GameState / SaveManager flow.
9. Wire Daily Scene parent logic to interpret `GameState.context["equipped_items"]` and explicitly call renderer APIs after `renderer_ready`.
10. Add tests and screenshot evidence for atomic commits, stale callbacks, empty outfit, z-index override, same-parent ordering, and multiple character instances.

## Validation Criteria

- Unit tests confirm `_ready()` does not read or write `GameState.context`.
- Unit tests confirm six `Sprite2D` nodes are direct children, use category default `z_index`, and start with `EMPTY_SLOT_FULL`.
- Unit tests confirm HOT/WARM callbacks can complete synchronously without losing pending state.
- Unit tests confirm successful `equip_item(...)` commits texture, `z_index`, and `_equipped_items` in the same callback turn.
- Unit tests confirm texture failure preserves old texture, old `z_index`, and old `_equipped_items`.
- Unit tests confirm `apply_outfit([])`, all-invalid input, and normalized-empty input emit `outfit_applied([])` without waiting for timeout.
- Unit tests confirm stale generation and stale batch callbacks cannot modify texture or emit stale `outfit_applied(...)`.
- Unit tests confirm `_exit_tree()` invalidates callbacks and does not call `TextureCache.cancel_request()`.
- Unit tests confirm `get_equipped_items()` sorts by effective `z_index` with fixed category tie-break.
- Integration tests confirm WARDROBE UI updates equipped state only from `outfit_apply_result(...)`.
- Integration tests confirm WARDROBE confirmation persists `SpriteLayeredRenderer.get_equipped_items()`, not UI-local state.
- Integration tests confirm Daily Scene waits for `outfit_applied(...)` before starting narrative entry that assumes visible outfit readiness.
- Screenshot tests confirm z-index override items render in approved order across relevant hair/top/accessory combinations.
- Static review confirms no code directly reads renderer `_equipped_items`, writes `GameState.context` from the renderer, or calls `ResourceLoader` directly for clothing textures.

## Related Decisions

- ADR-0002: Persistence Ownership and Save Rollback Strategy
- ADR-0003: Texture Loading Cache and Web Fallback Strategy
- ADR-0004: Scene Transition and State Machine Contract
- ADR-0005: Input Gesture Ownership and UI Focus Model
- ADR-0006: Presentation to Gameplay Communication Pattern
- `design/gdd/sprite-layered-rendering.md`
- `design/gdd/drag-dress-up.md`
- `design/gdd/wardrobe-ui.md`
- `design/gdd/wardrobe-database.md`
- `design/gdd/save-load.md`
