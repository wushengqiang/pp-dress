# Story 002: 保存、重置与后端封装

> **Epic**: 保存/加载
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/save-load.md`  
**Requirement**: `TR-save-load-001`

**ADR Governing Implementation**: ADR-0002: Persistence Ownership and Save Rollback Strategy  
**ADR Decision Summary**: SaveManager 提供受限写入口和平台后端封装；Web 通过 JS wrapper，非 Web 通过文件替换流程。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify `JavaScriptBridge.eval()` wrapper behavior, `FileAccess.store_string()` boolean returns, and non-Web tmp/bak replacement on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Save/reset actions must be explicit and bounded.
- Forbidden: No direct UI or gameplay code should bypass SaveManager.
- Guardrail: Writes must be safe, synchronous, and failure-aware.

## Acceptance Criteria

*From GDD `design/gdd/save-load.md`, scoped to this story:*

- [ ] `save()` 将当前 `SaveData` 写入持久化后端并返回 bool
- [ ] `saved` 仅在最终持久化确认成功后发出
- [ ] `reset()` 删除持久化键/文件并恢复默认内存数据
- [ ] `reset()` 失败时返回 `false` 且不崩溃
- [ ] `is_save_exists()` 正确反映后端是否存在存档
- [ ] `set_equipped_items(items)` 仅作为 GameState 的受限写入口
- [ ] `set_scene_in_progress(value)` 仅作为 GameState 的受限写入口
- [ ] 非 Web 路径能够完成临时文件与替换流程

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- Web backend must use a JSON-string wrapper result, not raw JS objects.
- `save()` success is platform-specific and must be checked explicitly.
- Reset must not silently recreate the save file.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: startup load and snapshot isolation
- Story 003: `advance_day()` transaction and rollback logic
- Story 004: version mismatch, bad-save lock, and schema failure behavior

## QA Test Cases

**AC-1**: save writes successfully
  - Given: a valid in-memory save object
  - When: `save()` is called
  - Then: the backend is updated and `saved` is emitted
  - Edge cases: a repeated save should fully overwrite with the newest snapshot

**AC-2**: reset clears persistent data
  - Given: an existing stored save
  - When: `reset()` is called
  - Then: the backend save is removed and memory returns to defaults
  - Edge cases: reset failure must return `false` without crashing

**AC-3**: existence checks match backend state
  - Given: a backend with or without a stored save
  - When: `is_save_exists()` is called
  - Then: the method reflects the actual backend state
  - Edge cases: Web unavailable storage is handled in Story 4
