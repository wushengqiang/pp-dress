# Story 002: 本地化 Key 与 CSV 合同

> **Epic**: 轻叙事对话
> **Status**: Ready
> **Layer**: Narrative
> **Type**: Integration
> **Estimate**: 2-4h
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/light-narrative-dialogue.md`  
**Requirement**: `TR-light-narrative-dialogue-001`

**ADR Governing Implementation**: ADR-0011: Dialogue Content Provider and Localization Contract  
**ADR Decision Summary**: 正式文本只保存 key，玩家可见文案通过 Godot Translation CSV 解析。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify `tr()` lookup, key coverage, and long localized string behavior on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: 文案必须用 key 访问。
- Forbidden: 不得在 provider 里硬编码正式玩家文本。
- Guardrail: speaker 和 body key 都要可本地化。

## Acceptance Criteria

*From GDD `design/gdd/light-narrative-dialogue.md`, scoped to this story:*

- [ ] `text_key` 与 `speaker_name_key` 只存 key
- [ ] `tr()` 路径可解析正式文案
- [ ] CSV 资源格式符合合同
- [ ] 缺失 key 由 UI 侧兜底而不是硬编码替代
- [ ] 本地化覆盖可被验证

## Implementation Notes

*Derived from ADR-0011 Implementation Guidelines:*

- provider 不负责翻译结果，只负责 key 约定。
- UI 会负责显示缺失 key 的安全行为。
- CSV 合同是正式发布前的重要验收点。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: provider contract and data shape
- Story 003: sequence selection and flavor injection
- Story 004: invalid data validation and fallback handling

## QA Test Cases

**AC-1**: keys are present for each line
  - Given: a valid dialogue sequence
  - When: localization keys are inspected
  - Then: each visible string uses a key
  - Edge cases: no hardcoded formal text slips in

**AC-2**: tr lookup resolves the content
  - Given: imported CSV translation data
  - When: keys are resolved
  - Then: the UI can render the localized text
  - Edge cases: missing keys are caught in validation

**AC-3**: long localized strings remain usable
  - Given: a long translated line
  - When: it renders in the UI
  - Then: wrapping remains readable
  - Edge cases: no overflow or clipping occurs
