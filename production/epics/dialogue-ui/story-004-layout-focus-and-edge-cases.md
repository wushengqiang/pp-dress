# Story 004: 布局、焦点与边界情况

> **Epic**: 对话 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/dialogue-ui.md`  
**Requirement**: `TR-dialogue-ui-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern; ADR-0011: Dialogue Content Provider and Localization Contract  
**ADR Decision Summary**: 对话 UI 必须在窄屏、长文本和不同焦点路径下保持可读、可交互、可恢复。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify panel coverage, keyboard focus, and long localized strings with the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 面板不得覆盖角色主体过多。
- Forbidden: 不可把 hover 当成唯一信息源。
- Guardrail: 所有按钮/控件热区必须达到 44x44px。

## Acceptance Criteria

*From GDD `design/gdd/dialogue-ui.md`, scoped to this story:*

- [ ] 面板固定在底部，不越过画面中线
- [ ] 所有可交互控件热区不小于 44x44px
- [ ] hover、pressed、keyboard_focus 状态可区分
- [ ] 长文本会自动换行或分页
- [ ] 视口过矮或移动端横屏时布局仍可用
- [ ] 空序列、非法 day、缺失 key 等边界都有安全兜底

## Implementation Notes

*Derived from ADR-0006 / ADR-0011 Implementation Guidelines:*

- 视觉布局优先于局部信息密度。
- 焦点路径应为 keyboard/gamepad 和 pointer 都成立。
- 任何坏数据都应该降级，而不是把玩家卡在对话里。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: sequence loading and localization resolution
- Story 002: typewriter and one-action input advance
- Story 003: completion signal and scene-exit cleanup

## QA Test Cases

**AC-1**: narrow viewports keep the text readable
  - Given: a small or rotated viewport
  - When: the panel lays out
  - Then: text remains readable and controls remain reachable
  - Edge cases: the panel does not cover too much of the character

**AC-2**: focus states stay distinct
  - Given: mouse hover and keyboard focus
  - When: controls are focused
  - Then: hover, pressed, and keyboard focus can be distinguished
  - Edge cases: focus does not disappear on device switching

**AC-3**: invalid content still degrades gracefully
  - Given: missing keys or zero-line sequences
  - When: the UI tries to render them
  - Then: it falls back to a safe line or completion path
  - Edge cases: no broken-resource copy is shown
