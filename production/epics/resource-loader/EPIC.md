# Epic: 资源加载器

> **Layer**: Foundation
> **GDD**: design/gdd/resource-loader.md
> **Architecture Module**: TextureCache
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories resource-loader`

## Overview

实现纹理资源的分层加载与缓存管线，支持首帧预加载、按需异步加载和后台预测加载。它确保衣橱缩略图与角色全尺寸纹理在 Web 内存和帧预算约束下稳定可用，支撑“即时有感”的交互反馈。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0003: Texture Loading Cache and Web Fallback Strategy | 热/暖缓存、线程加载、资源去重、Web 回退与内存预算控制 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-resource-loader-001 | TextureCache tiered loading, threaded requests, HOT/WARM cache, LRU eviction, duplicate request fan-out, Web fallback, and memory budget handling. | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/resource-loader.md` are verified
- Loading, caching, eviction, and fallback behavior have passing tests
- Web resource loading and memory budgets are validated on the pinned engine

## Next Step

Run `/create-stories resource-loader` to break this epic into implementable stories.
