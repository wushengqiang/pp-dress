# Cross-GDD Review Report

Date: 2026-06-11
GDDs Reviewed: 17 docs, covering 15 MVP systems
Engine Context: Godot 4.6
Context gap: `.Codex/docs/technical-preferences.md` was not present in this workspace; engine version came from `docs/engine-reference/godot/VERSION.md`.

---

## Systems Covered

- 服装数据库
- 场景/状态管理
- 精灵分层渲染
- 保存/加载
- 资源加载器
- 输入管理
- 进度管理
- 衣橱 UI
- 对话 UI
- 主菜单/晚安 UI
- 音频管理
- 拖拽换装
- 每日场景
- 轻叙事对话
- 服装解锁

---

## Consistency Issues

### Blocking

#### B-1: Autoload 注册顺序互相冲突

涉及 GDD:

- `design/gdd/resource-loader.md`
- `design/gdd/save-load.md`
- `design/gdd/progress-management.md`

冲突:

- `resource-loader.md` 的 Core Rules / Autoload 注册顺序写为 `WardrobeDatabase -> GameState -> TextureCache`
- `save-load.md` 的 Core Rules / Autoload 注册顺序写为 `WardrobeDatabase -> GameState -> SaveManager -> TextureCache`
- `progress-management.md` 的 Core Rules / Autoload 注册顺序写为 `WardrobeDatabase -> GameState -> SaveManager -> TextureCache -> InputManager -> ProgressManager`

Godot Project Settings 只能有一个 Autoload 顺序。当前 `TextureCache` 同时被定义为第 3 和第 4，且 `InputManager` / `ProgressManager` 的相对位置也只在部分 GDD 中出现。

Required action:

Use one authoritative chain, likely the fuller `WardrobeDatabase -> GameState -> SaveManager -> TextureCache -> InputManager -> ProgressManager`, then update `resource-loader.md` and any related AC/BOOT notes.

#### B-2: `systems-index.md` 依赖层级陈旧

涉及 GDD:

- `design/gdd/systems-index.md`
- `design/gdd/scene-state-management.md`
- `design/gdd/sprite-layered-rendering.md`
- `design/gdd/resource-loader.md`

冲突:

- `systems-index.md` lists `场景/状态管理` as Depends On `—`
- `scene-state-management.md` states it depends on `服装数据库`, `保存/加载`, `资源加载器`, `输入管理`, and `进度管理`
- `systems-index.md` puts `精灵分层渲染` and `资源加载器` in the zero-dependency Foundation layer
- `sprite-layered-rendering.md` depends on `服装数据库` and `资源加载器`
- `resource-loader.md` depends on `服装数据库` and `场景/状态管理`

This stale index can mislead architecture order and story slicing.

Required action:

Update `systems-index.md` Systems Enumeration, Dependency Map, and layer grouping so it reflects each GDD's current dependency section.

#### B-3: Day 1 解锁记录 AC 与进度公式冲突

涉及 GDD:

- `design/gdd/save-load.md`
- `design/gdd/progress-management.md`
- `design/gdd/clothing-unlock.md`

冲突:

- `save-load.md` AC-9 expects `ProgressManager` to record day 1 unlocks in `unlock_progress["1"]` inside `advance_day()`
- `progress-management.md` defines day 1 items as available at startup, not calculated by `advance_day()`; `advance_day()` handles `new_day >= 2`
- `clothing-unlock.md` AC-18 says initial `unlock_day = 1` clothing is not shown as a "new clothes arrived" unlock prompt

The current Save/Load AC requires a record that should not exist under the progression model.

Required action:

Revise `save-load.md` AC-9 to verify day 2+ unlock record round-trip, or explicitly decide that day 1 gets a historical record even though it is not a new unlock event.

### Warnings

#### W-1: MVP 物品数量估算不一致

涉及 GDD:

- `design/gdd/wardrobe-database.md`
- `design/gdd/progress-management.md`
- `design/gdd/resource-loader.md`

Concern:

`wardrobe-database.md` owns the MVP content count as about 30 items. `progress-management.md` contains an example ending at about 38 items. `resource-loader.md` memory estimates use 30 THUMB textures.

