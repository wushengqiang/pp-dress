# Cross-GDD Review Report

Date: 2026-06-10
Focus: full
Verdict: CONCERNS

## GDDs Reviewed

15 system GDDs:

- design/gdd/audio-management.md
- design/gdd/clothing-unlock.md
- design/gdd/daily-scene.md
- design/gdd/dialogue-ui.md
- design/gdd/drag-dress-up.md
- design/gdd/input-management.md
- design/gdd/light-narrative-dialogue.md
- design/gdd/main-menu-goodnight-ui.md
- design/gdd/progress-management.md
- design/gdd/resource-loader.md
- design/gdd/save-load.md
- design/gdd/scene-state-management.md
- design/gdd/sprite-layered-rendering.md
- design/gdd/wardrobe-database.md
- design/gdd/wardrobe-ui.md

Baseline documents:

- design/gdd/game-concept.md
- design/gdd/systems-index.md
- design/registry/entities.yaml
- docs/consistency-report-2026-06-10.md

Project context:

- Engine: Godot 4.6
- Language: GDScript
- Platform: Web
- Input: Mouse + Touch

## Summary

The 15 MVP systems are directionally coherent. The core loop remains:

`MAIN_MENU -> WARDROBE -> DAILY_SCENE -> GOODNIGHT -> MAIN_MENU`

The major design commitments are consistent across GDDs:

- No outfit scoring, ranking, fail states, punishment, or "correct outfit" messaging.
- Clothing unlock ownership stays with ProgressManager.
- Clothing Unlock only presents unlock results and wardrobe highlights.
- Day advancement happens at `GOODNIGHT -> MAIN_MENU`.
- `TOTAL_DAYS = 7` is consistent across the registry and GDDs.
- Core audio event keys are aligned with the audio-management event catalog.

No blocking cross-GDD contradiction was found. The remaining concerns are tracking, dependency map accuracy, and technical validation gates before implementation.

## Consistency Issues

### Blocking

None.

### Warnings

#### W1. systems-index dependency map contradicts its own system enumeration

`design/gdd/systems-index.md` has a reliable system enumeration table:

- `sprite-layered-rendering.md` depends on Wardrobe Database and Resource Loader.
- `resource-loader.md` depends on Wardrobe Database and Scene/State Management.

The individual GDDs confirm those dependencies:

- `design/gdd/sprite-layered-rendering.md` lists Wardrobe Database and Resource Loader as hard dependencies.
- `design/gdd/resource-loader.md` lists Wardrobe Database and Scene/State Management as dependencies.

However, the Dependency Map section in `systems-index.md` labels its first layer as `Foundation Layer (zero dependencies)` and includes both Sprite Layered Rendering and Resource Loader there. That label is stale: those systems are foundational in importance, but not zero-dependency systems.

Recommendation:

- Revise the Dependency Map language to distinguish "foundation importance" from "zero dependencies".
- Either move Resource Loader and Sprite Layered Rendering into dependency-aware layers, or rename the section so architects do not infer they can initialize independently.

#### W2. Three MVP GDDs remain short of Approved status

Current GDD file headers show:

- `design/gdd/sprite-layered-rendering.md`: `In Design`
- `design/gdd/save-load.md`: `Designed`
- `design/gdd/input-management.md`: `Designed`

`systems-index.md` also tracks 12 reviewed / 12 approved docs and explicitly lists these three as remaining non-approved GDDs.

Recommendation:

- Run `/design-review` on:
  - `design/gdd/sprite-layered-rendering.md`
  - `design/gdd/save-load.md`
  - `design/gdd/input-management.md`
- Only then promote them to Approved and update the systems index tracker.

#### W3. Resource Loader still has a P0 Web threading and memory validation gate

`resource-loader.md` correctly calls out a P0 technical risk: Godot 4.6 Web export may require COOP/COEP headers and a threads-enabled export template for `ResourceLoader.load_threaded_request()` to behave as intended. It also requires target-platform memory validation, especially around full-size clothing textures, mipmaps, WebGL alignment, and cache sizing.

