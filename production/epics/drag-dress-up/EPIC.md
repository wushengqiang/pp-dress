# Epic: 拖拽换装

> **Layer**: Feature
> **GDD**: design/gdd/drag-dress-up.md
> **Architecture Module**: DragDressUp
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories drag-dress-up`

## Overview

实现衣橱选择到角色穿搭应用之间的交互仲裁层。它接收衣橱 UI 发出的拖拽或点击意图，调用精灵分层渲染确认装备结果，并将确认后的状态回写给衣橱 UI，同时提供柔和的失败退化与音频反馈。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0006: Presentation to Gameplay Communication Pattern | UI 提交意图，Gameplay 确认结果，再同步回 UI | HIGH |
| ADR-0007: Sprite Layered Renderer and Outfit State Ownership | 渲染器拥有装备状态与确认信号，应用由结果驱动 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-drag-dress-up-001 | Drop validation, click alternative, equip request tokening, renderer-result mapping, soft feedback, and no persistence/progression ownership. | ADR-0006 ✅ ADR-0007 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/drag-dress-up.md` are verified
- Tokening, no-op handling, and renderer timeout behavior have passing tests
- Input, renderer, and audio integration are validated on the pinned engine

## Next Step

Run `/create-stories drag-dress-up` to break this epic into implementable stories.
