# Story 003: 去抖、确认与恢复

> **Epic**: 主菜单/晚安 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/main-menu-goodnight-ui.md`  
**Requirement**: `TR-main-menu-goodnight-ui-001`

**ADR Governing Implementation**: ADR-0004: Scene Transition and State Machine Contract; ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 按钮在请求后临时锁定，直到状态切换完成、失败或超时。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify button state restoration and transition timeout behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 第一次请求后临时禁用按钮。
- Forbidden: 不得因为失败而永久卡死。
- Guardrail: 键盘/手柄焦点不可落到隐藏按钮上。

## Acceptance Criteria

*From GDD `design/gdd/main-menu-goodnight-ui.md`, scoped to this story:*

- [ ] 重复点击不会重复请求状态切换
- [ ] 请求失败后按钮恢复可用
- [ ] 进度推进不由 UI 执行
- [ ] 完成模式与普通模式的按钮状态合法
- [ ] 非法 day 只用于显示 clamp，不修正存档

## Implementation Notes

*Derived from ADR-0004 / ADR-0006 Implementation Guidelines:*

- UI 需要容忍状态切换失败。
- 已请求的转换不应永久锁死界面。
- 焦点恢复必须可预测。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: mode switching and visibility
- Story 002: transition request routing
- Story 004: localization and accessibility edge cases

## QA Test Cases

**AC-1**: repeated clicks do not stack
  - Given: a start button is active
  - When: the player clicks it several times quickly
  - Then: only one transition request is sent
  - Edge cases: the button locks briefly after request

**AC-2**: failed transitions restore the UI
  - Given: a transition request is rejected
  - When: the timeout or rejection arrives
  - Then: the buttons become usable again
  - Edge cases: focus is restored to a valid control

**AC-3**: disabled controls remain focus-safe
  - Given: a hidden or disabled control exists
  - When: keyboard/gamepad navigation runs
  - Then: focus skips it
  - Edge cases: the first available control receives focus
