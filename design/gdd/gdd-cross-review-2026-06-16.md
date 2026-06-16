## Cross-GDD Review Report
Date: 2026-06-16
GDDs Reviewed: 15
Systems Covered: 服装数据库, 场景/状态管理, 精灵分层渲染, 保存/加载, 资源加载器, 输入管理, 进度管理, 衣橱 UI, 对话 UI, 主菜单/晚安 UI, 音频管理, 拖拽换装, 每日场景, 轻叙事对话, 服装解锁

---

### Consistency Issues

#### Blocking

None.

No cross-GDD contradiction was found that must block architecture. The shared values and event contracts reviewed are internally aligned:

- `TOTAL_DAYS = 7` remains consistent across progress, save/load, main-menu/goodnight, daily-scene, and light-narrative-dialogue.
- `new_items(day)` is consistently owned by ProgressManager and consumed by Clothing Unlock.
- `visible_categories(day)` is consistently owned by ProgressManager and consumed by Wardrobe UI.
- Audio event keys `wardrobe.outfit_applied`, `progress.items_unlocked`, `scene.daily.entered`, `scene.music.daily_generic`, `scene.music.day_{n}`, and `scene.transition_page` are registered or explicitly defined as weak/degradable event requests.
- Drag Dress-Up, Wardrobe UI, and Sprite Layered Rendering agree that renderer-confirmed `outfit_apply_result(...)` / `equip_item_completed(...)` is the source of truth for successful equipment changes.

#### Warnings

**W-01: Systems index status is stale**

`design/gdd/systems-index.md` still marks several GDDs as `Needs Revision`:

| GDD | Current systems-index status | Evidence of later approval / cleanup |
|-----|------------------------------|--------------------------------------|
| `wardrobe-database.md` | Needs Revision | `systems-index.md` Next Steps says warning-level flagged GDDs, including wardrobe-database pillar metadata, were synced. |
| `scene-state-management.md` | Needs Revision | `systems-index.md` Next Steps says scene-state Autoload prose was synced. |
| `resource-loader.md` | Needs Revision | Review log shows Resource Loader was approved after lean re-review. |
| `progress-management.md` | Needs Revision | `systems-index.md` Next Steps says progress-management item-count example was synced. |
| `wardrobe-ui.md` | Needs Revision | Wardrobe UI review log shows approved, and later Next Steps says InputManager region contract was synced. |

Impact: future `/gate-check` or `/create-architecture` may treat design as incomplete even though the review trail indicates these items were resolved. This is metadata drift, not a design-rule contradiction.

Recommendation: update `systems-index.md` statuses to match the latest review logs and cleanup history, or run `/consistency-check` to formally synchronize status metadata.

**W-02: InputManager downstream list omits Scene/State Management**

`scene-state-management.md` declares `输入管理` as a BOOT dependency:

- `scene-state-management.md`: GameState checks `InputManager.is_ready`; formal implementation must not enter interactive WARDROBE if InputManager is unavailable.

`input-management.md` declares downstream systems as Wardrobe UI, Drag Dress-Up, Dialogue UI (future), and Main Menu/Goodnight UI (future), but does not list Scene/State Management as a downstream readiness checker.

Impact: the runtime contract is already clear in Scene/State Management, but the dependency relationship is one-directional in documentation. Architecture could miss that GameState must wait for `InputManager.is_ready` even though it does not consume input signals.

Recommendation: add a downstream row in `input-management.md`: "场景/状态管理 | readiness dependency | BOOT checks `InputManager.is_ready`; does not consume input signals."

**W-03: Wardrobe confirmation save pseudocode can imply saving raw selection instead of renderer-confirmed outfit**

`sprite-layered-rendering.md` says Wardrobe/Daily Scene callers should write `GameState.context["equipped_items"]` from `sprite_layered_renderer.get_equipped_items()` after confirmation. `wardrobe-ui.md` says local `equipped_items` is overwritten only from `outfit_apply_result(..., accepted=true, equipped_items, ...)`.

`save-load.md` pseudocode currently uses:

```text
on_outfit_confirmed(raw_items):
    filtered_items = filter_items_available_for_day(raw_items, day)
    GameState.context["equipped_items"] = filtered_items
    SaveManager.set_equipped_items(filtered_items)
```

Impact: this could lead an implementer to persist requested/filtered items rather than the renderer-confirmed final outfit. That matters when an item fails to load, is rejected by renderer validation, or a pending equipment request has not resolved.

Recommendation: revise the pseudocode to obtain `confirmed_items` from the renderer-confirmed equipped state, or from Wardrobe UI state only after it was updated by `outfit_apply_result(... accepted=true ...)`.

**W-04: Resource Loader still has a P0 prototype gate before implementation**

`resource-loader.md` explicitly marks Godot 4.6 Web `ResourceLoader.load_threaded_request()` behavior and Web memory usage as a P0 validation requirement. `systems-index.md` also lists resource-loader Web threading/memory validation as a next step.

Impact: not a GDD contradiction, but it is a production-readiness constraint. Architecture can proceed if it records the risk and preserves fallback room, but implementation should not assume threaded loading and current cache limits are safe until `/prototype` verifies them.

