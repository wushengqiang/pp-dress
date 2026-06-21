# Story 001: 上下文读取与场景配置

> **Epic**: 每日场景
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/daily-scene.md`  
**Requirement**: `TR-daily-scene-001`

**ADR Governing Implementation**: ADR-0004: Scene Transition and State Machine Contract; ADR-0011: Dialogue Content Provider and Localization Contract  
**ADR Decision Summary**: 每日场景从 GameState 读取 day/context，并按 day 选择安全配置与背景氛围。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify context reads, day clamping, and safe fallback scene config behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: `scene_day` 必须在 1..7 内。
- Forbidden: 不得修正存档或推进天数。
- Guardrail: day 1 配置必须始终可用。

## Acceptance Criteria

*From GDD `design/gdd/daily-scene.md`, scoped to this story:*

- [ ] `_ready()` 读取 `GameState.current_state` 和 `GameState.context`
- [ ] `current_day` 优先来自 context
- [ ] 缺失时回退到 `GameState.get_current_day()`
- [ ] 7 天场景配置可按 day 选择
- [ ] 缺失配置时回退到 day 1 safe fallback

## Implementation Notes

*Derived from ADR-0004 / ADR-0011 Implementation Guidelines:*

- 场景配置选择是显示与编排逻辑，不是进度修复。
- 只要有安全 fallback，就不应卡住玩家。
- context 只消费，不反写。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: character spawning and outfit application
- Story 003: dialogue start and goodnight routing
- Story 004: recovery, refresh, and viewport edge cases

## QA Test Cases

**AC-1**: current day is read safely
  - Given: a saved or live GameState context
  - When: DailyScene initializes
  - Then: it resolves a valid day for the scene
  - Edge cases: illegal day values are clamped locally

**AC-2**: missing scene config falls back
  - Given: a missing daily configuration entry
  - When: the scene resolves it
  - Then: it falls back to the day 1 safe config
  - Edge cases: warnings are logged, gameplay continues

**AC-3**: context is not written back
  - Given: the scene reads GameState context
  - When: it finishes initialization
  - Then: no progress or save write occurs
  - Edge cases: only local display state is changed
