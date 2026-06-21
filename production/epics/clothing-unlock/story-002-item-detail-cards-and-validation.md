# Story 002: 物品详情卡与数据校验

> **Epic**: 服装解锁
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: 2-4h
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/clothing-unlock.md`  
**Requirement**: `TR-clothing-unlock-001`

**ADR Governing Implementation**: ADR-0008: Progression and Unlock Event Contract; ADR-0010: Wardrobe Database Schema and Read-Only Query Contract  
**ADR Decision Summary**: 解锁展示卡依赖数据库读取服装名称、类目和缩略图，并跳过无效条目。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify database lookups and thumbnail fallback on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 卡片数据必须来自 WardrobeDatabase。
- Forbidden: 不得直接改写物品名或分类。
- Guardrail: 无效条目必须跳过，不阻断其余显示。

## Acceptance Criteria

*From GDD `design/gdd/clothing-unlock.md`, scoped to this story:*

- [ ] `WardrobeDatabase.get_item_by_id(item_id)` 用于详情解析
- [ ] 卡片显示名称、类目和缩略图
- [ ] 无效 item_id 被跳过
- [ ] 缩略图失败时使用占位图
- [ ] 轻柔文案不带奖励/结算语气

## Implementation Notes

*Derived from ADR-0008 / ADR-0010 Implementation Guidelines:*

- 数据解析是只读的。
- 无效数据不应破坏其余展示。
- 详情卡面应保持克制和稳定。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: unlock batch trigger and safe timing
- Story 003: wardrobe highlight handoff and consume behavior
- Story 004: audio, queueing, and fallback handling

## QA Test Cases

**AC-1**: valid ids render detail cards
  - Given: valid unlocked item ids
  - When: the cards are built
  - Then: name/category/thumbnail appear
  - Edge cases: missing thumbnails use placeholders

**AC-2**: invalid ids are ignored
  - Given: a batch with a bad item id
  - When: it is processed
  - Then: the bad id is skipped
  - Edge cases: the rest of the batch still shows

**AC-3**: card copy stays gentle
  - Given: the unlock prompt is visible
  - When: copy is rendered
  - Then: it stays calm and non-judgmental
  - Edge cases: no reward language appears
