# Story 004: 预警级边界与未就绪安全返回

> **Epic**: 服装数据库
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/wardrobe-database.md`  
**Requirement**: `TR-wardrobe-database-001`

**ADR Governing Implementation**: ADR-0010: Wardrobe Database Schema and Read-Only Query Contract  
**ADR Decision Summary**: 非阻断问题使用警告继续加载；未就绪时查询必须返回安全默认值，不能崩溃或污染内部状态。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify clamping, warnings, empty-data behavior, and safe fallback semantics on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Non-blocking issues should warn and continue.
- Forbidden: No crash or mutation when queries run before readiness.
- Guardrail: Preserve deterministic output and bounded cost for repeated queries.

## Acceptance Criteria

*From GDD `design/gdd/wardrobe-database.md`, scoped to this story:*

- [ ] `z_index_override` 超出 1–10 时通过 `push_warning()` 输出警告并 clamp
- [ ] `get_z_index()` 对边界值始终返回 1–10 范围内结果
- [ ] `sort_order` 在同类目内重复时，打印 `push_warning()` 警告但继续加载
- [ ] `tags` 包含未定义枚举值时，打印 `push_warning()` 警告并跳过无效标签
- [ ] `get_items_by_tag("nonexistent_tag")` 返回空数组
- [ ] `get_items_by_category("nonexistent_category")` 返回空数组
- [ ] `get_unlocked_items(0)` 返回空数组
- [ ] `items` 数组为空时，`is_ready == true` 且所有查询返回空结果或安全默认值
- [ ] `get_all_items()` 连续调用满足帧预算边界
- [ ] 未初始化状态下调用所有查询方法返回安全空值，不触发错误
- [ ] JSON 中包含 schema 未定义的额外字段时，打印 `push_warning()` 警告并继续加载
- [ ] `wardrobe.json` 文件不存在时，`is_ready == false` 且 `load_error` 包含文件路径

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Safe defaults are required for pre-ready calls.
- Warnings should not block startup.
- Extra JSON fields should be ignored after warning.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: positive startup loading and base content verification
- Story 002: deep-copy query semantics and deterministic list ordering
- Story 003: blocking schema and type validation failures

## QA Test Cases

**AC-1**: z-index clamping warns but continues
  - Given: a test JSON with `z_index_override` below 1 and above 10
  - When: the database loads and `get_z_index()` is called
  - Then: warnings are logged and values are clamped to the legal range
  - Edge cases: `0`, `-1`, `11`, and `999` all clamp correctly

**AC-2**: duplicate sort order stays deterministic
  - Given: a category with repeated `sort_order`
  - When: `get_items_by_category(cat)` is called multiple times
  - Then: the order is deterministic and warnings are emitted
  - Edge cases: `id` alphabetical tiebreaker must remain stable

**AC-3**: invalid tags are ignored with warnings
  - Given: items that include unknown tag values
  - When: the database loads
  - Then: warnings are emitted and only valid tags are retained
  - Edge cases: items with only invalid tags load with `tags: []`

**AC-4**: pre-ready calls are safe
  - Given: a database instance before readiness
  - When: every public query method is called
  - Then: each method returns the documented safe default and does not crash
  - Edge cases: repeated calls must remain safe

