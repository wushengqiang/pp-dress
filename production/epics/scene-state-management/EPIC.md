# Epic: 场景/状态管理

> **Layer**: Foundation
> **GDD**: design/gdd/scene-state-management.md
> **Architecture Module**: GameState
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories scene-state-management`

## Overview

实现全局场景状态机与 BOOT 编排，负责启动恢复、状态切换、场景就绪确认和错误路由。它协调 Foundation 服务的就绪检查，并在场景转换完成后向下游广播稳定的状态与上下文。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: Autoload Order and Boot Orchestration | 固定 Autoload 顺序、延迟 BOOT、就绪检查与场景确认 | MEDIUM |
| ADR-0002: Persistence Ownership and Save Rollback Strategy | 保存提交边界、恢复语义与失败回滚 | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scene-state-001 | Autoload order, BOOT orchestration, GameState finite state machine, scene readiness handshake, transition timeout, and recovery routing. | ADR-0001 ✅, ADR-0002 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/scene-state-management.md` are verified
- BOOT、状态转换、恢复与超时行为都有通过的测试
- 与保存、进度和场景就绪的边界行为已验证

## Next Step

Run `/create-stories scene-state-management` to break this epic into implementable stories.
