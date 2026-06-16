# Cross-GDD Review Report - Rerun

Date: 2026-06-11
Mode: full rerun after blocking-fix pass
GDDs Reviewed: 17 docs, covering 15 MVP systems
Engine Context: Godot 4.6
Context gap: `.Codex/docs/technical-preferences.md` was not present in this workspace; engine version came from `docs/engine-reference/godot/VERSION.md`.

---

## Verdict: CONCERNS

The three blocking issues from `gdd-cross-review-2026-06-11.md` have been resolved in source GDDs. No new blocking cross-GDD contradictions were found.

Architecture may proceed after the team accepts the remaining warning-level drift, but the warnings below should be cleaned up before final pre-production gate or story slicing.

---

## Blocking Recheck

### B-1: Autoload order conflict

Status: Resolved.

Evidence:

- `resource-loader.md` now uses `WardrobeDatabase -> GameState -> SaveManager -> TextureCache -> InputManager -> ProgressManager`.
- `save-load.md` now uses the same authoritative chain.
- `progress-management.md` already used the same full chain.

Residual note:

`scene-state-management.md` still describes only `WardrobeDatabase`, `GameState`, and generic "later Autoload" entries. This is no longer contradictory, but it is stale enough to remain a warning.

### B-2: `systems-index.md` stale dependency map

Status: Resolved.

Evidence:

- `systems-index.md` now lists `场景/状态管理` dependencies on `服装数据库`, `保存/加载`, `资源加载器`, `输入管理`, and `进度管理`.
- `精灵分层渲染` is no longer in the zero-dependency layer.
- `资源加载器` is no longer in the zero-dependency layer.
- `服装解锁` now includes `主菜单/晚安 UI` and `场景/状态管理`.

Residual note:

The index overview still names the old `Foundation -> Core -> Feature -> Presentation` sequence while the actual map now uses `Foundation -> Core Infrastructure -> Rendering/UI -> Feature -> Narrative`.

### B-3: Save/Load day 1 unlock AC conflict

Status: Resolved.

Evidence:

- `save-load.md` AC-9 now verifies day 2 `unlock_progress["2"]` round-trip.
- The same AC explicitly states that day 1 initial items are not written to `unlock_progress["1"]`.

---

## Remaining Concerns

### W-1: `wardrobe-ui.md` still uses the old InputManager contract

Type: Cross-GDD stale reference
Priority: High warning

`input-management.md` now defines registered gesture regions and event dictionaries carrying `region_id`, `owner_id`, and `source_key`. It explicitly says InputManager does not carry `item_id`; Wardrobe UI must map `region_id -> item_id`.

`wardrobe-ui.md` still says:

- `DRAGGING` enters on `InputManager.drag_started` when the start point is an unlocked card.
- Input dependency is described only as listening to `drag_started` / `drag_updated` / `drag_ended` / `clicked` / `hovered`.
- AC-16 and AC-19 do not require `region_id` lookup or stale-region cancellation.

Required cleanup:

Update `wardrobe-ui.md` so card controls register gesture regions, maintain a `region_id -> item_id` map, reject stale `region_id`, and only enter `DRAGGING(item_id)` after resolving that map and confirming the item is unlocked.

### W-2: Progress item-count example still conflicts with the ~30 item budget

Type: Tuning/example drift
Priority: Medium warning

`game-concept.md`, `wardrobe-database.md`, and `resource-loader.md` consistently use about 30 MVP clothing items.

`progress-management.md` still contains:

```text
第 7 天穿搭中: ~8 + 5x6 = ~38 件
通关: 全部 ~30 件
```

Required cleanup:

Change the progression example to a distribution that totals about 30, such as 7 initial items plus 4/4/4/4/4/3 over days 2-7, or mark the table as obsolete.

### W-3: Scene-state Autoload section is still incomplete

Type: Stale reference
Priority: Medium warning

`scene-state-management.md` says:

```text
1. WardrobeDatabase
2. GameState
3. 后续 Autoload（保存/加载、资源加载器、输入管理）在 GameState 之后注册
```

This no longer contradicts the project chain, but it omits `ProgressManager` and does not name the authoritative order now used by `resource-loader.md`, `save-load.md`, and `progress-management.md`.

Required cleanup:

Replace the generic third bullet with the full chain:

`WardrobeDatabase -> GameState -> SaveManager -> TextureCache -> InputManager -> ProgressManager`

### W-4: Layer labels drift inside `systems-index.md` and resource quick reference

Type: Documentation drift
Priority: Low warning

`systems-index.md` Overview still says systems follow `Foundation -> Core -> Feature -> Presentation`, but the actual map now uses `Foundation -> Core Infrastructure -> Rendering/UI -> Feature -> Narrative`.

