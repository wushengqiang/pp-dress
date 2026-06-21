# Story 003: 批量穿搭与默认穿搭

> **Epic**: 精灵分层渲染
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/sprite-layered-rendering.md`  
**Requirement**: `TR-sprite-layered-rendering-001`

**ADR Governing Implementation**: ADR-0007: Sprite Layered Renderer and Outfit State Ownership; ADR-0003: Texture Loading Cache and Web Fallback Strategy  
**ADR Decision Summary**: `apply_outfit()` and `equip_default_outfit()` must settle as explicit batches, even when some textures fail or are queued.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify batch token semantics, final outfit snapshot ordering, and default-outfit selection behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Batch settle must always terminate in a clear result.
- Forbidden: No hanging batch while waiting for impossible textures.
- Guardrail: Final outfit snapshot must be deterministic.

## Acceptance Criteria

*From GDD `design/gdd/sprite-layered-rendering.md`, scoped to this story:*

- [ ] `apply_outfit(item_ids)` 支持批量装备
- [ ] 非目标类目会被卸下
- [ ] 空数组 `apply_outfit([])` 等同于 `clear_outfit()`
- [ ] 全无效输入也能以 `outfit_applied([])` 结算
- [ ] `equip_default_outfit(day)` 按类目选择最小 `sort_order`
- [ ] 默认穿搭通过 `apply_outfit(default_item_ids)` 结算
- [ ] `outfit_applied(applied_item_ids)` 在批次全部结算后发出

## Implementation Notes

*Derived from ADR-0007 / ADR-0003 Implementation Guidelines:*

- Batch results must reflect the settled current outfit, not only success cases.
- Later batch requests must supersede older unfinished batches.
- Default outfit selection is data-driven from WardrobeDatabase.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: renderer bootstrap and node validation
- Story 002: single-item equip and stale callback handling
- Story 004: unequip / clear / query APIs

## QA Test Cases

**AC-1**: batch apply settles deterministically
  - Given: a mixed outfit list
  - When: `apply_outfit()` runs
  - Then: the final applied outfit is deterministic and `outfit_applied` fires once
  - Edge cases: missing items should not block settlement

**AC-2**: default outfit chooses stable items
  - Given: unlocked items for a day
  - When: `equip_default_outfit(day)` is called
  - Then: each category picks the lowest sort order item
  - Edge cases: sort-order ties must follow the documented id ordering

**AC-3**: empty and all-invalid batches settle
  - Given: `apply_outfit([])` or a fully invalid batch
  - When: the batch runs
  - Then: the renderer settles to an empty outfit and emits `outfit_applied([])`
  - Edge cases: no batch should hang waiting for invalid work
