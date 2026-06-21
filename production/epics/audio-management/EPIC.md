# Epic: 音频管理

> **Layer**: Foundation
> **GDD**: design/gdd/audio-management.md
> **Architecture Module**: AudioManager
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories audio-management`

## Overview

实现全局音频事件路由与播放策略，统一管理 UI、换装、对话、场景与解锁反馈的声音层。它负责把事件意图映射成克制、低压力的音频行为，并处理 Web 音频解锁、冷却、并发与静音状态。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0009: Audio Event Routing and Web Unlock Behavior | 事件驱动音频路由、bus 管理、播放池、Web 解锁与失败非阻断 | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-audio-management-001 | Event-key audio routing, buses, SFX/UI pools, Web audio unlock, cooldowns, and non-blocking audio failure behavior. | ADR-0009 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/audio-management.md` are verified
- Event routing, cooldown, pooling, and mute behavior have passing tests
- Web unlock and focus-loss behavior are validated

## Next Step

Run `/create-stories audio-management` to break this epic into implementable stories.
