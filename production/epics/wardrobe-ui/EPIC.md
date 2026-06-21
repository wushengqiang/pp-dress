# Epic: 衣橱 UI

> **Layer**: Presentation
> **GDD**: design/gdd/wardrobe-ui.md
> **Architecture Module**: WardrobeUI
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories wardrobe-ui`

## Overview

实现衣橱界面的类目切换、物品网格、缩略图呈现、锁定状态说明以及换装意图输出。它把输入管理、服装数据库、资源加载器和进度管理汇合成一个清晰的玩家操作界面，并通过本地信号把玩家选择交给下游换装系统确认，确保 UI 只负责表达意图与同步展示，不越权修改装备真相。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0005: Input Gesture Ownership and UI Focus Model | 显式注册手势区域，输入层不携带物品身份，标准 Control 保持原生路径 | HIGH |
| ADR-0006: Presentation to Gameplay Communication Pattern | UI 只发意图信号，确认结果后再同步权威状态，不使用全局事件总线 | HIGH |
| ADR-0003: Texture Loading Cache and Web Fallback Strategy | 缩略图通过 TextureCache 异步/缓存获取，遵守 Web 回退与内存预算 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-wardrobe-ui-001 | Category and item grid UI, thumbnail consumption, ProgressManager availability, gesture-region mapping, drag/click intents, and confirmed outfit UI state. | ADR-0005 ✅ ADR-0006 ✅ ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/wardrobe-ui.md` are verified
- All logic and integration stories have passing tests in `tests/`
- All UI and interaction stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories wardrobe-ui` to break this epic into implementable stories.
