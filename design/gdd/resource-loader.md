# 资源加载器 (Resource Loader)

> **Status**: Approved
> **Author**: user + Claude Code Game Studios
> **Last Updated**: 2026-06-05
> **Implements Pillar**: 即时有感

> **Quick reference** — Layer: `Core Infrastructure` · Priority: `MVP` · Key deps: `WardrobeDatabase`, `SceneStateManagement`

## Overview

资源加载器是「每日穿搭」游戏的纹理资产管理基础设施。它实现三层渐进加载策略——**启动预加载**（首帧必需资源）、**场景按需加载**（当前穿搭所需纹理）、**后台预测加载**（下一场景可能需要的资源）——确保在 256MB Web 内存上限和 60fps 帧预算约束下，约 30 件服装的全尺寸纹理（1024×1536，单张 ~8.4MB GPU 含 mipmap）和缩略图（48×48，单张 ~12KB GPU）在正确的时间以正确的分辨率出现在渲染管线中。

该系统本身不产生游戏行为——它是一个数据管道。但它直接支撑「即时有感」核心支柱：玩家拖拽一件衣服到角色身上时，纹理切换必须在 1 帧内完成（<16ms），否则"即时"的感觉就会断裂。系统通过分层缓存策略（热缓存命中 <1ms，暖缓存命中 <5ms，冷加载完整纹理 <16ms）和异步预加载来保证这个约束。

对下游消费者（精灵分层渲染、衣橱 UI），资源加载器提供统一的纹理获取接口——消费者不需要关心纹理来自内存缓存、磁盘还是后台线程，只需要提供一个物品 ID 和一个分辨率等级。

## Player Fantasy

资源加载器没有独立的玩家幻想——玩家不会说"这个游戏的纹理加载策略真棒"。但它支撑的体验是玩家直接感受到的：

- **"换装瞬间就能看到"**：拖拽一件衣服到角色身上，纹理在一帧之内切换完成——没有加载延迟、没有占位灰色方块。这种即时性让「即时有感」支柱成为可感知的现实。
- **"打开衣橱很流畅"**：衣橱网格中的缩略图在滚动时即时显示，不会出现"先空白再加载"的闪烁。玩家浏览衣橱时感受到的是响应性，而不是等待。
- **"切换场景不卡顿"**：从主菜单进入衣橱、从衣橱进入每日场景——纹理在场景切换前已预加载完毕。玩家不会看到纹理逐个弹出的过程。

简言之：这个系统不创造情感，但它消除技术摩擦——而消除摩擦本身，就是「即时有感」支柱的技术实现。

## Detailed Design

### Core Rules

**架构**：一个 Godot Autoload 单例（`resource_loader_manager.gd`，Autoload 注册名 `TextureCache`）管理全部纹理加载和缓存。它在 BOOT 阶段执行 Tier 1 预加载，然后通过信号和方法接口为下游系统提供纹理。

> **命名说明**：Autoload 注册名使用 `TextureCache` 而非 `ResourceLoader`，因为 Godot 引擎已有内置静态类 `ResourceLoader`。使用同名 Autoload 会遮蔽内置类，导致 `ResourceLoader.load()` 等核心 API 不可用。

**Autoload 注册顺序**（与全项目唯一 Autoload 链一致）：
```
1. WardrobeDatabase
2. GameState
3. SaveManager
4. TextureCache       ← 本系统
5. InputManager
6. ProgressManager
```

> **顺序说明**：TextureCache 的 `_ready()` 中 Tier 1 依赖 `WardrobeDatabase.is_ready == true`——WardrobeDatabase 在位置 1 保证就绪。GameState 在位置 2 管理 Foundation/Core 系统 BOOT 流程，SaveManager 在位置 3 先建立持久化入口，TextureCache 在位置 4 独立完成 Tier 1 加载（不依赖 GameState 的 BOOT 协调）。InputManager 与 ProgressManager 位于 TextureCache 之后；GameState 在场景转换时（如进入 WARDROBE）检查 `TextureCache.is_ready`，而非在自身 `_ready()` 中检查。

**三层加载策略**：

| 层级 | 触发时机 | 加载内容 | 加载方式 | 完成标准 |
|------|---------|---------|---------|---------|
| **Tier 1** — 启动预加载 | BOOT 阶段，TextureCache._ready() | UI 框架纹理 + 首日（day=1）所有物品的 THUMB 纹理 | 同步 `ResourceLoader.load()` | 全部加载完成 → `is_ready = true` |
| **Tier 2** — 场景按需 | 进入 WARDROBE / 切换类目 / 拖拽换装 | 当前穿搭的 FULL 纹理 + 当前浏览类目的 THUMB 纹理 | 异步 `load_threaded_request()` | 纹理就绪 → 发出 `texture_loaded` 信号 |
| **Tier 3** — 后台预测 | 空闲帧（`_process` 中逐帧推进） | 未装备类目的 FULL 纹理 + 次日缩略图 | 异步逐帧（每帧最多 1 个请求） | 静默完成，不触发信号 |

**分辨率等级**：

| 等级 | 标识 | 尺寸 | 用途 | GPU 内存（单张，含 mipmap） | 缓存策略 |
|------|------|------|------|-------------|---------|
| `THUMB` | `0` | 48×48 | 衣橱 UI 网格 | ~12KB（RGBA8 + mipmap） | 全量常驻，永不淘汰 |
| `FULL` | `1` | 1024×1536 | 角色精灵渲染 | ~8.4MB（RGBA8 + mipmap） | LRU 淘汰，热缓存上限 8 张 |

**缓存架构**（自维护三态缓存——不依赖 Godot ResourceLoader 内部缓存行为）：

```
热缓存 (Hot):  Dictionary[String, HotEntry]
              HotEntry = { texture: Texture2D, last_access: int }
              key = "{item_id}:{resolution}"  →  "top_white_tee:1"
              └── 直接内存引用，get_texture() 命中时返回（<1ms）
              └── 上限：FULL 纹理 MAX_HOT_FULL 张；THUMB 纹理无上限

暖缓存 (Warm): Dictionary[String, Texture2D]
              └── 自维护二级缓存——LRU 淘汰从 Hot 移入 Warm，不释放纹理
              └── 上限：MAX_WARM_FULL 张 FULL 纹理（默认 4）
              └── Warm 满时淘汰最旧的 Warm 条目：调用 `remove_resource_from_cache(path)` 释放引擎缓存，再将本系统引用置 null
              └── 获取时从 Warm 取出并提升到 Hot（<5ms）

冷 (Cold):    两个缓存层均未命中
              └── 需完整 I/O + PNG 解码管线（<16ms 单张 FULL）
```

