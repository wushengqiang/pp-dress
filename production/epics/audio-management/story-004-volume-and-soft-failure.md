# Story 004: 音量换算与非阻断失败

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/audio-management.md`  
**Requirement**: `TR-audio-management-001`

**ADR Governing Implementation**: ADR-0009: Audio Event Routing and Web Unlock Behavior  
**ADR Decision Summary**: 音量与淡入淡出由音频管理统一计算，未知事件、缺失资源和上下文错误都必须软失败。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify bus-level volume math, fade cancellation, and missing-resource logging on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Final volume must stay within safe bounds.
- Forbidden: No sound failure may alter gameplay state.
- Guardrail: Music transitions must fade rather than hard cut.

## Acceptance Criteria

*From GDD `design/gdd/audio-management.md`, scoped to this story:*

- [ ] `effective_volume_db` 计算与 clamp 规则正确
- [ ] `base_volume_db`、`bus_volume_db`、`user_volume_db` 可合并
- [ ] `MUSIC_FADE_SECONDS`、`UI_FADE_SECONDS` 作为淡入淡出规则生效
- [ ] 播放与当前音乐相同的 key 时不重启音乐
- [ ] 未注册事件不播放声音，仅 warning
- [ ] 音频资源缺失或加载失败时静默失败并保留当前状态
- [ ] `progress.items_unlocked` 仅在确认的非空解锁批次后触发

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

- Clamp final playback volume to safe ranges.
- Keep music transitions smooth and cancelable.
- Audio must be best-effort and never act as gameplay authority.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: event routing and event-map selection
- Story 002: pooling, cooldown, and max-instance enforcement
- Story 003: unlock gating and suspend/mute state behavior

## QA Test Cases

**AC-1**: volume math is stable
  - Given: base, bus, and user volume offsets
  - When: the final volume is computed
  - Then: it clamps to the documented safe range
  - Edge cases: UI/SFX must not exceed the UI cap

**AC-2**: music fade behaves correctly
  - Given: a music transition
  - When: the target music changes
  - Then: the current track fades rather than hard-cutting
  - Edge cases: repeated fade requests must cancel the old fade cleanly

**AC-3**: missing resources fail softly
  - Given: a mapped event with a missing resource
  - When: the event is played
  - Then: a warning is logged and gameplay continues without sound
  - Edge cases: current music should remain intact where possible
