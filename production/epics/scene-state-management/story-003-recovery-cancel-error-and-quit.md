# Story 003: 恢复、取消、错误路由与退出

> **Epic**: 场景/状态管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/scene-state-management.md`  
**Requirement**: `TR-scene-state-001`

**ADR Governing Implementation**: ADR-0002: Persistence Ownership and Save Rollback Strategy; ADR-0004: Scene Transition and State Machine Contract  
**ADR Decision Summary**: BOOT 可恢复到 DAILY_SCENE，GOODNIGHT 依赖进度提交成功后才返回主菜单，错误与退出必须按受控路由处理。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify BOOT recovery into DAILY_SCENE, GOODNIGHT rollback behavior, and ERROR/QUIT routing on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Recovery must distinguish valid empty outfits from invalid data.
- Forbidden: No unsafe recovery into DAILY_SCENE.
- Guardrail: Error and quit paths must not leak technical details.

## Acceptance Criteria

*From GDD `design/gdd/scene-state-management.md`, scoped to this story:*

- [ ] BOOT 在 `scene_in_progress == true` 且数据有效时可恢复到 DAILY_SCENE
- [ ] `equipped_items == []` 被保留为明确空穿搭语义
- [ ] `equipped_items` 缺失或无效时不进入 DAILY_SCENE
- [ ] GOODNIGHT → MAIN_MENU 在 `advance_day() == true` 时成功
- [ ] GOODNIGHT → MAIN_MENU 在 `advance_day() == false` 时停留在 GOODNIGHT 未安全结束状态
- [ ] 运行时场景文件缺失可路由到 ERROR
- [ ] MAIN_MENU / GOODNIGHT 可路由到 QUIT

## Implementation Notes

*Derived from ADR-0002 / ADR-0004 Implementation Guidelines:*

- Recovery must respect the persistence contract and not invent a default outfit.
- Failure must keep the player in the low-pressure retry flow.
- Quit must be a terminal state with clear cleanup behavior.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: BOOT readiness checks and initial startup sequencing
- Story 002: legal transition table and ready handshake
- Story 004: current_day facade, transition guard, and context lifetime

## QA Test Cases

**AC-1**: BOOT recovery works only with valid data
  - Given: a saved `scene_in_progress` state and valid outfit data
  - When: BOOT runs
  - Then: it may route directly to DAILY_SCENE
  - Edge cases: invalid or missing outfit data must not recover into DAILY_SCENE

**AC-2**: GOODNIGHT commit failure stays in GOODNIGHT
  - Given: a failed `advance_day()`
  - When: the GOODNIGHT completion flow runs
  - Then: GameState remains in GOODNIGHT and does not enter MAIN_MENU
  - Edge cases: no duplicate save attempt should occur

**AC-3**: error and quit paths are controlled
  - Given: a missing scene file or quit request
  - When: the corresponding transition is invoked
  - Then: the app routes to ERROR or QUIT appropriately
  - Edge cases: player-facing messages should remain non-technical
