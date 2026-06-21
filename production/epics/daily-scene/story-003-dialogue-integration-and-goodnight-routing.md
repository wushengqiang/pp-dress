# Story 003: 对话接入与晚安路由

> **Epic**: 每日场景
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/daily-scene.md`  
**Requirement**: `TR-daily-scene-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern; ADR-0011: Dialogue Content Provider and Localization Contract; ADR-0004: Scene Transition and State Machine Contract  
**ADR Decision Summary**: 场景在视觉就绪后启动对话，接收完成事件后请求进入 GOODNIGHT。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify dialogue start only once, completion handling, and transition request order on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 对话完成后只请求一次 GOODNIGHT。
- Forbidden: 不得直接推进到 MAIN_MENU。
- Guardrail: 对话 UI 不可缺失时要有 fallback 结束控制。

## Acceptance Criteria

*From GDD `design/gdd/daily-scene.md`, scoped to this story:*

- [ ] 视觉就绪后启动对话 UI
- [ ] 传入 day/context 给对话 UI
- [ ] 接收 `dialogue_sequence_finished(day)`
- [ ] 完成后请求 `GameState.request_transition(State.GOODNIGHT)`
- [ ] 重复完成信号不会重复转场

## Implementation Notes

*Derived from ADR-0006 / ADR-0011 / ADR-0004 Implementation Guidelines:*

- DailyScene 负责承接流程，不负责内容。
- 结束控制必须只出现一次。
- 转场请求被拒绝时应保留温和的重试路径。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: context reads and scene config selection
- Story 002: character spawning and outfit application
- Story 004: recovery, refresh, and viewport edge cases

## QA Test Cases

**AC-1**: dialogue starts only after visuals are ready
  - Given: the scene has built safely
  - When: the character and background are ready
  - Then: the dialogue UI starts
  - Edge cases: a fallback visual still counts as ready

**AC-2**: goodnight is requested once
  - Given: dialogue has finished
  - When: the player confirms the end
  - Then: the scene requests GOODNIGHT
  - Edge cases: duplicate completion signals are ignored

**AC-3**: fallback end control works
  - Given: the dialogue UI is unavailable
  - When: the scene needs to end the day
  - Then: the fallback end control can still request GOODNIGHT
  - Edge cases: player is not trapped
