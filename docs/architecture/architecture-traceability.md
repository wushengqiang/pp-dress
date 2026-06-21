# Architecture Traceability Index

Last Updated: 2026-06-20
Engine: Godot 4.6

## Coverage Summary

- Total requirements: 15
- Covered: 15 (100%)
- Partial: 0
- Gaps: 0

## Full Matrix

| Requirement ID | GDD | System | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|
| TR-wardrobe-database-001 | wardrobe-database.md | Wardrobe Database | Static wardrobe JSON schema, read-only query API, z-index resolution, unlock-day metadata, deterministic ordering, and schema validation. | ADR-0010 | Covered |
| TR-save-load-001 | save-load.md | Save/Load | SaveData schema, Web/local persistence, bad-save protection, bounded write ownership, GOODNIGHT rollback, and recovery semantics. | ADR-0002, ADR-0004 | Covered |
| TR-input-management-001 | input-management.md | Input Management | Mouse/touch normalization, explicit gesture regions, drag/click/scroll arbitration, native GUI separation, and Godot 4.6 focus handling. | ADR-0005 | Covered |
| TR-audio-management-001 | audio-management.md | Audio Management | Event-key audio routing, buses, SFX/UI pools, Web audio unlock, cooldowns, and non-blocking audio failure behavior. | ADR-0009 | Covered |
| TR-resource-loader-001 | resource-loader.md | Resource Loader | TextureCache tiered loading, threaded requests, HOT/WARM cache, LRU eviction, duplicate request fan-out, Web fallback, and memory budget handling. | ADR-0003 | Covered |
| TR-scene-state-001 | scene-state-management.md | Scene/State Management | Autoload order, BOOT orchestration, GameState finite state machine, scene readiness handshake, transition timeout, and recovery routing. | ADR-0001, ADR-0004 | Covered |
| TR-progress-management-001 | progress-management.md | Progress Management | Current-day authority, unlock computation, post-save progress signals, save-failure rollback, and unlock availability boundary. | ADR-0002, ADR-0004, ADR-0008 | Covered |
| TR-sprite-layered-rendering-001 | sprite-layered-rendering.md | Sprite Layered Rendering | Sprite2D layered renderer, z-index ordering, renderer-owned outfit state, async callback guards, and result signal semantics. | ADR-0003, ADR-0007 | Covered |
| TR-wardrobe-ui-001 | wardrobe-ui.md | Wardrobe UI | Category and item grid UI, thumbnail consumption, ProgressManager availability, gesture-region mapping, drag/click intents, and confirmed outfit UI state. | ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0010 | Covered |
| TR-dialogue-ui-001 | dialogue-ui.md | Dialogue UI | Dialogue rendering, typewriter/input advancement, provider consumption, completion signal, fallback behavior, and focus/accessibility boundaries. | ADR-0005, ADR-0006, ADR-0011 | Covered |
| TR-main-menu-goodnight-ui-001 | main-menu-goodnight-ui.md | Main Menu / Goodnight UI | Start/goodnight/retry/continue transition intents, no progression ownership, native button paths, focus behavior, and audio event routing. | ADR-0004, ADR-0005, ADR-0006, ADR-0009 | Covered |
| TR-drag-dress-up-001 | drag-dress-up.md | Drag Dress-Up | Drop validation, click alternative, equip request tokening, renderer-result mapping, soft feedback, and no persistence/progression ownership. | ADR-0005, ADR-0006, ADR-0007, ADR-0009 | Covered |
| TR-daily-scene-001 | daily-scene.md | Daily Scene | Day/context consumption, character/background/dialogue hosting, outfit application, fallback controls, and GOODNIGHT request ownership. | ADR-0004, ADR-0006, ADR-0007, ADR-0009, ADR-0011 | Covered |
| TR-light-narrative-dialogue-001 | light-narrative-dialogue.md | Light Narrative Dialogue | Seven-day dialogue provider, sequence and line data contract, localization keys, deterministic fallback, and non-scoring flavor lines. | ADR-0011 | Covered |
| TR-clothing-unlock-001 | clothing-unlock.md | Clothing Unlock | Confirmed unlock presentation only, item validation, prompt timing, wardrobe one-time highlight handoff, and unlock audio event routing. | ADR-0008, ADR-0009, ADR-0010 | Covered |

## Known Gaps

None.

## Superseded Requirements

None.

## Notes

- This index uses the first stable TR registry entries created by `/architecture-review` on 2026-06-20.
- `docs/architecture/architecture.md` still contains stale internal ADR audit text that should be refreshed to match this index.
