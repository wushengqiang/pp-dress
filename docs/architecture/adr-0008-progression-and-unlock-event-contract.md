# ADR-0008: Progression and Unlock Event Contract

## Status
Proposed

## Date
2026-06-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Progression / UI / Audio |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None directly required by the architecture. Implementation must verify typed signal connections, `await signal`, and Godot 4.6 dual-focus behavior only where UI consumers react to unlock presentation. |
| **Verification Required** | Verify `ProgressManager` emits unlock signals only after successful persistence, `ClothingUnlock` relays confirmed unlock IDs without re-querying progression authority, `WardrobeUI` consumes queued unlock IDs once per session, and `AudioManager` plays `progress.items_unlocked` only from confirmed unlock events. |

Godot 4.6 is post-LLM-cutoff for this project. The checked engine references flag UI/Input as HIGH risk because mouse/touch focus is separate from keyboard/gamepad focus. This ADR relies on that behavior only indirectly: unlock presentation and wardrobe highlight consumers must not assume one focus model covers all input paths.

Deprecated APIs and patterns to avoid:

- Do not use `yield()`; use `await signal`.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not let presentation code query progression internals to reconstruct unlock deltas.
- Do not use a global event bus for MVP unlock distribution.

Engine Specialist Validation: not spawned in this run because no engine-specialist delegation tool was available in the current session. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002: Persistence Ownership and Save Rollback Strategy; ADR-0006: Presentation to Gameplay Communication Pattern |
| **Enables** | `ClothingUnlock`, wardrobe unlock presentation queueing, wardrobe highlight consumption, and audio feedback routing for confirmed unlocks |
| **Blocks** | Implementation stories that need a single authoritative unlock event contract between `ProgressManager`, `ClothingUnlock`, `WardrobeUI`, and `AudioManager` |
| **Ordering Note** | This ADR should be accepted before stories implement unlock presentation, wardrobe one-time highlight consumption, or audio playback keyed from unlock events. |

## Context

### Problem Statement

The project already defines progression authority in `ProgressManager`, and clothing unlock presentation exists as a separate system that should only react to confirmed unlock results. What is still missing is the contract that binds those systems together: who emits the unlock event, what payload it carries, whether UI may reconstruct unlock deltas on its own, and how one-time wardrobe highlight state is handed off without reusing progression authority.

Without this decision, implementation can drift in three bad directions:

1. `WardrobeUI` or `ClothingUnlock` re-derives unlock deltas by querying `WardrobeDatabase` and `ProgressManager`, causing duplicate logic.
2. Presentation code starts polling progression state instead of consuming a confirmed event.
3. Audio and highlight consumers disagree about whether an unlock is authoritative, creating stale or repeated UI feedback.

This decision is needed before implementing the unlock presentation flow, because it defines the boundary between authoritative progression and session-level presentation.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- `ProgressManager` already owns progression rules, persistence commit timing, and `items_unlocked`.
- `ClothingUnlock` already exists in GDD form as a lightweight presenter, not a progression authority.
- `WardrobeUI` already owns item-card highlight presentation and must not become a second unlock authority.
- `AudioManager` must stay event-driven and must not query progression state.
- MVP target is Web, so unlock feedback must remain lightweight and tolerant of missing audio.

### Requirements

- Must keep `ProgressManager` as the single authority for unlock truth.
- Must emit unlock presentation only after `SaveManager.save()` succeeds.
- Must define how `ClothingUnlock` receives and distributes confirmed unlock IDs.
- Must define how `WardrobeUI` consumes new unlock IDs exactly once per session.
- Must define how `AudioManager` is triggered for unlock feedback.
- Must avoid a global event bus for MVP.

## Decision

The project will use a confirmed-event, session-queue unlock contract.

`ProgressManager` remains the only system that determines when new items are unlocked. On successful `advance_day()` persistence, it emits `items_unlocked(item_ids: Array[String])` as the authoritative unlock event.

`ClothingUnlock` is the session-level presenter and relay. It listens to `ProgressManager.items_unlocked(...)`, filters the payload through `WardrobeDatabase.get_item_by_id(...)` for display-only enrichment, and stores the confirmed item IDs in a session queue. It does not compute deltas, does not read `current_day`, does not call `advance_day()`, and does not write `unlock_progress`.

`WardrobeUI` consumes the queued confirmed IDs from `ClothingUnlock`, not from `ProgressManager` directly. It may request the current queued batch when entering a safe UI state, but it must treat the batch as already-authoritative and must not try to rebuild it by comparing current and previous progression state.

`AudioManager` is triggered by `ClothingUnlock` through the existing event key `progress.items_unlocked`. It may play `progress.unlock_soft`, but it does not decide whether an unlock exists.

### Architecture Diagram

```text
ProgressManager.advance_day()
  -> save succeeds
  -> emit items_unlocked(item_ids)
       -> ClothingUnlock queue confirmed IDs
       -> ClothingUnlock optionally queries WardrobeDatabase for display data
       -> ClothingUnlock requests AudioManager.play_event("progress.items_unlocked", context)
       -> WardrobeUI pulls confirmed queue during safe UI state
```

### Key Interfaces

```gdscript
signal items_unlocked(item_ids: Array[String])

func get_newly_unlocked_items() -> Array[String]
func get_confirmed_unlock_queue() -> Array[String]
func consume_confirmed_unlock_queue() -> Array[String]
```

Contract rules:

- `ProgressManager.items_unlocked(item_ids)` is the only authoritative unlock signal.
- `ClothingUnlock` may queue confirmed IDs for the current session, but it must not mutate progression data.
- `WardrobeUI` consumes confirmed IDs from `ClothingUnlock` and displays one-time highlight state.
- `AudioManager` receives `progress.items_unlocked` as a soft feedback request only.

