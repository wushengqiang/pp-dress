# ADR-0011: Dialogue Content Provider and Localization Contract

## Status
Accepted

## Date
2026-06-20

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Core / Localization |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0004-scene-transition-and-state-machine-contract.md`, `docs/architecture/adr-0005-input-gesture-ownership-and-ui-focus-model.md`, `docs/architecture/adr-0006-presentation-to-gameplay-communication-pattern.md` |
| **Post-Cutoff APIs Used** | Godot 4.6 CSV localization plural/context support is an approved resource format capability. Godot 4.5 live translation preview and AccessKit screen reader support affect validation, not provider API shape. |
| **Verification Required** | Verify `tr()` lookup for `text_key` and `speaker_name_key`, CSV Translation import with context columns, long localized line layout in Dialogue UI, missing-key fallback behavior, deterministic sequence ordering, and Godot 4.6 pointer/touch versus keyboard focus behavior for dialogue controls. |

Godot 4.6 is post-LLM-cutoff for this project. The checked engine references flag UI and localization-adjacent workflow as HIGH risk because Godot 4.6 separates mouse/touch focus from keyboard/gamepad focus, Godot 4.5 added live translation preview and screen reader support, and Godot 4.6 adds CSV plural/context localization support. This ADR relies only on verified project reference docs and does not assume unverified APIs.

Deprecated APIs and patterns to avoid:

- Do not hardcode formal player-visible dialogue text in Dialogue UI.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not use `yield()`; use `await signal`.
- Do not collapse hover and keyboard focus into one visual state in dialogue controls.

Engine Specialist Validation: not spawned in this run because sub-agent delegation tools are not available in this session. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004: Scene Transition and State Machine Contract; ADR-0005: Input Gesture Ownership and UI Focus Model; ADR-0006: Presentation to Gameplay Communication Pattern |
| **Enables** | Implementation stories for `LightNarrativeDialogue`, dialogue CSV localization import, dialogue content validation tests, Dialogue UI provider integration, and Daily Scene dialogue context wiring. |
| **Blocks** | Stories that implement the formal dialogue content provider, formal localization table import, or replace Dialogue UI's temporary fallback provider as the normal content source. |
| **Ordering Note** | ADR-0004, ADR-0005, and ADR-0006 should be accepted before this ADR is accepted. This ADR should be accepted before implementing formal dialogue data, provider APIs, or localization import stories. |

## Context

### Problem Statement

The GDDs currently define `LightNarrativeDialogue` as the formal daily dialogue content source, while `DialogueUI` still references `request_dialogue_sequence(day, context)` as a temporary fallback-provider contract. The project needs one accepted architecture decision that assigns long-term ownership, locks the provider API, separates content keys from localized strings, and defines fallback behavior before implementation stories begin.

Without this ADR, implementers could place formal text inside Dialogue UI, let Daily Scene directly request narrative content, store player-visible text in runtime content tables, use incompatible sequence shapes, or treat missing localization as a blocking runtime error. Those outcomes would contradict the GDD boundary that Dialogue UI renders and advances text, Daily Scene orchestrates scene flow, and Light Narrative Dialogue owns formal content.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- Target platform is Web with mouse and touch as MVP inputs.
- Dialogue UI is a presentation system and must not own formal narrative content.
- Daily Scene provides context and listens for completion, but must not directly drive the normal provider request path.
- GameState owns state transitions; dialogue content must not request `GOODNIGHT`.
- ProgressManager owns day progression; dialogue content must not advance or repair progress.
- Formal player-visible strings must use localization keys and Godot `tr()` path.
- MVP narrative is seven linear days, short text, no choices, no scoring, no failure states.

### Requirements

- Must define the long-term owner of `request_dialogue_sequence(day, context)`.
- Must define `DialogueSequence` and `DialogueLine` data shape.
- Must define how formal content references localized text.
- Must choose the localization resource format for implementation.
- Must define provider fallback and Dialogue UI fallback boundaries.
- Must prevent narrative content from becoming gameplay, state, audio, or persistence authority.
- Must keep sequence selection deterministic for tests and localization.

## Decision

The project will implement `LightNarrativeDialogue` as the formal dialogue content provider and the long-term owner of:

```gdscript
func request_dialogue_sequence(day: int, context: Dictionary) -> Dictionary
```

`DialogueUI` is the only normal runtime caller. `DailyScene` provides context to Dialogue UI and listens for `dialogue_sequence_finished(day)`, but it does not directly request formal dialogue content unless a future ADR accepts an emergency-only path.

The provider returns defensive-copy `Dictionary` snapshots shaped as `DialogueSequence` and `DialogueLine`. Consumers may read the returned data but must not mutate returned dictionaries or arrays as authoritative content state.

Formal player-visible text is not stored in UI scripts or formal sequence data. Formal content data stores only stable keys:

- `text_key`
- `speaker_name_key`
- optional metadata keys such as `sequence_id`, `scene_id`, `portrait_expression`, `line_type`, and `mood_key`

Dialogue UI resolves display text with Godot `tr()`:

```gdscript
var speaker_text := tr(line["speaker_name_key"])
var body_text := tr(line["text_key"])
```

The formal localization resource format is Godot Translation CSV import. MVP does not require plural logic, but CSV context columns are allowed and should be used where the same key text needs speaker, narrator, or line disambiguation. Live translation preview in Godot 4.5+ must be part of UI validation for long strings.

### Provider API Contract

```gdscript
func request_dialogue_sequence(day: int, context: Dictionary) -> Dictionary
```

Input:

- `day: int`
- `context.scene_id: String` optional
- `context.equipped_items: Array[String]` optional
- `context.dialogue_context_tags: Array[String]` optional

Output `DialogueSequence` dictionary:

```gdscript
{
    "sequence_id": String,
    "day": int,
    "scene_id": String,
    "mood_key": String,
    "lines": Array[Dictionary]
}
```

Output `DialogueLine` dictionary:

```gdscript
{
    "line_id": String,
    "speaker_id": String,
    "speaker_name_key": String,
    "text_key": String,
    "portrait_expression": String,
    "line_type": String
}
```

Allowed `line_type` values from the formal provider are:

- `dialogue`
- `narration`
- `flavor`

`system_hint` is reserved for Dialogue UI fallback and operation hints. Formal Light Narrative Dialogue content must not output `system_hint`.

### Content Storage Contract

MVP formal content data contains one root table:

```text
dialogue_sequences: Dictionary[int, DialogueSequence]
```

Required day keys are `1..7`. Day 1 is the required safe fallback sequence. Each normal day sequence contains 3-5 lines and must not exceed the GDD's `LINES_PER_DAY_MAX`.

The implementation may represent the static table as Godot `Resource`, `.tres`, JSON-like dictionaries, or an equivalent static data resource, but the provider API above is the external contract. The content storage format remains internal until an implementation story chooses the concrete asset type.

### Localization Contract

Formal content tables must store keys only:

- `line.text_key`
- `line.speaker_name_key`
- `sequence.mood_key` only if used for presentation/audio guidance

The localized text table is separate from sequence data and imported as Godot Translation CSV. Required CSV coverage before implementation handoff:

- every `text_key`
- every `speaker_name_key`
- `dialogue.fallback.daily_quiet`
- any UI labels referenced by Dialogue UI, such as `goodnight` or `continue` keys, if they are part of the same content handoff

Dialogue UI handles missing localization at runtime by skipping invalid lines or using its fallback line path. Missing formal localization keys are a content validation failure before release, not a reason for Light Narrative Dialogue to hardcode player-visible text.

### Fallback Contract

Fallback is layered:

```text
DialogueUI
  -> LightNarrativeDialogue.request_dialogue_sequence(day, context)
       -> exact day / scene sequence
       -> day default sequence
       -> day 1 safe fallback sequence
       -> emergency sequence using dialogue.fallback.daily_quiet
  -> DialogueUI fallback line or finish-confirm path if provider is unavailable
  -> DailyScene fallback finish control only if DialogueUI itself is unavailable
