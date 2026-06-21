# Story 002: 逐字显示与输入推进

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
**ADR Decision Summary**: 对话 UI 负责逐字揭示、单次确认只执行一个动作，并支持鼠标/触摸/键盘/手柄推进。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify focus separation, input debounce, and long-line wrapping with the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 单次确认只能补全文本或推进下一行。
- Forbidden: 不得一帧内跳过多行文本。
- Guardrail: hover 不能承载唯一信息，确认输入必须跨设备可用。

## Acceptance Criteria

*From GDD `design/gdd/dialogue-ui.md`, scoped to this story:*

- [ ] 文本默认逐字显示
- [ ] 点击/确认可补全文本
- [ ] 当前行完整后再推进下一行
- [ ] 一次确认最多执行一个动作
- [ ] 鼠标、触摸、键盘、手柄都可推进
- [ ] 快速连续点击不会跳过多条已读文本

## Implementation Notes

*Derived from ADR-0006 / ADR-0011 Implementation Guidelines:*

- 输入推进应与文本完成状态严格分离。
- 逐字逻辑只属于 UI 层，不应把推进结果当成内容规则。
- Button 与 gameplay region 不应对同一动作双重触发。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: sequence loading and provider fallback
- Story 003: end-of-sequence confirmation and completion signal
- Story 004: layout bounds, focus visuals, and narrow viewport recovery

## QA Test Cases

**AC-1**: partial line can be completed with one confirm
  - Given: a partially revealed line
  - When: the player confirms
  - Then: the full line is shown
  - Edge cases: the same confirm does not advance to the next line

**AC-2**: completed line advances one step at a time
  - Given: a fully visible line that is not the last line
  - When: the player confirms
  - Then: the next line appears
  - Edge cases: repeated input is debounced

**AC-3**: multiple input types behave the same
  - Given: mouse, touch, keyboard, and gamepad confirmation
  - When: the player advances dialogue
  - Then: the UI responds identically across devices
  - Edge cases: hover is not required to continue