> **设计决策**：暖缓存由本系统自维护（`_warm_cache: Dictionary`），不依赖 Godot ResourceLoader 内部缓存行为。**关键发现**：Godot 4.x 中 `ResourceLoader.load()` **和** `load_threaded_get()` 均将资源放入引擎级 `ResourceCache`（强引用缓存）。仅将本系统 Dictionary 引用置 null **不会**释放 GPU 纹理——引擎缓存仍持有引用。因此 LRU 淘汰路径在释放 Warm 条目时必须额外调用 `ResourceLoader.remove_resource_from_cache(path)` 才能真正释放纹理。`/prototype` 阶段需验证 Godot 4.6 Web 导出中 `remove_resource_from_cache()` 的可用性

**内存管理——LRU 淘汰**：

- 缩略图（THUMB）：全量常驻，不参与淘汰（~30 × 12KB ≈ 360KB）
- 全尺寸纹理（FULL）：热缓存上限 `MAX_HOT_FULL = 8`（~67MB），暖缓存上限 `MAX_WARM_FULL = 4`（~33.5MB）
- 当热缓存 FULL 数量达到上限时，淘汰最久未访问的纹理：将其从 `_hot_cache` 移除，移入 `_warm_cache`
- 当暖缓存数量达到 `MAX_WARM_FULL` 上限时，淘汰最久未访问的 Warm 条目——将其纹理引用置 null（真正释放，交还 GC）
- 淘汰时机：在加载新的 FULL 纹理到热缓存前检查
- 通过 `get_texture_or_request()` 或 `get_texture()` 访问 Warm 命中的纹理时，自动提升回 Hot（<5ms）。**提升也触发淘汰连锁**：若提升时 Hot 已满，先淘汰最久未访问的 Hot FULL 条目到 Warm（若 Warm 也满则连锁淘汰最旧 Warm 条目），再将目标纹理从 Warm 提升到 Hot

**API 接口**：

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `get_texture(item_id, resolution)` | item_id: String, resolution: int | Texture2D\|null | 同步获取。热缓存命中直接返回；暖缓存命中提升并返回（<5ms）；冷缓存返回 null |
| `get_texture_or_request(item_id, resolution, callback)` | 同上 + callback: Callable | void | **推荐**聚合方法。热/暖缓存命中时同步调用 callback(Texture2D)；冷缓存时自动发起异步加载 + 连接信号，加载完成后调用 callback。消除下游样板代码和信号竞态 |
| `request_texture(item_id, resolution)` | item_id: String, resolution: int | void | 异步请求。冷缓存时触发 `load_threaded_request()`；加载完成后发出 `texture_loaded` 信号。暖缓存命中时直接提升到热缓存并发出信号 |
| `preload_outfit(item_ids)` | Array[String] | void | 预加载指定物品的 FULL 纹理（Tier 2 入口），每帧最多处理 1 个请求 |
| `preload_category_thumbnails(category)` | String | void | 预加载指定类目全部物品的 THUMB 纹理 |
| `preload_day_thumbnails(day)` | int | void | 预加载指定天数解锁的全部物品的 THUMB 纹理 |
| `is_cached(item_id, resolution)` | String, int | bool | 纹理是否在热缓存或暖缓存中。**LOADING 状态的纹理返回 false**——纹理尚未就绪，不可用于渲染 |
| `evict_full_textures()` | — | void | 清空所有 FULL 热缓存和暖缓存条目（场景切换时调用）。对每个条目调用 `remove_resource_from_cache(path)` 释放引擎缓存，再置 null 本系统引用。**同时清理 `_pending_requests` 中所有 FULL 请求记录**——防止废弃请求导致后续重请求死锁（见 Edge Case #21） |
| `cancel_request(item_id, resolution)` | String, int | void | 取消指定纹理的进行中异步请求。若请求已完成则无操作。**取消时通知所有等待方 callback(null)**，防止调用方永久挂起 |
| `get_memory_estimate()` | — | int | 热缓存 + 暖缓存中所有纹理的估计内存占用（bytes）

**属性**：

| 属性 | 类型 | 说明 |
|------|------|------|
| `is_ready` | bool | Tier 1 完成后设为 true。下游系统应在查询前检查 |
| `load_error` | String | 非空 = Tier 1 加载中有纹理失败，内容为失败路径列表 |

**信号**：

| 信号 | 参数 | 说明 |
|------|------|------|
| `texture_loaded(item_id, resolution)` | String, int | 单个纹理异步加载完成，下游可调用 `get_texture()` 获取 |
| `batch_completed(item_ids)` | Array[String] | 一批预加载请求全部完成（用于场景切换确认） |

**纹理路径解析**：

```
# wardrobe.json 中存储的是相对路径
texture_path:  "clothing/top_white_tee.png"
thumbnail_path: "clothing/thumbnails/top_white_tee.png"

# TextureCache 解析为完整 res:// 路径
full_path = "res://assets/textures/" + relative_path
```

**Tier 1 加载流程**（`_ready()` 中同步执行）：

1. 检查 `WardrobeDatabase.is_ready`——数据库必须已就绪
2. 从 `WardrobeDatabase.get_unlocked_items(1)` 获取首日物品列表
3. 遍历列表，对每个物品：`ResourceLoader.load("res://assets/textures/" + item.thumbnail_path)` → 写入热缓存
4. 如有任何加载失败，记录到 `load_error` 但不中断——缺失纹理用占位图替代
5. 全部完成 → `is_ready = true`

**Tier 2 异步加载**：

1. 下游调用 `request_texture(item_id, FULL)` 或 `preload_outfit(item_ids)`
2. 系统检查热缓存 → 已命中则立即返回
3. 未命中 → `ResourceLoader.load_threaded_request(full_path)` 加入请求队列
4. `_process()` 中轮询 `load_threaded_get_status()` → `THREAD_LOAD_LOADED` 时调用 `load_threaded_get()` 取出，写入热缓存，发出 `texture_loaded` 信号
5. 通过 `ResourceLoader.load_threaded_get_status()` 获取的状态值：`THREAD_LOAD_IN_PROGRESS`(0) / `THREAD_LOAD_LOADED`(1) / `THREAD_LOAD_FAILED`(2) / `THREAD_LOAD_INVALID_RESOURCE`(3)

