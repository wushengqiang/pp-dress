# Story 001: 主菜单与晚安模式

> **Epic**: 主菜单/晚安 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/main-menu-goodnight-ui.md`  
**Requirement**: `TR-main-menu-goodnight-ui-001`

**ADR Governing Implementation**: ADR-0004: Scene Transition and State Machine Contract; ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: UI 根据当前 GameState 状态选择主菜单、完成模式或晚安页，但不拥有状态切换权。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify `_ready()` state reads, hidden/default/completed mode switching, and focus-safe button visibility.

**Control Manifest Rules (this layer)**:
- Required: 只在 MAIN_MENU 或 GOODNIGHT 状态显示对应 UI。
- Forbidden: 不得显示第 8 天或写入进度。
- Guardrail: 通关模式必须与普通模式保持一致的可访问性。

## Acceptance Criteria

*From GDD `design/gdd/main-menu-goodnight-ui.md`, scoped to this story:*

- [ ] `_ready()` 读取 `GameState.current_state` 与 `GameState.get_current_day()`
- [ ] `MAIN_MENU` 显示开始今天、退出等基本入口
- [ ] `GOODNIGHT` 显示晚安收束页
- [ ] `highest_day_completed >= 7` 时进入完成模式
- [ ] 非目标状态时 UI 隐藏

## Implementation Notes

*Derived from ADR-0004 / ADR-0006 Implementation Guidelines:*

- UI 是状态消费者，不是状态拥有者。
- 所有状态展示都要基于只读 facade。
- 完成模式不能意外推进到第 8 天。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: start/continue/retry/quit transition requests
- Story 003: debouncing and state confirmation handling
- Story 004: focus, localization, and edge-case recovery

## QA Test Cases

**AC-1**: main menu shows the expected entrance state
  - Given: `GameState` is in `MAIN_MENU`
  - When: the UI initializes
  - Then: the start and exit controls are visible
  - Edge cases: day values are clamped for display only

**AC-2**: goodnight uses the correct mode
  - Given: `GameState` is in `GOODNIGHT`
  - When: the UI initializes
  - Then: the goodnight summary appears
  - Edge cases: missing outfit context does not block the page

**AC-3**: completed week changes the mode
  - Given: `highest_day_completed >= 7`
  - When: the UI updates
  - Then: the completed mode is shown
  - Edge cases: day 8 is never presented
