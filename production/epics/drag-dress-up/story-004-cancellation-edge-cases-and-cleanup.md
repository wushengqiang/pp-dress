# Story 004: 取消、边界与清理

> **Epic**: 拖拽换装
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/drag-dress-up.md`  
**Requirement**: `TR-drag-dress-up-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern; ADR-0007: Sprite Layered Renderer and Outfit State Ownership  
**ADR Decision Summary**: 取消、离场、渲染器未就绪与坏数据都要安静降级，不留下脏状态。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify cleanup on scene exit and invalid hotzone fallback on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 离开场景时清理 pending token。
- Forbidden: 不得把取消视为失败惩罚。
- Guardrail: 错误路径必须保持温和降级。

## Acceptance Criteria

*From GDD `design/gdd/drag-dress-up.md`, scoped to this story:*

- [ ] WARDROBE 离开时取消 pending 状态
- [ ] 渲染器未就绪时不调用 `equip_item`
- [ ] 无效 item_id / 类目会返回安全失败
- [ ] hotzone 缺失或为零时安全降级
- [ ] 拖拽中断不会写回成功结果

## Implementation Notes

*Derived from ADR-0006 / ADR-0007 Implementation Guidelines:*

- 场景退出时，旧结果不能再写回。
- 取消与失败是不同的玩家体验，输出应分开处理。
- 安全降级优先于硬错误。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: intent reception and hotzone validation
- Story 002: equip request tokening and renderer confirmation
- Story 003: result sync and audio feedback

## QA Test Cases

**AC-1**: scene exit invalidates pending requests
  - Given: an equip request is in flight
  - When: the scene leaves WARDROBE
  - Then: the request is invalidated
  - Edge cases: late callbacks are ignored

**AC-2**: bad data returns soft failures
  - Given: invalid item ids or categories
  - When: the request is processed
  - Then: a safe failure reason is returned
  - Edge cases: no hard crash occurs

**AC-3**: hotzone missing disables application safely
  - Given: the character hotzone cannot be resolved
  - When: the player drops an item
  - Then: the application is cancelled
  - Edge cases: feedback remains gentle