**Tier 3 预测加载**：

1. WARDROBE 进入后，在 `_process()` 中逐帧处理预测队列（每帧 1 个请求，不影响帧率）
2. 队列由空闲帧填充器生成：按类目 z_index 顺序预加载未装备类目的 FULL 纹理
3. GOODNIGHT 场景中预加载次日缩略图（若 day < 7）
4. 预测加载仅填充暖缓存，不提升到热缓存，不触发信号

**`_process()` 职责**：

- 每帧检查进行中的异步请求状态（最多迭代 5 个以避免帧超时）
- 将已完成的纹理写入热缓存并发出 `texture_loaded` 信号
- 从 Tier 3 队列中取 1 个请求发起新的 `load_threaded_request()`
- 总耗时预算：每帧 <2ms（留给渲染管线 ≥14ms）

### States and Transitions

资源加载器本身不管理游戏状态——它是无状态的加载管线。但它管理的纹理有状态转换：

```
COLD ──load_threaded_request()──→ LOADING ──成功──→ WARM ──get_texture()──→ HOT
  │                                  │                   │                      │
  │                                  └──失败──→ COLD     │←───evict()───────────┘
  │                                                      │
  │                          └──Warm 满时淘汰──→ COLD     │
  │                                                      
  └──────────────────────────────────────────────────────┘
```

| 状态 | 含义 | 获取延迟 | 内存占用 |
|------|------|---------|---------|
| COLD | 未加载 | N/A（需加载） | 0 |
| LOADING | `load_threaded_request` 进行中 | N/A（等待中） | 0 |
| WARM | 已加载，在 `_warm_cache` 中，无热引用 | <5ms | ~8.4MB（FULL）/ ~12KB（THUMB） |
| HOT | 在 `_hot_cache` 中，引用持有 | <1ms | ~8.4MB（FULL）/ ~12KB（THUMB） |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|---------|
| 服装数据库 | 本系统依赖 | 读取 `texture_path`、`thumbnail_path`、`unlock_day`。通过 `get_item_by_id()` 获取单物品路径，通过 `get_unlocked_items(day)` 获取批量物品列表 |
| 场景/状态管理 | 本系统依赖 | BOOT 阶段初始化（Tier 1）。GameState 通过 `is_ready` 检查资源加载器是否就绪。`skip_resource_loader` 在系统设计后设为 `false` |
| 精灵分层渲染 | 依赖本系统 | 换装时调用 `get_texture_or_request(item_id, FULL, callback)` 获取全尺寸纹理；callback 结果必须先经过精灵分层渲染的实例生命周期、generation/token 和节点有效性校验，校验通过后才可设置 `sprite.texture` |
| 衣橱 UI | 依赖本系统 | 显示物品网格时调用 `get_texture_or_request(item_id, THUMB, callback)` 获取缩略图设置到 TextureRect；在进入 WARDROBE 时调用 `preload_category_thumbnails(category)` |
| 拖拽换装 | 间接依赖（通过精灵分层渲染） | 不直接调用本系统 API |

> **Tier 1 依赖 WardrobeDatabase**：`_ready()` 中调用 `WardrobeDatabase.get_unlocked_items(1)`。Autoload 注册顺序保证 `WardrobeDatabase` 在 `TextureCache` 之前初始化。
> **共享请求取消约束**：`cancel_request(item_id, resolution)` 是纹理级取消，取消时会通知所有等待方 `callback(null)`。需要“只取消某个 Character 实例”的下游系统不得调用该方法，应使用本地 token/generation 丢弃迟到回调，避免影响其他实例或 UI 等待方。

> **空闲帧预加载协议**：`_process()` 中使用 `_paused` 布尔标志守卫——场景切换时设置为 `true` 暂停预加载，新场景 `_on_scene_ready()` 回调后恢复。防止在过渡期间加载不需要的纹理。

> **注意**：请勿使用 `is_processing() == false` 检查——`set_process(false)` 后 `_process()` 根本不会被调用，该检查为死代码。

## Formulas

### 缓存键构造

