# Story 004: 内存预算与 Web 回退

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
**ADR Decision Summary**: 资源加载器要在预算内工作，并为 Web 环境保留可验证的回退路径和安全失败行为。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify `get_memory_estimate()`, Web-over-HTTP loading assumptions, and fallback responses on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Memory behavior must be measurable.
- Forbidden: No frame-blocking synchronous fallback for runtime cold loads.
- Guardrail: Web fallback must preserve player flow and use placeholders/null callbacks.

## Acceptance Criteria

*From GDD `design/gdd/resource-loader.md`, scoped to this story:*

- [ ] `get_memory_estimate()` 可返回热/暖缓存总占用估算
- [ ] 估算遵循纹理大小与 mipmap 因子规则
- [ ] `_process()` 的轮询受每帧预算约束
- [ ] Web 端资源加载基于 HTTP/HTTPS 场景验证
- [ ] 缺失纹理不阻塞其他资源加载
- [ ] `get_texture()` 在未就绪或冷缺失时返回安全空值
- [ ] 纹理尺寸不符时由下游处理，不在加载器层失败

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

- Prefer preserving flow over blocking on failed loads.
- Keep fallback options available if target-host threaded loading differs.
- Runtime synchronous PNG loading is not an approved fallback.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: startup preload and initial readiness
- Story 002: async request fan-out and callbacks
- Story 003: eviction and pending-request invalidation

## QA Test Cases

**AC-1**: memory estimate is available
  - Given: populated HOT/WARM caches
  - When: `get_memory_estimate()` is called
  - Then: it returns a positive estimate based on cached textures
  - Edge cases: empty cache must return 0

**AC-2**: Web fallback preserves flow
  - Given: a Web deployment where a texture cannot be loaded
  - When: the texture is requested
  - Then: the failure is non-blocking and the caller receives null or placeholder behavior
  - Edge cases: no runtime fallback may block the frame

**AC-3**: frame budget is bounded
  - Given: active async polling in `_process()`
  - When: multiple requests are pending
  - Then: work stays within the documented per-frame budget
  - Edge cases: excess requests should defer to later frames
