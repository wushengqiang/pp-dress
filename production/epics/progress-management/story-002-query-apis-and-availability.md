# Story 002: 查询 API 与可用性判定

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
**ADR Decision Summary**: ProgressManager 是当前天数、已完成天数、物品解锁和类目可见性的唯一查询层。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify query behavior, typed return shapes, and cache-backed lookups on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Query answers must be authoritative and stable.
- Forbidden: No UI may reconstruct progress truth from raw save data.
- Guardrail: Queries must stay read-only and cheap.

## Acceptance Criteria

*From GDD `design/gdd/progress-management.md`, scoped to this story:*

- [ ] `get_current_day()` 返回当前天数
- [ ] `get_highest_day_completed()` 返回已完成最高天数
- [ ] `get_total_days()` 返回固定总天数 7
- [ ] `is_day_available(day)` 按规则返回可玩性
- [ ] `is_day_completed(day)` 按规则返回完成状态
- [ ] `is_last_day()` 在第 7 天返回 true
- [ ] `is_item_unlocked(item_id)` 以缓存为准
- [ ] `get_unlocked_items(category)` 支持按类目过滤
- [ ] `get_items_for_day(day)` 返回指定天数的解锁记录
- [ ] `is_category_visible(category)` 返回当前类目可见性
- [ ] `get_visible_categories()` 返回当前可见类目列表

## Implementation Notes

*Derived from ADR-0002 / ADR-0008 Implementation Guidelines:*

- Queries must not mutate progress state.
- Unlock truth must remain separate from presentation.
- Category visibility is derived from progression, not wardrobe data.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: initial load and state repair
- Story 003: `advance_day()` persistence and rollback
- Story 004: unlock queue, category visibility persistence, and reset behavior

## QA Test Cases

**AC-1**: day availability behaves correctly
  - Given: a repaired progress state
  - When: `is_day_available()` and `is_day_completed()` are queried
  - Then: the answers match the documented boundary rules
  - Edge cases: day 1, next available day, and day 7 must be covered

**AC-2**: unlock queries are cache-backed
  - Given: a loaded unlock cache
  - When: item and day unlock queries are issued
  - Then: answers are stable and read-only
  - Edge cases: unknown items should return false or empty results safely

**AC-3**: category visibility is derived
  - Given: different current days
  - When: visible-category queries are made
  - Then: the expected category set is returned
  - Edge cases: unknown categories must return false
