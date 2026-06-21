# Story 004: 音频、兜底与队列恢复

> **Epic**: 服装解锁
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-4h
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/clothing-unlock.md`  
**Requirement**: `TR-clothing-unlock-001`

**ADR Governing Implementation**: ADR-0008: Progression and Unlock Event Contract; ADR-0009: Audio Event Routing and Web Unlock Behavior  
**ADR Decision Summary**: 解锁提示音是可选的，失败不阻断；未消费队列只存在于本次会话。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify audio fallback and queue persistence in-session on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 音频失败必须静默降级。
- Forbidden: 不得写入长期存档队列。
- Guardrail: 提示关闭不等于高亮丢失。

## Acceptance Criteria

*From GDD `design/gdd/clothing-unlock.md`, scoped to this story:*

- [ ] 可请求 `progress.items_unlocked` 音频事件
- [ ] 音频失败不影响视觉提示
- [ ] 队列可保留到衣橱初始化
- [ ] 玩家关闭提示后高亮仍保留
- [ ] 存档重置会清空会话内队列

## Implementation Notes

*Derived from ADR-0008 / ADR-0009 Implementation Guidelines:*

- 音频是附带的惊喜，不是必须条件。
- 队列只在会话内存在。
- 兜底必须温和，不暴露技术信息。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: unlock trigger timing
- Story 002: item detail cards and validation
- Story 003: wardrobe highlight handoff and consume behavior

## QA Test Cases

**AC-1**: audio is optional
  - Given: an unlock batch arrives
  - When: the system tries to play sound
  - Then: missing audio does not block presentation
  - Edge cases: visual prompt still shows

**AC-2**: queued ids survive until wardrobe is ready
  - Given: wardrobe UI is not initialized yet
  - When: unlock ids arrive
  - Then: they stay in the session queue
  - Edge cases: queue is cleared on new game/reset

**AC-3**: dismissing prompt does not lose highlight
  - Given: the prompt is visible
  - When: the player closes it
  - Then: the ids remain queued for wardrobe highlight
  - Edge cases: they are still one-time only
