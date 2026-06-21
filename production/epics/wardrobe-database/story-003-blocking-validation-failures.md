# Story 003: 阻断性数据校验失败路径

> **Epic**: 服装数据库
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/wardrobe-database.md`  
**Requirement**: `TR-wardrobe-database-001`

**ADR Governing Implementation**: ADR-0010: Wardrobe Database Schema and Read-Only Query Contract  
**ADR Decision Summary**: 只要 schema、必填字段、引用关系或类型不满足契约，就必须阻断加载并给出可诊断错误。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify line-numbered JSON parse diagnostics and load-failure handling in the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Startup load must reject ambiguous or invalid data.
- Forbidden: No silent fallback for blocking schema errors.
- Guardrail: Error messages should preserve enough detail for diagnosis.

## Acceptance Criteria

*From GDD `design/gdd/wardrobe-database.md`, scoped to this story:*

- [ ] 包含重复 `id` 的 JSON 触发加载失败，`load_error` 包含两个冲突物品的名称
- [ ] 包含无效 `category` 的 JSON 触发加载失败，`load_error` 包含物品 id 和无效值
- [ ] 缺少必填字段（id / name / texture_path）的 JSON 触发加载失败，`load_error` 包含物品索引和缺失字段名
- [ ] 格式错误的 JSON 触发加载失败，`load_error` 包含行号
- [ ] `categories` 字典为空时触发加载失败，`is_ready == false`
- [ ] `categories` 中某个类目缺少 `z_index_default` 字段触发加载失败
- [ ] `id` 前缀与 `category` 字段不一致触发加载失败
- [ ] `name` 超过 8 个字符触发加载失败
- [ ] `sort_order` 为负数触发加载失败
- [ ] `unlock_day` 非整数、`null`、缺失或 `< 1` 触发加载失败
- [ ] `tags` 为非数组、`null` 或缺失时触发加载失败
- [ ] `texture_path`、`thumbnail_path` 为非字符串或空字符串时触发加载失败

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Validation failures must stop startup before data is exposed.
- Populate `load_error` with actionable diagnostics.
- Keep blocking validation separate from warning-only cleanup.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: successful bootstrap and base item/category verification
- Story 002: query behavior, deep copies, and deterministic output
- Story 004: warning-only cases, safe defaults, and performance checks

## QA Test Cases

**AC-1**: duplicate item IDs are rejected
  - Given: a test JSON with two items sharing the same `id`
  - When: `WardrobeDatabase` loads it
  - Then: loading fails and `load_error` mentions both conflicting items
  - Edge cases: item order should not affect detection

**AC-2**: invalid category references are rejected
  - Given: a test JSON with an item whose `category` is not in `categories`
  - When: the database loads
  - Then: loading fails and `load_error` contains the item id and invalid category
  - Edge cases: case mismatch should also fail

**AC-3**: required field and type violations are rejected
  - Given: test JSON variants missing or corrupting required fields
  - When: the database loads each variant
  - Then: loading fails with a diagnostic that names the missing field or invalid type
  - Edge cases: `unlock_day`, `sort_order`, `name`, `texture_path`, and `tags` all need separate coverage

**AC-4**: malformed JSON reports line numbers
  - Given: syntactically invalid JSON
  - When: the database loads it
  - Then: loading fails and `load_error` includes a line number
  - Edge cases: multiple syntax errors should still report the first parse error clearly
