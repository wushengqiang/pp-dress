# Epic: 对话 UI

> **Layer**: Presentation
> **GDD**: design/gdd/dialogue-ui.md
> **Architecture Module**: DialogueUI
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories dialogue-ui`

## Overview

实现每日场景中的轻叙事阅读界面，负责请求当天对话序列、逐句展示、输入推进和结束确认。它不拥有正式剧情文本，不决定天数推进，只把轻叙事内容、安全兜底和玩家确认转化为清晰、温和的阅读流程。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0006: Presentation to Gameplay Communication Pattern | UI 只发意图，确认结果后再同步状态，避免 UI 直接驱动游戏权威 | HIGH |
| ADR-0011: Dialogue Content Provider and Localization Contract | LightNarrativeDialogue 作为正式内容源，UI 使用 `tr()` 解析文本键 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-dialogue-ui-001 | Dialogue rendering, typewriter/input advancement, provider consumption, completion signal, fallback behavior, and focus/accessibility boundaries. | ADR-0006 ✅ ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/dialogue-ui.md` are verified
- Formal provider integration and fallback behavior have passing tests
- Text wrapping, input advancement, and focus states are validated on the pinned engine

## Next Step

Run `/create-stories dialogue-ui` to break this epic into implementable stories.
