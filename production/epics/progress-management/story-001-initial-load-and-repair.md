# Story 001: 初始化加载与进度修复

> **Epic**: 进度管理
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/progress-management.md`  
**Requirement**: `TR-progress-management-001`

**ADR Governing Implementation**: ADR-0002: Persistence Ownership and Save Rollback Strategy  
**ADR Decision Summary**: ProgressManager 从 SaveManager 读取存档快照，并把天数和完成记录修复到合法范围后再对外提供查询结果。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify `SaveManager` snapshot reads, progression repair, and typed signal connections on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Progress state must be repaired before being exposed.
- Forbidden: Do not let UI or scenes repair progression directly.
- Guardrail: Initial repair should remain bounded and deterministic.

## Acceptance Criteria

*From GDD `design/gdd/progress-management.md`, scoped to this story:*

- [ ] `ProgressManager._ready()` 在 SaveManager 可用后加载进度
- [ ] `is_ready == true` 在修复与缓存初始化完成后成立
- [ ] `current_day` 从 SaveManager 同步
- [ ] `highest_day_completed` 从 SaveManager 同步
- [ ] `current_day` 与 `highest_day_completed` 的非法值被修复到合法范围
- [ ] `progress_loaded` 在初始化完成后发出
- [ ] `_unlocked_items_cache` 在初始化时构建

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- ProgressManager owns progression meaning, not persistence transport.
- Repair must happen before any query API is considered reliable.
- Ready signaling should occur only after cache reconstruction completes.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: query APIs and day/category availability rules
- Story 003: `advance_day()` transaction and persistence commit
- Story 004: unlock queue, category visibility, and reset behavior

## QA Test Cases

**AC-1**: initialization completes after SaveManager is ready
  - Given: a ready SaveManager snapshot
  - When: ProgressManager initializes
  - Then: `is_ready == true`
  - Edge cases: startup should wait for `loaded` when necessary

**AC-2**: invalid stored day values are repaired
  - Given: stored days outside the legal range
  - When: the manager initializes
  - Then: the repaired values are within the legal range
  - Edge cases: recovery must not expose the invalid raw values

**AC-3**: progress_loaded is emitted once
  - Given: progress repair and cache build complete
  - When: initialization finishes
  - Then: `progress_loaded` is emitted exactly once
  - Edge cases: repeated initialization should not duplicate the signal
