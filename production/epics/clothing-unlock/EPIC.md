# Epic: 服装解锁

> **Layer**: Feature
> **GDD**: design/gdd/clothing-unlock.md
> **Architecture Module**: ClothingUnlock
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories clothing-unlock`

## Overview

实现晚安后的轻量解锁展示与衣橱高亮交付，把进度管理确认的新物品转化为玩家能感受到的温柔惊喜。它只消费解锁结果，不计算解锁，不推进天数，也不拥有长期存档权。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0008: Progression and Unlock Event Contract | 解锁批次、衣橱高亮和音频反馈必须基于确认结果 | HIGH |
| ADR-0006: Presentation to Gameplay Communication Pattern | UI 只消费结果并回传展示，不越权改写进度 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-clothing-unlock-001 | Confirmed unlock presentation only, item validation, prompt timing, wardrobe one-time highlight handoff, and unlock audio event routing. | ADR-0008 ✅ ADR-0006 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/clothing-unlock.md` are verified
- Unlock presentation, highlighter handoff, and fallback behavior have passing tests
- Web and accessibility behavior are validated on the pinned engine

## Next Step

Run `/create-stories clothing-unlock` to break this epic into implementable stories.
