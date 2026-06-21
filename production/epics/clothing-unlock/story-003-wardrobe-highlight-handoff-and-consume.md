# Story 003: 衣橱高亮交付与一次性消费

> **Epic**: 服装解锁
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-5h
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/clothing-unlock.md`  
**Requirement**: `TR-clothing-unlock-001`

**ADR Governing Implementation**: ADR-0008: Progression and Unlock Event Contract; ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 新解锁物品会交给衣橱 UI 做一次性高亮，并在玩家看到后消费。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify one-time badge consumption and wardrobe-side handoff on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 高亮必须是一批有效 item id。
- Forbidden: 不得重复显示已消费的高亮。
- Guardrail: 灰色类目也可承接新标记，但不能误导可用性。

## Acceptance Criteria

*From GDD `design/gdd/clothing-unlock.md`, scoped to this story:*

- [ ] `newly_unlocked_item_ids` 交给衣橱 UI
- [ ] 衣橱 UI 可一次性高亮对应卡片
- [ ] 玩家看见后可消费高亮
- [ ] 同一批物品不会反复显示新标记
- [ ] 当前不可见类目也能安全等待消费

## Implementation Notes

*Derived from ADR-0008 / ADR-0006 Implementation Guidelines:*

- 高亮是展示，不是状态真相本身。
- 消费后的高亮应该自然消退。
- 如果衣橱未初始化，需要保留待消费队列。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: unlock batch trigger and safe timing
- Story 002: item detail cards and validation
- Story 004: audio and fallback queue recovery

## QA Test Cases

**AC-1**: wardrobe receives the unlock ids
  - Given: a valid unlock batch
  - When: presentation completes
  - Then: the wardrobe UI receives the ids
  - Edge cases: ids are not mutated in transit

**AC-2**: highlight is consumed once
  - Given: the wardrobe has shown the new badge
  - When: the card is seen
  - Then: the badge is consumed
  - Edge cases: re-entering the wardrobe does not repeat it

**AC-3**: invisible categories can still queue highlights
  - Given: a new item in a hidden category
  - When: it is handed off
  - Then: it remains queued safely
  - Edge cases: it does not imply category availability
