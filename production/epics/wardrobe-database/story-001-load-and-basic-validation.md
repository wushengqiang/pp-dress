# Story 001: 启动加载与基础校验

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
**ADR Decision Summary**: 单 JSON 数据源、同步 Autoload 加载、只读查询、防御性拷贝、确定性排序与 z-index 解析。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify `FileAccess.open()`, `get_as_text()`, `JSON.new().parse(...)`, synchronous `_ready()` completion, and defensive `.duplicate(true)` semantics on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Foundation Autoload must finish startup checks synchronously.
- Forbidden: No `_ready()` async wait, no ready signals for startup load.
- Guardrail: Keep startup path lightweight; fail fast on schema errors.

## Acceptance Criteria

*From GDD `design/gdd/wardrobe-database.md`, scoped to this story:*

- [ ] `wardrobe.json` 被成功解析，`WardrobeDatabase.is_ready == true`，`load_error == ""`
- [ ] `get_all_items()` 返回非空数组
- [ ] `get_item_by_id("top_white_tee")["id"] == "top_white_tee"`
- [ ] `get_item_by_id("top_white_tee")["name"] == "白色T恤"`
- [ ] `get_item_by_id("top_white_tee")["category"] == "top"`
- [ ] `get_item_by_id("top_white_tee")["sort_order"] == 0`
- [ ] `get_item_by_id("top_white_tee")["tags"]` 为数组
- [ ] `get_categories()` 返回的类目键集合与 JSON 定义一致

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Use `FileAccess.open("res://assets/data/wardrobe.json", FileAccess.READ)`.
- Parse with `JSON.new().parse(text)` so line-numbered diagnostics are available.
- Complete validation synchronously inside `_ready()`.
- Do not emit startup ready/error signals; consumers check `is_ready` and `load_error`.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: query behavior, defensive copies, unlocked filtering, and z-index lookup semantics
- Story 003: blocking validation failures for malformed JSON and invalid schema
- Story 004: warning-only cases, safe defaults when not ready, and performance boundaries

## QA Test Cases

**AC-1**: startup load succeeds
  - Given: a valid `wardrobe.json`
  - When: `WardrobeDatabase` initializes
  - Then: `is_ready == true` and `load_error == ""`
  - Edge cases: file present but empty items array is handled in Story 004

**AC-2**: required item fields are present on a known item
  - Given: the loaded database contains `top_white_tee`
  - When: `get_item_by_id("top_white_tee")` is called
  - Then: the returned dict contains the expected `id`, `name`, `category`, `sort_order`, and `tags`
  - Edge cases: field validation failures are covered in Story 003
