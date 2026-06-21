# Story 002: 异步请求与重复请求 fan-out

> **Epic**: 资源加载器
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/resource-loader.md`  
**Requirement**: `TR-resource-loader-001`

**ADR Governing Implementation**: ADR-0003: Texture Loading Cache and Web Fallback Strategy  
**ADR Decision Summary**: 冷加载走 `load_threaded_request()`，重复请求去重并向所有等待方回调同一结果。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify threaded loading, callback fan-out, and same-frame hot/warm callback behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Consumer callbacks must be safe on same-frame hits.
- Forbidden: No duplicate engine loads for the same in-flight texture.
- Guardrail: Async request handling must remain bounded per frame.

## Acceptance Criteria

*From GDD `design/gdd/resource-loader.md`, scoped to this story:*

- [ ] `get_texture_or_request(item_id, resolution, callback)` 可用于推荐式聚合请求
- [ ] `request_texture(item_id, resolution)` 可发起异步冷加载
- [ ] 冷缓存请求会调用 `ResourceLoader.load_threaded_request()`
- [ ] 重复的进行中请求会被去重
- [ ] 同一纹理的所有等待方都会收到结果回调
- [ ] HOT / WARM 命中可同步回调
- [ ] `texture_loaded(item_id, resolution)` 在异步完成后发出

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

- Add callbacks before starting the threaded request.
- Downstream systems must set their token or generation before calling the request API.
- Async completion must not overwrite newer local state in consumers.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: tier-1 startup preload and ready flag
- Story 003: eviction and request invalidation
- Story 004: memory estimate and Web fallback policy

## QA Test Cases

**AC-1**: duplicate request fan-out works
  - Given: multiple callers request the same cold texture
  - When: the first threaded load completes
  - Then: every waiting callback receives the same texture
  - Edge cases: a completed HOT/WARM request may resolve synchronously

**AC-2**: asynchronous requests are deduplicated
  - Given: the same item/resolution requested multiple times while loading
  - When: requests are issued
  - Then: only one engine load is started
  - Edge cases: request ordering must not lose any callbacks

**AC-3**: loading signals are emitted
  - Given: a successful async load
  - When: the texture finishes loading
  - Then: `texture_loaded` fires with the correct item and resolution
  - Edge cases: failed loads must not emit the success signal
