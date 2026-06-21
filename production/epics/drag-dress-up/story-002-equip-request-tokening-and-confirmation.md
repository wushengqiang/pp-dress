# Story 002: 装备请求、Token 与确认

> **Epic**: 拖拽换装
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/drag-dress-up.md`  
**Requirement**: `TR-drag-dress-up-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern; ADR-0007: Sprite Layered Renderer and Outfit State Ownership  
**ADR Decision Summary**: 有效意图会调用渲染器装备，并用 token 保护最新请求不被迟到结果覆盖。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify equip completion, same-item no-op, and stale callback guard behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 只有最新 token 可以回写结果。
- Forbidden: 不能把同一件衣服重复当作新成功。
- Guardrail: 渲染器确认之前，UI 不得假定成功。

## Acceptance Criteria

*From GDD `design/gdd/drag-dress-up.md`, scoped to this story:*

- [ ] 有效意图调用 `equip_item(item_id)`
- [ ] 监听 `equip_item_completed(...)`
- [ ] 同物品 no-op 视为轻量结果
- [ ] 最新 token 才能回写
- [ ] 超时后返回受控失败结果

## Implementation Notes

*Derived from ADR-0006 / ADR-0007 Implementation Guidelines:*

- 结果确认是从渲染器回来，不是从 UI 猜出来。
- token 是防止迟到回调污染当前状态的关键。
- no-op 不应该播放成功反馈。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: input intent reception and hotzone checks
- Story 003: result sync, audio feedback, and persistence boundary
- Story 004: cancellation, renderer failures, and cleanup

## QA Test Cases

**AC-1**: valid drop reaches the renderer
  - Given: a drop inside the character hotzone
  - When: the flow continues
  - Then: `equip_item(item_id)` is called
  - Edge cases: stale ids are rejected earlier

**AC-2**: same item is treated as no-op
  - Given: the same item is already equipped
  - When: it is applied again
  - Then: the result is a no-op
  - Edge cases: no success audio is played

**AC-3**: older tokens cannot overwrite newer ones
  - Given: two equip requests in quick succession
  - When: the first result arrives late
  - Then: the older result is ignored
  - Edge cases: only the newest request remains authoritative
