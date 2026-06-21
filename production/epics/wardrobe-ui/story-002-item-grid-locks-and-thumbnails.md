# Story 002: 物品网格、锁定态与缩略图

> **Epic**: 衣橱 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 3-5h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/wardrobe-ui.md`  
**Requirement**: `TR-wardrobe-ui-001`

**ADR Governing Implementation**: ADR-0003: Texture Loading Cache and Web Fallback Strategy; ADR-0006: Presentation to Gameplay Communication Pattern  
**ADR Decision Summary**: 物品卡片的缩略图只通过 TextureCache 获取，锁定态与装备态只作为展示结果，不在 UI 内部伪造权威状态。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify async texture callbacks, placeholder fallback, and Control redraw behavior for large item grids on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 每张卡片都必须能表达 available / locked / equipped / selected 状态。
- Forbidden: 不得绕过 TextureCache 直接读纹理文件。
- Guardrail: 缩略图未就绪时必须安全退化为占位图。

## Acceptance Criteria

*From GDD `design/gdd/wardrobe-ui.md`, scoped to this story:*

- [ ] `WardrobeDatabase.get_items_by_category(category)` 驱动物品网格
- [ ] 已解锁物品显示缩略图、名称和状态
- [ ] 未解锁物品显示锁定卡片与 `unlock_day`
- [ ] `TextureCache.get_texture_or_request(item_id, THUMB, callback)` 用于缩略图加载
- [ ] 缩略图未完成或失败时显示占位图
- [ ] 空类目显示温和空状态，不报错

## Implementation Notes

*Derived from ADR-0003 / ADR-0006 Implementation Guidelines:*

- 卡片文字只使用数据库定义名称，不自行改写业务文本。
- 缩略图加载失败不应改变可用性判断。
- UI 不在本地推断装备是否成功，只显示来自上游的状态快照。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: class category shell and dependency-ready boot path
- Story 003: input region registration and item intent emission
- Story 004: outfit result sync, confirmation state, and responsive layout edge cases

## QA Test Cases

**AC-1**: unlocked cards display textures when available
  - Given: a category with unlocked items and cached thumbnails
  - When: the grid renders
  - Then: each card shows its thumbnail, name, and available state
  - Edge cases: missing textures fall back to the placeholder

**AC-2**: locked cards surface unlock information
  - Given: an item whose `unlock_day` is in the future
  - When: the grid renders
  - Then: the card is visibly locked and shows the unlock day
  - Edge cases: locked cards remain non-draggable

**AC-3**: empty categories do not break layout
  - Given: a category with no items
  - When: the user opens the category
  - Then: the UI shows a calm empty state
  - Edge cases: the selected category label remains active
