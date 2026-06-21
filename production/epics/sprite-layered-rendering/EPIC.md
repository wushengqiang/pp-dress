# Epic: 精灵分层渲染

> **Layer**: Core
> **GDD**: design/gdd/sprite-layered-rendering.md
> **Architecture Module**: SpriteLayeredRenderer
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories sprite-layered-rendering`

## Overview

实现角色穿搭的视觉终点。它管理六个 Sprite2D 层，按照服装数据库定义的类目和 z-index 显示当前穿搭，并在纹理就绪后原子更新视觉状态与结果信号。它不处理拖拽、不管理库存，也不解释场景上下文，只负责把正确的服装纹理显示在正确的层级上。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0007: Sprite Layered Renderer and Outfit State Ownership | 渲染器拥有 per-instance outfit state、generation/token 防护和结果信号语义 | HIGH |
| ADR-0003: Texture Loading Cache and Web Fallback Strategy | 纹理请求、热/暖缓存、同步/异步回调和失效行为由 TextureCache 统一提供 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-sprite-layered-rendering-001 | Sprite2D layered renderer, z-index ordering, renderer-owned outfit state, async callback guards, and result signal semantics. | ADR-0007 ✅, ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/sprite-layered-rendering.md` are verified
- Renderer signals and texture callbacks behave correctly under hot/warm/cold loads
- Visual layering and stale callback safety are validated

## Next Step

Run `/create-stories sprite-layered-rendering` to break this epic into implementable stories.
