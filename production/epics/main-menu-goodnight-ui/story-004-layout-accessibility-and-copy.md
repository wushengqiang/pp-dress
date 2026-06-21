# Story 004: 布局、可访问性与文案

> **Epic**: 主菜单/晚安 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/main-menu-goodnight-ui.md`  
**Requirement**: `TR-main-menu-goodnight-ui-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 文案走本地化、按钮可访问、布局温和且不密集。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify focus rings, localization wrapping, and 44x44 hit targets on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 所有按钮必须支持鼠标、触摸、键盘和手柄。
- Forbidden: 不得使用失败、惩罚或评分语气。
- Guardrail: 文本过长时必须换行或更宽布局。

## Acceptance Criteria

*From GDD `design/gdd/main-menu-goodnight-ui.md`, scoped to this story:*

- [ ] 所有可见文本使用 `tr()` key
- [ ] 所有热区不小于 44x44px
- [ ] hover、pressed、keyboard_focus 可区分
- [ ] 完成提示与晚安文案保持温和
- [ ] 过长本地化文本不溢出

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- UI 重点是“被温柔迎接/安放”的气质。
- 视觉层级要简单，不能像信息密集菜单。
- Web 退出失败时应保留静态告别感。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: state-based mode selection
- Story 002: transition request routing
- Story 003: debounce and recovery handling

## QA Test Cases

**AC-1**: text wraps without breaking layout
  - Given: a long localized label
  - When: it renders in the menu
  - Then: the label wraps or fits cleanly
  - Edge cases: no overlap with primary controls

**AC-2**: focus visuals remain distinct
  - Given: mouse hover and keyboard focus
  - When: controls are interacted with
  - Then: hover, pressed, and focus states are visibly distinct
  - Edge cases: disabled controls do not capture focus

**AC-3**: touch targets are large enough
  - Given: mobile or web touch input
  - When: the user taps buttons
  - Then: the targets are at least 44x44px
  - Edge cases: safe-area margins are respected
