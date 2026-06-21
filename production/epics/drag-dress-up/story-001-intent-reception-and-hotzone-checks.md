# Story 001: 意图接收与热区判定

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
**ADR Decision Summary**: 拖拽换装只消费衣橱 UI 发来的意图，并先判定落点是否落在角色热区。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify token ownership, hotzone checks, and signal wiring on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 只处理 `item_drag_dropped` / `item_selected_for_equip`。
- Forbidden: 不得重新解析原始输入事件。
- Guardrail: 角色热区外必须视为取消。

## Acceptance Criteria

*From GDD `design/gdd/drag-dress-up.md`, scoped to this story:*

- [ ] 接收 `item_drag_dropped(item_id, position)`
- [ ] 接收 `item_selected_for_equip(item_id)`
- [ ] 角色热区命中才继续应用流程
- [ ] 热区外视为取消，不改状态
- [ ] 不直接读取输入层原始事件

## Implementation Notes

*Derived from ADR-0006 / ADR-0007 Implementation Guidelines:*

- 目标是判断“是否能应用”，不是判断“玩家是否做对了”。
- 点击替代路径不需要落点判定。
- 逻辑层不拥有 UI 卡片状态。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: equip request, tokening, and renderer confirmation
- Story 003: result sync, no-op, timeout, and audio feedback
- Story 004: edge cases, cancellation, and cleanup

## QA Test Cases

**AC-1**: drag intents reach the system
  - Given: the wardrobe UI emits a drop intent
  - When: the system receives it
  - Then: it starts hotzone validation
  - Edge cases: invalid item ids are rejected later

**AC-2**: clicks are treated as alternate apply intents
  - Given: a selected item exists
  - When: the click alternative is triggered
  - Then: the system begins click-apply flow
  - Edge cases: no selected item results in a soft no-op

**AC-3**: outside drops cancel cleanly
  - Given: a drop position outside the character hotzone
  - When: it is evaluated
  - Then: the request is cancelled
  - Edge cases: no outfit state changes occur
