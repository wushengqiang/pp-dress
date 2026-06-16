# Consistency Check Report

Date: 2026-06-15
Mode: full
Registry entries checked: 1 entity, 6 items, 3 formulas, 7 constants
GDDs scanned: 15 system GDDs

Scanned GDDs:

- `audio-management.md`
- `clothing-unlock.md`
- `daily-scene.md`
- `dialogue-ui.md`
- `drag-dress-up.md`
- `input-management.md`
- `light-narrative-dialogue.md`
- `main-menu-goodnight-ui.md`
- `progress-management.md`
- `resource-loader.md`
- `save-load.md`
- `scene-state-management.md`
- `sprite-layered-rendering.md`
- `wardrobe-database.md`
- `wardrobe-ui.md`

---

## Conflicts Found

None.

---

## Stale Registry Entries

None.

Registry `last_updated` is `2026-06-11` and remains consistent with the current GDD set, including the optional `scene.music.day_{n}` event-key family.

---

## Unverifiable References

None requiring action.

Some registry entries are structural baselines rather than repeated literal names in GDD prose, such as `player_character` and `wardrobe_category_*`. Their comparable attributes were checked through nearby category keys, labels, formulas, and interface references rather than literal registry-entry names.

---

## Clean Entries

Verified clean:

- Entity: `player_character`
- Items: `wardrobe_category_top`, `wardrobe_category_bottom`, `wardrobe_category_shoes`, `wardrobe_category_accessory`, `wardrobe_category_hair`, `wardrobe_category_makeup`
- Formulas: `new_items`, `visible_categories`, `is_day_available`
- Constants: `TOTAL_DAYS`, `AUDIO_EVENT_PROGRESS_ITEMS_UNLOCKED`, `AUDIO_EVENT_WARDROBE_OUTFIT_APPLIED`, `AUDIO_EVENT_SCENE_DAILY_ENTERED`, `AUDIO_EVENT_SCENE_MUSIC_DAILY_GENERIC`, `AUDIO_EVENT_SCENE_MUSIC_DAY_N`, `AUDIO_EVENT_SCENE_TRANSITION_PAGE`

Key checks:

- `TOTAL_DAYS` remains `7` across progression, main menu/goodnight UI, daily scene, dialogue UI, light narrative dialogue, and clothing unlock.
- `new_items(day)` matches `ids(WardrobeDatabase.get_unlocked_items(day)) - ids(WardrobeDatabase.get_unlocked_items(day - 1))` in both Progress Management and Clothing Unlock.
- `visible_categories(day)` matches Progress Management and Wardrobe UI behavior: all six category labels can be displayed, while the visible/enabled set follows the day-based progression rule.
- Wardrobe category keys and labels match registry values: `top/上装`, `bottom/下装`, `shoes/鞋子`, `accessory/配饰`, `hair/发型`, `makeup/妆容`.
- Audio event constants match current GDD references, including optional day-specific music fallback to `scene.music.daily_generic`.
- Recent approval/status updates for Save/Load, Sprite Layered Rendering, and Input Management do not introduce registry-value conflicts.

---

## Verdict: PASS

No cross-document registry conflicts were found. Registry and GDDs agree on all checked comparable values.
