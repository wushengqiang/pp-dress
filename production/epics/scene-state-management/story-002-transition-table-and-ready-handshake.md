# Story 002: 状态转换表与场景就绪握手

> **Epic**: 场景/状态管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/scene-state-management.md`  
**Requirement**: `TR-scene-state-001`

**ADR Governing Implementation**: ADR-0001: Autoload Order and Boot Orchestration; ADR-0004: Scene Transition and State Machine Contract  
**ADR Decision Summary**: 合法状态转换必须通过明确的表驱动校验，场景变更在新场景 `_ready()` 后才提交并广播。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify `change_scene_to_file()`, `_on_scene_ready()`, and `state_changed` timing on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Transitions must be validated before scene change.
- Forbidden: No immediate post-change state commit.
- Guardrail: Scene-ready callback must be matched to the pending transition.

## Acceptance Criteria

*From GDD `design/gdd/scene-state-management.md`, scoped to this story:*

- [ ] `request_transition(to_state, transition_context)` 作为唯一正常入口存在
- [ ] 合法状态转换被允许，非法状态转换被拒绝
- [ ] `is_transitioning == true` 时第二次转换请求被拒绝
- [ ] `change_scene_to_file()` 被调用后，状态不会立即提交
- [ ] 新场景 `_ready()` 调用 `_on_scene_ready()` 后才发出 `state_changed`
- [ ] `state_changed(from, to)` 参数与实际转换一致
- [ ] `state_changed` 携带的 context 是深拷贝

## Implementation Notes

*Derived from ADR-0001 / ADR-0004 Implementation Guidelines:*

- Transition commit happens only after scene readiness confirmation.
- Illegal transitions must not emit `state_changed`.
- The destination scene must confirm minimal safe initialization.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: BOOT orchestration and readiness checks
- Story 003: recovery, cancel, error routing, and quit handling
- Story 004: current_day facade, context rules, and timeout guard

## QA Test Cases

**AC-1**: legal transitions commit after readiness
  - Given: a legal transition request
  - When: the destination scene calls `_on_scene_ready()`
  - Then: `state_changed` is emitted exactly once
  - Edge cases: invalid scene-state callbacks must be ignored

**AC-2**: illegal transitions are rejected
  - Given: an invalid from/to pair
  - When: `request_transition()` is called
  - Then: it returns false and emits nothing
  - Edge cases: re-entrant requests while transitioning must fail

**AC-3**: context is copied safely
  - Given: transition context data
  - When: the transition commits
  - Then: listeners receive a deep copy
  - Edge cases: later mutations must not affect GameState internal context
