# Story 003: 序列选择、风味与兜底

> **Epic**: 轻叙事对话
> **Status**: Ready
> **Layer**: Narrative
> **Type**: Logic
> **Estimate**: 3-5h
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/light-narrative-dialogue.md`  
**Requirement**: `TR-light-narrative-dialogue-001`

**ADR Governing Implementation**: ADR-0011: Dialogue Content Provider and Localization Contract  
**ADR Decision Summary**: 按 day/scene 选择基础序列，最多插入一条非评分式 flavor，并在缺失时回退到 day 1 安全序列。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify deterministic fallback order and flavor insertion bounds on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: fallback 层次必须固定。
- Forbidden: 不得产生评分或失败语义。
- Guardrail: flavor 最多 1 条，且必须克制。

## Acceptance Criteria

*From GDD `design/gdd/light-narrative-dialogue.md`, scoped to this story:*

- [ ] day 1..7 都能选到基础序列
- [ ] 缺失 day 回退到 day 1
- [ ] `scene_id` 仅用于更精准选择
- [ ] flavor 最多插入 1 条
- [ ] fallback 路径保持温和

## Implementation Notes

*Derived from ADR-0011 Implementation Guidelines:*

- 选择逻辑必须是确定性的。
- flavor 只做轻柔回应，不做判断。
- 兜底不是错误展示，是内容安全路径。

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: provider contract and data shape
- Story 002: localization keys and CSV contract
- Story 004: invalid line validation and emergency recovery

## QA Test Cases

**AC-1**: exact day selection returns that day’s sequence
  - Given: a known day and context
  - When: the provider resolves it
  - Then: the matching sequence is returned
  - Edge cases: unknown scene_id still picks a valid day sequence

**AC-2**: flavor is bounded and gentle
  - Given: flavor candidates exist
  - When: a sequence is built
  - Then: at most one flavor line is inserted
  - Edge cases: no judgment language is allowed

**AC-3**: fallback remains deterministic
  - Given: a missing or invalid day
  - When: it is resolved
  - Then: the provider falls back to day 1
  - Edge cases: repeated requests return the same fallback
