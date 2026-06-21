# Story 003: 进度提交事务与回滚

> **Epic**: 保存/加载
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/save-load.md`  
**Requirement**: `TR-save-load-001`

**ADR Governing Implementation**: ADR-0002: Persistence Ownership and Save Rollback Strategy  
**ADR Decision Summary**: 进度推进是事务边界；保存成功前不得提交可见进度，失败时必须回滚内存状态和持久层字段。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify transactional save ordering, rollback semantics, and signal emission timing on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Progress commits must be atomic from the player's point of view.
- Forbidden: No premature progress signals before persistence succeeds.
- Guardrail: Rollback must preserve the last successful persisted state.

## Acceptance Criteria

*From GDD `design/gdd/save-load.md`, scoped to this story:*

- [ ] `GameState` 在 GOODNIGHT 完成时先清除 `scene_in_progress`
- [ ] `ProgressManager.advance_day()` 作为唯一常规进度推进入口
- [ ] `advance_day()` 的成功或失败可由调用方观察
- [ ] `day_completed`、`items_unlocked`、`day_started` 只在保存成功后发出
- [ ] 保存失败时，`ProgressManager` 与 `SaveManager` 的进度字段都回滚
- [ ] 保存失败时，GameState 只在内存中恢复 `scene_in_progress = true`
- [ ] 失败路径不得再次写入保存后端

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- The GOODNIGHT completion flow is a transaction boundary.
- GameState owns scene flow; ProgressManager owns commit semantics.
- The last successful persisted state must remain the recovery source.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: startup load and save snapshot reading
- Story 002: save/reset mechanics and backend wrappers
- Story 004: bad-save lock, schema mismatch, and web storage failures

## QA Test Cases

**AC-1**: successful commit advances progress
  - Given: a valid current day and unlocked state
  - When: GOODNIGHT completion succeeds
  - Then: progress is advanced and signals are emitted
  - Edge cases: the final day must not advance past the cap

**AC-2**: failed commit rolls back state
  - Given: a backend save failure during `advance_day()`
  - When: the transaction runs
  - Then: runtime progress and SaveManager fields revert to the prior snapshot
  - Edge cases: `scene_in_progress` is only restored in memory by GameState

**AC-3**: no premature progress signals
  - Given: a transaction in progress
  - When: the final save has not yet succeeded
  - Then: no day-completion or unlock signals are emitted
  - Edge cases: failure path must remain silent aside from error reporting