## Alternatives Considered

### Alternative 1: ProgressManager Directly Drives All UI

- **Description**: `ProgressManager` would emit unlocks and also talk directly to wardrobe highlight and audio consumers.
- **Pros**: Fewer moving parts.
- **Cons**: Mixes progression authority with presentation routing and makes `ProgressManager` too broad.
- **Rejection Reason**: Rejected because unlock presentation is a separate concern from progression truth.

### Alternative 2: WardrobeUI Reconstructs Unlock Deltas

- **Description**: `WardrobeUI` would compare old and new progression state and infer new unlocks itself.
- **Pros**: Fewer explicit relay objects.
- **Cons**: Duplicates progression logic, encourages polling, and risks desync with persisted unlock results.
- **Rejection Reason**: Rejected because UI must not re-derive progression authority.

### Alternative 3: Global Unlock Event Bus

- **Description**: Unlocks would be published to a shared dispatcher consumed by UI and audio systems.
- **Pros**: Very decoupled.
- **Cons**: Hides ownership, complicates ordering, and adds infrastructure before MVP needs it.
- **Rejection Reason**: Rejected for MVP.

## Consequences

### Positive

- Unlock truth stays in one place: `ProgressManager`.
- Presentation gets a stable session queue instead of recomputing deltas.
- Wardrobe highlight state can be consumed once and discarded cleanly.
- Audio feedback follows confirmed unlocks only.
- UI code becomes simpler because it reacts to an explicit confirmed batch.

### Negative

- `ClothingUnlock` becomes a small relay layer that must manage queue lifecycle carefully.
- Session-only unlock queues need cleanup on reset, reload, and scene changes.
- `WardrobeUI` still needs a narrow consumption API to pull queued unlock IDs at the right moment.

### Risks

- **Risk**: Presentation re-queries progression and creates duplicate unlock batches.  
  **Mitigation**: Make `WardrobeUI` consume only from `ClothingUnlock` queue APIs and register a forbidden pattern against delta reconstruction.
- **Risk**: Unlock IDs are replayed after scene changes or refreshes.  
  **Mitigation**: Keep the queue session-scoped and clear it on reset or new game.
- **Risk**: Audio plays without a confirmed unlock batch.  
  **Mitigation**: Trigger `progress.items_unlocked` only from the confirmed relay path.
- **Risk**: `ClothingUnlock` drifts into progression authority.  
  **Mitigation**: Keep it read-only on progression state and limit it to queueing, filtering, and dispatch.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `progress-management.md` | `items_unlocked` is emitted only after `SaveManager.save()` succeeds. | Keeps unlock events authoritative and post-persistence only. |
| `progress-management.md` | `ProgressManager` is the only normal writer for `unlock_progress`. | Prevents UI and presenters from writing or repairing unlock state. |
| `clothing-unlock.md` | Clothing unlock only consumes new unlock IDs and does not calculate them. | Defines `ClothingUnlock` as a confirmed-event relay, not a delta calculator. |
| `clothing-unlock.md` | New item highlight is a one-time wardrobe state. | Gives `WardrobeUI` a queue-based consume path for session-only highlighting. |
| `wardrobe-ui.md` | Wardrobe UI depends on `is_item_unlocked(item_id)` for availability and highlight behavior. | Keeps availability authority in `ProgressManager` while highlight consumption comes from the confirmed queue. |
| `audio-management.md` | `progress.items_unlocked` is the unlock feedback event. | Binds audio playback to confirmed unlock dispatch rather than to progression polling. |
| `save-load.md` | Unlock persistence and GOODNIGHT rollback must not expose uncommitted progress. | Unlock presentation only occurs after the committed progression event. |

## Performance Implications

- **CPU**: Negligible. Unlock relay and queue operations are low-frequency and occur only on day completion or reset.
- **Memory**: Session queue is small, storing only a handful of item IDs and optional display metadata.
- **Load Time**: No direct load-time cost beyond signal hookup.
- **Network**: Not applicable.

## Migration Plan

This ADR is written before implementation. Implementation stories should:

1. Keep `ProgressManager.items_unlocked(item_ids)` as the authoritative unlock signal.
2. Implement `ClothingUnlock` as a session queue that consumes confirmed unlock IDs.
3. Add an API for `WardrobeUI` to consume queued unlock IDs once per session.
4. Ensure `WardrobeUI` does not reconstruct unlock deltas from progression state.
5. Route unlock audio through `AudioManager.play_event("progress.items_unlocked", context)`.
6. Clear queued unlock state on reset, new game, and scene lifecycle transitions.
7. Add tests for exactly-once highlight consumption and post-persistence unlock emission.

## Validation Criteria

- Unit tests confirm `ProgressManager.items_unlocked` is emitted only after successful persistence.
- Unit tests confirm `ClothingUnlock` queues confirmed unlock IDs without mutating progression state.
- Unit tests confirm `WardrobeUI` consumes the queued unlock batch and does not reconstruct deltas.
- Unit tests confirm queued unlock IDs are consumed once per session and cleared on reset.
- Integration tests confirm unlock audio is triggered only from confirmed unlock events.
- Static review confirms no UI code reads progression internals to infer unlock deltas.
- Static review confirms no global event bus is introduced for MVP unlock dispatch.

## Related Decisions

- ADR-0002: Persistence Ownership and Save Rollback Strategy
- ADR-0006: Presentation to Gameplay Communication Pattern
- Future ADR: Audio event routing and feedback ownership
- Future ADR: Wardrobe UI highlight lifecycle details