```
cache_key = item_id + ":" + str(resolution)
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `item_id` | String | wardrobe.json 中的有效物品 id | 物品唯一标识符 |
| `resolution` | int | 0 或 1 | 0=THUMB, 1=FULL |

**示例**：`"top_white_tee:1"` = top_white_tee 的 FULL 纹理

### 纹理路径解析

```
resolved_path = "res://assets/textures/" + item.texture_path
```

| 变量 | 类型 | 说明 |
|------|------|------|
| `item.texture_path` | String | wardrobe.json 中定义的相对路径 |
| `resolved_path` | String | Godot `ResourceLoader.load()` 可接受的绝对路径 |

### 纹理 GPU 内存估算

```
gpu_memory_bytes = texture.get_width() × texture.get_height() × 4 × MIPMAP_FACTOR
MIPMAP_FACTOR = 1.33
```

| 变量 | 类型 | 说明 |
|------|------|------|
| `texture.get_width()` | int | 纹理像素宽度 |
| `texture.get_height()` | int | 纹理像素高度 |
| `4` | constant | RGBA8 每像素 4 字节 |
| `MIPMAP_FACTOR` | float | 1.33 = mipmap 链总开销（1 + 1/4 + 1/16 + … → 4/3）。Godot 默认对导入纹理启用 mipmap |

> **注意**：此公式不含 NPOT 对齐开销（1536 → 2048，+78%），因为 Godot 4.6 Web 导出中 1536 高度对齐行为依赖 WebGL 实现。`/prototype` 阶段需实测验证。若对齐至 2048，单张 FULL 实际占用可达 1024×2048×4×1.33 ≈ 11.1MB。

**预期输出**：
- THUMB（48×48）：~12KB（含 mipmap）
- FULL（1024×1536）：~8.4MB（含 mipmap）

**`get_memory_estimate()` 实现**：遍历热缓存和暖缓存中所有条目，对每个 `Texture2D` 调用上述公式（含 MIPMAP_FACTOR）求和。

### LRU 访问序

LRU 淘汰依赖访问时间戳追踪：

```
last_access = Time.get_ticks_msec()
```

当热缓存中 FULL 纹理数量达到 `MAX_HOT_FULL` 且需要插入新 FULL 纹理时（**注意**：计数仅含 `resolution == FULL` 的条目，THUMB 条目不计入此上限）：
1. 扫描所有 `resolution == FULL` 的热缓存条目
2. 找到 `last_access` 最小的条目（最久未访问；若有平局则选任意一个——同一帧内加载的多张纹理可能时间戳相同）
3. 将其从 `_hot_cache` 移除，移入 `_warm_cache`
4. 若 `_warm_cache.size() >= MAX_WARM_FULL`，淘汰 Warm 中最旧的条目——调用 `ResourceLoader.remove_resource_from_cache(path)` 释放引擎缓存，再将本系统引用置 null
5. 插入新纹理到 `_hot_cache`，设置 `last_access = Time.get_ticks_msec()`

每次 `get_texture()` 命中时更新该条目的 `last_access`。

### 纹理状态转换延迟

| 转换 | 延迟上限 | 实现机制 |
|------|---------|---------|
| HOT → 返回 | <1ms | Dictionary 直接查找 |
| WARM → HOT | <5ms | 从 `_warm_cache` 移到 `_hot_cache`（Dictionary 操作，无 I/O） |
| COLD → WARM | <16ms（单张 FULL）/ <2ms（单张 THUMB） | 完整 I/O + PNG 解码管线 |
| COLD → LOADING | <1ms | `load_threaded_request()` 立即返回，后台线程加载 |

### 帧预算

```
_process_budget = 2.0 ms
max_poll_iterations = min(5, pending_request_count)
```

| 变量 | 类型 | 值 | 说明 |
|------|------|-----|------|
| `_process_budget` | float | 2.0 | `_process()` 每帧最大耗时（ms） |
| `max_poll_iterations` | int | ≤5 | 每帧最多轮询的异步请求数 |
| `pending_request_count` | int | 0–N | 当前进行中的 `load_threaded_request` 数量 |

## Edge Cases

| # | 场景 | 预期行为 | 理由 |
|---|------|----------|------|
| 1 | 纹理文件不在 `.pck` 中（`load_threaded_get_status` 返回 `FAILED` 或 `INVALID_RESOURCE`） | 加载失败，`load_error` 追加失败路径。`texture_loaded` 信号不发出。`get_texture()` 返回 null。下游系统应使用占位纹理 | 缺失纹理不应阻止其他纹理的正常加载和使用 |
| 2 | `WardrobeDatabase.is_ready == false` 时 `TextureCache._ready()` 执行 | 打印 `push_error()`，`is_ready = false`，`load_error` 记录 "Database not ready"。不执行 Tier 1 | Autoload 顺序保证不应出现此情况——若出现则说明注册顺序配置错误 |
| 3 | `request_texture()` 在 `is_ready == false` 时被调用 | 打印 `push_warning()`，调用被忽略。下游系统应在调用前检查 `is_ready` | 未就绪加载器不应静默接受请求 |
| 4 | `get_texture()` 在 `is_ready == false` 时被调用 | 返回 null。不打印警告——这是开发阶段场景未初始化的正常情况 | 静默返回 null 让下游系统自行处理 |
| 5 | 热缓存已满 + LRU 淘汰的纹理正被 Sprite2D 节点引用 | 纹理从 `_hot_cache` 移入 `_warm_cache`，不影响 Sprite2D 已持有的引用——Godot 引用计数保持纹理存活。下次 `get_texture()` 时从 `_warm_cache` 恢复（<5ms）。若 `_warm_cache` 满且该纹理被再次淘汰（Warm → COLD），调用 `remove_resource_from_cache(path)` 移除引擎缓存后本系统引用置 null——但 Sprite2D 持有的引用仍保持纹理存活直到节点释放。下次 `get_texture()` 需重新从磁盘加载 | LRU 热淘汰只移动缓存层；Warm 淘汰调用 `remove_resource_from_cache()` + 释引用。引擎硬引用移除后纹理生命周期仅由 Sprite2D 节点引用计数维持 |
| 6 | 同一纹理在 LOADING 状态被再次 `request_texture()` | 检测到已有进行中请求，跳过重复的 `load_threaded_request()`。新调用方加入等待列表，就绪后一起通知 | 防止同一文件多个并行加载 |
| 7 | 同一纹理在 LOADING 状态被 `get_texture()` | 返回 null——调用方应连接 `texture_loaded` 信号等待通知 | 同步获取不阻塞等待异步结果 |
| 8 | `preload_outfit()` 收到空数组 `[]` | 静默返回，不触发任何加载 | 空输入是合法情况（e.g.，初始空穿搭） |
| 9 | `resolution` 参数不在 {0, 1} 范围内 | `get_texture()` 返回 null，`request_texture()` 打印 `push_warning()` 后忽略 | 防御性编程，防止缓存键污染 |
| 10 | `item_id` 在 wardrobe.json 中不存在 | `WardrobeDatabase.get_item_by_id()` 返回 null → `get_texture()` 返回 null。不尝试加载不存在的路径 | 无效 id 由数据库层判定 |
| 11 | `_process()` 中轮询耗时超过 2ms 预算 | 每帧轮询前记录开始时间，超 2ms 立即 `return`，剩余请求推迟到下一帧 | 硬性帧预算约束 |
| 12 | 场景切换时仍有进行中异步加载 | `evict_full_textures()` 调用时：(1) 将进行中的 Tier 2 请求标记为"废弃"；(2) 从 `_pending_requests` 中移除所有 FULL 请求记录（释放去重锁）；(3) 通知所有等待方 callback(null)；(4) 清空 Tier 3 队列。`_process()` 检测到废弃标记时不发信号、不写热缓存 | 旧场景纹理不需要触发新场景的 UI 更新。清理 `_pending_requests` 防止后续重请求被去重逻辑跳过导致死锁（见 #21） |
| 13 | 全部 FULL 纹理加载后的内存占用量 | HOT 上限 `MAX_HOT_FULL=8`（~67MB）+ WARM 上限 `MAX_WARM_FULL=4`（~33.5MB）+ 缩略图 30 张（~0.36MB）+ WASM 运行时基线（~100-140MB，建议使用 120MB 作为默认估算）+ 音频/UI/其他（~10-30MB）≈ **低估算 231MB / 高估算 271MB**。**注意**：NPOT 高度 1536 在某些 WebGL 实现中可能向上对齐至 2048（+78% GPU 内存），极端对齐场景下约 257-307MB。**必须在 `/prototype` 阶段实测验证——若超 250MB 则降低 `MAX_HOT_FULL` 至 6 和/或启用 Basis Universal 压缩**（压缩后 FULL 纹理 ~1MB/张 含 mipmap，12 张仅 ~12MB） | 默认值 `8+4=12` 张 FULL 纹理涵盖"当前穿搭 + 最近浏览 + 预测"模式。WARM 满后最旧条目通过 `remove_resource_from_cache()` 真正释放。实际 GPU 内存需 `/prototype` 实测——NPOT 对齐和 GPU 纹理格式差异可能导致系统性偏差 |
| 14 | Web 端 `.pck` 尚未完全下载时访问 `res://` | 不存在此竞态——Godot Web 导出在 `.pck` 完全下载后才启动游戏和 Autoload | Godot Web 导出生命周期保证 |
| 15 | 纹理尺寸与预期不符 | 不校验尺寸——由美术资产管线保证。若异常导致渲染变形，由精灵分层渲染系统处理 | 尺寸校验不是加载器职责 |
| 16 | `get_memory_estimate()` 在热缓存为空时调用 | 返回 0 | 空缓存是合法状态 |
| 17 | Tier 1 中有个别纹理加载失败 | 失败路径追加到 `load_error`，继续加载其余纹理。`is_ready` 仍设为 true | 一个纹理缺失不应阻止启动 |
| 18 | Godot 4.6 Web 端 `load_threaded_request()` 实际不创建后台线程 | **已知风险（见 Open Questions #1）**。若验证发现线程不可用，备选方案：(A) 使用 Basis Universal GPU 压缩导入（单张 FULL 6MB→0.8MB，允许更大的热缓存）并提高 `MAX_HOT_FULL` 至 20-25 补偿异步缺失；(B) 降低 FULL 分辨率至 512×768（单张 ~1.6MB）；(C) 预加载全部 30 张 FULL 到热缓存（~188MB 未压缩 / ~24MB Basis 压缩）。**不推荐**分帧同步 `load()`——`ResourceLoader.load()` 是原子阻塞操作，单张 FULL 的 PNG 解码在主线程耗时 50-200ms，每帧 1 次会导致持续卡顿 | 同步 load() 回退对 FULL 纹理不可行。API 契约不变的前提是线程可用或使用 GPU 压缩 |
| 19 | `evict_full_textures()` 后立即调用 `get_texture()` | `evict_full_textures()` 清空热缓存和暖缓存——对每个 FULL 条目调用 `remove_resource_from_cache(path)` 后纹理引用置 null。`get_texture()` 返回 null（COLD 状态）。需重新调用 `request_texture()` 或 `get_texture_or_request()` 加载 | 场景切换时完全清空 FULL 缓存（含引擎缓存），旧场景纹理不应在新场景中恢复 |
| 20 | `MAX_HOT_FULL` 或 `MAX_WARM_FULL` 被设为不合理值 | setter 使用 `clamp(value, 1, 20)` 保护 `MAX_HOT_FULL`，`clamp(value, 0, 10)` 保护 `MAX_WARM_FULL`。`_ready()` 中加 assert(`MAX_HOT_FULL + MAX_WARM_FULL <= 25`) | `MAX_HOT_FULL=20, MAX_WARM_FULL=10` 极限组合 ≈252MB GPU 内存（仅 FULL 纹理）— 加上 WASM 基线已远超 256MB。assert 提供额外安全网。`MAX_WARM_FULL = 0` 合法——禁用暖缓存，淘汰调用 `remove_resource_from_cache()` 后置 null |
| 21 | `evict_full_textures()` 后新场景立即 `request_texture()` 同一纹理 | `evict_full_textures()` 已从 `_pending_requests` 中清理了旧请求记录（见 #12）。新 `request_texture()` 检测不到冲突的 pending 请求 → 正常发起新的 `load_threaded_request()`。旧请求完成时因废弃标记被忽略。**注意**：若未清理 `_pending_requests`，新请求会被去重逻辑跳过而永久挂起 | 废弃请求的去重锁必须随 evict 一同释放，否则造成静默死锁 |
| 22 | `is_cached()` 对 LOADING 状态的纹理被调用 | 返回 false。纹理在加载完成前不可用于渲染，调用方应通过 `get_texture_or_request()` 的 callback 或 `texture_loaded` 信号获取通知 | LOADING 状态既不在 Hot 也不在 Warm——`is_cached()` 的语义是"纹理是否可立即获取"。LOADING 纹理不满足此条件 |

