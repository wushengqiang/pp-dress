# Story 004: 恢复、刷新与边界情况

> **Epic**: 每日场景
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/daily-scene.md`  
**Requirement**: `TR-daily-scene-001`

**ADR Governing Implementation**: ADR-0004: Scene Transition and State Machine Contract; ADR-0011: Dialogue Content Provider and Localization Contract  
**ADR Decision Summary**: 刷新、载入异常、空数据和视口变化都要降级而不是阻塞当日流程。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify refresh recovery, viewport recompute, and emergency fallback tone on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 进入/退出都要能安全恢复。
- Forbidden: 不可显示技术错误式文案。
- Guardrail: 任何迟到回调都不得复活已退出场景。

## Acceptance Criteria

*From GDD `design/gdd/daily-scene.md`, scoped to this story:*

- [ ] 浏览器刷新时可从保存状态恢复
- [ ] 视口变化时会重新计算锚点
- [ ] 缺失背景/角色时使用 fallback
- [ ] 等待中的晚安请求不会重复
- [ ] 视觉和对话 fallback 同时触发时仍保持温和 tone

## Implementation Notes

*Derived from ADR-0004 / ADR-0011 Implementation Guidelines:*

- 恢复逻辑属于 GameState/SaveLoad 边界，DailyScene 只承接。
- 视觉降级不能带来技术错误文案。
- 退出后任何回调都必须静默。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: context reads and scene config selection
- Story 002: character spawning and outfit application
- Story 003: dialogue start and goodnight routing

## QA Test Cases

**AC-1**: refresh recovery restarts safely
  - Given: the browser refreshes during the scene
  - When: the save is restored
  - Then: the scene can be entered again safely
  - Edge cases: it restarts from the saved day/outfit context

**AC-2**: viewport changes are handled
  - Given: the viewport changes size
  - When: layout recalculates
  - Then: anchors and regions update
  - Edge cases: stale anchors are not reused

**AC-3**: fallback paths keep the tone warm
  - Given: background and dialogue resources are missing
  - When: the scene degrades
  - Then: the player still sees a calm, usable scene
  - Edge cases: no broken-resource error text is shown
