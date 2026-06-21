# Story 001: 解锁批次与展示触发

> **Epic**: 服装解锁
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-4h
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/clothing-unlock.md`  
**Requirement**: `TR-clothing-unlock-001`

**ADR Governing Implementation**: ADR-0008: Progression and Unlock Event Contract; ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 服装解锁只消费进度管理发出的确认批次，在合适时机触发展示流程。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify event consumption and safe presentation timing on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 只消费 confirmed unlock batch。
- Forbidden: 不得自行计算 current_day 或 unlock_progress。
- Guardrail: 空批次必须静默跳过。

## Acceptance Criteria

*From GDD `design/gdd/clothing-unlock.md`, scoped to this story:*

- [ ] 监听 `items_unlocked(Array[String])`
- [ ] 空数组不触发展示
- [ ] 展示只在晚安后/主菜单安全时机出现
- [ ] 不调用 `advance_day()`
- [ ] 不写入进度数据

## Implementation Notes

*Derived from ADR-0008 / ADR-0006 Implementation Guidelines:*

- 解锁事实来源只有进度管理。
- 这层只做展示，不做规则。
- 时机不对就延后，不要抢流程。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: item detail cards and database lookup
- Story 003: wardrobe highlighter handoff and one-time consume
- Story 004: audio, fallback, and queue recovery

## QA Test Cases

**AC-1**: non-empty batches trigger presentation flow
  - Given: a confirmed unlock batch
  - When: it is received
  - Then: presentation flow begins
  - Edge cases: the UI timing remains safe

**AC-2**: empty batches are ignored
  - Given: an empty list of new items
  - When: it arrives
  - Then: nothing is shown
  - Edge cases: no audio event is requested

**AC-3**: no progression writes happen here
  - Given: a valid unlock batch
  - When: the system handles it
  - Then: it does not mutate day/progress
  - Edge cases: only display-side state changes
