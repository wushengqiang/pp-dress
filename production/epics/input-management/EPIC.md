# Epic: 输入管理

> **Layer**: Foundation
> **GDD**: design/gdd/input-management.md
> **Architecture Module**: InputManager
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories input-management`

## Overview

实现统一的输入归一化层，把鼠标、触摸与悬停事件转换为稳定的交互语义，并与 Godot 原生 GUI 事件边界配合工作。它只处理被显式注册的游戏手势区域，不接管普通按钮或滚动控件。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0005: Input Gesture Ownership and UI Focus Model | 游戏手势区域显式注册、GUI 与手势分流、双平台输入仲裁 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-input-management-001 | Mouse/touch normalization, explicit gesture regions, drag/click/scroll arbitration, native GUI separation, and Godot 4.6 focus handling. | ADR-0005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/input-management.md` are verified
- Mouse, touch, scroll, and focus paths have passing tests
- Web canvas input behavior is validated on the pinned engine

## Next Step

Run `/create-stories input-management` to break this epic into implementable stories.
