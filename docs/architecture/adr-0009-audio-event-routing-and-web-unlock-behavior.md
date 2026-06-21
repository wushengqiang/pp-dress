# ADR-0009: Audio Event Routing and Web Unlock Behavior

## Status
Accepted

## Date
2026-06-20

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Audio / Web Platform |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/audio.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0001-autoload-order-and-boot-orchestration.md`, `docs/architecture/adr-0006-presentation-to-gameplay-communication-pattern.md`, `docs/architecture/adr-0008-progression-and-unlock-event-contract.md` |
| **Post-Cutoff APIs Used** | None directly. Godot 4.6 audio references list no audio-specific breaking changes in 4.4-4.6. Implementation relies on stable `AudioStreamPlayer`, `AudioServer`, audio buses, typed signal connections, and `await signal` patterns. |
| **Verification Required** | Verify Godot 4.6 Web export audio unlock on first player gesture, bus setup, SFX/UI pool limits, music fade cancellation, mute/suspended behavior, missing-resource failure paths, and that no downstream system creates raw audio players or treats audio playback as gameplay success. |

Godot 4.6 is post-LLM-cutoff for this project. The checked audio module reference does not identify audio API breaking changes in Godot 4.4, 4.5, or 4.6, but browser autoplay restrictions and background-tab behavior remain platform risks that must be validated on target Web builds.

Deprecated APIs and patterns to avoid:

- Do not use `yield()`; use `await signal`.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not create new `AudioStreamPlayer` nodes per short sound at runtime; use a bounded pool.
- Do not use audio event routing as a generic MVP gameplay event bus.

Engine Specialist Validation: not spawned in this run because the current tool policy only allows sub-agent spawning when the user explicitly requests delegation. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: Autoload Order and Boot Orchestration; ADR-0006: Presentation to Gameplay Communication Pattern; ADR-0008: Progression and Unlock Event Contract |
| **Enables** | Implementation stories for `AudioManager`, audio event maps, Web audio unlock handling, UI/SFX bus routing, music transitions, unlock feedback audio, and audio non-blocking failure tests. |
| **Blocks** | Stories that wire audio feedback from main menu, wardrobe UI, dialogue UI, drag dress-up, daily scene, goodnight UI, or clothing unlock before the project has a single accepted audio routing contract. |
| **Ordering Note** | ADR-0006 prevents this ADR from becoming a general UI/gameplay event bus. ADR-0008 constrains `progress.items_unlocked` audio to confirmed non-empty unlock batches. This ADR should be accepted before audio implementation stories or audio event asset specs are marked ready. |

## Context

### Problem Statement

The Audio Management GDD defines audio as a global Core service that receives event intents from UI, gameplay, scene, dialogue, and unlock systems. Without an ADR, implementation can drift into each caller creating its own `AudioStreamPlayer`, passing raw resource paths, directly changing bus volume, replaying stale Web unlock events, or depending on sound playback to confirm gameplay progress.

The project also targets Web, where browser autoplay policies commonly prevent audio playback until a user gesture. That platform behavior must be handled internally by `AudioManager` so other systems can emit soft audio intents without blocking the player flow or exposing technical prompts.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- Target platform is Web with mouse and touch input.
- Audio must support the project's gentle companion tone: quiet, non-punitive, non-fanfare feedback.
- ADR-0006 rejects a global MVP event bus for UI/gameplay communication.
- ADR-0008 allows unlock audio only after `ClothingUnlock` receives a confirmed non-empty unlock batch.
- `AudioManager` may be a Foundation service, but its failure must never block BOOT, state transitions, outfit application, dialogue advancement, or unlock presentation.
- MVP may use a local audio event map directly; future resource-loader integration must not change caller contracts.

### Requirements

- Must expose one stable audio event entry point.
- Must define event key naming and payload boundaries.
- Must route events through audio buses rather than per-node volume ownership.
- Must use bounded SFX/UI player pools for short sounds.
- Must define cooldown and max-instance behavior for repeated events.
- Must define music fade and repeated-music behavior.
- Must handle Web audio unlock without technical UI prompts.
- Must define `READY`, `WAITING_FOR_USER_GESTURE`, `MUTED`, and `SUSPENDED` behavior.
- Must fail softly for unknown events, missing resources, pool exhaustion, and browser audio restrictions.

## Decision

The project will implement audio through a single `AudioManager.play_event(event_key: String, context: Dictionary = {}) -> void` entry point backed by an internal audio event map, audio buses, bounded SFX/UI player pools, music players, and Web unlock state.

Callers emit audio intent keys only. They do not pass raw `AudioStream` resources, resource paths, bus names, node references, or gameplay authority. `AudioManager` owns the mapping from event key to asset key, bus, base volume, cooldown, max instances, queue-before-unlock policy, priority, and fade behavior.

Audio playback is always best-effort. A failed, muted, suspended, unregistered, locked, or browser-blocked sound must not change gameplay results, state transitions, persistence, dialogue, wardrobe selection, or unlock presentation.

### Event Key Contract

Event keys are stable strings grouped by domain:

- `ui.*`
- `wardrobe.*`
- `dialogue.*`
- `scene.*`
- `progress.*`
- `system.*`

MVP keys include:

| Event Key | Normal Caller | Routing Rule |
|-----------|---------------|--------------|
| `ui.menu_entered` | Main menu / Goodnight UI | Queue before Web unlock; soft page-in sound or menu music cue. |
| `ui.menu.start_pressed` | Main menu UI | UI bus; short confirmation; never blocks transition. |
| `ui.menu.exit_pressed` | Main menu UI | UI/SFX bus; soft farewell; never blocks quit fallback. |
| `ui.goodnight_entered` | Goodnight UI | SFX/Music bus; low-energy closure cue. |
| `ui.goodnight.continue_pressed` | Goodnight UI | UI bus; short warm continue sound. |
| `wardrobe.category_pressed` | Wardrobe UI | UI/SFX bus; category tick. |
| `wardrobe.item_pressed` | Wardrobe UI | SFX bus; fabric touch. |
| `wardrobe.item_locked_pressed` | Wardrobe UI | UI/SFX bus; locked feedback with cooldown. |
| `wardrobe.item_drag_started` | Wardrobe UI / DragDressUp wiring | SFX bus; fabric lift; no per-frame drag audio. |
| `wardrobe.outfit_applied` | DragDressUp after confirmed result | SFX bus; success feedback only after accepted outfit result. |
| `dialogue.line_advanced` | Dialogue UI | UI bus; low-interruption page/text advance. |
| `dialogue.line_completed` | Dialogue UI | UI bus; optional subtle prompt. |
| `dialogue.finished_confirmed` | Dialogue UI | UI bus; warm finish confirmation. |
| `scene.daily.entered` | Daily Scene | SFX/Ambience; queue before unlock if needed. |
| `scene.music.daily_generic` | Daily Scene | Music bus; fallback daily loop. |
| `scene.music.day_{n}` | Daily Scene | Music bus; falls back to `scene.music.daily_generic` if undefined. |
| `scene.transition_page` | GameState or routable scene | SFX bus; short page-transition cue. |
| `progress.items_unlocked` | ClothingUnlock only | SFX bus; only after confirmed non-empty unlock batch. |

`context` may contain light parameters such as `day`, `category`, `item_category`, `intensity`, or `is_locked`. `AudioManager` must ignore invalid context fields and must not query or mutate progression, wardrobe, dialogue, scene, save, or input state to repair context.

### Audio Buses

MVP uses these buses:

1. `Master`
2. `Music`
3. `SFX`
4. `UI`

`Ambience` and `Voice` may be reserved, but MVP implementation must not require them unless an accepted follow-up ADR or asset spec scopes that work.

Volume is bus-owned. Callers do not directly set bus volume. `AudioManager` clamps final playback volume:

```text
effective_volume_db = clamp(base_volume_db + bus_volume_db + user_volume_db, -80.0, 0.0)
ui_sfx_volume_db = min(effective_volume_db, MAX_UI_SFX_VOLUME_DB)
```

Default knobs follow the Audio Management GDD:

| Knob | Default |
|------|---------|
| `MASTER_VOLUME_DB` | `0 dB` |
| `MUSIC_VOLUME_DB` | `-10 dB` |
| `UI_VOLUME_DB` | `-8 dB` |
| `SFX_VOLUME_DB` | `-8 dB` |
| `AMBIENCE_VOLUME_DB` | `-18 dB` |
| `MAX_UI_SFX_VOLUME_DB` | `-6 dB` |

### SFX/UI Pooling

`AudioManager` pre-creates a bounded pool of `AudioStreamPlayer` nodes for short UI/SFX events. The MVP default is:

```text
SFX_POOL_SIZE = 8
DEFAULT_MAX_INSTANCES = 2
DEFAULT_EVENT_COOLDOWN_MS = 120
LOCKED_FEEDBACK_COOLDOWN_MS = 300
DRAG_AUDIO_COOLDOWN_MS = 250
```

Rules:

- Runtime short sounds must reuse the pool.
- Pool exhaustion does not create more players.
- Low-priority events are dropped when the pool is full.
- High-priority events may only steal the oldest instance of the same event key.
- No event may steal music players.
- Drag movement must not play per-frame audio; only discrete drag start, optional valid hover, and confirmed result events may play.

### Music Playback

Music is managed separately from the short-sound pool. `AudioManager` owns current music key, target stream, volume, fade state, and repeated-key handling.

Rules:

- Normal music transitions fade rather than hard cut.
- Default music fade duration is `MUSIC_FADE_SECONDS = 1.0`.
- If a new music request arrives during an unfinished fade, cancel the old transition and use current actual volume as the new fade start.
- If requested music key matches the current music key, do not restart playback.
- Missing music resources keep the current music or current silent state and log a warning.
- Per-day music keys such as `scene.music.day_{n}` fall back to `scene.music.daily_generic` if unmapped.

### Web Audio Unlock

On Web exports, `AudioManager` starts in `WAITING_FOR_USER_GESTURE` when browser policy prevents immediate playback. It listens for the first accepted player gesture through approved input/UI paths and then attempts to unlock audio.

Before unlock:

- Music, scene-enter, and page-enter events may queue if their event map sets `allow_queue_before_unlock = true`.
- Hover, drag, locked-click, and rapid short UI/SFX events do not queue.
- The unlock queue is bounded by `MAX_UNLOCK_QUEUE_SIZE = 4`.
- For music events, keep only the newest effective music request.

After unlock:

- Play only the newest valid music event and at most one necessary first UI feedback.
- Do not replay a burst of stale hover, drag, click, or locked feedback sounds.
- If unlock fails, stay in `WAITING_FOR_USER_GESTURE` or degrade silently according to platform behavior.
- Do not show a technical "click to enable audio" prompt in the MVP player flow.

### Audio States

```text
UNINITIALIZED
  -> WAITING_FOR_USER_GESTURE
  -> READY
  -> MUTED
  -> SUSPENDED
