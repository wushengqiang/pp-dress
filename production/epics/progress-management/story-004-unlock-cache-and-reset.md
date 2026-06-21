# Story 004: 解锁缓存、类目可见性与重置

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
**ADR Decision Summary**: 解锁缓存和可见类目由进度管理派生与维护，重置时必须完整清空并重新计算。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify unlock queue lifecycle, category visibility derivation, and reset behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Unlock state must be session-safe and derived.
- Forbidden: No UI may recalculate unlock deltas itself.
- Guardrail: Reset must restore a clean initial progression state.

## Acceptance Criteria

*From GDD `design/gdd/progress-management.md`, scoped to this story:*

- [ ] `get_newly_unlocked_items()` 返回当前天数新解锁的物品
- [ ] `advance_day()` 成功后解锁缓存被更新
- [ ] `items_unlocked` 只在成功提交后发出
- [ ] `reset_progress()` 可清空解锁缓存并重新计算
- [ ] `get_visible_categories()` 与天数规则一致
- [ ] `is_category_visible(category)` 在未知类目时返回 false
- [ ] 重置后恢复初始天数、完成记录和解锁状态

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines:*

- ClothingUnlock and WardrobeUI must consume confirmed unlock batches only.
- Reset should clear session-scoped unlock state cleanly.
- Category visibility derives from progression day windows.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: initial load and repair
- Story 002: query APIs and availability
- Story 003: `advance_day()` transaction and persistence

## QA Test Cases

**AC-1**: newly unlocked items are exposed once
  - Given: a successful day advance
  - When: `get_newly_unlocked_items()` is queried
  - Then: it returns the current day’s new items
  - Edge cases: empty unlock days should return an empty array

**AC-2**: reset restores a clean state
  - Given: non-default progress
  - When: `reset_progress()` is called
  - Then: the initial progress state is restored
  - Edge cases: unlock cache and category visibility must also reset

**AC-3**: category visibility is stable
  - Given: the current day changes
  - When: `get_visible_categories()` is queried
  - Then: the category list matches the day window rules
  - Edge cases: unknown categories must be filtered out
