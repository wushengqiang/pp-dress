# Architecture Review Report

Date: 2026-06-20
Engine: Godot 4.6
GDDs Reviewed: 15
ADRs Reviewed: 11

---

## Traceability Summary

Total requirements: 15
Covered: 15
Partial: 0
Gaps: 0

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

## Coverage Gaps

None. Current grouped GDD technical requirements all have accepted ADR coverage.

## Cross-ADR Conflicts

No blocking cross-ADR conflicts found.

The ADR set consistently separates authority:

- GameState owns scene routing and context transfer.
- SaveManager owns persistence transport and storage safety, not progression rules.
- ProgressManager owns day and unlock authority.
- WardrobeDatabase owns static clothing data only.
- TextureCache owns texture loading and cache lifecycle only.
- InputManager owns identity-free gesture streams only.
- WardrobeUI owns region-to-item mapping and presentation state.
- DragDressUp adapts UI intent to renderer result.
- SpriteLayeredRenderer owns per-instance visual outfit state.
- AudioManager owns audio event playback and Web unlock behavior.

## ADR Dependency Order

No unresolved dependencies or dependency cycles found. All reviewed ADRs are Accepted.

1. ADR-0001: Autoload Order and Boot Orchestration
2. ADR-0002: Persistence Ownership and Save Rollback Strategy
3. ADR-0003: Texture Loading Cache and Web Fallback Strategy
4. ADR-0004: Scene Transition and State Machine Contract
5. ADR-0005: Input Gesture Ownership and UI Focus Model
6. ADR-0006: Presentation to Gameplay Communication Pattern
7. ADR-0007: Sprite Layered Renderer and Outfit State Ownership
8. ADR-0008: Progression and Unlock Event Contract
9. ADR-0009: Audio Event Routing and Web Unlock Behavior
10. ADR-0010: Wardrobe Database Schema and Read-Only Query Contract
11. ADR-0011: Dialogue Content Provider and Localization Contract

## GDD Revision Flags

None. No GDD assumption was found contradicting verified Godot 4.6 behavior or accepted ADRs.

## Engine Compatibility Issues

Engine: Godot 4.6
ADRs with Engine Compatibility section: 11 / 11

Deprecated API References:

- None found in ADR decision text.

Stale Version References:

- None. All ADRs record Godot 4.6.

Post-Cutoff API / Behavior Risks To Verify:

- ADR-0001 and ADR-0004: `SceneTree.change_scene_to_file()`, Autoload `_ready()` timing, typed signals, `await signal`, and Time APIs must be verified in pinned Godot 4.6.
- ADR-0002: Godot 4.4+ `FileAccess.store_*` boolean returns and Web `JavaScriptBridge` localStorage wrappers must be verified.
- ADR-0003: `ResourceLoader.load_threaded_request()` and Web-over-HTTP / COOP / COEP behavior must be verified in release export. Prototype evidence already reports PASS for the tested flow.
- ADR-0005 and ADR-0006: Godot 4.6 dual-focus behavior must be tested for mouse/touch and keyboard/gamepad focus separation.
- ADR-0007: same-parent `Sprite2D` z-index ordering and stale callback generation guards must be validated.
- ADR-0009: browser audio unlock and background-tab behavior remain platform risks.
- ADR-0010: JSON parse diagnostics, export inclusion, and defensive-copy behavior must be tested on Web builds.
- ADR-0011: CSV localization context/plural support, `tr()` lookup, and long localized dialogue layout must be verified.

Engine Specialist Findings:

- Not available in this run because the current session did not expose a sub-agent delegation tool. Local audit used the checked Godot reference docs under `docs/engine-reference/godot/`.

## Architecture Document Coverage

`docs/architecture/architecture.md` covers the current system layer map, ownership rules, data flows, and API boundaries for all 15 systems.

Concern: its ADR audit section is stale. It still states that only ADR-0001 exists and reports most requirement groups as gaps, but the repository now contains accepted ADR-0001 through ADR-0011. This is documentation drift, not an active architecture gap.

Missing systems in architecture layers: none found.

Orphaned architecture systems: none found.

## Pre-Gate Checklist

| Item | Status |
|---|---|
| `tests/unit/` | Missing |
| `tests/integration/` | Missing |
| `.github/workflows/tests.yml` | Missing |
| `design/accessibility-requirements.md` | Missing |
| `design/ux/interaction-patterns.md` | Missing |

## Verdict: CONCERNS

Architecture coverage is complete for the current grouped technical requirement baseline, and no blocking ADR conflicts were found. The verdict remains CONCERNS because the master architecture document contains stale ADR audit content, engine-specialist consultation could not be run in this session, and pre-gate test / UX / accessibility infrastructure is not present.

## Blocking Issues

None for architecture coverage.

## Required ADRs

None for the current GDD baseline.

## Immediate Actions

1. Update `docs/architecture/architecture.md` ADR audit and traceability sections to reflect ADR-0001 through ADR-0011.
2. Run `/test-setup` to create unit/integration test directories and CI workflow.
3. Run `/ux-design` to create accessibility and interaction-pattern documents before gate-check.
