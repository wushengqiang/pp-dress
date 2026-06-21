# Story 001: 启动与类目壳层

> **Epic**: 衣橱 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/wardrobe-ui.md`  
**Requirement**: `TR-wardrobe-ui-001`

**ADR Governing Implementation**: ADR-0006: Presentation to Gameplay Communication Pattern; ADR-0005: Input Gesture Ownership and UI Focus Model  
**ADR Decision Summary**: 衣橱 UI 只负责本地展示态与类目壳层，依赖就绪后再显示可用类目，不直接改写装备真相。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify Control 初始化、typed signal wiring、类目按钮 focus 行为，以及加载态切换在 pinned engine 上的表现。

**Control Manifest Rules (this layer)**:
- Required: 6 个固定类目壳层必须可渲染且顺序稳定。
- Forbidden: 不得在 UI 启动时直接读取或写入装备结果。
- Guardrail: 依赖未就绪时只能进入轻量 LOADING 状态。

## Acceptance Criteria

*From GDD `design/gdd/wardrobe-ui.md`, scoped to this story:*

- [ ] `LOADING -> READY` 的初始化路径正确
- [ ] 6 个 MVP 类目始终显示，顺序为 `top, bottom, shoes, accessory, hair, makeup`
- [ ] `ProgressManager.get_visible_categories()` 控制类目的 enabled / disabled 状态
- [ ] 未就绪时显示轻量加载态，不渲染错误的可用状态
- [ ] `category_selected(category)` 只允许可见类目进入选中态
- [ ] 禁用类目保持灰色并显示锁图标，不打开物品网格

## Implementation Notes

*Derived from ADR-0006 / ADR-0005 Implementation Guidelines:*

- UI 只维护本地浏览状态，不承担规则判断。
- 类目点击必须保持原生 Control 行为与可访问性。
- 依赖就绪前不要推断解锁状态或缩略图状态。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: item grid, lock cards, and thumbnail loading
- Story 003: drag/click intent wiring and region-to-item mapping
- Story 004: outfit result synchronization, confirmation flow, and layout edge cases

## QA Test Cases

**AC-1**: shell boots into a stable browsing state
  - Given: a ready WardrobeUI scene and ready dependencies
  - When: `_ready()` runs
  - Then: the UI enters `READY` with the first visible category selected
  - Edge cases: missing dependencies must keep the UI in LOADING

**AC-2**: category order is fixed
  - Given: the MVP wardrobe categories
  - When: the UI builds the category bar
  - Then: the order is `top, bottom, shoes, accessory, hair, makeup`
  - Edge cases: absent categories are filtered without changing the order of remaining items

**AC-3**: disabled categories remain inert
  - Given: a category not returned by `ProgressManager.get_visible_categories()`
  - When: the player clicks or taps it
  - Then: the current category does not change
  - Edge cases: the disabled label still renders as part of the fixed shell
