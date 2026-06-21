# Story 001: 渲染器启动与节点契约

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
**ADR Decision Summary**: Character 场景在准备好六个 Sprite2D、空槽纹理和依赖就绪后才进入可渲染状态，并且不读取 GameState.context。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify same-parent Sprite2D layering, cached node lookup, and typed signal connections on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Six direct-child Sprite2D nodes must exist and share the same base transform contract.
- Forbidden: Do not read GameState.context in _ready().
- Guardrail: Initialization must fail fast on missing dependencies or nodes.

## Acceptance Criteria

*From GDD `design/gdd/sprite-layered-rendering.md`, scoped to this story:*

- [ ] `Character._ready()` 检查 `WardrobeDatabase.is_ready`、`TextureCache.is_ready` 和 `EMPTY_SLOT_FULL`
- [ ] 6 个 Sprite2D 直接子节点按类目命名并存在
- [ ] Sprite2D 的初始 `z_index` 与类目默认值一致
- [ ] 所有精灵的初始纹理为 `EMPTY_SLOT_FULL`
- [ ] `is_ready == true` 在初始化完成后成立
- [ ] `renderer_ready` 在初始化完成后发出
- [ ] `_ready()` 不读取 `GameState.context`

## Implementation Notes

*Derived from ADR-0007 / ADR-0003 Implementation Guidelines:*

- The renderer is a thin visual ownership layer, not a scene orchestrator.
- Missing dependencies must fail early and keep `is_ready == false`.
- Render-node references should be cached in `_ready()`.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: single-item equip result handling and stale callback guards
- Story 003: batch apply, default outfit, and apply completion behavior
- Story 004: unequip / clear / query behavior and ordering

## QA Test Cases

**AC-1**: renderer boots only when dependencies are ready
  - Given: ready dependencies and a valid character scene
  - When: `_ready()` runs
  - Then: `is_ready == true` and `renderer_ready` is emitted
  - Edge cases: missing `EMPTY_SLOT_FULL` should fail fast

**AC-2**: sprite nodes are validated
  - Given: the character scene
  - When: renderer initialization runs
  - Then: all six direct-child Sprite2D nodes exist and are correctly named
  - Edge cases: a missing node should keep the renderer unready

**AC-3**: no context read occurs in _ready()
  - Given: a character instance
  - When: the renderer initializes
  - Then: it does not inspect `GameState.context`
  - Edge cases: scene-specific outfit selection must remain external
