# Story 003: 结束确认与完成信号

> **Epic**: 对话 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/dialogue-ui.md`  
**Requirement**: `TR-dialogue-ui-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern; ADR-0011: Dialogue Content Provider and Localization Contract  
**ADR Decision Summary**: 当序列结束后，UI 提供温和继续操作，并只通过完成信号把结果交回每日场景。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify signal emission order, scene-exit cleanup, and finish state persistence on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 结束确认只能在序列结束后出现。
- Forbidden: UI 不直接请求 GOODNIGHT。
- Guardrail: 只发一次 `dialogue_sequence_finished(day)`。

## Acceptance Criteria

*From GDD `design/gdd/dialogue-ui.md`, scoped to this story:*

- [ ] 最后一行显示完成后展示继续/晚安操作
- [ ] 确认结束时发出 `dialogue_sequence_finished(day)`
- [ ] 对话 UI 不直接请求 `GameState.request_transition(State.GOODNIGHT)`
- [ ] 重复结束信号不会重复发出
- [ ] 场景离开时会取消计时与输入

## Implementation Notes

*Derived from ADR-0006 / ADR-0011 Implementation Guidelines:*

- 完成信号是给每日场景的，不是给全局状态机的。
- 结束页应保持温和，不进入结算语气。
- 迟到信号必须在 scene-exit 时被忽略。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: provider loading and fallback path
- Story 002: typewriter display and one-action input advance
- Story 004: responsive layout and accessibility recovery

## QA Test Cases

**AC-1**: final line reveals the end control
  - Given: the last dialogue line is fully visible
  - When: the player advances it
  - Then: the UI shows a gentle end control
  - Edge cases: the control remains touchable and readable

**AC-2**: completion is signaled once
  - Given: the sequence has finished
  - When: the player confirms completion
  - Then: `dialogue_sequence_finished(day)` is emitted exactly once
  - Edge cases: repeated clicks are ignored after the first signal

**AC-3**: exiting the scene stops pending work
  - Given: the player leaves the scene mid-dialogue
  - When: the UI is freed
  - Then: timers and callbacks are cancelled
  - Edge cases: no late completion signal fires after exit