## Dependencies

| 系统 | 方向 | 依赖性质 |
|------|------|----------|
| 服装数据库 | 本系统依赖 | 读取 `texture_path`、`thumbnail_path`、`unlock_day`。`_ready()` 中调用 `get_unlocked_items(1)` 获取 Tier 1 加载列表。下游请求时通过 `get_item_by_id()` 解析路径 |
| 场景/状态管理 | 本系统依赖 | BOOT 阶段执行 Tier 1，GameState 通过 `is_ready` 检查就绪状态。`evict_full_textures()` 在场景切换时由 GameState 或新场景 `_ready()` 调用 |
| 精灵分层渲染 | 依赖本系统 | 调用 `get_texture_or_request(id, FULL, callback)` 获取角色精灵纹理；callback 返回的纹理由精灵分层渲染校验 token/lifecycle 后再写入 Sprite2D |
| 衣橱 UI | 依赖本系统 | 调用 `get_texture_or_request(id, THUMB, callback)` 获取缩略图；进入 WARDROBE 时调用 `preload_category_thumbnails(cat)` |

本系统不依赖其他游戏系统。依赖以下 Godot 内置 API：

| API | 用途 |
|-----|------|
| `ResourceLoader.load(path)` | Tier 1 同步加载缩略图 |
| `ResourceLoader.load_threaded_request(path)` | Tier 2/3 异步加载 |
| `ResourceLoader.load_threaded_get_status(path)` | 轮询异步加载进度 |
| `ResourceLoader.load_threaded_get(path)` | 取出已加载完成的资源 |
| `ResourceLoader.exists(path)` | 检查资源路径是否存在（可选） |
| `Time.get_ticks_msec()` | LRU 访问时间戳 |
| `Time.get_ticks_usec()` | `_process()` 帧预算精确计时 |

## Tuning Knobs

