# Story 002: 角色生成与穿搭应用

> **Epic**: 每日场景
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/daily-scene.md`  
**Requirement**: `TR-daily-scene-001`

**ADR Governing Implementation**: ADR-0007: Sprite Layered Renderer and Outfit State Ownership; ADR-0003: Texture Loading Cache and Web Fallback Strategy  
**ADR Decision Summary**: 每日场景实例化角色并应用已确认穿搭，必要时使用安全默认穿搭兜底。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify outfit application order, fallback readiness, and late-signal handling on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 应用 `equipped_items` 或 safe default outfit。
- Forbidden: 不直接加载服装纹理。
- Guardrail: 角色或渲染器未就绪时要能降级。

## Acceptance Criteria

*From GDD `design/gdd/daily-scene.md`, scoped to this story:*

- [ ] 实例化 `Character` 场景
- [ ] 有 `equipped_items` 时调用 `apply_outfit(equipped_items)`
- [ ] 缺失时使用默认穿搭兜底
- [ ] 等待 `outfit_applied(...)` 或安全 ready
- [ ] 角色位置/缩放由 DailyScene 决定

## Implementation Notes

*Derived from ADR-0007 / ADR-0003 Implementation Guidelines:*

- DailyScene 是编排者，不是渲染器内部 owner。
- default outfit 只用于缺失上下文的安全路径。
- 迟到结果在退出后必须忽略。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: context reads and scene config selection
- Story 003: dialogue startup and goodnight request routing
- Story 004: refresh, viewport, and emergency fallback cases

## QA Test Cases

**AC-1**: outfit is applied when context exists
  - Given: valid equipped items in context
  - When: the scene starts
  - Then: the character applies the outfit
  - Edge cases: empty arrays still count as explicit outfit data

**AC-2**: missing outfit context falls back safely
  - Given: no equipped_items context key
  - When: the scene builds
  - Then: a safe default outfit is used
  - Edge cases: progression is not blocked

**AC-3**: late outfit signals do not re-enter state
  - Given: the scene is exiting
  - When: a delayed outfit-applied signal arrives
  - Then: it is ignored
  - Edge cases: dialogue does not restart
