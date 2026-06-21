# Story 003: 悬停与失焦取消

> **Epic**: 输入管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/input-management.md`  
**Requirement**: `TR-input-management-001`

**ADR Governing Implementation**: ADR-0005: Input Gesture Ownership and UI Focus Model  
**ADR Decision Summary**: 鼠标悬停与主动手势取消必须可预测；窗口失焦、页面隐藏、场景切换和布局重建都应终止当前手势。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify hover / unhover emission, cancellation reasons, and the active-gesture cleanup path on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Hover feedback must not survive invalid UI state.
- Forbidden: No stale active gesture may survive blur or layout change.
- Guardrail: Cancellation must happen exactly once per interrupted stream.

## Acceptance Criteria

*From GDD `design/gdd/input-management.md`, scoped to this story:*

- [ ] 鼠标进入注册 hover 区域时发出 `hovered`
- [ ] 鼠标离开 viewport 或 hover 区域时发出 `unhovered`
- [ ] `cancel_active_gesture(reason)` 可强制取消当前手势
- [ ] `InputEventScreenTouch.canceled == true` 时取消当前手势
- [ ] 窗口失焦、页面隐藏、场景切换、布局重建时取消当前手势
- [ ] DRAGGING 被中断时发出 `drag_ended(interrupted=true)`
- [ ] POTENTIAL 状态取消时不发 click 或 drag

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

- Hover and active drag are separate states.
- Cancel reasons should be explicit and stable.
- Region cleanup must not leave stale ownership behind.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: region registration and ownership boundary
- Story 002: click/drag/scroll arbitration
- Story 004: focus model and Web canvas default behavior

## QA Test Cases

**AC-1**: hover emits and clears correctly
  - Given: a registered hover region
  - When: the mouse enters and leaves the region or viewport
  - Then: `hovered` and `unhovered` are emitted in the expected order
  - Edge cases: touch inputs must not alter hover state

**AC-2**: cancellation clears active gesture exactly once
  - Given: an active drag
  - When: blur, cancel, scene change, or layout rebuild occurs
  - Then: one interrupted `drag_ended` is emitted and the gesture is cleared
  - Edge cases: repeated cancel calls must not duplicate end events

**AC-3**: cancelled potential gestures do not click
  - Given: a press that has not crossed the drag threshold
  - When: cancellation occurs
  - Then: neither click nor drag is emitted
  - Edge cases: canceled touch starts must behave the same way