| 参数 | 当前值 | 安全范围 | 增大效果 | 减小效果 |
|------|--------|----------|----------|----------|
| `MAX_HOT_FULL` | 8 | 1–20 | 更多 FULL 纹理常驻热缓存 → 换装命中率更高，但 GPU 内存占用增大（每张 +~8.4MB） | 更少内存占用，但换装时冷命中概率增大（需异步等待） |
| `MAX_WARM_FULL` | 4 | 0–10 | 更多淘汰后保留的纹理 → 回退命中率更高。0 = 禁用暖缓存（淘汰直接释放引擎缓存 + 本系统引用） | 更少内存占用，但淘汰的纹理再访问需重新加载 |
| `_process_budget_ms` | 2.0 | 0.5–5.0 | 每帧可处理更多异步请求，纹理就绪更快，但渲染管线帧预算被压缩 | 不影响渲染帧率，但异步加载完成更慢 |
| `MAX_POLL_PER_FRAME` | 5 | 1–20 | 爆发式完成更多请求，但单帧耗时增加 | 加载更平滑但响应更慢 |
| `TEXTURE_BASE_PATH` | `"res://assets/textures/"` | 任意有效 res:// 路径 | 可指向不同资产目录 | 路径不存在导致全部加载失败 |
| `PLACEHOLDER_FULL_PATH` | `"res://assets/textures/ui/placeholder_full.png"` | 有效 PNG 路径 | — | — |
| `PLACEHOLDER_THUMB_PATH` | `"res://assets/textures/ui/placeholder_thumb.png"` | 有效 PNG 路径 | — | — |
| `TIER3_ENABLED` | `true` | `true` / `false` | 后台预测加载启用，场景切换更流畅 | 节省 CPU 和内存，但场景切换可能有冷命中 |
| `TIER3_MAX_QUEUE` | 20 | 0–50 | 更大的预测队列，覆盖更多未来纹理 | 更保守的资源使用 |

**交互关系**：
- `MAX_HOT_FULL` + `MAX_WARM_FULL` 联动：若关闭 Tier 3，建议提高至 12+6（150% 默认值）补偿预测加载缺失。总 FULL 缓存上限 = `MAX_HOT_FULL + MAX_WARM_FULL`（默认 12 张 ≈ 100MB GPU 内存，含 mipmap）
- `_process_budget_ms` 和 `MAX_POLL_PER_FRAME` 联动：两者共同约束每帧耗时。实际耗时 ≈ `min(MAX_POLL_PER_FRAME, 进行中请求数) × 单次轮询耗时`
- `MAX_WARM_FULL = 0` 合法——暖缓存禁用，LRU 淘汰直接释放纹理。适用于内存极度受限的环境

所有旋钮在 `resource_loader_manager.gd` 文件顶部以 `@export` 常量定义，可在 Godot 编辑器中直接调整，无需改代码。

## Visual/Audio Requirements

资源加载器是纯基础设施——无视觉或音频输出。所有视觉反馈由下游系统（精灵分层渲染、衣橱 UI）负责。

| 事件 | 视觉反馈 | 音频反馈 | 优先级 |
|------|---------|---------|--------|
| 纹理加载中 | 无——下游系统可使用占位纹理 | 无 | — |
| 纹理就绪 | 无——下游系统通过 `texture_loaded` 信号自行更新渲染 | 无 | — |
| 纹理加载失败 | 无——下游系统使用占位纹理 | 无 | — |

> 加载器本身不渲染任何 UI。占位纹理的视觉设计属于资产管线职责。

## UI Requirements

资源加载器不渲染任何 UI。加载进度和错误状态的展示由下游系统负责：

| 信息 | 展示位置 | 更新方式 |
|------|---------|---------|
| Tier 1 加载状态 | Boot 画面（GameState.ERROR 场景） | `is_ready` / `load_error` 属性 |
| 纹理缺失（占位纹理可见） | 角色渲染区 / 衣橱网格 | 精灵分层渲染和衣橱 UI 自行检测 `get_texture()` 返回 null |

## Acceptance Criteria

**Tier 1 — 启动预加载**

- [ ] AC-1：`TextureCache._ready()` 执行后，`is_ready == true`，首日全部物品的 THUMB 纹理在热缓存中（`is_cached(id, 0) == true` 对所有 `unlock_day == 1` 的物品）
- [ ] AC-2：Tier 1 中个别纹理加载失败时，`is_ready` 仍为 true，`load_error` 包含失败路径，其余纹理正常可用
- [ ] AC-3：`WardrobeDatabase.is_ready == false` 时，`TextureCache.is_ready == false`，`load_error` 包含 "Database not ready"

**Tier 2 — 场景按需加载**

- [ ] AC-4：`request_texture(id, FULL)` 对冷缓存纹理发起异步加载，在 `_process()` 完成加载后发出 `texture_loaded(id, FULL)` 信号。备注：此 AC 依赖 `load_threaded_request` 在目标平台的可用性
- [ ] AC-5：`request_texture(id, FULL)` 对已在热缓存的纹理不发起 `load_threaded_request()`，不发出 `texture_loaded` 信号
- [ ] AC-6（设计约束——代码审查验证）：`request_texture(id, FULL)` 对正在 LOADING 的纹理不发起重复的 `load_threaded_request()`。内部实现通过等待列表机制确保加载完成后所有等待方收到通知。验证方式：代码审查确认去重逻辑 + spy/mock 验证 `load_threaded_request` 调用次数 ≤1
- [ ] AC-7：`preload_outfit(["id1", "id2", "id3"])` 将 3 个 FULL 纹理加入加载队列，全部完成后发出 `batch_completed(ids)` 信号

**Tier 3 — 后台预测加载**

- [ ] AC-8：`TIER3_ENABLED = true` 时，`_process()` 每帧从 Tier 3 预测队列中取出最多 1 个请求，发起 `load_threaded_request()`（在帧预算允许且无 Tier 2 待处理时）
- [ ] AC-9：Tier 3 加载完成的纹理写入 `_warm_cache`（自维护暖缓存），不写入 `_hot_cache`，不发出 `texture_loaded` 信号
- [ ] AC-10：`TIER3_ENABLED = false` 时，`_process()` 不从 Tier 3 队列发起新的预测加载

**缓存操作**

- [ ] AC-11：`get_texture(id, THUMB)` 命中热缓存时返回非 null 的 Texture2D
- [ ] AC-12：`get_texture(id, FULL)` 对冷缓存返回 null
- [ ] AC-13：`get_texture(id, FULL)` 对暖缓存（`_warm_cache`）命中时，将纹理从 `_warm_cache` 移到 `_hot_cache` 并返回 Texture2D
- [ ] AC-14：`is_cached(id, THUMB)` 在热缓存或暖缓存命中时返回 true
- [ ] AC-15：`is_cached(id, FULL)` 在冷缓存（既不在 `_hot_cache` 也不在 `_warm_cache`）时返回 false

