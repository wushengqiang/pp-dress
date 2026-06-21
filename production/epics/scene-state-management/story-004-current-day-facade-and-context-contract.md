# Story 004: current_day Facade 与 context 约束

> **Epic**: 场景/状态管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/scene-state-management.md`  
**Requirement**: `TR-scene-state-001`

**ADR Governing Implementation**: ADR-0002: Persistence Ownership and Save Rollback Strategy; ADR-0004: Scene Transition and State Machine Contract  
**ADR Decision Summary**: GameState 通过 ProgressManager 暴露当前天数，并以受控 context 和 transition 守卫支持场景之间的安全通信。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify `get_current_day()`, `context` duplication, and transition timeout behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: current_day must be a facade, not duplicated authority.
- Forbidden: Do not mutate shared context through emitted copies.
- Guardrail: Transition timeout must route to ERROR cleanly.

## Acceptance Criteria

*From GDD `design/gdd/scene-state-management.md`, scoped to this story:*

- [ ] `GameState.get_current_day()` 作为 Facade 返回当前天数
- [ ] `current_day` 异常值在 BOOT 后被修复为合法范围
- [ ] `context` 在 BOOT 时初始化为空 `{}`
- [ ] `context` 可被下游系统在状态转换前写入
- [ ] `context` 在场景切换后仍可读取
- [ ] `is_transitioning` 守卫会阻止并发转换
- [ ] 5 秒超时会将转换路由到 ERROR

## Implementation Notes

*Derived from ADR-0002 / ADR-004 Implementation Guidelines:*

- Progress authority remains with ProgressManager.
- context emitted in `state_changed` must be a deep copy.
- Timeout handling must not rely on `_process()` polling.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: BOOT orchestration and readiness checks
- Story 002: transition table and ready handshake
- Story 003: recovery, cancel, error routing, and quit handling

## QA Test Cases

**AC-1**: current day facade works
  - Given: loaded progression data
  - When: `GameState.get_current_day()` is called
  - Then: it returns the repaired current day
  - Edge cases: invalid stored values must be normalized before exposure

**AC-2**: context survives scene handoff
  - Given: context written before a valid transition
  - When: the new scene becomes ready
  - Then: the context is still available to the new state
  - Edge cases: emitted context copies must not mutate the source

**AC-3**: transition timeout is enforced
  - Given: a transition that never receives `_on_scene_ready()`
  - When: the timeout elapses
  - Then: GameState routes to ERROR
  - Edge cases: duplicate timeout handling must not emit duplicate commits