Recommendation:

Update the progress example to the about-30-item content budget.

#### W-2: 场景状态 AC 仍保留 prototype skip 语义

涉及 GDD:

- `design/gdd/scene-state-management.md`
- `design/gdd/resource-loader.md`

Concern:

`scene-state-management.md` AC-5 still allows skipping not-yet-designed Foundation systems into MAIN_MENU, while dependency notes say formal MVP skip flags must be false. `resource-loader.md` also says formal implementation must not skip the loader.

Recommendation:

Mark this AC as prototype-only or remove it from formal MVP acceptance criteria.

#### W-3: 服装解锁对主菜单/GameState 的依赖未在系统索引体现

涉及 GDD:

- `design/gdd/clothing-unlock.md`
- `design/gdd/systems-index.md`

Concern:

`clothing-unlock.md` depends on 主菜单/晚安 UI for safe presentation timing and on GameState for stable menu state. `systems-index.md` only lists 进度管理, 服装数据库, 衣橱 UI.

Recommendation:

Add 主菜单/晚安 UI and 场景/状态管理 as weak/medium dependencies in `systems-index.md`.

#### W-4: Registry 未登记可选每日音乐事件族

涉及 GDD:

- `design/gdd/audio-management.md`
- `design/gdd/daily-scene.md`
- `design/registry/entities.yaml`

Concern:

`audio-management.md` and `daily-scene.md` mention `scene.music.day_{n}`, but the registry only contains `scene.music.daily_generic`.

Recommendation:

If `scene.music.day_{n}` is a long-term cross-system key family, add it to the registry. Otherwise, clarify in audio docs that it is an optional pattern key outside the registry baseline.

---

## Game Design Issues

### Blocking

None.

### Warnings

#### W-5: 最快进度路径可能绕过“随心搭配”核心动作

涉及 GDD:

- `design/gdd/game-concept.md`
- `design/gdd/progress-management.md`
- `design/gdd/wardrobe-ui.md`
- `design/gdd/clothing-unlock.md`

Concern:

The optimal unlock speed path can become: start today -> confirm without changing outfit -> quickly finish dialogue -> goodnight -> unlock. This does not violate the no-pressure pillar, but it can make clothing expression feel optional rather than central.

Recommendation:

Do not add scoring or mandatory outfit changes. Instead, add soft expression hooks: daily-scene/dialogue flavor that acknowledges the current outfit, or a gentle "today's outfit" confirmation beat in Wardrobe UI.

#### W-6: 衣橱阶段移动端注意力预算接近上限

涉及 GDD:

- `design/gdd/wardrobe-ui.md`
- `design/gdd/drag-dress-up.md`
- `design/gdd/main-menu-goodnight-ui.md`

Concern:

Wardrobe can simultaneously show day/progress, six categories, locked/disabled states, newly unlocked highlights, selected/equipped/dragging/hover/focus states, and cancel/confirm actions. These all serve the same core action, but mobile attention budget is tight.

Recommendation:

`/ux-design wardrobe-ui` should specifically validate mobile Day 1 and Day 4 cognitive load. Avoid letting lock/new/highlight/selected/equipped/focus states compete visually.

#### W-7: `wardrobe-database.md` 使用非基线支柱名“衣为焦点”

涉及 GDD:

- `design/gdd/wardrobe-database.md`
- `design/gdd/game-concept.md`
- `design/gdd/systems-index.md`

Concern:

The baseline pillars are 每日陪伴, 随心搭配, 即时有感. `wardrobe-database.md` uses `衣为焦点`, which is not part of the current concept pillar set.

Recommendation:

Change `wardrobe-database.md` metadata to `随心搭配, 即时有感`, unless the team intentionally adds a fourth pillar to `game-concept.md`.

---

## Cross-System Scenario Issues

Scenarios walked: 4

### Blockers

#### S-2: GOODNIGHT 推进与新衣解锁链

Systems involved:

- Daily Scene
- GameState
- ProgressManager
- SaveManager
- Clothing Unlock
- Main Menu / Wardrobe UI

Failure mode:

