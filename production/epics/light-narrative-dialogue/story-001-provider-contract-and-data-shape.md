# Story 001: Provider 合同与数据形状

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
**ADR Decision Summary**: `request_dialogue_sequence(day, context)` 返回固定形状的 DialogueSequence / DialogueLine 数据。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify dictionary shape, defensive copies, and deterministic ordering on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: provider 只返回内容，不驱动 UI。
- Forbidden: 不得输出评分、失败或结算语义。
- Guardrail: sequence 与 line 结构必须稳定。

## Acceptance Criteria

*From GDD `design/gdd/light-narrative-dialogue.md`, scoped to this story:*

- [ ] 实现 `request_dialogue_sequence(day, context)`
- [ ] 返回 `sequence_id`、`day`、`scene_id`、`lines`
- [ ] `lines` 包含必要字段
- [ ] provider 返回防御性拷贝
- [ ] 输出保持确定性

## Implementation Notes

*Derived from ADR-0011 Implementation Guidelines:*

- 这是 formal content owner，不是 UI helper。
- 数据 shape 不能依赖临时实现细节。
- 返回值必须可直接由 UI 消费。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: localization keys and CSV contract
- Story 003: selection, flavor, and deterministic fallback
- Story 004: validation and invalid-data recovery

## QA Test Cases

**AC-1**: provider returns the expected keys
  - Given: a valid day and context
  - When: the provider is queried
  - Then: a complete sequence dictionary is returned
  - Edge cases: returned data is a copy, not a shared mutable object

**AC-2**: line dictionaries have the required fields
  - Given: a returned sequence
  - When: its lines are inspected
  - Then: each line has the required contract fields
  - Edge cases: missing fields fail validation

**AC-3**: output is deterministic
  - Given: the same input twice
  - When: the provider is queried
  - Then: the same sequence is returned
  - Edge cases: no random ordering is introduced