**LRU 淘汰**

- [ ] AC-16：热缓存 FULL 纹理达到 `MAX_HOT_FULL`（8 张）时，插入第 9 张触发淘汰——最久未访问的 FULL 纹理从 `_hot_cache` 移到 `_warm_cache`
- [ ] AC-17：淘汰后（纹理在 `_warm_cache` 中），`get_texture(evicted_id, FULL)` 返回 Texture2D（从 `_warm_cache` 恢复到 `_hot_cache`），不返回 null
- [ ] AC-18：缩略图（THUMB）不参与 LRU 淘汰——所有已加载物品的 THUMB 均可通过 `get_texture(id, THUMB)` 获取且返回非 null Texture2D

**场景切换**

- [ ] AC-19：`evict_full_textures()` 清空所有 FULL 热缓存和暖缓存条目（`_hot_cache` 和 `_warm_cache` 中 resolution==FULL 的全部清除）。之后 `is_cached(any_id, FULL)` 返回 false（纹理引用已释放，回到 COLD 状态）
- [ ] AC-20：`evict_full_textures()` 调用时，进行中的 Tier 2 请求被标记废弃。`_process()` 检测到废弃标记后不发出 `texture_loaded` 信号，不写入任何缓存
- [ ] AC-21：`evict_full_textures()` 后缩略图不受影响——`is_cached(any_id, THUMB)` 仍返回 true（若已预加载）

**内存估算**

- [ ] AC-22：`get_memory_estimate()` 返回热缓存 + 暖缓存中所有 Texture2D 的 `width × height × 4` 总和（bytes）
- [ ] AC-23：`get_memory_estimate()` 在热缓存和暖缓存均为空时返回 0
- [ ] AC-24：热缓存包含 8 张 FULL（1024×1536）+ 30 张 THUMB（48×48）+ 暖缓存 4 张 FULL 时，`get_memory_estimate()` 返回 `(8 × 1024×1536×4 + 30 × 48×48×4 + 4 × 1024×1536×4) × MIPMAP_FACTOR` = `(50,331,648 + 276,480 + 25,165,824) × 1.33` = `75,773,952 × 1.33` ≈ **100,779,356 bytes**（~96MB）。精确值由测试数据集中 `HOT_FULL_COUNT`、`WARM_FULL_COUNT`、`THUMB_COUNT` 和 `MIPMAP_FACTOR` 决定

**API 防御**

- [ ] AC-25：`get_texture(id, resolution)` 对 `resolution ∉ {0, 1}` 返回 null
- [ ] AC-26：`request_texture(id, resolution)` 对 `resolution ∉ {0, 1}` 打印 `push_warning()` 后忽略
- [ ] AC-27：`request_texture(id, FULL)` 在 `is_ready == false` 时打印 `push_warning()` 后忽略
- [ ] AC-28：`get_texture(id, FULL)` 在 `is_ready == false` 时返回 null（不打印警告）
- [ ] AC-29：`preload_outfit([])` 静默返回，不触发任何副作用
- [ ] AC-30：对不存在的 `item_id`，`get_texture(nonexistent_id, FULL)` 返回 null

**性能**

- [ ] AC-31a（设计约束）：`get_texture()` 使用 Dictionary 直接索引查找——从代码结构保证 O(1) 时间复杂度，无额外计算或循环
- [ ] AC-31b（手动验证，ADVISORY）：在目标 Web 构建中使用 Godot Profiler 确认热缓存命中耗时 <1ms。提供 profiler 截图
- [ ] AC-32a（设计约束）：`_process()` 中 `MAX_POLL_PER_FRAME = 5` 硬限制，且每次轮询前检查耗时超 2ms 立即 `return`
- [ ] AC-32b（手动验证，ADVISORY）：在目标 Web 构建中使用 Godot Profiler 确认 `_process()` 帧耗时峰值 <2ms
- [ ] AC-33a（自动化）：Tier 1 对所有 `unlock_day == 1` 的物品使用 `ResourceLoader.load()` 同步加载，全部完成后 `is_ready == true`
- [ ] AC-33b（手动验证，ADVISORY）：在目标 Web 构建中，Tier 1 总耗时 <100ms（使用 `Time.get_ticks_msec()` 差值测量），不含 WASM 编译时间
- [ ] AC-34a（设计约束）：`get_memory_estimate()` 遍历最多 47 个缓存条目（8 HOT + 4 WARM + 30 THUMB + 边距），每条目仅做乘法 + 累加
- [ ] AC-34b（手动验证，ADVISORY）：在目标 Web 构建中确认调用耗时 <0.1ms

**信号**

- [ ] AC-35：`texture_loaded` 信号的 `item_id` 和 `resolution` 参数与 `request_texture()` 调用时的参数一致
- [ ] AC-36：同一纹理多次 `request_texture()` 时 `texture_loaded` 信号只发出一次（去重）
- [ ] AC-37：`batch_completed` 信号的 `item_ids` 数组与 `preload_outfit()` 调用时的数组集合一致（顺序可能不同）

**聚合方法 `get_texture_or_request()`**

- [ ] AC-40：热缓存命中——`get_texture_or_request(id, FULL, callback)` 对已在 `_hot_cache` 中的纹理，同步调用 `callback(texture)` 且 texture 非 null。不发起 `load_threaded_request()`，不发出 `texture_loaded` 信号
- [ ] AC-41：暖缓存命中——`get_texture_or_request(id, FULL, callback)` 对已在 `_warm_cache` 中的纹理，从 Warm 提升到 Hot（若 Hot 已满则触发淘汰连锁），同步调用 `callback(texture)` 且 texture 非 null。不发起新的异步加载
- [ ] AC-42：冷缓存——`get_texture_or_request(id, FULL, callback)` 对 COLD 纹理，发起 `load_threaded_request()`。加载完成后调用 `callback(texture)` 且 texture 非 null。`texture_loaded` 信号同时发出
- [ ] AC-43：重复请求去重——同一纹理在 LOADING 状态下再次 `get_texture_or_request(id, FULL, callback2)`，不发起重复的 `load_threaded_request()`。两个 callback（callback1 + callback2）在加载完成后均被调用且参数一致
- [ ] AC-44：加载失败——`get_texture_or_request(id, FULL, callback)` 对加载失败的纹理（`load_threaded_get_status` 返回 FAILED 或 INVALID_RESOURCE），`callback(null)` 被调用。`texture_loaded` 信号不发出。`load_error` 追加失败路径
- [ ] AC-45：`is_ready == false` 时调用——`get_texture_or_request(id, FULL, callback)` 打印 `push_warning()`，`callback(null)` 被调用，不发起加载
- [ ] AC-46：无效 resolution——`get_texture_or_request(id, 999, callback)` 打印 `push_warning()`，`callback(null)` 被调用，不发起加载
- [ ] AC-47：`evict_full_textures()` 后 LOADING 中的 `get_texture_or_request()`——若 evict 时纹理仍在加载，标记废弃后 `callback(null)` 被调用（不传入纹理），`texture_loaded` 信号不发出

