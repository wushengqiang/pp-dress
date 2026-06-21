# Story 003: HOT/WARM LRU 与场景切换失效

> **Epic**: 资源加载器
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/resource-loader.md`  
**Requirement**: `TR-resource-loader-001`

**ADR Governing Implementation**: ADR-0003: Texture Loading Cache and Web Fallback Strategy  
**ADR Decision Summary**: HOT/WARM 缓存由项目自维护，FULL 纹理按 LRU 淘汰，场景切换时可主动失效。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify `last_access` handling, `evict_full_textures()`, `cancel_request()`, and cache promotion/demotion logic on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: HOT/WARM behavior must be deterministic.
- Forbidden: No reliance on nonexistent engine cache removal APIs.
- Guardrail: Eviction must preserve THUMB responsiveness.

## Acceptance Criteria

*From GDD `design/gdd/resource-loader.md`, scoped to this story:*

- [ ] HOT 缓存与 WARM 缓存按设计存在
- [ ] FULL 纹理按 LRU 淘汰
- [ ] WARM 命中可提升回 HOT
- [ ] `evict_full_textures()` 会清空 FULL 热/暖缓存
- [ ] `evict_full_textures()` 会清理 FULL 的 pending 请求记录
- [ ] `cancel_request(item_id, resolution)` 可取消进行中的请求
- [ ] `THUMB` 纹理在场景切换时保留

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

- Do not depend on `ResourceLoader.remove_resource_from_cache()`.
- Scene owners may evict FULL textures, but not per-widget instance.
- Cancelled or evicted loads must notify waiting callers with `callback(null)`.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: startup preload and tier-1 initialization
- Story 002: async request fan-out and completion signals
- Story 004: memory estimate and Web fallback behavior

## QA Test Cases

**AC-1**: LRU eviction is stable
  - Given: HOT and WARM FULL caches at capacity
  - When: a new FULL texture is loaded
  - Then: the least recently used FULL entry is demoted or removed per cache rules
  - Edge cases: THUMB entries must not be evicted by FULL pressure

**AC-2**: WARM promotion works
  - Given: a texture in WARM
  - When: it is requested again
  - Then: it is promoted to HOT and returned
  - Edge cases: promotion must keep the cache deterministic

**AC-3**: scene-switch invalidation clears FULL requests
  - Given: pending FULL requests
  - When: `evict_full_textures()` is called
  - Then: pending FULL records are invalidated and callbacks are notified with null
  - Edge cases: THUMB textures remain available