```

| State | Meaning | Rules |
|-------|---------|-------|
| `UNINITIALIZED` | Buses, pools, and event map are not ready. | Accept no playback; BOOT must not block on optional audio success. |
| `WAITING_FOR_USER_GESTURE` | Web platform has not unlocked audio. | Queue only allowed music/page events; drop short stale sounds. |
| `READY` | Normal playback is allowed. | Apply event map, cooldown, pool, volume, and fade rules. |
| `MUTED` | Player/system mute is active. | Receive events and update cooldown where appropriate, but output no sound; do not replay missed short sounds on unmute. |
| `SUSPENDED` | Page lost focus, tab backgrounded, or game paused. | Lower or pause music/ambience; do not queue short UI/SFX; restore music with fade on resume. |

### Non-Blocking Failure Rules

`AudioManager` must fail soft:

- Unknown event key: log warning, play nothing.
- Missing UI/SFX resource: log warning, play nothing.
- Missing music resource: log warning, keep current music or silence.
- Pool full: drop low-priority event or steal same-key oldest high-priority event.
- Cooldown active: drop event without queueing.
- Web audio locked: queue only explicitly allowed events.
- Muted/suspended: do not output short sounds and do not later replay them.
- Invalid context: ignore invalid fields and use event defaults.

### Architecture Diagram

```text
UI / Gameplay / Scene / Unlock systems
  -> AudioManager.play_event(event_key, context)
       -> validate event map
       -> apply Web unlock / mute / suspended state
       -> apply cooldown and max_instances
       -> route music event to music player + fade
       -> route UI/SFX event to pooled AudioStreamPlayer
       -> log and soft-fail on missing resources or blocked playback
