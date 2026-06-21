# Story 004: UI 焦点与 Web 默认行为边界

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
**ADR Decision Summary**: Godot 4.6 的 hover、pressed、键盘/手柄 focus 必须分开建模；`set_input_as_handled()` 只控制 Godot 事件传播，不保证浏览器 DOM 默认行为。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify dual-focus behavior, disabled/hidden focus cleanup, and Web canvas default behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Focus and hover states must be tracked separately.
- Forbidden: Do not rely on `set_input_as_handled()` as a browser scroll blocker.
- Guardrail: Web canvas policies must be validated in the target browser.

## Acceptance Criteria

*From GDD `design/gdd/input-management.md`, scoped to this story:*

- [ ] `is_hovering()` 仅反映鼠标是否在 viewport 内
- [ ] `mark_input_handled()` 包装 Godot handled 调用用于测试
- [ ] `Viewport.set_input_as_handled()` 仅作为 Godot 传播控制
- [ ] `keyboard_focus` 与 `hover` 可同时存在于不同 Controls 上
- [ ] 隐藏或禁用的 Controls 不应保留可达 focus
- [ ] Web canvas 内拖拽不会触发页面滚动、文本选择、右键菜单或 pinch zoom

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

- Focus semantics must be validated separately from hover and press.
- The browser shell is responsible for DOM-level behavior suppression.
- Tests must cover the exported Web shell, not just the Godot runtime.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: region registration and identity boundary
- Story 002: click/drag/scroll arbitration
- Story 003: hover and cancellation paths

## QA Test Cases

**AC-1**: focus and hover can coexist independently
  - Given: a UI with multiple Controls
  - When: one control has keyboard focus and another is hovered
  - Then: both states remain valid on their respective controls
  - Edge cases: disabled or hidden controls must not remain reachable

**AC-2**: handled input only affects Godot propagation
  - Given: an active drag
  - When: `mark_input_handled()` is called
  - Then: Godot propagation is consumed, but browser default behavior is not assumed blocked
  - Edge cases: the wrapper must be spyable in tests

**AC-3**: Web canvas behavior is clean
  - Given: an exported Web build in the target browser
  - When: dragging inside the canvas
  - Then: page scrolling, text selection, context menu, and pinch zoom do not interfere
  - Edge cases: browser-specific limitations must be recorded explicitly
