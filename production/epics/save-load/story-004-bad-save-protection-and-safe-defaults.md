# Story 004: 坏档保护与安全默认值

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
**ADR Decision Summary**: 损坏数据、版本不匹配和存储不可用都必须返回受控默认值，同时保留足够信息供 UI 和调试路径处理。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Verify Web `localStorage` wrapper behavior, parse failures, version checks, and default-overwrite lock semantics on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Failure must be recoverable or explicitly blocked.
- Forbidden: No technical exceptions should leak to gameplay flow.
- Guardrail: Keep diagnostics available without exposing them to players directly.

## Acceptance Criteria

*From GDD `design/gdd/save-load.md`, scoped to this story:*

- [ ] `localStorage` 不可用时，Web wrapper 捕获异常且游戏不中断
- [ ] `load()` 在存储不可用时返回默认存档并保持 `is_ready == true`
- [ ] `is_save_exists()` 在存储不可用时返回 `false`
- [ ] `save()` 在存储不可用时返回 `false`
- [ ] `save_version` 不匹配时按规则拒绝不兼容数据
- [ ] 有效但业务值异常的数据由下游修复，而不是 SaveManager 深度修复
- [ ] `equipped_items` 缺失、为 null、不是数组或为空时可按恢复规则处理
- [ ] `default_overwrite_locked` 在坏档读取失败后正确设置
- [ ] 默认档覆盖被锁定时，自动保存必须拒绝写入
- [ ] 重置和坏档路径保留非技术、低压的失败语义

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- Treat backend data as untrusted input.
- Preserve the last good save and block unsafe overwrites.
- Web wrapper must return structured JSON strings from JS.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: normal startup load and snapshot handling
- Story 002: successful save/reset and backend replacement mechanics
- Story 003: transactional progress commit and rollback

## QA Test Cases

**AC-1**: storage unavailable is non-fatal
  - Given: Web storage throws on access
  - When: SaveManager loads or saves
  - Then: the game continues, `load()` falls back to defaults, and `save()` fails cleanly
  - Edge cases: the UI should be able to present a low-pressure warning

**AC-2**: version mismatch is rejected
  - Given: a saved payload with an unsupported version
  - When: it is loaded
  - Then: the data is rejected according to the version rule
  - Edge cases: older business-valid data remains a downstream concern

**AC-3**: bad-save lock blocks unsafe overwrite
  - Given: an existing save that cannot be safely read
  - When: the user has not acknowledged overwrite
  - Then: automatic save is blocked
  - Edge cases: acknowledgement should clear the lock for the approved reset flow
