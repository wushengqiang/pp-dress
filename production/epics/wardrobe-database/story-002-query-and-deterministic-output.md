# Story 002: 只读查询与确定性输出

> **Epic**: 服装数据库
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/wardrobe-database.md`  
**Requirement**: `TR-wardrobe-database-001`

**ADR Governing Implementation**: ADR-0010: Wardrobe Database Schema and Read-Only Query Contract  
**ADR Decision Summary**: 查全量、按类目、按标签、按 ID、按解锁日和 z-index 的查询都应返回快照，不暴露内部引用，并保持确定性排序。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify deep-copy behavior, deterministic sort order, O(1) lookup intent, and `get_z_index(...)` clamping on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Query methods must remain read-only and return snapshots.
- Forbidden: No consumer mutation of internal dictionaries or arrays.
- Guardrail: Query order must be deterministic across repeated calls.

## Acceptance Criteria

*From GDD `design/gdd/wardrobe-database.md`, scoped to this story:*

- [ ] `get_item_by_id("nonexistent_id")` 返回 `null`
- [ ] `get_items_by_category("hair")` 仅返回 `category == "hair"` 的物品
- [ ] `get_items_by_category("hair")` 的结果按 `sort_order` 升序排列
- [ ] `get_items_by_category("hair")` 与 `get_all_items()` 过滤后的结果一致
- [ ] `get_unlocked_items(1)` 仅返回 `unlock_day == 1` 的物品
- [ ] `get_unlocked_items(3)` 仅包含 `unlock_day <= 3` 的物品
- [ ] `get_unlocked_items(6)` 包含 `unlock_day == 6` 的物品
- [ ] `get_z_index(get_item_by_id("accessory_scarf_front")) == 7`
- [ ] `get_z_index(get_item_by_id("top_white_tee")) == 4`
- [ ] `get_items_by_tag("cute")` 返回所有包含该标签的物品
- [ ] `get_all_items()` 按类目分组并保持确定性排序
- [ ] 修改任意查询方法返回的 Dict/Array，不影响数据库内部状态

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Return defensive copies from every public query method.
- Keep lookup structures private.
- Use stable ordering with deterministic tiebreakers.
- `get_z_index()` must resolve override first and then clamp to `1..10`.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: startup file loading and basic schema bootstrap
- Story 003: failure-path validation for malformed schemas and missing required fields
- Story 004: non-blocking warnings, safe defaults, and performance boundary checks

## QA Test Cases

**AC-1**: missing item lookup is safe
  - Given: a loaded database
  - When: `get_item_by_id("nonexistent_id")` is called
  - Then: the result is `null`
  - Edge cases: repeated calls must not mutate internal state

**AC-2**: category filtering is exact and ordered
  - Given: a loaded database with multiple `hair` items
  - When: `get_items_by_category("hair")` is called
  - Then: every result has `category == "hair"` and the list is sorted by `sort_order`
  - Edge cases: same-sort-order tie behavior is covered in Story 004

**AC-3**: unlock-day filtering is inclusive
  - Given: a loaded database
  - When: `get_unlocked_items(1)`, `get_unlocked_items(3)`, and `get_unlocked_items(6)` are called
  - Then: each call returns only items whose `unlock_day <= day`
  - Edge cases: `day=0` is covered in Story 004

**AC-4**: z-index resolution is correct
  - Given: a loaded database
  - When: `get_z_index(...)` is called for the named sample items
  - Then: override and default values resolve to the expected z-index
  - Edge cases: clamping boundaries are covered in Story 004

**AC-5**: query results are deep copies
  - Given: a loaded database
  - When: a returned Dict/Array is modified by the caller
  - Then: a fresh query returns the original unmodified data
  - Edge cases: nested structures must also remain isolated