This scenario hits B-3. The flow relies on `advance_day()` producing new unlock records after GOODNIGHT, but Save/Load AC-9 expects a day 1 unlock record while ProgressManager and Clothing Unlock both treat day 1 as initial availability rather than a new unlock event.

Required action:

Revise `save-load.md` AC-9 to day 2+ or explicitly define a day 1 historical record that is not used as a "new item" event.

#### S-3: BOOT 恢复链

Systems involved:

- SaveManager
- ProgressManager
- GameState
- Resource Loader
- InputManager
- WARDROBE / DAILY_SCENE

Failure mode:

This scenario hits B-1. The BOOT chain depends on a stable Autoload ordering, but different GDDs currently define incompatible registration sequences.

Required action:

Select and propagate one authoritative Autoload order before architecture.

### Warnings

#### S-1: 衣橱拖拽换装链

Systems involved:

- Input Management
- Wardrobe UI
- Drag Dress-Up
- Sprite Layered Rendering
- Audio Management

Concern:

`input-management.md` was revised to a registered region / `region_id` ownership model. `wardrobe-ui.md` still describes older behavior: it listens to `drag_started` and infers that the start point was an unlocked card. This is workable but stale.

Recommendation:

Update `wardrobe-ui.md` so it registers card gesture regions with InputManager and maps `region_id -> item_id`.

### Info

#### S-4: 每日场景呈现链

Systems involved:

- GameState
- Daily Scene
- Sprite Layered Rendering
- Dialogue UI
- GOODNIGHT UI

Finding:

The flow is mostly closed. `equipped_items` missing/empty has fallback behavior; late `outfit_applied` is ignored; Daily Scene does not advance progress directly.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `design/gdd/resource-loader.md` | Autoload order conflict resolved on 2026-06-11 | Consistency | Resolved (was Blocking) |
| `design/gdd/systems-index.md` | Dependency map stale issue resolved on 2026-06-11 | Consistency | Resolved (was Blocking) |
| `design/gdd/save-load.md` | Day 1 unlock AC conflict resolved on 2026-06-11 | Consistency | Resolved (was Blocking) |
| `design/gdd/wardrobe-ui.md` | Needs sync with new InputManager region/ownership contract | Scenario | Warning |
| `design/gdd/progress-management.md` | MVP item count example conflicts with ~30 item budget | Consistency | Warning |
| `design/gdd/scene-state-management.md` | Prototype skip AC remains in formal MVP criteria | Consistency | Warning |
| `design/gdd/wardrobe-database.md` | Pillar metadata uses non-baseline pillar | Design Theory | Warning |
| `design/registry/entities.yaml` | Optional `scene.music.day_{n}` key family not registered | Registry | Warning |

---

## Verdict: FAIL

One or more blocking consistency issues must be resolved before architecture begins.

### Resolution Update - 2026-06-11

Blocking items B-1, B-2, B-3 have been addressed in the GDD set:

1. `resource-loader.md` and `save-load.md` now share the same authoritative Autoload chain: `WardrobeDatabase -> GameState -> SaveManager -> TextureCache -> InputManager -> ProgressManager`.
2. `systems-index.md` now reflects current dependency declarations, including `场景/状态管理` dependencies, `精灵分层渲染` dependency on `资源加载器`, and `服装解锁` dependency on `主菜单/晚安 UI` plus `场景/状态管理`.
3. `save-load.md` AC-9 now verifies day 2+ `unlock_progress` round-trip and explicitly excludes day 1 initial items from `unlock_progress["1"]`.

Residual warning-level issues remain. Re-run `/consistency-check` or `/review-all-gdds` to confirm the blocking verdict can be cleared.

### Required actions before re-running

1. Confirm the resolved Autoload order, systems index, and Save/Load AC-9 by re-running `/consistency-check` or `/review-all-gdds`.
2. Review the intentional `场景/状态管理` ↔ `资源加载器` BOOT/check coupling during architecture so it is implemented through `is_ready` checks rather than direct `_ready()` mutual calls.
3. Sync `wardrobe-ui.md` to the revised InputManager registered-region contract.
4. Address warning-level metadata and registry drift, then re-run `/review-all-gdds` or `/consistency-check`.
