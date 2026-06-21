# Story 001: 启动加载与恢复

> **Epic**: 保存/加载
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/save-load.md`  
**Requirement**: `TR-save-load-001`

**ADR Governing Implementation**: ADR-0002: Persistence Ownership and Save Rollback Strategy  
**ADR Decision Summary**: SaveManager 负责持久化运输与安全，启动时加载默认值或持久化快照，并对基础结构做校验。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify `JSON.new().parse(...)`, `SaveData.from_dict(...)`, typed field reconstruction, and startup `loaded` timing on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Startup load must complete without blocking gameplay.
- Forbidden: No gameplay rule repair inside SaveManager.
- Guardrail: Load path must remain synchronous and deterministic.

## Acceptance Criteria

*From GDD `design/gdd/save-load.md`, scoped to this story:*

- [ ] `SaveManager._ready()` 自动执行一次内部加载流程
- [ ] `load()` 在 ready 前会执行同一加载流程
- [ ] `load()` 在 ready 后直接返回当前 `data`
- [ ] `loaded(data)` 在启动加载完成后发出
- [ ] `is_ready == true` 在加载完成后成立
- [ ] `get_data_snapshot()` 返回深拷贝快照
- [ ] `SaveData` 使用 JSON 原生类型进行序列化/反序列化
- [ ] `save_version`、`current_day`、`equipped_items`、`scene_in_progress`、`highest_day_completed`、`unlock_progress` 被正确加载

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- `SaveManager` is a persistence pipe, not a rules authority.
- Use `SaveData.to_dict()` / `from_dict()` and validate base schema only.
- Downstream systems rely on ready checks or loaded signals, not same-frame assumptions.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: save/reset mechanics, Web/local backend wrappers, and user-facing save failure handling
- Story 003: progress commit transaction and rollback semantics
- Story 004: bad-save protection, version mismatch, and safe defaults for failure cases

## QA Test Cases

**AC-1**: startup load completes
  - Given: a valid persisted save or no save at all
  - When: `SaveManager` initializes
  - Then: `is_ready == true` and `loaded` is emitted
  - Edge cases: startup should not require explicit external `load()`

**AC-2**: snapshot is isolated
  - Given: a loaded `SaveManager`
  - When: `get_data_snapshot()` is called and the result is modified
  - Then: the internal save data remains unchanged
  - Edge cases: nested arrays and dictionaries must also be isolated

**AC-3**: data schema fields are reconstructed
  - Given: persisted JSON containing the SaveData fields
  - When: the save is loaded
  - Then: the runtime object contains the expected typed fields
  - Edge cases: types are validated in Story 4
