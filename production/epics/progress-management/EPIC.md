# Epic: 进度管理

> **Layer**: Core
> **GDD**: design/gdd/progress-management.md
> **Architecture Module**: ProgressManager
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories progress-management`

## Overview

实现游戏天数、完成进度、物品解锁和类目可见性的唯一权威查询层。它从保存数据和服装数据库中读取真相，计算玩家当前可玩天数、当前是否解锁某件服装，以及每一天完成后应提交哪些新解锁，但不渲染 UI、不控制场景切换，也不直接负责持久化实现细节。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Persistence Ownership and Save Rollback Strategy | ProgressManager 负责进度语义与提交回滚，SaveManager 负责持久化运输 | MEDIUM |
| ADR-0008: Progression and Unlock Event Contract | unlock 事件、衣橱高亮和音频反馈必须基于确认的解锁批次 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-progress-management-001 | Current-day authority, unlock computation, post-save progress signals, save-failure rollback, and unlock availability boundary. | ADR-0002 ✅, ADR-0008 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/progress-management.md` are verified
- `advance_day()` success and rollback paths are covered
- Unlock truth, day availability, and category visibility behave consistently with SaveManager and WardrobeDatabase

## Next Step

Run `/create-stories progress-management` to break this epic into implementable stories.
