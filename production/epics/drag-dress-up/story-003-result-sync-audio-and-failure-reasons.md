# Story 003: 结果回写、音频与失败原因

> **Epic**: 拖拽换装
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/drag-dress-up.md`  
**Requirement**: `TR-drag-dress-up-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern; ADR-0007: Sprite Layered Renderer and Outfit State Ownership; ADR-0009: Audio Event Routing and Web Unlock Behavior  
**ADR Decision Summary**: 确认结果回写给衣橱 UI，音频只作为轻反馈，失败原因保持克制且不惩罚。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify soft feedback dispatch, reason mapping, and non-blocking audio failures on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 回写必须以确认结果为准。
- Forbidden: 不得修改进度或存档。
- Guardrail: 音频失败不能阻断装备结果。

## Acceptance Criteria

*From GDD `design/gdd/drag-dress-up.md`, scoped to this story:*

- [ ] 成功后回写 `outfit_apply_result(..., true, equipped_items, "equipped")`
- [ ] 失败按明确 reason 回写
- [ ] 成功时触发轻柔音频事件
- [ ] 音频失败不阻断逻辑
- [ ] 衣橱 UI 在结果回写后同步状态

## Implementation Notes

*Derived from ADR-0006 / ADR-0007 / ADR-0009 Implementation Guidelines:*

- 结果回写是一条清晰的单向确认链。
- 音频是附带反馈，不是业务判定。
- reason 只用于状态语义，不用于评分。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: intent reception and hotzone validation
- Story 002: equip request tokening and renderer confirmation
- Story 004: cleanup, cancellation, and renderer not ready paths

## QA Test Cases

**AC-1**: successful equip syncs back to the wardrobe
  - Given: a confirmed equip result
  - When: the result returns
  - Then: the wardrobe UI receives the new equipped items
  - Edge cases: success audio is optional but should be attempted

**AC-2**: failed outcomes return explicit reasons
  - Given: a rejected apply attempt
  - When: the flow finishes
  - Then: the reason is mapped and returned
  - Edge cases: no punitive feedback is used

**AC-3**: audio failure does not block the result
  - Given: audio is unavailable
  - When: the equip completes
  - Then: the logical result still returns
  - Edge cases: the UI still updates correctly
