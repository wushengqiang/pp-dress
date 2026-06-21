# Story 001: 序列加载与兜底

> **Epic**: 对话 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/dialogue-ui.md`  
**Requirement**: `TR-dialogue-ui-001`

**ADR Governing Implementation**: ADR-0011: Dialogue Content Provider and Localization Contract; ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 对话 UI 读取当前状态与 day/context，向正式 provider 请求序列，并在失败时进入温和 fallback。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify `tr()` key resolution, fallback line path, and `_ready()` state checks on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 正式文案必须走 provider + localization key。
- Forbidden: 不得在 UI 脚本中硬编码正式剧情文本。
- Guardrail: provider 或本地化失败时仍必须可读完当天片段。

## Acceptance Criteria

*From GDD `design/gdd/dialogue-ui.md`, scoped to this story:*

- [ ] `_ready()` 读取 `GameState.current_state`、`GameState.context`、`GameState.get_current_day()`
- [ ] 当前状态非 `DAILY_SCENE` 时 UI 隐藏或 disabled
- [ ] `LightNarrativeDialogue.request_dialogue_sequence(day, context)` 被调用
- [ ] `text_key` / `speaker_name_key` 通过 `tr()` 解析
- [ ] provider 无效或缺失时走 fallback sequence
- [ ] 空序列进入温和结束路径而不是崩溃

## Implementation Notes

*Derived from ADR-0011 / ADR-0006 Implementation Guidelines:*

- UI 负责消费正式 provider，不负责管理正式内容表。
- fallback 只用于正式 provider 不可用或不可播时。
- 对话 UI 不修正进度，只修正本地阅读状态。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: typewriter display, advancement, and debounce
- Story 003: completion confirmation and dialogue finished signal
- Story 004: layout wrapping, focus states, and accessibility edge cases

## QA Test Cases

**AC-1**: provider request is issued from the UI
  - Given: `GameState` is in `DAILY_SCENE`
  - When: the UI initializes
  - Then: it requests the daily sequence from the formal provider
  - Edge cases: missing `scene_id` still returns a valid day-based sequence

**AC-2**: missing localization does not crash the UI
  - Given: a line with a missing `text_key`
  - When: the UI renders
  - Then: it falls back to safe handling or skips the line
  - Edge cases: all lines invalid should enter fallback completion

**AC-3**: non-DAILY_SCENE state hides the panel
  - Given: the scene is not in `DAILY_SCENE`
  - When: DialogueUI starts
  - Then: the panel remains hidden or disabled
  - Edge cases: stale nodes do not drive transitions
