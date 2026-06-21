# Story 002: 播放池、冷却与并发限制

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
**ADR Decision Summary**: SFX/UI 声音使用有界播放池、冷却和并发限制，以防止快速操作造成刺耳叠音或节点膨胀。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify `AudioStreamPlayer` reuse, cooldown timing, and instance-stealing rules on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Short sounds must reuse a bounded pool.
- Forbidden: No runtime creation of unbounded audio players.
- Guardrail: High-frequency events must stay soft and bounded.

## Acceptance Criteria

*From GDD `design/gdd/audio-management.md`, scoped to this story:*

- [ ] SFX/UI 播放池存在且可复用
- [ ] `SFX_POOL_SIZE`、`DEFAULT_MAX_INSTANCES`、`DEFAULT_EVENT_COOLDOWN_MS` 可作为调参项工作
- [ ] 快速重复事件可被冷却丢弃
- [ ] 同一事件并发超过上限时按规则丢弃或抢占
- [ ] 不会为每个短音效临时创建新的播放器
- [ ] 拖拽更新不会逐帧播放音频

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

- Pool exhaustion must not create additional players.
- High-priority events may only steal the oldest instance of the same event key.
- Music playback must remain separate from SFX/UI pool ownership.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: event routing and event-map selection
- Story 003: Web unlock and focus-state behavior
- Story 004: volume math, fade cancellation, and missing-resource soft-fail rules

## QA Test Cases

**AC-1**: pool reuse works
  - Given: repeated short UI/SFX events
  - When: events are played back-to-back
  - Then: the bounded pool is reused instead of growing
  - Edge cases: the pool may drop low-priority sounds when full

**AC-2**: cooldown prevents spam
  - Given: a cooldown-enabled event
  - When: it is triggered repeatedly inside the cooldown window
  - Then: only allowed plays are emitted
  - Edge cases: repeated hover or locked feedback must stay soft

**AC-3**: max instance rules hold
  - Given: a max-instance-limited event
  - When: the event is triggered above its concurrency limit
  - Then: the oldest same-key instance may be stolen or the new one may be dropped per priority
  - Edge cases: music instances must never be stolen by SFX/UI requests
