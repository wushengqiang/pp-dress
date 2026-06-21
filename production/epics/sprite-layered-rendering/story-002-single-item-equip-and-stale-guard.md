# Story 002: 单件装备与过期回调防护

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
**ADR Decision Summary**: `equip_item()` 必须在纹理成功后原子更新 texture、z_index 和装备状态，并用 generation/token 忽略过期回调。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify same-frame hot/warm callback handling, generation/token checks, and result signal ordering on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Single-item results must be atomic and observable.
- Forbidden: No partial texture/z-index/state commits on failure.
- Guardrail: Stale callbacks must never overwrite newer visual state.

## Acceptance Criteria

*From GDD `design/gdd/sprite-layered-rendering.md`, scoped to this story:*

- [ ] `equip_item(item_id)` 可触发单件装备
- [ ] 成功时 texture、z_index 和 `_equipped_items` 原子更新
- [ ] `outfit_changed(category, old_item_id, new_item_id)` 在成功时发出
- [ ] `equip_item_completed(..., "equipped", ...)` 在成功时发出
- [ ] 已装备同一物品时返回 `"same_item"`
- [ ] 无效 item 返回 `"invalid_item"`
- [ ] 纹理失败保持旧状态不变并返回 `"texture_failed"`
- [ ] 过期回调被静默丢弃

## Implementation Notes

*Derived from ADR-0007 / ADR-0003 Implementation Guidelines:*

- Register generation and pending targets before requesting textures.
- `TextureCache.get_texture_or_request()` may call back synchronously.
- `equip_item_completed` is the single-item result truth source.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: renderer bootstrap and node validation
- Story 003: batch outfit apply and default outfit
- Story 004: unequip, clear, and query APIs

## QA Test Cases

**AC-1**: successful equip is atomic
  - Given: a valid item with a ready texture
  - When: `equip_item()` is called
  - Then: texture, z-index, and equipped state update together
  - Edge cases: hot/warm synchronous callbacks must still work

**AC-2**: invalid or same-item requests resolve clearly
  - Given: an invalid id or an already-equipped item
  - When: `equip_item()` is called
  - Then: the result status is deterministic and no partial update occurs
  - Edge cases: same-item no-op must not emit redundant visual change

**AC-3**: stale callbacks are ignored
  - Given: a newer equip request supersedes an older one
  - When: the older texture callback arrives late
  - Then: it is discarded and does not change the visual state
  - Edge cases: no stale signal should be emitted
