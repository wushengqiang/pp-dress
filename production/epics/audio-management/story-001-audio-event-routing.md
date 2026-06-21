# Story 001: 音频事件路由与事件映射

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
**ADR Decision Summary**: 音频通过单一 `play_event()` 入口和稳定事件键路由到预定义的 bus 与资源映射，不由调用方直接创建播放器或指定资源路径。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify typed signal connections, audio bus routing, and event-map lookup behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Callers emit intent, not raw audio resources.
- Forbidden: No downstream system may act as its own audio router.
- Guardrail: Keep event-key contracts stable and low pressure.

## Acceptance Criteria

*From GDD `design/gdd/audio-management.md`, scoped to this story:*

- [ ] `play_event(event_key, context)` 作为统一入口存在
- [ ] `event_key` 按 `ui.*` / `wardrobe.*` / `dialogue.*` / `scene.*` / `progress.*` / `system.*` 分域
- [ ] `context` 仅携带轻量参数，不影响其他系统状态
- [ ] 未注册事件不播放声音，仅记录 warning
- [ ] `Master`、`Music`、`SFX`、`UI` bus 作为 MVP 基础存在
- [ ] 主菜单、衣橱、对话、场景和解锁事件能映射到预定义音频行为

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

- AudioManager owns the event map, buses, and routing rules.
- Callers must not pass raw `AudioStream` objects or resource paths.
- Playback success must never change gameplay results.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: pooling, cooldown, and max-instance enforcement
- Story 003: Web unlock and suspended/muted state behavior
- Story 004: volume math, fade behavior, and missing-resource failure handling

## QA Test Cases

**AC-1**: routing entry point exists
  - Given: an initialized AudioManager
  - When: `play_event()` is called with a valid key
  - Then: the request is routed through the event map
  - Edge cases: invalid context fields must be ignored

**AC-2**: event domains are recognized
  - Given: keys in each supported domain
  - When: each key is played
  - Then: the correct event behavior is selected
  - Edge cases: unknown domains must fall back to warning-only failure

**AC-3**: bus selection is stable
  - Given: mapped UI, SFX, music, and master events
  - When: the events are processed
  - Then: they route to the intended bus
  - Edge cases: callers do not override bus ownership
