# Story 004: 校验与无效数据恢复

> **Epic**: 轻叙事对话
> **Status**: Ready
> **Layer**: Narrative
> **Type**: Logic
> **Estimate**: 2-4h
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/light-narrative-dialogue.md`  
**Requirement**: `TR-light-narrative-dialogue-001`

**ADR Governing Implementation**: ADR-0011: Dialogue Content Provider and Localization Contract  
**ADR Decision Summary**: 无效数据在发布前应被验证捕捉，运行时则必须提供安全 fallback。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify invalid-line validation and emergency fallback behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 序列必须在发布前可验证。
- Forbidden: 不得把坏数据带成崩溃。
- Guardrail: 运行时 fallback 不能泄露技术错误。

## Acceptance Criteria

*From GDD `design/gdd/light-narrative-dialogue.md`, scoped to this story:*

- [ ] 缺失 `line_id` 会被验证捕捉
- [ ] 缺失 `text_key` 可走安全处理
- [ ] 空序列会回退
- [ ] emergency safe sequence 可用
- [ ] 非法数据不会阻塞 UI

## Implementation Notes

*Derived from ADR-0011 Implementation Guidelines:*

- 校验失败应尽早暴露。
- 运行时回退应尽可能轻。
- 这里的目标是保证玩家能读完，而不是把错误显给玩家。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: provider contract and data shape
- Story 002: localization keys and CSV contract
- Story 003: sequence selection and flavor injection

## QA Test Cases

**AC-1**: invalid lines are caught by validation
  - Given: a malformed sequence
  - When: validation runs
  - Then: missing fields are detected
  - Edge cases: the build can be marked not ready

**AC-2**: empty sequences fall back safely
  - Given: a zero-line day
  - When: it is requested
  - Then: the provider uses safe fallback content
  - Edge cases: no crash or hard block occurs

**AC-3**: emergency sequences remain gentle
  - Given: broken content data
  - When: runtime needs a line
  - Then: a safe fallback sequence is returned
  - Edge cases: no technical error text is shown
