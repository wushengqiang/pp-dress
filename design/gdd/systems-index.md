# Systems Index: 每日穿搭 (Dress Up Daily)

> **Status**: Draft
> **Created**: 2026-06-05
> **Last Updated**: 2026-06-16
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

每日穿搭是一款 Web 端 2D 换装游戏，包含 15 个系统，涵盖拖拽交互、服装数据库、精灵叠层渲染、轻叙事对话和进度管理。所有系统均为 MVP 必须，遵循 Foundation → Core Infrastructure → Rendering/UI → Feature → Narrative 的依赖顺序设计。核心支柱（每日陪伴、随心搭配、即时有感）贯穿每个系统的设计约束。

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 服装数据库 (inferred) | Gameplay | MVP | Approved | design/gdd/wardrobe-database.md | — |
| 2 | 场景/状态管理 (inferred) | Core | MVP | Approved | design/gdd/scene-state-management.md | 服装数据库, 保存/加载, 资源加载器, 输入管理, 进度管理 |
| 3 | 精灵分层渲染 (inferred) | Gameplay | MVP | Approved | design/gdd/sprite-layered-rendering.md | 服装数据库, 资源加载器 |
| 4 | 保存/加载 (inferred) | Persistence | MVP | Approved | design/gdd/save-load.md | — |
| 5 | 资源加载器 (inferred) | Core | MVP | Approved | design/gdd/resource-loader.md | 服装数据库, 场景/状态管理 |
| 6 | 输入管理 (inferred) | Core | MVP | Approved | design/gdd/input-management.md | — |
| 7 | 进度管理 (inferred) | Progression | MVP | Approved | design/gdd/progress-management.md | 保存/加载, 服装数据库 |
| 8 | 衣橱 UI (inferred) | UI | MVP | Approved | design/gdd/wardrobe-ui.md | 输入管理, 服装数据库, 资源加载器, 进度管理 |
| 9 | 对话 UI (inferred) | UI | MVP | Approved | design/gdd/dialogue-ui.md | 场景/状态管理, 进度管理 |
| 10 | 主菜单/晚安 UI (inferred) | UI | MVP | Approved | design/gdd/main-menu-goodnight-ui.md | 场景/状态管理, 进度管理 |
| 11 | 音频管理 (inferred) | Audio | MVP | Approved | design/gdd/audio-management.md | — |
| 12 | 拖拽换装 | Gameplay | MVP | Approved | design/gdd/drag-dress-up.md | 输入管理, 精灵分层渲染, 衣橱 UI, 音频管理 |
| 13 | 每日场景 | Gameplay | MVP | Approved | design/gdd/daily-scene.md | 场景/状态管理, 精灵分层渲染, 对话 UI, 进度管理 |
| 14 | 轻叙事对话 | Narrative | MVP | Approved | design/gdd/light-narrative-dialogue.md | 每日场景, 对话 UI, 进度管理 |
| 15 | 服装解锁 | Progression | MVP | Approved | design/gdd/clothing-unlock.md | 进度管理, 服装数据库, 衣橱 UI, 主菜单/晚安 UI, 场景/状态管理 |

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Core** | Runtime orchestration and shared infrastructure | 场景/状态管理, 资源加载器, 输入管理 |
| **Gameplay** | The systems that make the game fun | 服装数据库, 精灵分层渲染, 拖拽换装, 每日场景 |
| **Progression** | How the player progresses | 进度管理, 服装解锁 |
| **Persistence** | Save state and continuity | 保存/加载 |
| **UI** | Player-facing information displays | 衣橱 UI, 对话 UI, 主菜单/晚安 UI |
| **Audio** | Sound and music | 音频管理 |
| **Narrative** | Story and dialogue delivery | 轻叙事对话 |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function | First playable prototype | Design NOW |

All 15 systems are MVP-required. Each system directly supports at least one pillar and one core mechanic. No system can be deferred without breaking the core loop.

---

## Dependency Map

> **说明**：本表反映各 GDD `Dependencies` 段落的当前声明。`场景/状态管理` 与 `资源加载器` 存在 BOOT 编排与就绪检查的双向关系：GameState 负责检查 TextureCache 就绪，TextureCache 又需要 GameState 作为 BOOT/场景切换编排者。实现时应通过 Autoload 顺序和 `is_ready` 检查解耦，避免在 `_ready()` 中互相强调用。

### Foundation Layer (zero dependencies)

1. **服装数据库** — 所有服装的定义数据（名称、类别、图片路径、解锁条件），是整个换装系统的数据骨架
2. **保存/加载** — Web LocalStorage 持久化，关闭浏览器后进度不丢失；不做业务规则判定
3. **输入管理** — 统一处理鼠标和触摸事件，提供拖拽和点击双模式信号
4. **音频管理** — 统一管理轻量音频事件；任一音频失败不得阻断游戏流程

