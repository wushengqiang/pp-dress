# Epic: 保存/加载

> **Layer**: Foundation
> **GDD**: design/gdd/save-load.md
> **Architecture Module**: SaveManager
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories save-load`

## Overview

实现浏览器与本地存储之间的持久化通道，负责保存、加载、恢复和坏档保护。它不解释玩法规则，只负责把进度与会话数据安全落盘，并为进度管理和场景恢复提供可靠的存档边界。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Persistence Ownership and Save Rollback Strategy | SaveManager 负责持久化运输与安全，ProgressManager 负责进度语义与提交回滚 | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-save-load-001 | SaveData schema, Web/local persistence, bad-save protection, bounded write ownership, GOODNIGHT rollback, and recovery semantics. | ADR-0002 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/save-load.md` are verified
- All persistence and rollback tests pass
- Web/local storage failure and recovery paths are covered

## Next Step

Run `/create-stories save-load` to break this epic into implementable stories.