```

### Key Interfaces

```gdscript
enum AudioState {
    UNINITIALIZED,
    WAITING_FOR_USER_GESTURE,
    READY,
    MUTED,
    SUSPENDED,
}

func play_event(event_key: String, context: Dictionary = {}) -> void
func set_muted(is_muted: bool) -> void
func set_bus_user_volume(bus_name: StringName, volume_db: float) -> void
func get_audio_state() -> AudioState
func notify_user_gesture() -> void
func notify_focus_changed(has_focus: bool) -> void
```

Event map entry shape:

```gdscript
{
    "asset_key": "ui.confirm_soft",
    "bus": &"UI",
    "base_volume_db": -8.0,
    "cooldown_ms": 120,
    "max_instances": 2,
    "priority": "normal",
    "allow_queue_before_unlock": false,
    "is_music": false,
    "fade_seconds": 0.0,
}
```

Contract rules:

- Callers use `play_event(...)`; they do not create audio players.
- Callers use stable event keys; they do not pass raw resource paths.
- Callers do not depend on playback success.
- `progress.items_unlocked` is requested by `ClothingUnlock` only after confirmed non-empty unlock presentation.
- Audio event routing is not a generic gameplay event bus.

## Alternatives Considered

### Alternative 1: Direct AudioManager Entry Point With Internal Event Map

- **Description**: Callers invoke `AudioManager.play_event(event_key, context)`. `AudioManager` owns mapping, buses, pools, Web unlock, music fades, and failure handling.
- **Pros**: Simple call contract, clear audio ownership, matches the Audio Management GDD, keeps gameplay authority out of audio, and avoids a broad event bus.
- **Cons**: Callers know the `AudioManager` interface and event keys; event map maintenance must stay disciplined.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: Godot Signals Broadcast to AudioManager

- **Description**: Each UI/gameplay system emits local signals for audio-worthy moments; scene composition connects them to `AudioManager`.
- **Pros**: Fits Godot signal idioms and can reduce direct Autoload references in some scenes.
- **Cons**: Produces lots of wiring for simple soft feedback, can lose early events if signals are emitted before wiring, and does not remove the need for a central event map.
- **Rejection Reason**: Rejected as the default. Local signals may still feed gameplay results, but the final audio call contract remains `play_event(...)`.

### Alternative 3: Global Event Bus for Audio, UI, and Gameplay

- **Description**: Systems publish events to a global dispatcher; AudioManager subscribes to audio-relevant events.
- **Pros**: Decoupled and flexible for large projects.
- **Cons**: Conflicts with ADR-0006's MVP ban on a global UI/gameplay event bus, hides ordering and ownership, and risks turning audio routing into gameplay authority.
- **Rejection Reason**: Rejected for MVP.

## Consequences

### Positive

- Audio has one owner and one caller-facing entry point.
- UI and gameplay systems remain free of raw audio resources and player-node lifecycle.
- Web autoplay restrictions are isolated inside `AudioManager`.
- Missing audio assets cannot break gameplay flow.
- SFX/UI concurrency and cooldown rules prevent harsh repeated sounds.
- Music behavior is predictable and testable.
- Unlock audio remains tied to confirmed unlock presentation.

### Negative

- The event map becomes a shared contract that must be kept in sync with GDDs and asset specs.
- Direct `AudioManager.play_event(...)` calls still create a known global dependency for soft feedback.
- Future complex ambience or voice systems may require a follow-up ADR if MVP event-map routing becomes too small.
- Web audio unlock behavior can only be fully trusted after browser export testing.

### Risks

- **Risk**: Developers bypass `AudioManager` and create local players in UI scripts.  
  **Mitigation**: Register forbidden patterns and include static review checks in audio implementation stories.
- **Risk**: Audio routing is misused as a gameplay event bus.  
  **Mitigation**: Keep payloads light, forbid gameplay authority in audio context, and reference ADR-0006.
- **Risk**: Web unlock replays stale queued events after the first gesture.  
  **Mitigation**: Queue only allowed events, keep latest music, and play at most one necessary UI feedback.
- **Risk**: Locked or repeated click sounds become irritating.  
  **Mitigation**: Enforce cooldowns, max instances, and low-energy asset direction.
- **Risk**: Missing music creates silence or abrupt change.  
  **Mitigation**: Keep current music or silence, log warning, and do not hard cut to broken state.
- **Risk**: Browser background/resume behavior differs by target browser.  
  **Mitigation**: Add Web focus/suspend/resume smoke tests for target browsers before shipping.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `audio-management.md` | Audio management exposes `play_event(event_key, context = {})`. | Defines `AudioManager.play_event(...)` as the only caller-facing audio entry point. |
| `audio-management.md` | Other systems do not create players, set buses, or pass raw resources. | Makes event keys the caller contract and places players, buses, and resource mapping inside `AudioManager`. |
| `audio-management.md` | MVP uses `Master`, `Music`, `SFX`, and `UI` buses. | Locks the MVP bus set and bus-owned volume rules. |
| `audio-management.md` | SFX/UI playback uses pools, cooldowns, and max-instance limits. | Defines bounded player pools, cooldown drops, and same-key steal behavior. |
| `audio-management.md` | Web unlock waits for first player input and does not replay old short sounds. | Defines `WAITING_FOR_USER_GESTURE`, bounded queueing, latest music retention, and stale short-sound drops. |
| `audio-management.md` | Unknown events and missing assets do not crash or block play. | Defines soft-failure behavior for unregistered events and missing resources. |
| `main-menu-goodnight-ui.md` | Main menu and goodnight UI only send audio events and do not manage audio resources. | Keeps UI callers on event keys such as `ui.menu.start_pressed` and `ui.goodnight_entered`. |
| `wardrobe-ui.md` | Locked and wardrobe interaction feedback is soft and non-punitive. | Routes locked and wardrobe events through cooldown-limited, low-energy UI/SFX events. |
| `dialogue-ui.md` | Dialogue advancement audio must be low-interruption. | Routes dialogue events through short UI bus sounds with low volume and no long-tail loop. |
| `drag-dress-up.md` | Outfit success feedback follows confirmed application, not speculative drag state. | Allows `wardrobe.outfit_applied` only after confirmed result from DragDressUp. |
| `daily-scene.md` | Daily scene can request scene music and soft entry cues. | Defines daily scene music keys and fallback to `scene.music.daily_generic`. |
| `clothing-unlock.md` | Unlock prompt requests `progress.items_unlocked`; audio failure must not block visual prompt. | Keeps unlock audio best-effort and tied to confirmed non-empty unlock presentation. |

## Performance Implications

- **CPU**: Low. Event lookup, cooldown checks, and pool selection must stay below `0.5ms` per discrete event on Web, excluding audio decoding and browser mixer cost.
- **Memory**: Bounded by pre-created short-sound pool and loaded audio streams. MVP default pool is 8 `AudioStreamPlayer` nodes; future asset specs must keep music/SFX memory within the project Web memory ceiling.
- **Load Time**: Bus and pool creation should be part of lightweight startup. Audio asset preloading beyond directly referenced MVP assets requires follow-up asset/resource planning.
- **Network**: None for MVP. Web export must serve packaged assets over the approved HTTP/HTTPS export path; audio playback must not assume network streaming.

## Migration Plan

This ADR is written before implementation. Implementation stories should:

1. Implement `AudioManager` with `play_event(...)`, audio state, event map, bus setup, music player, and SFX/UI pool.
2. Populate the MVP event map from `audio-management.md`.
3. Replace any proposed direct audio playback in UI/gameplay stories with event-key calls.
4. Connect first player gesture/focus notifications from approved UI/input paths to Web unlock and suspend handling.
5. Add cooldown, max-instance, missing-resource, muted, suspended, and Web unlock tests.
6. Generate `/asset-spec system:audio-management` to lock asset keys, file names, lengths, variants, and import settings.
7. Register the AudioManager contract and forbidden patterns in `docs/registry/architecture.yaml` after user approval.

## Validation Criteria

- Unit tests confirm unknown event keys log warning and do not crash.
- Unit tests confirm missing UI/SFX assets fail silently except diagnostics.
- Unit tests confirm missing music assets do not hard cut current music to a broken state.
- Unit tests confirm cooldown and `max_instances` limits.
- Unit tests confirm SFX/UI active players never exceed `SFX_POOL_SIZE`.
- Unit tests confirm repeated current music requests do not restart the loop.
- Unit tests confirm in-progress fades cancel and restart from current volume.
- Web integration tests confirm first user gesture unlocks audio on target browsers.
- Web integration tests confirm pre-unlock hover/drag/click short sounds are not replayed after unlock.
- Web integration tests confirm background/suspend lowers or pauses music and resumes by fade.
- Static review confirms UI/gameplay systems do not instantiate short-sound players directly.
- Static review confirms `progress.items_unlocked` audio is only requested from confirmed `ClothingUnlock` flow.
- Main flow smoke test confirms `MAIN_MENU -> WARDROBE -> DAILY_SCENE -> GOODNIGHT -> MAIN_MENU` continues if audio is muted, locked, or missing assets.

## Related Decisions

- ADR-0001: Autoload Order and Boot Orchestration
- ADR-0006: Presentation to Gameplay Communication Pattern
- ADR-0008: Progression and Unlock Event Contract
- `design/gdd/audio-management.md`
- `design/gdd/clothing-unlock.md`
- `design/gdd/main-menu-goodnight-ui.md`
- `design/gdd/wardrobe-ui.md`
- `design/gdd/dialogue-ui.md`
- `design/gdd/drag-dress-up.md`
- `design/gdd/daily-scene.md`
