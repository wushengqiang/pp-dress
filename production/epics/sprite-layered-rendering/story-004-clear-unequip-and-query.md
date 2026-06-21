# Story 004: 清空、卸下与查询

> **Epic**: 精灵分层渲染
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/sprite-layered-rendering.md`  
**Requirement**: `TR-sprite-layered-rendering-001`

**ADR Governing Implementation**: ADR-0007: Sprite Layered Renderer and Outfit State Ownership; ADR-0003: Texture Loading Cache and Web Fallback Strategy  
**ADR Decision Summary**: 卸下和查询必须稳定、可复制，并始终返回当前渲染器拥有的真实可见状态。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify `get_equipped_items()` ordering, `clear_outfit()` behavior, and empty-slot rendering on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Queries must return copies of renderer-owned state.
- Forbidden: No direct exposure of mutable internal outfit data.
- Guardrail: Clear/unequip operations must settle immediately.

## Acceptance Criteria

*From GDD `design/gdd/sprite-layered-rendering.md`, scoped to this story:*

- [ ] `unequip_category(category)` 可卸下单类目
- [ ] `clear_outfit()` 可卸下全部
- [ ] `get_equipped_items()` 返回当前穿搭快照副本
- [ ] `get_equipped_item_for_category(category)` 可查询单类目装备
- [ ] 空穿搭返回 `[]`
- [ ] 卸下后对应 Sprite2D 恢复空槽纹理与默认 z_index
- [ ] 查询结果不会泄露可变内部引用

## Implementation Notes

*Derived from ADR-0007 / ADR-0003 Implementation Guidelines:*

- Query APIs must be copy-returning.
- Clearing must update the visual state immediately and not hang on textures.
- Empty outfit semantics must remain explicit and deterministic.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: renderer bootstrap and node validation
- Story 002: single-item equip and stale callback handling
- Story 003: batch apply and default outfit

## QA Test Cases

**AC-1**: clear and unequip restore the empty state
  - Given: one or more equipped categories
  - When: `unequip_category()` or `clear_outfit()` is called
  - Then: the corresponding sprite(s) return to the empty slot texture and default z-index
  - Edge cases: empty outfits should remain empty

**AC-2**: queries return current authoritative state
  - Given: an equipped character
  - When: query APIs are called
  - Then: they return the current visible outfit snapshot
  - Edge cases: returned arrays must be copies, not internal references

**AC-3**: query ordering is stable
  - Given: a mixed outfit with overrides
  - When: `get_equipped_items()` is called repeatedly
  - Then: the returned order stays stable and matches current effective z-index
  - Edge cases: same-z categories must use the fixed tie-break order
