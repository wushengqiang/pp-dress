# Consistency Check Report

Date: 2026-06-21
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

Registry `last_updated` is `2026-06-11` and remains consistent with the current GDD set.

---

## Unverifiable References

None requiring action.

Some registry entries are structural baselines rather than repeated literal names in GDD prose, such as `player_character`, `wardrobe_category_*`, and audio event constant names. Their comparable attributes were checked through category keys, labels, formulas, and event-key values rather than literal registry-entry names.

---

## Clean Entries

Verified clean:

- Entity: `player_character`
- Items: `wardrobe_category_top`, `wardrobe_category_bottom`, `wardrobe_category_shoes`, `wardrobe_category_accessory`, `wardrobe_category_hair`, `wardrobe_category_makeup`
- Formulas: `new_items`, `visible_categories`, `is_day_available`
- Constants: `TOTAL_DAYS`, `AUDIO_EVENT_PROGRESS_ITEMS_UNLOCKED`, `AUDIO_EVENT_WARDROBE_OUTFIT_APPLIED`, `AUDIO_EVENT_SCENE_DAILY_ENTERED`, `AUDIO_EVENT_SCENE_MUSIC_DAILY_GENERIC`, `AUDIO_EVENT_SCENE_MUSIC_DAY_N`, `AUDIO_EVENT_SCENE_TRANSITION_PAGE`

Key checks:

- `TOTAL_DAYS` remains `7` across Progress Management, Daily Scene, Light Narrative Dialogue, Main Menu/Goodnight UI, and Save/Load boundary notes.
- `new_items(day)` matches `ids(WardrobeDatabase.get_unlocked_items(day)) - ids(WardrobeDatabase.get_unlocked_items(day - 1))` in both Progress Management and Clothing Unlock.
- `visible_categories(day)` matches Progress Management and Wardrobe UI behavior: all six category labels can be displayed, while the enabled set follows the day-based progression rule.
- Wardrobe category keys and labels remain consistent: `top`/`上装`, `bottom`/`下装`, `shoes`/`鞋子`, `accessory`/`配饰`, `hair`/`发型`, `makeup`/`妆容`.
- Audio event constants match current GDD references: `progress.items_unlocked`, `wardrobe.outfit_applied`, `scene.daily.entered`, `scene.music.daily_generic`, `scene.music.day_{n}`, and `scene.transition_page`.

---

## Verdict: PASS

No cross-document registry conflicts were found. Registry and GDDs agree on all checked comparable values.
