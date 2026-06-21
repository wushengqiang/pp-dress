# Story 003: Web 音频解锁与失焦状态

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/audio-management.md`  
**Requirement**: `TR-audio-management-001`

**ADR Governing Implementation**: ADR-0009: Audio Event Routing and Web Unlock Behavior  
**ADR Decision Summary**: Web 音频必须在首次玩家手势后解锁；失焦、静音和后台状态应降低或暂停声音，但不得阻塞流程或补播短音效。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify first-gesture unlock, suspended/muted behavior, and queue-before-unlock processing on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Audio failure must never block gameplay.
- Forbidden: No technical unlock prompts in the player flow.
- Guardrail: Unlock queue must remain bounded and non-explosive.

## Acceptance Criteria

*From GDD `design/gdd/audio-management.md`, scoped to this story:*

- [ ] Web 平台在首次玩家手势前进入等待解锁状态
- [ ] `notify_user_gesture()` 能触发音频解锁尝试
- [ ] 允许排队的事件在解锁前可暂存
- [ ] 点击、hover、拖拽等短音效在解锁前不排队
- [ ] `MUTED` 状态下不输出声音
- [ ] `SUSPENDED` 状态下音乐/氛围可暂停或降低
- [ ] 解锁失败、失焦或静音不会阻塞游戏流程

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

- Unlock is best-effort and non-blocking.
- Short sound bursts should not replay after unlock.
- The browser host remains responsible for DOM-level autoplay constraints.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: event routing and map lookup
- Story 002: pooling, cooldown, and concurrency limits
- Story 004: volume math, fade behavior, and missing-resource handling

## QA Test Cases

**AC-1**: Web unlock gates audio correctly
  - Given: a Web build before first player gesture
  - When: audio events are fired
  - Then: only eligible events may queue and no blocking prompt appears
  - Edge cases: short sounds must not flood the unlock queue

**AC-2**: mute and suspend state silence output
  - Given: muted or suspended audio state
  - When: audio events are played
  - Then: no audible output occurs
  - Edge cases: state changes must not re-play dropped short sounds

**AC-3**: unlock is non-blocking
  - Given: audio is locked or unlock fails
  - When: UI or gameplay proceeds
  - Then: gameplay continues normally
  - Edge cases: no gameplay route may depend on sound playback success