```

Rules:

- `day` is locally clamped to `1..7`; the provider does not write the repaired value back.
- Unknown or missing `scene_id` selects by day only.
- Missing or invalid `dialogue_context_tags` returns the base sequence.
- `dialogue_context_tags` are cropped to `MAX_DIALOGUE_CONTEXT_TAGS`.
- Missing or empty `equipped_items` skips clothing flavor and still returns base content.
- Invalid equipped item IDs are ignored for flavor matching.
- Multiple flavor candidates are resolved by deterministic priority, never random.
- MVP inserts at most one flavor line.

### System Boundary Rules

`LightNarrativeDialogue` must not:

- render UI
- handle input
- call `GameState.request_transition(...)`
- emit or consume `dialogue_sequence_finished(day)`
- call `ProgressManager.advance_day()`
- modify SaveManager, WardrobeDatabase, GameState context, or equipped outfit state
- play audio or create audio players
- output scoring, correctness, failure, rating, or reward semantics

`DialogueUI` remains responsible for:

- calling `request_dialogue_sequence(day, context)`
- resolving `text_key` and `speaker_name_key` through `tr()`
- typewriter display
- input advancement and debouncing
- layout, wrapping, paging, and missing-key runtime fallback
- emitting `dialogue_sequence_finished(day)` once

`DailyScene` remains responsible for:

- providing `day`, `scene_id`, `equipped_items`, and `dialogue_context_tags` context to Dialogue UI
- starting Dialogue UI after visual readiness
- receiving `dialogue_sequence_finished(day)`
- requesting `GameState.request_transition(State.GOODNIGHT)` through the approved GameState path

### Architecture Diagram

```text
GameState.context / DailyScene scene_config
  -> DailyScene builds dialogue context
  -> DialogueUI starts after visual_ready
  -> LightNarrativeDialogue.request_dialogue_sequence(day, context)
       -> validates static content table
       -> selects deterministic sequence
       -> returns defensive-copy DialogueSequence
  -> DialogueUI tr(text_key), renders, advances input
  -> DialogueUI emits dialogue_sequence_finished(day)
  -> DailyScene requests GameState transition to GOODNIGHT
