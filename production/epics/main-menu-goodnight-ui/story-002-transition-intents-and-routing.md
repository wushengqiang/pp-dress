# Story 002: 转换意图与路由

> **Epic**: 主菜单/晚安 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/main-menu-goodnight-ui.md`  
**Requirement**: `TR-main-menu-goodnight-ui-001`

**ADR Governing Implementation**: ADR-0004: Scene Transition and State Machine Contract; ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 按钮只发出请求，真正的场景转换和进度推进由 GameState 执行。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify typed transition requests and rejection handling on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: `request_transition(...)` 是唯一正常转换入口。
- Forbidden: 不得直接调用 SceneTree 切场景或 advance_day。
- Guardrail: 重复点击必须被去抖。

## Acceptance Criteria

*From GDD `design/gdd/main-menu-goodnight-ui.md`, scoped to this story:*

- [ ] “开始今天”请求进入 WARDROBE
- [ ] “继续/明天见”请求进入 MAIN_MENU
- [ ] “退出”请求进入 QUIT 或等价流程
- [ ] 通关后重玩只发出意图，不直接改 day
- [ ] 转换请求被拒绝时 UI 恢复可用

## Implementation Notes

*Derived from ADR-0004 / ADR-0006 Implementation Guidelines:*

- 状态转换应通过 GameState 走正式入口。
- UI 可以临时锁按钮，但不能假定转换成功。
- Web 端退出失败应降级处理而不是报错。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: mode selection and state-based visibility
- Story 003: debounce and transition lock recovery
- Story 004: focus, text, and layout edge cases

## QA Test Cases

**AC-1**: start today issues a wardrobe request
  - Given: main menu mode is active
  - When: the player presses start
  - Then: the UI requests WARDROBE transition
  - Edge cases: repeated clicks do not duplicate requests

**AC-2**: goodnight continues back to the menu
  - Given: the goodnight page is active
  - When: the player presses continue
  - Then: the UI requests MAIN_MENU transition
  - Edge cases: progress advance still remains outside the UI

**AC-3**: quit uses the guarded path
  - Given: the quit action is available
  - When: the player activates it
  - Then: the UI requests QUIT or the web equivalent
  - Edge cases: web fallback remains gentle