This is not a design contradiction; it is a technical gate that can invalidate the preferred loading strategy if ignored.

Recommendation:

- Run the Resource Loader prototype before implementation handoff.
- Capture an ADR for the chosen fallback:
  - Basis Universal compression,
  - lower FULL resolution,
  - smaller hot/warm cache,
  - or a preload strategy if threading is unavailable.

## Game Design Issues

### Blocking

None.

### Warnings

#### W4. Several architecture-level interface choices remain open

The GDDs intentionally define semantics without forcing implementation mechanism in a few places:

- Drag Dress Up result delivery: signal vs callable callback vs event bus.
- Clothing Unlock to Wardrobe UI handoff: push vs pull for `newly_unlocked_item_ids`.
- Audio resource ownership: direct audio event table references vs Resource Loader involvement.
- Light Narrative Dialogue provider and localization resource format.

These are acceptable open architecture inputs, not GDD contradictions.

Recommendation:

- Resolve these through ADRs during `/create-architecture`.
- Do not let individual implementation stories invent their own communication patterns ad hoc.

## Game Design Holism

### Progression Loop Competition

Pass.

The game has one clear progression spine: a 7-day daily loop with wardrobe growth. Clothing unlocks add options, but do not create a competing scoring, economy, XP, or challenge loop.

### Player Attention Budget

Pass.

The moment-to-moment active systems are limited:

- Wardrobe category/item choice.
- Drag or click outfit application.
- Confirmation into daily scene.
- Simple dialogue advancement.

Persistence, resource loading, audio, progression, and unlock presentation are mostly passive or supportive. The design stays within a comfortable attention budget for a cozy dress-up game.

### Dominant Strategy Detection

Pass.

No scoring, stat advantage, rating, economy, or win condition exists, so no outfit strategy can dominate mechanically. The GDDs consistently state that all outfits are valid and player taste is the only standard.

### Economic Loop Analysis

Pass.

There is no currency, XP, stamina, crafting material, or sink/source economy in MVP. The only progression resource is clothing availability over days, owned by ProgressManager and WardrobeDatabase.

### Difficulty Curve Consistency

Pass.

The game has no challenge difficulty curve. The only ramp is cognitive/onboarding complexity: early days expose basic categories, later days reveal more categories. This matches the concept and progress-management GDD.

### Pillar Alignment

Pass with technical risk.

- Daily Companionship: daily-scene, dialogue-ui, light-narrative-dialogue, main-menu-goodnight-ui, save-load, progress-management.
- Free Styling: wardrobe-database, wardrobe-ui, drag-dress-up, sprite-layered-rendering, clothing-unlock.
- Immediate Feedback: input-management, drag-dress-up, sprite-layered-rendering, resource-loader, audio-management.

No system appears to drift into anti-pillars such as scoring, competitive ranking, deep branching narrative, or massive collection bloat.

### Player Fantasy Coherence

Pass.

The GDDs consistently frame the player as a gentle stylist/companion, not a competitor, optimizer, or quest grinder.

## Cross-System Scenario Issues

Scenarios walked: 4

### Scenario 1: Wardrobe Outfit Application

Systems involved:

- Input Management
- Wardrobe UI
- Drag Dress Up
- Sprite Layered Rendering
- Resource Loader
- Audio Management

Flow:

1. Player drags or clicks an item in Wardrobe UI.
2. Wardrobe UI emits an outfit intent.
3. Drag Dress Up validates the intent and calls Sprite Layered Rendering.
4. Sprite Layered Rendering requests texture through TextureCache.
5. Result is returned to Wardrobe UI through `outfit_apply_result`.
6. Audio/visual feedback plays only after confirmed application.

Result: pass.

Notes:

- Same-item no-op, invalid item, locked item, renderer not ready, and timeout behavior are defined.
- The only remaining choice is implementation mechanism for the result callback/event path.

