# Story 003: advance_day 事务与持久化提交

> **Epic**: 进度管理
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/progress-management.md`  
**Requirement**: `TR-progress-management-001`

**ADR Governing Implementation**: ADR-0002: Persistence Ownership and Save Rollback Strategy; ADR-0008: Progression and Unlock Event Contract  
**ADR Decision Summary**: `advance_day()` 是唯一写入口，必须在保存成功后才提交可见进度并发出完成/解锁信号。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify transactional persistence ordering, rollback restoration, and signal emission timing on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Progress commits must be atomic to the player.
- Forbidden: No unlock or day-complete signal before persistence succeeds.
- Guardrail: Save failure must restore the previous snapshot cleanly.

## Acceptance Criteria

*From GDD `design/gdd/progress-management.md`, scoped to this story:*

- [ ] `advance_day()` 尝试完成当前天并持久化
- [ ] `advance_day()` 成功时返回 `true`
- [ ] `advance_day()` 失败时返回 `false`
- [ ] 保存成功后才发出 `day_completed`
- [ ] 保存成功后才发出 `items_unlocked`
- [ ] 保存成功后才发出 `day_started`
- [ ] 保存失败时恢复调用前快照
- [ ] 第 7 天不推进到第 8 天

## Implementation Notes

*Derived from ADR-0002 / ADR-0008 Implementation Guidelines:*

- The transaction boundary lives inside `advance_day()`.
- `SaveManager.save()` result determines commit success.
- Unlock signals must only reflect confirmed persistence.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: initial load and repair
- Story 002: read-only query APIs
- Story 004: unlock queue and reset behavior

## QA Test Cases

**AC-1**: successful advance commits day and unlocks
  - Given: a valid current day and save backend
  - When: `advance_day()` succeeds
  - Then: current day and completed day advance appropriately
  - Edge cases: the final day must remain at 7

**AC-2**: failed save rolls back
  - Given: a save failure during `advance_day()`
  - When: the transaction runs
  - Then: the prior snapshot is restored and `false` is returned
  - Edge cases: no completion/unlock signals should be emitted

**AC-3**: signals are post-commit only
  - Given: a successful transaction
  - When: the save completes
  - Then: completion and unlock signals fire after persistence succeeds
  - Edge cases: a failing transaction must stay silent