`resource-loader.md` quick reference still says `Layer: Foundation`, while the updated index places it in `Core Infrastructure`.

Required cleanup:

Synchronize the overview and quick references with the new layer map.

### W-5: Wardrobe database pillar metadata still uses non-baseline pillar text

Type: Pillar drift
Priority: Low warning

`game-concept.md` defines the baseline pillars as:

- 每日陪伴
- 随心搭配
- 即时有感

`wardrobe-database.md` metadata still says:

```text
Implements Pillar: 衣为焦点, 随心搭配
```

The body text already says the database supports `随心搭配` and `即时有感`, so this appears to be metadata drift rather than a design conflict.

Required cleanup:

Change metadata to `随心搭配, 即时有感`, unless `衣为焦点` is intentionally promoted into `game-concept.md`.

### W-6: Optional `scene.music.day_{n}` event family remains outside registry

Type: Registry drift
Priority: Low warning

`audio-management.md` and `daily-scene.md` both reference optional day-specific music events:

```text
scene.music.day_{n}
```

The registry currently contains `scene.music.daily_generic` but not the optional day-key family.

Required cleanup:

Either register `scene.music.day_{n}` as an optional event-key family, or state in audio/daily-scene docs that it is intentionally outside the baseline registry and must be mapped during asset-spec work.

---

## Game Design Holism

No blocking game design theory issues were found.

The core loop remains consistent:

1. MAIN_MENU starts or resumes the day.
2. WARDROBE supports free outfit choice without score pressure.
3. DAILY_SCENE acknowledges the day and outfit without ranking correctness.
4. GOODNIGHT calls the progress advance path.
5. ProgressManager emits new item unlocks for the next day.
6. Clothing Unlock presents new items as soft delight, not achievement pressure.

Remaining design-theory concern:

The fastest progression path can still be "start day -> confirm quickly -> finish dialogue -> goodnight". This does not violate the no-score pillar, but UX should add soft expression hooks so outfit choice feels emotionally present without becoming mandatory.

---

## Cross-System Scenarios

### Scenario A: GOODNIGHT -> MAIN_MENU -> unlock presentation

Verdict: Pass with warning.

The day 1 unlock-record conflict is resolved. `advance_day()` now owns day 2+ unlock records, SaveManager persists them, and Clothing Unlock consumes `items_unlocked(new_items)`.

Warning: Presentation timing still depends on Main Menu / GameState safe UI timing, which should be made concrete during UX or architecture.

### Scenario B: WARDROBE drag gesture -> outfit apply

Verdict: Concerns.

InputManager now has a stronger and safer ownership model, but Wardrobe UI has not fully adopted it. This is the highest-priority remaining warning because it affects implementation handoff for drag/click behavior.

### Scenario C: BOOT restore after refresh

Verdict: Pass with warning.

Save/Load, ProgressManager, and GameState agree that ProgressManager repairs progress before BOOT consumes `current_day`. Scene-state Autoload prose should still be synced to the authoritative full chain.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `design/gdd/wardrobe-ui.md` | Synced with `InputManager.register_gesture_region` / `region_id` contract on 2026-06-11 | Stale reference | Resolved |
| `design/gdd/progress-management.md` | Item-count example synced to ~30 item MVP budget on 2026-06-11 | Tuning/example drift | Resolved |
| `design/gdd/scene-state-management.md` | Autoload prose now names the authoritative full chain | Stale reference | Resolved |
| `design/gdd/systems-index.md` | Overview layer labels synced to current layer map | Documentation drift | Resolved |
| `design/gdd/resource-loader.md` | Quick reference layer synced to Core Infrastructure | Documentation drift | Resolved |
| `design/gdd/wardrobe-database.md` | Metadata synced to baseline pillars | Pillar drift | Resolved |
| `design/registry/entities.yaml` | Optional `scene.music.day_{n}` key family registered | Registry drift | Resolved |

---

## Recommended Next Actions

### Resolution Update - 2026-06-11

The major warning items in this rerun have been addressed:

1. `wardrobe-ui.md` now uses InputManager registered gesture regions and `region_id -> item_id` ownership.
2. `progress-management.md` item-count examples now total about 30 MVP items.
3. `scene-state-management.md` now names the full authoritative Autoload chain.
4. `systems-index.md`, `resource-loader.md`, and `wardrobe-database.md` metadata now match the revised layer and pillar baselines.
5. `design/registry/entities.yaml` now registers optional `scene.music.day_{n}` as an event-key family with fallback to `scene.music.daily_generic`.

Recommended next:

1. Run `/consistency-check` to verify warning cleanup.
2. Run `/design-review` on remaining non-approved GDDs.
3. Run `/gate-check pre-production` only after remaining design reviews and prototype risk checks are complete.