Recommendation: keep `/prototype resource-loader` as a required pre-implementation technical gate.

---

### Game Design Issues

#### Blocking

None.

The full GDD set remains aligned with the three game pillars:

- 每日陪伴: daily scene, light narrative, save/load, main menu/goodnight, and audio all support low-pressure continuity.
- 随心搭配: wardrobe database, wardrobe UI, drag dress-up, progress, and clothing unlock avoid scoring, judging, or punitive failure states.
- 即时有感: input, sprite rendering, resource loader, drag dress-up, wardrobe UI, and audio all define immediate feedback requirements.

No system currently violates the anti-pillars:

- No scoring/ranking system was introduced.
- No deep branching narrative was introduced.
- No massive-collection pressure was introduced beyond the MVP scale.

#### Warnings

**W-05: Active attention budget is close but acceptable**

During WARDROBE play, the player actively manages:

1. Category selection
2. Item selection / drag or click application
3. Outfit confirmation/cancel
4. Occasional locked/new-item feedback

This is within the 3-4 active-system comfort range. The design remains safe because Progress, Save/Load, Resource Loader, Audio, and GameState are passive or background systems from the player's perspective.

Recommendation: keep Clothing Unlock prompts skippable and avoid adding extra live goals or scoring prompts to WARDROBE.

**W-06: Resource and progression economy is intentionally light, but final-day sink/source behavior should stay documented**

The only progression "resource" is unlocked clothing. Sources are day completion via ProgressManager; sinks are player use in Wardrobe UI. There is no currency, XP, stamina, or competitive economy.

The existing design correctly avoids `items_unlocked` on day 7 if no new day exists. Clothing Unlock AC-16 covers this.

Recommendation: no change required; preserve this in implementation tests.

---

### Cross-System Scenario Issues

Scenarios walked: 3

1. BOOT recovery into Daily Scene
2. Wardrobe equip-confirm-save flow
3. Goodnight progression and clothing unlock presentation

#### Blockers

None.

#### Warnings

**W-07: Wardrobe equip-confirm-save flow can persist the wrong outfit if implementation follows Save/Load pseudocode literally**

Systems involved: Wardrobe UI, Drag Dress-Up, Sprite Layered Rendering, GameState, SaveManager

Walkthrough:

1. Player applies an item in WARDROBE.
2. Wardrobe UI emits `item_drag_dropped(...)` or `item_selected_for_equip(...)`.
3. Drag Dress-Up calls renderer `equip_item(item_id)`.
4. Sprite Layered Rendering validates item/category/texture and emits `equip_item_completed(...)`.
5. Drag Dress-Up returns `outfit_apply_result(..., accepted, equipped_items, reason)`.
6. Wardrobe UI updates local `equipped_items` only when `accepted == true`.
7. Player clicks Confirm Outfit.
8. Save/Load pseudocode may lead implementers to save `raw_items` filtered by day, rather than the final renderer-confirmed `equipped_items`.

Failure mode: stale or rejected equipment intent can be saved if an implementation bypasses renderer-confirmed state.

Recommendation: revise `save-load.md` pseudocode and acceptance wording to say confirmation saves renderer-confirmed `equipped_items`.

#### Info

**I-01: BOOT recovery path is coherent**

Systems involved: Save/Load, ProgressManager, GameState, Daily Scene, Sprite Layered Rendering

GameState waits for SaveManager and ProgressManager, uses ProgressManager's repaired current day, filters saved `equipped_items`, then writes Daily Scene context. Empty explicit outfit is handled separately from missing outfit context. No contradiction found.

**I-02: Goodnight progression and unlock presentation ordering is coherent**

Systems involved: GameState, ProgressManager, SaveManager, Clothing Unlock, Main Menu/Goodnight UI, Audio Management

GameState clears `scene_in_progress`, ProgressManager advances and saves, then emits day/unlock signals only on save success. Clothing Unlock listens to `items_unlocked(new_items)`, ignores empty arrays, and degrades gracefully when audio or thumbnails fail. No double-unlock or day 8 issue found.

---

### GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `design/gdd/systems-index.md` | Status metadata appears stale relative to review logs and cleanup history | Consistency | Warning |
| `design/gdd/input-management.md` | Downstream dependency list omits GameState readiness check | Consistency | Warning |
| `design/gdd/save-load.md` | Wardrobe save pseudocode can imply raw selection persistence instead of renderer-confirmed outfit | Scenario / Consistency | Warning |
| `design/gdd/resource-loader.md` | P0 prototype gate remains open for Godot 4.6 Web threading and memory behavior | Production readiness | Warning |

---

### Verdict: CONCERNS

No blocking cross-GDD contradiction was found. The design is coherent enough for architecture work if the architecture explicitly records the Resource Loader P0 prototype gate and the renderer-confirmed outfit save contract.

Recommended next:

1. Apply quick documentation fixes for `input-management.md` and `save-load.md`.
2. Sync `systems-index.md` statuses with latest review logs.
3. Run `/prototype resource-loader` and `/prototype drag-dress-up` before implementation.
4. Run `/gate-check pre-production` after status sync and P0 prototype checks.