```

### Key Interfaces

```gdscript
# LightNarrativeDialogue
func request_dialogue_sequence(day: int, context: Dictionary) -> Dictionary
func validate_dialogue_content() -> Array[String]
func get_load_error() -> String
```

```gdscript
# DialogueUI
func start_dialogue(day: int, context: Dictionary) -> void
signal dialogue_sequence_finished(day: int)
```

```gdscript
# DailyScene -> DialogueUI context keys
{
    "scene_id": String,
    "equipped_items": Array[String],
    "dialogue_context_tags": Array[String]
}
```

Implementation rules:

- Provider return values must be copied deeply enough that UI mutation cannot corrupt provider-owned content.
- Validation errors should identify `sequence_id`, `line_id`, and missing key names.
- Formal provider data should not include prototype-only `text` fields.
- Test fixtures may include prototype `text` only in Dialogue UI fallback tests, not in formal provider acceptance tests.

## Alternatives Considered

### Alternative 1: Formal LightNarrativeDialogue Provider

- **Description**: A dedicated provider owns the seven-day content table, validates content keys, returns deterministic sequence snapshots, and keeps localized text in Godot Translation CSV resources.
- **Pros**: Matches GDD ownership, keeps UI focused on rendering, supports localization, keeps Daily Scene as orchestration, and makes content validation testable.
- **Cons**: Requires one more system boundary and explicit provider integration.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: Dialogue UI Owns Formal Content

- **Description**: Dialogue UI keeps the seven-day content table and resolves text directly while rendering.
- **Pros**: Fewer scripts for the first prototype.
- **Cons**: Makes UI the formal narrative owner, blurs fallback and content responsibilities, complicates localization validation, and contradicts the Light Narrative Dialogue GDD.
- **Rejection Reason**: Rejected because Dialogue UI must not own formal narrative content.

### Alternative 3: Daily Scene Owns Dialogue Content

- **Description**: Daily Scene selects and injects full dialogue sequences into Dialogue UI.
- **Pros**: Daily Scene already knows scene context and visual readiness.
- **Cons**: Gives scene orchestration ownership of narrative content, bypasses the GDD's provider boundary, and makes fallback and validation harder to reuse.
- **Rejection Reason**: Rejected because Daily Scene should provide context, not own formal text.

### Alternative 4: Store Player-Visible Text In Sequence Data

- **Description**: Dialogue sequence data contains localized or default visible text directly.
- **Pros**: Simple to inspect during early prototyping.
- **Cons**: Blocks clean localization, creates duplicate source-of-truth for text, and invites UI code to rely on non-key fields.
- **Rejection Reason**: Rejected for formal content. Prototype-only fallback text may exist only in Dialogue UI fallback tests or emergency development data.

## Consequences

### Positive

- The temporary provider ambiguity is resolved.
- Dialogue UI, Daily Scene, and Light Narrative Dialogue have clear responsibilities.
- Formal content can be validated independently from rendering.
- Localization work has a concrete Godot resource format.
- Runtime fallback keeps the player able to reach GOODNIGHT even if content data is incomplete.
- Deterministic selection makes tests, localization, and QA repeatable.

### Negative

- Implementation must create provider integration before formal dialogue content can replace UI fallback.
- Content authors must manage keys and CSV rows instead of writing visible text directly in sequence data.
- Missing-key behavior must be tested in both provider validation and Dialogue UI runtime fallback.
- Defensive copies add small per-request overhead.

### Risks

- **Risk**: GDDs or stories continue to treat `request_dialogue_sequence(...)` as temporary.  
  **Mitigation**: Sync Dialogue UI, Daily Scene, and Light Narrative Dialogue GDD wording with this ADR.
- **Risk**: UI displays raw keys when localization is missing.  
  **Mitigation**: Dialogue UI tests must cover missing `text_key` and missing Translation entries.
- **Risk**: Content validation runs every request and wastes frame time.  
  **Mitigation**: Full validation runs at startup or test time; request path uses prevalidated tables and cheap fallback checks.
- **Risk**: Clothing flavor drifts into scoring.  
  **Mitigation**: Content validation rejects scoring, correctness, rating, failure, and comparison terms.
- **Risk**: Provider returns mutable shared dictionaries.  
  **Mitigation**: Return defensive-copy snapshots and register the provider state ownership / interface in the architecture registry.
- **Risk**: Localization context support is assumed incorrectly.  
  **Mitigation**: Verify CSV Translation import, context columns, and `tr()` lookup behavior in Godot 4.6 before implementation handoff.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `light-narrative-dialogue.md` | Light Narrative Dialogue is the formal content provider for `request_dialogue_sequence(day, context)`. | Assigns formal ownership to `LightNarrativeDialogue` and makes Dialogue UI the only normal caller. |
| `light-narrative-dialogue.md` | `DialogueSequence` contains `sequence_id`, `day`, `scene_id`, and `lines`; each `DialogueLine` contains stable key fields. | Defines the provider return dictionary shape and required line fields. |
| `light-narrative-dialogue.md` | Formal content must use `text_key`, `speaker_name_key`, and `tr()` path. | Separates sequence data from Godot Translation CSV resources and bans formal visible text in content data. |
| `light-narrative-dialogue.md` | MVP is seven linear days with deterministic, non-scoring flavor. | Requires `1..7` day keys, deterministic fallback, and at most one non-scoring flavor line. |
| `dialogue-ui.md` | Dialogue UI requests content, renders text, advances input, and emits completion without owning progress or transitions. | Keeps Dialogue UI as provider caller and rendering owner, not formal content, state, or progression owner. |
| `dialogue-ui.md` | Missing text keys or provider failure should not trap the player. | Defines provider and UI fallback layers so the player can still reach end confirmation. |
| `daily-scene.md` | Daily Scene provides day, scene, outfit, and dialogue tags context and listens for completion. | Keeps Daily Scene as context provider and GOODNIGHT transition requester, not normal content caller. |
| `main-menu-goodnight-ui.md` | Player-visible UI text must use `tr()` and localization keys. | Aligns dialogue text and speaker names with the same localization path. |

## Performance Implications

- **CPU**: A normal `request_dialogue_sequence(...)` call should stay under 0.5ms on Web, excluding startup/test-time full content validation. Runtime work is day clamp, tag crop, deterministic lookup, optional flavor selection, and defensive copy.
- **Memory**: The seven-day MVP table is small. Returned snapshots allocate small dictionaries and arrays; callers must not retain many historical sequences.
- **Load Time**: Startup may validate all dialogue content and localization keys. This should be bounded and reported as content readiness, not repeated per request.
- **Network**: Not applicable for MVP. Localization and dialogue data are packaged with the Godot Web export.

## Migration Plan

1. Update Dialogue UI, Daily Scene, and Light Narrative Dialogue GDD wording to treat `LightNarrativeDialogue` as the formal provider and Dialogue UI fallback as fallback-only.
2. Implement `LightNarrativeDialogue.request_dialogue_sequence(day, context)`.
3. Add static seven-day provider data with key-only formal lines.
4. Add Godot Translation CSV resources for all dialogue text and speaker name keys.
5. Add provider validation tests for day keys, required fields, line counts, allowed line types, missing localization keys, forbidden scoring language, fallback sequence, and deterministic ordering.
6. Update Dialogue UI integration to call the formal provider first and use its fallback line only when provider data is unavailable or invalid at runtime.
7. Validate long localized strings in Godot live translation preview and Web export.

## Validation Criteria

- `request_dialogue_sequence(day, context)` returns valid sequence dictionaries for days `1..7`.
- Same day/context requests return stable line ordering.
- Missing or invalid days use local fallback without writing ProgressManager or SaveManager.
- Missing `scene_id`, missing `equipped_items`, and missing/long/unknown tags still return playable base content.
- Formal provider never returns `system_hint`.
- Formal provider never returns prototype-only `text` fields in release data.
- Dialogue UI displays localized speaker names and text through `tr()`.
- Missing localization keys do not display raw technical errors to the player.
- Dialogue UI still emits `dialogue_sequence_finished(day)` once.
- Daily Scene remains the component that requests `GameState.request_transition(State.GOODNIGHT)`.

## Related Decisions

- `docs/architecture/adr-0004-scene-transition-and-state-machine-contract.md`
- `docs/architecture/adr-0005-input-gesture-ownership-and-ui-focus-model.md`
- `docs/architecture/adr-0006-presentation-to-gameplay-communication-pattern.md`
- `docs/architecture/adr-0009-audio-event-routing-and-web-unlock-behavior.md`
- `design/gdd/dialogue-ui.md`
- `design/gdd/light-narrative-dialogue.md`
- `design/gdd/daily-scene.md`
- `design/gdd/main-menu-goodnight-ui.md`
