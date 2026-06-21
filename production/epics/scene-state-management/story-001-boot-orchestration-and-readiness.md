# Story 001: BOOT 编排与就绪检查

> **Epic**: 场景/状态管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/scene-state-management.md`  
**Requirement**: `TR-scene-state-001`

**ADR Governing Implementation**: ADR-0001: Autoload Order and Boot Orchestration; ADR-0002: Persistence Ownership and Save Rollback Strategy  
**ADR Decision Summary**: GameState 通过 deferred BOOT 执行就绪检查，不在同帧访问后续 Autoload；保存/恢复数据由 SaveManager 与 ProgressManager 的各自职责边界提供。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify Autoload order, deferred `_boot()`, `is_ready/load_error` checks, and no same-frame later-Autoload access on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Boot must be deferred and explicit.
- Forbidden: No same-frame reads of later Autoloads in `_ready()`.
- Guardrail: Startup checks must remain bounded and deterministic.

## Acceptance Criteria

*From GDD `design/gdd/scene-state-management.md`, scoped to this story:*

- [ ] `GameState._ready()` 进入 `BOOT` 状态
- [ ] `GameState._ready()` 不在同帧访问 `SaveManager` / `ProgressManager`
- [ ] BOOT 按 DB → Save → Progress → Resource → Input 顺序检查
- [ ] 各入口系统的 `is_ready` / `load_error` 会被读取
- [ ] 任一入口系统失败时可进入 `ERROR`
- [ ] BOOT 初始化全部成功后可继续进入 MAIN_MENU
- [ ] BOOT 总耗时满足 `<10ms` 预算

## Implementation Notes

*Derived from ADR-0001 / ADR-0002 Implementation Guidelines:*

- Use a deferred or next-frame boot entry.
- Do not solve startup order with mutual `_ready()` calls.
- Keep boot work lightweight and avoid per-frame polling.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: state transition table and scene-ready handshake
- Story 003: recovery, cancel, error routing, and quit handling
- Story 004: current_day facade, context rules, and transition timeout guard

## QA Test Cases

**AC-1**: BOOT starts correctly
  - Given: a fresh game start
  - When: GameState initializes
  - Then: `current_state == BOOT`
  - Edge cases: no same-frame access to later Autoloads should occur

**AC-2**: boot order is deterministic
  - Given: a test harness capturing initialization order
  - When: BOOT runs
  - Then: the recorded order is DB → Save → Progress → Resource → Input
  - Edge cases: failing services must stop the flow deterministically

**AC-3**: startup checks gate progress
  - Given: a failed startup-gated system
  - When: BOOT evaluates readiness
  - Then: it routes to ERROR instead of MAIN_MENU
  - Edge cases: successful startup must still respect the deferred BOOT boundary
