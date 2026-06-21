# Epic: 每日场景

> **Layer**: Feature
> **GDD**: design/gdd/daily-scene.md
> **Architecture Module**: DailyScene
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories daily-scene`

## Overview

实现玩家确认穿搭后的当日呈现场景，负责读取当前天数与穿搭上下文、实例化角色、装配背景与氛围，并承载当天对话。它编排每日小片段的视觉与流程，但不拥有进度、正式剧情或场景切换权。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0004: Scene Transition and State Machine Contract | 场景完成后通过 GameState 进行受控转场 | MEDIUM |
| ADR-0006: Presentation to Gameplay Communication Pattern | 场景只传递意图与上下文，不越权驱动游戏权威 | HIGH |
| ADR-0011: Dialogue Content Provider and Localization Contract | 对话内容由正式 provider 提供，场景只承载上下文 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-daily-scene-001 | Day/context consumption, character/background/dialogue hosting, goodnight request ownership, and outfit application. | ADR-0004 ✅ ADR-0006 ✅ ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/daily-scene.md` are verified
- Out-of-order scene readiness, outfit application, and transition handling have passing tests
- Fallback visual and dialogue paths are validated on the pinned engine

## Next Step

Run `/create-stories daily-scene` to break this epic into implementable stories.
