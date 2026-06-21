# Epic: 主菜单/晚安 UI

> **Layer**: Presentation
> **GDD**: design/gdd/main-menu-goodnight-ui.md
> **Architecture Module**: MainMenuGoodnightUI
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories main-menu-goodnight-ui`

## Overview

实现主菜单与晚安收束页的统一 UI，负责显示当前天数、开始今天、退出、继续以及通关重玩入口。它只发出状态转换意图，不拥有进度与解锁逻辑，并在不同游戏状态下保持温和、低压力、可访问的入口与收束体验。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0004: Scene Transition and State Machine Contract | 统一场景切换由 GameState 负责，UI 只能请求转换 | MEDIUM |
| ADR-0006: Presentation to Gameplay Communication Pattern | UI 只发意图，状态确认后再同步界面 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-main-menu-goodnight-ui-001 | Start/goodnight/retry/continue transition intents, no progression ownership, native button paths, focus behavior, and audio event routing. | ADR-0004 ✅ ADR-0006 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/main-menu-goodnight-ui.md` are verified
- Transition requests, button focus, and completed-state variants have passing tests
- Web and keyboard/gamepad input paths are validated on the pinned engine

## Next Step

Run `/create-stories main-menu-goodnight-ui` to break this epic into implementable stories.