### Scenario 2: Goodnight, Day Advance, and Clothing Unlock

Systems involved:

- Daily Scene
- Main Menu / Goodnight UI
- Scene/State Management
- Save/Load
- Progress Management
- Clothing Unlock
- Wardrobe UI
- Audio Management

Flow:

1. Daily Scene requests GOODNIGHT after dialogue.
2. Goodnight UI lets the player continue.
3. GameState clears `scene_in_progress = false`.
4. ProgressManager advances the day and saves.
5. ProgressManager emits `items_unlocked(new_items)` for non-final day unlocks.
6. Clothing Unlock displays a soft prompt after returning to main menu.
7. Wardrobe UI later consumes new item highlights.

Result: pass.

Notes:

- Previous save-order ambiguity has been resolved in the GDDs.
- Day 7 behavior is consistent: no day 8, no `items_unlocked`, completed state is shown by UI/GameState.

### Scenario 3: Daily Scene Presentation

Systems involved:

- Scene/State Management
- Daily Scene
- Sprite Layered Rendering
- Resource Loader
- Dialogue UI
- Light Narrative Dialogue
- Audio Management

Flow:

1. GameState enters DAILY_SCENE with `current_day` and `equipped_items`.
2. Daily Scene instantiates Character and applies outfit.
3. Sprite Layered Rendering emits `outfit_applied` or Daily Scene times out safely.
4. Dialogue UI requests/plays the daily sequence.
5. Player reaches GOODNIGHT.

Result: pass.

Notes:

- Missing/empty/invalid `equipped_items` have fallbacks.
- Texture and dialogue failures degrade to placeholder/default content.
- The player-facing tone remains non-technical and non-punitive.

### Scenario 4: Boot, Restore, and Resource Readiness

Systems involved:

- Scene/State Management
- Wardrobe Database
- Save/Load
- Resource Loader
- Progress Management
- Wardrobe UI
- Daily Scene

Flow:

1. GameState boots and checks foundation systems.
2. SaveManager loads localStorage or default save data.
3. WardrobeDatabase parses static wardrobe data.
4. Resource Loader performs Tier 1 readiness.
5. GameState routes to MAIN_MENU or restores DAILY_SCENE if `scene_in_progress == true`.

Result: warning.

Concern:

- The flow is well specified, but Resource Loader's preferred Web threading/memory assumptions require prototype validation before implementation commitment.

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| design/gdd/systems-index.md | Dependency Map label and layer assignment are stale relative to the system enumeration and individual GDD dependencies. | Consistency / Tracking | Warning |
| design/gdd/resource-loader.md | P0 Web threading and memory prototype remains unresolved. | Technical Risk | Warning |
| design/gdd/sprite-layered-rendering.md | File status is still `In Design`; run individual design review before architecture gate. | Process | Warning |
| design/gdd/save-load.md | File status is still `Designed`; run individual design review before architecture gate. | Process | Warning |
| design/gdd/input-management.md | File status is still `Designed`; run individual design review before architecture gate. | Process | Warning |

## Verdict: CONCERNS

No blocking issue prevents architecture thinking from starting, but the project should not pass the Pre-Production gate until:

1. `systems-index.md` dependency map and tracker are corrected.
2. The three remaining non-approved GDDs pass `/design-review`.
3. Resource Loader Web threading/memory risk is prototyped or captured in an ADR with a concrete fallback.
4. Drag Dress Up Web input feel is prototyped, as already tracked in the systems index.

## Recommended Next

1. Run `/design-review design/gdd/sprite-layered-rendering.md`.
2. Run `/design-review design/gdd/save-load.md`.
3. Run `/design-review design/gdd/input-management.md`.
4. Run `/prototype resource-loader` for Godot 4.6 Web threading and memory validation.
5. Run `/prototype drag-dress-up` for mouse/touch feel validation.
6. After those are resolved, run `/gate-check pre-production`.
