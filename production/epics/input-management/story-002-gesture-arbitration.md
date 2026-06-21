# Story 002: 点击、拖拽与滚动仲裁

> **Epic**: 输入管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/input-management.md`  
**Requirement**: `TR-input-management-001`

**ADR Governing Implementation**: ADR-0005: Input Gesture Ownership and UI Focus Model  
**ADR Decision Summary**: 鼠标与触摸被归一化为统一语义，拖拽、点击和滚动必须先仲裁，再进入主动手势状态。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify mouse/touch thresholds, click timeout handling, drag start/update/end semantics, and `_input()` ordering on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Click and drag must be mutually coherent for one active source.
- Forbidden: No long-press MVP signal, no ambiguous half-drag state.
- Guardrail: Gesture processing must stay within the documented frame budget.

## Acceptance Criteria

*From GDD `design/gdd/input-management.md`, scoped to this story:*

- [ ] 鼠标和触摸事件被归一化为 click / drag 语义
- [ ] `mouse_drag_threshold` 与 `touch_drag_threshold` 可设置并 clamp 到安全范围
- [ ] `click_timeout` 可设置并 clamp 到安全范围
- [ ] 距离严格大于阈值时才进入拖拽
- [ ] 阈值内 release 发出 click
- [ ] 超时但未超阈值时不发 MVP 长按信号
- [ ] 同一活跃 source 只允许一个当前手势
- [ ] ScrollContainer 优先时输入流可释放给滚动，不会中途升级为拖拽

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

- Use explicit gesture ownership, not global click interpretation.
- Dragging begins only after threshold and intent arbitration both pass.
- The same UI action must not fire both native GUI and InputManager business paths.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: region registration and item identity boundary
- Story 003: hover and cancellation paths
- Story 004: focus model and Web canvas validation

## QA Test Cases

**AC-1**: click and drag thresholds behave correctly
  - Given: a registered drag/click region
  - When: press, move below threshold, and release within timeout
  - Then: a click is emitted and no drag begins
  - Edge cases: movement exactly equal to threshold must not count as drag

**AC-2**: active source arbitration is exclusive
  - Given: one active pointer source
  - When: a second source starts interaction
  - Then: the second source is ignored until the first ends
  - Edge cases: mouse and touch sources must be tracked independently by key

**AC-3**: scroll can win over drag
  - Given: a scroll-priority region inside a scroll container
  - When: early movement follows the scroll axis
  - Then: the stream is released to scrolling and never upgrades to drag
  - Edge cases: diagonal movement must resolve deterministically