### Core Infrastructure Layer

1. **资源加载器** — depends on: 服装数据库, 场景/状态管理
2. **进度管理** — depends on: 保存/加载, 服装数据库
3. **场景/状态管理** — depends on: 服装数据库, 保存/加载, 资源加载器, 输入管理, 进度管理

### Rendering/UI Layer

1. **精灵分层渲染** — depends on: 服装数据库, 资源加载器
2. **衣橱 UI** — depends on: 输入管理, 服装数据库, 资源加载器, 进度管理
3. **对话 UI** — depends on: 场景/状态管理, 进度管理
4. **主菜单/晚安 UI** — depends on: 场景/状态管理, 进度管理

### Feature Layer

1. **拖拽换装** — depends on: 输入管理, 精灵分层渲染, 衣橱 UI, 音频管理
2. **每日场景** — depends on: 场景/状态管理, 精灵分层渲染, 对话 UI, 进度管理
3. **服装解锁** — depends on: 进度管理, 服装数据库, 衣橱 UI, 主菜单/晚安 UI, 场景/状态管理

### Narrative Layer

1. **轻叙事对话** — depends on: 每日场景, 对话 UI, 进度管理

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | 服装数据库 | MVP | Foundation | S |
| 2 | 保存/加载 | MVP | Foundation | S |
| 3 | 输入管理 | MVP | Foundation | S |
| 4 | 音频管理 | MVP | Foundation | S |
| 5 | 资源加载器 | MVP | Core Infrastructure | M |
| 6 | 进度管理 | MVP | Core Infrastructure | S |
| 7 | 场景/状态管理 | MVP | Core Infrastructure | S |
| 8 | 精灵分层渲染 | MVP | Rendering/UI | S |
| 9 | 衣橱 UI | MVP | Rendering/UI | M |
| 10 | 对话 UI | MVP | Rendering/UI | S |
| 11 | 主菜单/晚安 UI | MVP | Rendering/UI | S |
| 12 | 拖拽换装 | MVP | Feature | M |
| 13 | 每日场景 | MVP | Feature | M |
| 14 | 服装解锁 | MVP | Feature | S |
| 15 | 轻叙事对话 | MVP | Narrative | M |

Effort: S = 1 session, M = 2-3 sessions. A "session" is one focused design conversation producing a complete GDD.

---

## Circular Dependencies

- `场景/状态管理` ↔ `资源加载器` has an intentional BOOT/check relationship. Treat it as orchestration coupling, not direct `_ready()` mutual invocation. Architecture must preserve this with Autoload order plus `is_ready` checks.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 服装数据库 | Design | 数据结构定义错误会导致所有依赖系统返工。部件类别、属性字段、解锁条件——一旦写进代码就很难改 | 设计时先枚举所有 6 个类别、每类 4-5 件的具体数据，验证数据结构覆盖所有情况 |
| 拖拽换装 | Technical | Web 端拖拽可能与浏览器默认行为（滚动、选中文本）冲突。触摸事件和鼠标事件需要不同处理路径 | `/prototype 拖拽换装` 先做技术验证，确认 Godot 4.6 Web 导出拖拽体验达标 |
| 资源加载器 | Technical | 三层渐进加载策略如果设计不当，首帧加载 >2s 或切换类别时卡顿 | 明确 5MB 首帧预算，用 `ResourceLoader.load_threaded_request()` 异步加载 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 15 |
| Design docs started | 15 |
| Design docs reviewed | 15 |
| Design docs approved | 15 |
| MVP systems designed | 15/15 |

---

## Next Steps

- [x] Resolve `/review-all-gdds` 2026-06-11 blocking items: Autoload order, systems-index dependency map, save-load day 1 unlock AC
- [x] Sync warning-level flagged GDDs: 衣橱 UI InputManager region contract, 进度管理 item-count example, 场景/状态管理 Autoload prose, 服装数据库 pillar metadata
- [x] Save/Load lean design review approved on 2026-06-15 after rollback/reset/Web wrapper revisions
- [x] Sprite Layered Rendering lean design review approved on 2026-06-15 after async/result-signal, TextureCache, empty-outfit, and performance acceptance criteria revisions
- [x] Input Management lean design review approved on 2026-06-15 after Autoload order and RegionOptions schema revisions
- [ ] Run `/consistency-check` after registry updates and status sync
- [ ] Validate 资源加载器 Web threading/memory risk with `/prototype` before implementation
- [ ] Validate 拖拽换装 with `/prototype` before committing to full implementation
- [ ] Re-run `/review-all-gdds` or `/consistency-check` after flagged revisions
- [ ] Run `/gate-check pre-production` when all MVP GDDs are approved and technical P0 prototype checks are resolved
