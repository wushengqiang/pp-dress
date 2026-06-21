# Story 004: 结果同步、确认与响应式边界

> **Epic**: 衣橱 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/wardrobe-ui.md`  
**Requirement**: `TR-wardrobe-ui-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 衣橱 UI 只在收到 `outfit_apply_result(...)` 后更新权威式展示状态，并在取消、失败和视口变化时保持稳定。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify scene-exit cleanup, stale result handling, Control layout adaptation, and touch-target sizing on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 只在结果确认后同步 equipped 状态。
- Forbidden: 不得预先把 intent 当成成功。
- Guardrail: 取消、离开场景、视口变窄时必须安全回收拖拽与选中态。

## Acceptance Criteria

*From GDD `design/gdd/wardrobe-ui.md`, scoped to this story:*

- [ ] `outfit_apply_result(item_id, accepted, equipped_items, reason)` 驱动 equipped 同步
- [ ] `accepted == true` 时使用返回的 `equipped_items` 更新本地展示
- [ ] `accepted == false` 时不伪造装备成功
- [ ] `same_item` 被视为 no-op，不播放失败反馈
- [ ] 切换类目、离开 WARDROBE 或场景变化时可取消拖拽
- [ ] 视口过窄或方向变化时布局切换为上下分区

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- UI 的 confirmed state 必须来自结果信号，不来自本地猜测。
- scene-exit 清理必须让旧结果不能回写已释放 UI。
- 触控热区与角色可见性优先于同屏卡片数量。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: boot path and category shell visibility
- Story 002: grid content, lock cards, and thumbnails
- Story 003: gesture region registration and item intent emission

## QA Test Cases

**AC-1**: confirmed results update the UI
  - Given: a valid equip result from downstream
  - When: `outfit_apply_result(...)` arrives
  - Then: the equipped cards update from the returned list
  - Edge cases: stale results for an old item are ignored after scene exit

**AC-2**: failures do not fake success
  - Given: a rejected outfit apply result
  - When: the UI receives `accepted == false`
  - Then: it does not mark the item as equipped
  - Edge cases: `same_item` does not trigger failure feedback

**AC-3**: responsive layout preserves usability
  - Given: a narrow viewport or orientation change
  - When: the layout refreshes
  - Then: the UI moves to a stacked arrangement and keeps touch targets usable
  - Edge cases: the character remains more visible than the control surface
