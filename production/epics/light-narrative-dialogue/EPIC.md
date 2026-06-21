# Epic: 轻叙事对话

> **Layer**: Narrative
> **GDD**: design/gdd/light-narrative-dialogue.md
> **Architecture Module**: LightNarrativeDialogue
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories light-narrative-dialogue`

## Overview

实现每日对话的正式内容 provider，按天数与场景上下文返回短小、线性的对话序列，并通过本地化键而不是硬编码文案来提供可播放内容。它只提供文本与元数据，不负责 UI、输入、转场或进度。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0011: Dialogue Content Provider and Localization Contract | 正式对话内容由 LightNarrativeDialogue 提供，文本使用本地化 key | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-light-narrative-dialogue-001 | Seven-day dialogue provider, sequence and line data contract, localization keys, deterministic fallback, and non-scoring flavor lines. | ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/light-narrative-dialogue.md` are verified
- Provider shape, localization keys, fallback, and flavor validation have passing tests
- Formal content stays deterministic and UI-agnostic on the pinned engine

## Next Step

Run `/create-stories light-narrative-dialogue` to break this epic into implementable stories.
