# Story 003: 意图接线与卡片手势

> **Epic**: 衣橱 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/wardrobe-ui.md`  
**Requirement**: `TR-wardrobe-ui-001`

**ADR Governing Implementation**: ADR-0005: Input Gesture Ownership and UI Focus Model; ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 衣橱 UI 维护 `region_id -> item_id` 映射，并将点击/拖拽只作为意图发给下游换装系统。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify typed signal connections, hover/click/drag routing, and UI focus separation from native Control actions on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 只对已解锁物品注册可交互热区。
- Forbidden: InputManager 不能携带 `item_id`，UI 不能把命中坐标当作业务身份。
- Guardrail: 拖拽与点击替代流程必须共用同一份身份映射。

## Acceptance Criteria

*From GDD `design/gdd/wardrobe-ui.md`, scoped to this story:*

- [ ] `register_gesture_region(region_id, rect, options)` 为可交互卡片注册热区
- [ ] `region_id -> item_id` 映射由 UI 维护
- [ ] 已解锁物品支持拖拽开始、拖拽更新与拖拽结束
- [ ] 点击已解锁卡片可进入 selected 状态
- [ ] 点击/拖拽输出 `item_selected_for_equip(item_id)` 与 `item_drag_dropped(item_id, position)`
- [ ] 锁定物品与禁用类目不进入 selected / drag 状态

## Implementation Notes

*Derived from ADR-0005 / ADR-0006 Implementation Guidelines:*

- UI 只转译玩家意图，不决定装备是否成功。
- 标准 GUI 与 gameplay gesture 不能重复触发同一业务动作。
- 失效的 `region_id` 必须被丢弃，不可回退到旧卡片或坐标猜测。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: category shell and enabled/disabled class visibility
- Story 002: card content, lock visuals, and thumbnail loading
- Story 004: result synchronization, cancel/reset behavior, and layout edge cases

## QA Test Cases

**AC-1**: region mapping stays UI-owned
  - Given: a rendered wardrobe card
  - When: the UI registers its gesture region
  - Then: the region maps to an `item_id` only inside WardrobeUI
  - Edge cases: InputManager never receives the item identity

**AC-2**: drag intent is emitted only for unlocked items
  - Given: an unlocked wardrobe card
  - When: the player drags it
  - Then: the UI emits `item_drag_dropped(item_id, position)` on drop
  - Edge cases: locked cards do not start drag

**AC-3**: click-to-select works as an alternative path
  - Given: an unlocked wardrobe card
  - When: the player clicks it
  - Then: the card becomes selected
  - Edge cases: selecting a different card replaces the previous selection