**线程不可用回退**（Open Question #1 / Edge Case #18）

- [ ] AC-48：当 `/prototype` 验证发现目标平台 `load_threaded_request()` 不可用（无真实后台线程）时，系统回退到策略 (A) Basis Universal 压缩 + 增大热缓存 或 (B) 降低 FULL 分辨率，不崩溃，`is_ready` 仍可达 true。此 AC 在 `/prototype` 阶段前保持 OPEN 状态

**回调竞态保护**

- [ ] AC-49：`get_texture_or_request()` 实现中，等待方注册（callback 加入 pending callbacks 列表）必须在 `load_threaded_request()` 调用**之前**完成。验证方式：mock `load_threaded_request` 为同步立即完成，确认 callback 仍被调用且不丢失

**`cancel_request()` 副作用**

- [ ] AC-50：`cancel_request(id, FULL)` 调用后，`texture_loaded` 信号不发出，所有已注册的等待方 callback(null) 被调用，`_pending_requests` 中该请求的记录被移除。再次 `request_texture(id, FULL)` 可正常发起新加载（去重锁已释放）

**`_paused` 守卫**

- [ ] AC-51：`_paused = true` 时，`_process()` 中不推进 Tier 2 请求轮询，不从 Tier 3 队列发起新的 `load_threaded_request()`。`_paused = false` 恢复后正常推进

**`load_error` 累积格式**

- [ ] AC-52：多次加载失败（e.g. 2 个不同纹理失败）后，`load_error` 以换行符 `"\n"` 分隔各失败路径，而非覆盖前次记录。验证：触发 2 次失败 → 字符串包含 2 行，每行含完整 `res://` 路径

**`get_texture_or_request()` THUMB 路径**

- [ ] AC-53：`get_texture_or_request(id, THUMB, callback)` 对热缓存命中的缩略图同步调用 `callback(texture)` 且 texture 非 null。AC-40~47 的所有行为对 `resolution=THUMB` 同样适用（仅分辨率参数不同）

**路径解析**

- [ ] AC-38：路径解析函数 `_resolve_path("clothing/top_white_tee.png")` 返回 `"res://assets/textures/clothing/top_white_tee.png"`（纯字符串拼接，独立于 I/O 操作）
- [ ] AC-39：加载失败时 `load_error` 包含完整解析后的 `res://` 路径

## Open Questions

| 问题 | 负责人 | 截止 | 决议 |
|------|--------|------|------|
| **【P0 阻塞】** Godot 4.6 Web 导出中 `ResourceLoader.load_threaded_request()` 是否在独立线程执行？需要 (1) 服务端配置 COOP/COEP headers，(2) 使用 threads-enabled 导出模板。若不可用：备选方案为 (A) Basis Universal GPU 压缩 + 增大热缓存，(B) 降低 FULL 分辨率，(C) 预加载全部纹理。**不推荐**分帧同步 load()——阻塞式 PNG 解码会导致每帧 50-200ms 卡顿。**附加验证门**：`/prototype` 中实测总内存占用（含 mipmap 开销）——若超过 250MB，必须在 MVP 实现前降低 `MAX_HOT_FULL` 至 8 和/或启用 Basis Universal 压缩 | 技术总监 | `/prototype` 阶段 | **P0 阻塞——实现前必须验证**。若线程不可用，Tier 2/3 异步架构需重新设计。若内存超限，缓存上限需收紧 |
| 是否启用 Basis Universal GPU 纹理压缩导入？FULL 纹理 6.29MB/张 → ~0.8MB/张，10 张从 63MB→8MB。这是单次决策中影响最大的内存优化 | 技术总监 | 资产管线启动前 | 强烈建议在 MVP 阶段启用。与线程可用性联动——若线程不可用，压缩是降低预加载内存压力的关键 |
| 占位纹理（placeholder）的视觉设计——应显示纯色方块、灰色轮廓、还是游戏 logo 水印？ | 美术总监 | 资产管线启动前 | 占位纹理在开发阶段和纹理加载失败时可见。视觉方向应匹配"温暖手绘风"。建议使用半透明角色轮廓而非纯色方块 |
| `texture_loaded` 信号去重等待列表是否有内存上限？若下游系统反复 `request_texture()` 同一 id 且纹理始终加载失败，等待列表会无限增长 | 实现阶段 | 实现时 | 建议实现时给每个纹理的等待列表加 `MAX_WAITERS = 10` 上限，超出时 `push_warning()` |
| Tier 3 预测队列的填充策略是否需要在设计阶段细化？当前定义"按类目 z_index 顺序"，未定义具体空闲帧分配算法 | 系统设计师 | 实现前 | MVP 阶段按类目顺序足够。建议优化为优先加载当前已装备类目的其他物品（而非加载完全不同的类目）。后续可引入基于 `tags` 的启发式 |

**已决议**：
| 问题 | 决议 |
|------|------|
| Autoload 名称冲突 | 使用 `TextureCache` 而非 `ResourceLoader`，避免遮蔽 Godot 内置类 |
| Autoload 注册顺序 | `WardrobeDatabase → GameState → SaveManager → TextureCache → InputManager → ProgressManager` |
| 暖缓存实现 | 自维护 `_warm_cache: Dictionary`，含 `MAX_WARM_FULL = 4` 上限 |
| THUMB 内存估算 | 统一为 9KB（48×48×4 = 9,216 bytes） |
| 回退策略 | 同步 `load()` 回退不可行——改用 GPU 压缩 + 增大热缓存 |
