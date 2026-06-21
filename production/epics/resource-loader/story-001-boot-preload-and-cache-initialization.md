# Story 001: 启动预加载与缓存初始化

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
**ADR Decision Summary**: TextureCache 负责启动期 Tier 1 预加载、就绪标记、以及 day-1 THUMB 缓存初始化。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify synchronous `_ready()`, `ResourceLoader.load()`, and `WardrobeDatabase.get_unlocked_items(1)` behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Startup preload must complete without blocking later systems.
- Forbidden: No synchronous runtime cold-load fallback beyond Tier 1.
- Guardrail: Tier 1 should remain bounded and deterministic.

## Acceptance Criteria

*From GDD `design/gdd/resource-loader.md`, scoped to this story:*

- [ ] `TextureCache._ready()` 在启动时执行 Tier 1 预加载
- [ ] `WardrobeDatabase.is_ready == true` 时才执行 Tier 1
- [ ] `WardrobeDatabase.get_unlocked_items(1)` 被用于首日缩略图列表
- [ ] `ResourceLoader.load()` 用于同步加载 THUMB 纹理
- [ ] `is_ready == true` 在 Tier 1 完成后成立
- [ ] `load_error` 记录 Tier 1 中失败的纹理路径
- [ ] `THUMB` 纹理作为常驻缓存可用

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

- `TextureCache` is the sole runtime texture-loading authority.
- Tier 1 must finish during `_ready()` and should not depend on scene logic.
- Missing optional textures should not block other startup loads.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: async cold requests and duplicate request fan-out
- Story 003: HOT/WARM LRU eviction and scene-switch invalidation
- Story 004: memory estimate and Web fallback behavior

## QA Test Cases

**AC-1**: startup preload succeeds
  - Given: a ready WardrobeDatabase and valid day-1 thumbnails
  - When: TextureCache initializes
  - Then: `is_ready == true`
  - Edge cases: one missing optional texture should not prevent the rest from loading

**AC-2**: day-1 thumbnails are loaded
  - Given: day-1 unlock data
  - When: Tier 1 preload runs
  - Then: the thumbnails for day-1 unlocked items are cached
  - Edge cases: empty unlock list should still complete safely

**AC-3**: startup errors are reported
  - Given: a missing or invalid tier-1 texture
  - When: preload runs
  - Then: `load_error` records the failure path
  - Edge cases: successful items continue loading despite a single failure
