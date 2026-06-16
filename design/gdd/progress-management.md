# 进度管理 (Progress Management)

> **Status**: Approved
> **Author**: user + Claude Code Game Studios
> **Last Updated**: 2026-06-12
> **Implements Pillar**: 每日陪伴

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `保存/加载`, `服装数据库`

## Overview

进度管理是「每日穿搭」的进度追踪系统，作为 Godot Autoload 单例（`ProgressManager`）运行。它是 SaveManager（持久化数据）和 WardrobeDatabase（静态服装数据）之间的桥梁——从 SaveManager 读取当前天数、已完成进度和解锁记录，结合 WardrobeDatabase 中每件物品的 `unlock_day` 字段，向全游戏系统提供两个核心问题的答案：(1) "玩家可以玩第几天？"（进度门控），(2) "这件衣服现在能用吗？"（解锁判定）。每次"晚安"后的一次进度提交——`advance_day()`——是这个系统唯一的写操作入口：它尝试完成当前天、写入新解锁物品列表，并在持久化成功后才提交为玩家可见的新进度；第 7 天完成时只记录通关，不创建第 8 天。系统本身不渲染 UI、不控制场景切换、不管理服装数据——它是一个查询层：上游系统查询进度状态，SaveManager 和 WardrobeDatabase 提供数据。

## Player Fantasy

进度管理没有独立的玩家幻想——玩家不会说"这个游戏的进度门控逻辑设计得真好"。但它支撑的体验直接关系到「每日陪伴」支柱的"每日期待"节奏：

- **"明天会解锁什么新衣服？"**：玩家完成今天的穿搭、看完晚安画面、关闭浏览器——第二天打开游戏时，天数已经 +1，衣橱里多了 3-4 件新衣服。这种"隔天惊喜"不是魔法——是 ProgressManager 在 `advance_day()` 时计算了新一天的解锁列表并写入了 SaveManager。
- **"我的故事走到第几天了？"**：玩家在 MAIN_MENU 看到当前天数、已完成天数——这些数字来自 ProgressManager 的查询，不是硬编码的 UI 常量。进度数据是"每日陪伴"的叙事时钟——没有它，"7 天轻叙事"就是无结构的对话片段。
- **"为什么这件衣服还不能穿？"**：衣橱里灰色锁定的服装带着小锁图标——玩家知道它在未来某天会解锁。这种"等待期待"是收集感的来源。ProgressManager 的 `is_item_unlocked()` 是这个小锁图标的唯一真相来源。

简言之：这个系统不创造情感，但它是"每日陪伴"的计时器和"随心搭配"的门卫——它定义了玩家今天能穿什么、明天能期待什么。

## Detailed Design

### Core Rules

**架构**：一个 Godot Autoload 单例（`progress_manager.gd`，注册名 `ProgressManager`）在 `_ready()` 中连接 SaveManager 和 WardrobeDatabase，加载后计算初始解锁状态。系统不渲染 UI、不控制场景切换——它是一个查询层：其他系统询问进度状态，ProgressManager 根据 SaveManager 中的运行时数据 + WardrobeDatabase 中的静态配置给出答案。

**Autoload 注册顺序**：

```
1. WardrobeDatabase     ← 上游依赖（静态服装数据）
2. GameState
3. SaveManager          ← 上游依赖（持久化进度数据）
4. TextureCache
5. InputManager
6. ProgressManager      ← 本系统（需在 SaveManager 和 WardrobeDatabase 之后）
```

> **顺序说明**：上表是 Godot Project Settings 中的 Autoload 注册顺序，保证 `ProgressManager._ready()` 执行时 `WardrobeDatabase` 和 `SaveManager` 已存在。它不同于场景/状态管理 GDD 中的 BOOT 初始化顺序（DB → Save → Progress → Resource → Input）：BOOT 顺序描述 GameState 在启动流程中等待或检查各入口系统就绪的业务步骤。实现时两者都必须满足，但不要把 BOOT 初始化顺序误解为 Autoload 列表的完整排序。

**数据源**：ProgressManager 不拥有自己的持久化数据。它的全部状态来自：
- **SaveManager 只读快照/查询 API** → `current_day`、`highest_day_completed`、`unlock_progress`（运行时进度）
- **WardrobeDatabase.get_unlocked_items(day)** → 截至某天已解锁的物品字典列表（静态服装数据 + `unlock_day` 判定）
- **WardrobeDatabase.get_item_by_id(item_id)** → 单件物品的 `unlock_day` 和 `category`
- **WardrobeDatabase.get_categories()** → 类目定义，用于类目可见性规则

**API 接口**：

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `get_current_day()` | — | int | 当前游戏天数（1-7） |
| `get_highest_day_completed()` | — | int | 已完成的最高天数。0 = 尚未完成任何一天 |
| `get_total_days()` | — | int | 游戏总天数（固定 7） |
| `is_day_available(day)` | int | bool | 该天是否可玩。规则：`1 ≤ day ≤ highest_day_completed + 1` 且 `day ≤ 7` |
| `is_day_completed(day)` | int | bool | 该天是否已完成。规则：`1 ≤ day ≤ highest_day_completed` |
| `is_last_day()` | — | bool | `current_day == 7` |
| `is_item_unlocked(item_id)` | String | bool | 该物品当前是否解锁。规则：`item.unlock_day ≤ current_day` |
| `get_unlocked_items(category)` | String（可选） | Array[String] | 所有已解锁物品的 ID 列表。可选按类目过滤 |
| `get_items_for_day(day)` | int | Array[String] | 某天解锁的物品 ID 列表（从 `unlock_progress` 读取） |
| `get_newly_unlocked_items()` | — | Array[String] | 当前天数新解锁的物品（即 `unlock_progress[current_day]`） |
| `is_category_visible(category)` | String | bool | 该服装类目当前是否在衣橱中可见 |
| `get_visible_categories()` | — | Array[String] | 当前天数可见的服装类目键列表 |
| `advance_day()` | — | bool | 尝试完成当前天并持久化。返回 `true` 表示进度提交和 `SaveManager.save()` 均成功；返回 `false` 表示保存失败且已恢复调用前快照 |
| `mark_day_completed(day)` | int | void | 仅更新 `highest_day_completed` 数据，不发射 `day_completed`；信号由 `advance_day()` 在保存成功后统一发射 |

**属性**：

| 属性 | 类型 | 说明 |
|------|------|------|
| `is_ready` | bool | `_ready()` 完成且 SaveManager 已 loaded 后为 true |
| `current_day` | int | 当前天数（只读，从 SaveManager 同步） |
| `highest_day_completed` | int | 已完成最高天数（只读） |

**信号**：

| 信号 | 参数 | 说明 |
|------|------|------|
| `day_started` | int (day) | `advance_day()` 保存成功后，新的一天开始时发射 |
| `day_completed` | int (day) | `advance_day()` 保存成功后，某天完成时发射 |
| `items_unlocked` | Array[String] | `advance_day()` 保存成功后发射，携带新解锁的物品 ID 列表 |
| `progress_loaded` | — | 初始化解锁缓存完成后发射。其他系统应在收到此信号后才查询解锁状态 |

### `advance_day()` 详解

这是进度管理系统的核心写操作，被 GameState 在 GOODNIGHT → MAIN_MENU 转换时调用：

**调用前置条件**：GameState 必须先调用 `SaveManager.set_scene_in_progress(false)` 清除会话恢复标记，再调用 `ProgressManager.advance_day()`。由于 `advance_day()` 内部会执行最终 `SaveManager.save()`，该保存快照必须同时包含 `scene_in_progress = false`、新的完成天数、当前天数和 `unlock_progress`，避免刷新后错误恢复到已完成的 DAILY_SCENE。GameState 只有在 `advance_day()` 返回 `true` 后才进入 MAIN_MENU 或展示新一天/新解锁；返回 `false` 时停留在 GOODNIGHT 未安全结束状态。

```
advance_day() -> bool:
    1. snapshot = duplicate current_day, highest_day_completed, unlock cache, and SaveManager progress fields
    2. completed_day = current_day
    3. mark_day_completed(completed_day)    // 只改数据，不发信号
    4. if completed_day >= 7:
       a. set_current_day(7)                // 停留在最后一天，表示已通关
       b. if SaveManager.save() == false:
            restore ProgressManager current_day, highest_day_completed, and unlock cache from snapshot
            SaveManager.replace_progress_fields(snapshot.current_day, snapshot.highest_day_completed, snapshot.unlock_progress)
            return false
       c. 发射 day_completed(7)
       d. return true                       // 不存在第 8 天，不发射 day_started
    5. new_day = completed_day + 1
    6. 查询 WardrobeDatabase.get_unlocked_items(new_day) 与
       WardrobeDatabase.get_unlocked_items(completed_day) 的差集 → new_items
    7. 更新 SaveManager:
       a. set_current_day(new_day)
       b. record_unlocks(new_day, new_items)
    8. 准备内部解锁缓存候选值（不要让 UI 读取到已提交状态）
    9. if SaveManager.save() == false:
       a. restore ProgressManager current_day, highest_day_completed, and unlock cache from snapshot
       b. SaveManager.replace_progress_fields(snapshot.current_day, snapshot.highest_day_completed, snapshot.unlock_progress)
       c. return false    // scene_in_progress 由 GameState 在失败返回后恢复为 true，不由 ProgressManager 回滚
    10. 提交内部解锁缓存候选值
    11. 发射 day_completed(completed_day)
    12. 发射 items_unlocked(new_items)
    13. 发射 day_started(new_day)
    14. return true
```

**关键设计决策**：`advance_day()` 内部调用 `SaveManager.save()`，并把保存结果作为 `bool` 返回。调用方（GameState）不需要在调用 `advance_day()` 后再手动 save——一次调用完成进度推进 + 持久化。这避免了"调用方忘记 save 导致进度丢失"的时序 bug，同时避免保存失败时 UI 误以为新进度已安全提交。

**第 7 天语义**：`advance_day()` 在第 7 天被调用时仍然会完成当天并将 `highest_day_completed` 更新为 7。它只拒绝创建第 8 天。GameState 只有在 `advance_day() == true` 且收到 `day_completed(7)` 或检测到 `highest_day_completed == 7` 后进入通关/结尾画面，而不是等待 `day_started`。

### `is_item_unlocked()` 详解

解锁判定规则——这是"这件衣服现在能用吗"的唯一真相来源：

```
is_item_unlocked(item_id):
    1. item = WardrobeDatabase.get_item_by_id(item_id)
    2. if item == null: return false  (不存在的物品)
    3. return item.id in _unlocked_items_cache
```

**设计决策**：仅基于 `unlock_day` 判定。MVP 中所有解锁都是基于天数的——没有"完成特定任务解锁"或"组合搭配解锁"等事件型解锁。`unlock_progress` 在 SaveManager 中作为解锁记录留存，但不在 `is_item_unlocked()` 中作为判定依据——它是派生数据，不是权威源。未来如有事件型解锁需求，可扩展 `is_item_unlocked()` 的逻辑但 API 签名不变。

### 内部解锁缓存

ProgressManager 在 `_ready()` 中调用 `WardrobeDatabase.get_unlocked_items(current_day)` 计算一次完整解锁列表，并将返回字典中的 `id` 缓存在 `_unlocked_items_cache: Array[String]` 中。`get_unlocked_items()` 和 `is_item_unlocked()` 均查询缓存而非每次都遍历 WardrobeDatabase。`advance_day()` 先构造候选缓存；只有 `SaveManager.save()` 成功后才提交候选缓存，并在发射 `items_unlocked` 和 `day_started` 信号前完成更新。

缓存大小：7 天 × ~5 件/天 + 初始 ~8 件 ≈ 43 个字符串 ID < 2KB，内存开销可忽略。

### 类目可见性

进度管理同时负责衣橱类目的可见性。服装数据库只定义类目和物品；ProgressManager 决定“今天衣橱 UI 应显示哪些类目”。这支持 `game-concept.md` 中“前 3 天只开放基础部件，第 4 天起逐步解锁配饰、发型等”的新手节奏。

| 天数范围 | 可见类目 | 说明 |
|----------|----------|------|
| 第 1-3 天 | `top`, `bottom`, `shoes` | 只展示基础搭配类目，降低初始认知负担 |
| 第 4-5 天 | `top`, `bottom`, `shoes`, `accessory`, `hair` | 开始展示造型强化类目 |
| 第 6-7 天 | `makeup`, `top`, `bottom`, `shoes`, `accessory`, `hair` | 全部 MVP 类目可见 |

`is_category_visible(category)` 先检查 `category` 是否存在于 `WardrobeDatabase.get_categories()`；不存在则返回 `false`。`get_visible_categories()` 返回当前天数对应的类目键列表，并过滤掉 WardrobeDatabase 中不存在的类目，避免 UI 显示无效标签。

### Internal State Machine（不对外暴露）

```
UNINITIALIZED ──_ready()──→ WAITING_SAVE ──SaveManager.is_ready 或 loaded──→ COMPUTING ──缓存计算完成──→ READY
                                                                                        │
                                                                                        ├── advance_day() ──→ READY
                                                                                        ├── mark_day_completed() ──→ READY
                                                                                        └── 查询 API ──→ READY（纯读取，状态不变）
```

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|---------|
| 场景/状态管理 | 依赖本系统 | BOOT 中检查 `highest_day_completed` 决定是 MAIN_MENU、恢复 DAILY_SCENE，还是显示通关状态；GOODNIGHT 时调用 `advance_day()`，只有返回 `true` 才完成当天并推进天数 |
| 保存/加载 | 本系统依赖 | 读取 `current_day`、`highest_day_completed`、`unlock_progress`；通过 `save()` 持久化 |
| 服装数据库 | 本系统依赖 | 调用 `get_unlocked_items(day)`、`get_item_by_id(item_id)`、`get_categories()` 读取解锁和类目数据 |
| 衣橱 UI | 依赖本系统（未来） | 调用 `is_item_unlocked()` 决定服装部件显示为可用/锁定；调用 `get_unlocked_items()` 构建可用物品列表；调用 `get_visible_categories()` 构建类目标签 |
| 每日场景 | 依赖本系统（未来） | 调用 `get_current_day()` 确定今天加载哪个场景/对话 |
| 服装解锁 | 依赖本系统（未来） | 调用 `get_newly_unlocked_items()` 展示"新解锁！"提示 |

## Formulas

进度管理系统不包含复杂数学公式，但包含以下进度判定和门控规则：

### 进度门控规则

**天数可用性**：
```
is_day_available(day) = (day >= 1) AND (day ≤ highest_day_completed + 1) AND (day ≤ 7)
```
- 玩家只能玩"已完成天数的下一天"——不能跳关
- 已完成的 day 可以重玩（`is_day_available(1)` 在 `highest_day_completed = 3` 时返回 true）
- day 1 永远可用

**天数完成判定**：
```
is_day_completed(day) = (day >= 1) AND (day ≤ highest_day_completed)
```
- `highest_day_completed = 0` 时，所有 day 均未完成
- `highest_day_completed = 7` 时，所有 day 均已完成（游戏通关）

**最后一天判定**：
```
is_last_day() = (current_day == 7)
```

### 解锁判定

**物品解锁**：
```
is_item_unlocked(item_id) = item_id in _unlocked_items_cache
```
- `_unlocked_items_cache` 由 `WardrobeDatabase.get_unlocked_items(current_day)` 初始化
- 不存在的 `item_id` 不会进入缓存，因此返回 `false`
- 例：`top_white_tee` 的 `unlock_day = 1`，`current_day = 1` → 已解锁
- 例：`hair_ribbon` 的 `unlock_day = 3`，`current_day = 2` → 未解锁
- 不存在的 `item_id` → 返回 `false`

**新解锁物品计算**（`advance_day()` 内部）：
```
new_items(day) = ids(WardrobeDatabase.get_unlocked_items(day)) - ids(WardrobeDatabase.get_unlocked_items(day - 1))
```
- `day = 1` 时的解锁物品在游戏启动时已可用，不由 `advance_day()` 计算——`unlock_day = 1` 的物品在 `_ready()` 的初始缓存计算中处理
- `advance_day()` 只处理 `new_day ≥ 2` 的情况

**类目可见性**：
```
visible_categories(day) =
    day in 1..3 → ["top", "bottom", "shoes"]
    day in 4..5 → ["top", "bottom", "shoes", "accessory", "hair"]
    day in 6..7 → ["makeup", "top", "bottom", "shoes", "accessory", "hair"]
```
- 返回结果必须与 `WardrobeDatabase.get_categories()` 取交集，过滤不存在的类目
- 类目可见不等于该类目一定有可用物品；衣橱 UI 仍需用 `get_unlocked_items(category)` 获取实际可展示物品

**已完成天数的解锁物品**：
```
get_items_for_day(day) = SaveManager.get_data_snapshot().unlock_progress[str(day)]
```
- 返回该天解锁的物品 ID 列表
- 若 `unlock_progress` 中无此 key → 返回空数组（该天尚未完成或数据缺失）

### 进度数据完整度

| 场景 | current_day | highest_day_completed | 已解锁物品（估算） |
|------|-------------|----------------------|-------------------|
| 首次启动（默认存档） | 1 | 0 | ~7 件（`unlock_day = 1` 的物品） |
| 第 3 天穿搭中 | 3 | 2 | ~7 + 4 + 4 = ~15 件 |
| 第 7 天穿搭中 | 7 | 6 | ~7 + 4 + 4 + 4 + 4 + 4 + 3 = ~30 件（接近全部） |
| 通关（全部 7 天完成） | 7 | 7 | 全部 ~30 件 |

### 解锁节奏设计

基于 `game-concept.md` 的 MVP 定义（6 类目、每类 4-5 件、~30 件总量），解锁分布：

| 天数 | 解锁数量 | 累计解锁 | 说明 |
|------|---------|---------|------|
| 第 1 天（初始） | 6-8 件（目标约 7） | 6-8 | 每类目 1 件基础款，不调用 `advance_day()` |
| 第 2-6 天 | ~4 件/天 | ~27 | 均匀的"新衣服"惊喜 |
| 第 7 天 | ~3 件 | ~30 | 解锁最后一批，达到 MVP 总量 |

- 第 7 天时所有物品均已解锁（`unlock_day ≤ 7` 的自然结果）
- 如果某天在 WardrobeDatabase 中没有 `unlock_day == day` 的物品 → `new_items` 为空数组；只要保存成功，`advance_day()` 仍然正常推进天数，不报错（参见 EC-2）

## Edge Cases

### EC-1: 新游戏首次启动

**场景**：玩家首次打开游戏，localStorage 无存档数据。SaveManager 返回默认存档（`current_day = 1`，`highest_day_completed = 0`，`unlock_progress = {}`）。

**行为**：
- ProgressManager 在 `_ready()` 中先检查 `SaveManager.is_ready`
- 若 `SaveManager.is_ready == true`，通过 `SaveManager.get_data_snapshot()` 或正式查询 API 读取
- 若 `SaveManager.is_ready == false`，连接 SaveManager 的 `loaded` 信号，收到信号后再通过快照/查询 API 读取
- 读取 `data.current_day = 1` 后，遍历 WardrobeDatabase 计算 `unlock_day == 1` 的所有物品 → 解锁缓存初始化为初始物品列表
- `get_current_day()` 返回 1
- `get_highest_day_completed()` 返回 0——"尚未完成任何一天"
- `is_day_available(1)` 返回 true
- `is_day_available(2)` 返回 false——第 1 天尚未完成，第 2 天不可用
- `advance_day()` 在本次会话中不会被调用（玩家还没完成第 1 天的穿搭），但若被调用：
  - `new_day = 2`，查询 `unlock_day == 2` 的物品
  - `mark_day_completed(1)` 将 `highest_day_completed` 更新为 1
  - `record_unlocks(2, [...])` 记录第 2 天解锁物品

### EC-2: 某天没有任何解锁物品

**场景**：WardrobeDatabase 中不存在 `unlock_day == 3` 的物品（例如设计师把所有第 3 天物品移到了第 4 天）。

**行为**：
- `advance_day()` 中 `new_items` 为空数组 `[]`
- `record_unlocks(3, [])` 正常写入 SaveManager
- `items_unlocked([])` 信号发射——接收方收到空数组后不显示解锁提示
- 若 `SaveManager.save()` 成功，天数正常推进到 3，`highest_day_completed` 正常更新为 2
- 不报错、不跳过、不警告——某天没有解锁物品是合法的设计选择
- 空解锁不影响 `is_item_unlocked()`——该天的物品判定仍然基于 `unlock_day ≤ current_day`，只是没有"新物品"可展示

### EC-3: 第 7 天尝试调用 `advance_day()`

**场景**：玩家完成了第 7 天（最后一天）的穿搭，GameState 在 GOODNIGHT 时调用 `advance_day()`。

**行为**：
- `advance_day()` 先调用 `mark_day_completed(7)`，将候选 `highest_day_completed` 更新为 7
- `current_day` 保持为 7，不推进到第 8 天
- `SaveManager.save()` 持久化通关状态；若失败则恢复调用前快照并返回 `false`
- 保存成功后发射 `day_completed(7)`，不发射 `items_unlocked`，不发射 `day_started`
- `is_last_day()` 在第 7 天结束后仍然返回 `true`
- **设计决策**：第 7 天完成后不存在"第 8 天"。ProgressManager 负责记录“第 7 天已完成”；GameState 和 UI 负责展示通关画面

### EC-4: 存档中 `current_day` 超出合法范围

**场景**：由于历史 bug 或手动篡改，SaveManager 中的 `current_day` 为 0、负数或 > 7。

**行为**：
- ProgressManager 在初始缓存计算时检查 `current_day` 与 `highest_day_completed` 合法性
- 若 `current_day < 1`：clamp 为 1，发出 `push_warning("current_day out of range: {value}, clamped to 1")`
- 若 `current_day > 7`：clamp 为 7，发出 `push_warning`
- 若 `highest_day_completed < 0`：clamp 为 0，发出 `push_warning("highest_day_completed out of range: {value}, clamped to 0")`
- 若 `highest_day_completed > 7`：clamp 为 7
- 修复顺序必须固定：先将 `highest_day_completed` clamp 到 `0..TOTAL_DAYS`，再将 `current_day` clamp 到 `1..TOTAL_DAYS`，最后处理二者一致性
- 若 `highest_day_completed > current_day`：将 `current_day` 修正为 `min(highest_day_completed + 1, TOTAL_DAYS)`
- 若 `current_day > min(highest_day_completed + 1, TOTAL_DAYS)` 且 `highest_day_completed < TOTAL_DAYS`：将 `current_day` 修正为 `highest_day_completed + 1`
- 修复后的值写回 SaveManager（调用 `save()` 持久化修复结果）
- 这不是正常的游戏逻辑路径，但不应导致崩溃

### EC-5: `highest_day_completed` 大于 `current_day`

**场景**：存档数据异常——`highest_day_completed = 5` 但 `current_day = 3`（逻辑上不可能：已完成天数不可能超过当前天数）。

**行为**：
- ProgressManager 在 `_ready()` 中检测到此不一致
- 将 `current_day` 修正为 `min(highest_day_completed + 1, TOTAL_DAYS)`（即 6；若 `highest_day_completed == TOTAL_DAYS` 则保持 `TOTAL_DAYS`）并写回 SaveManager
- 发出 `push_warning("current_day inconsistent with highest_day_completed, corrected from {old} to {new}")`
- 这一修复确保玩家不会"卡在之前的天数"——进度已经推进，天数应该反映实际进度

### EC-5a: `current_day` 大于下一可用天

**场景**：存档数据异常——`current_day = 99`、`highest_day_completed = 0`。基础 clamp 后会得到 `current_day = 7`、`highest_day_completed = 0`，这会错误显示第 7 天并全量解锁。

**行为**：
- ProgressManager 在完成基础 clamp 后继续检查下一可用天
- `max_available_day = min(highest_day_completed + 1, TOTAL_DAYS)`
- 若 `current_day > max_available_day` 且 `highest_day_completed < TOTAL_DAYS`，将 `current_day` 修正为 `max_available_day`
- 上例最终修正为 `current_day = 1`、`highest_day_completed = 0`
- 修复后写回 SaveManager，并发出 warning

### EC-6: 重玩已完成的天

**场景**：玩家通关后在 MAIN_MENU 选择重玩第 3 天。`is_day_available(3)` 返回 true（已完成的天可以重玩）。

**行为**：
- **ProgressManager 不感知"重玩"**——它不知道也不关心玩家是在"首次游玩"还是"重玩"某天
- `is_item_unlocked()` 基于 `current_day` 判定，而 `current_day` 不会因重玩旧天数而改变
- 重玩时玩家可以使用已解锁的全部物品（包括第 7 天才解锁的物品在第 3 天重玩时可用）——这是设计意图：重玩的乐趣之一是用后期解锁的衣服搭配早期场景
- 重玩时 `advance_day()` 不被调用——GameState 在非首次完成场景时不推进天数

### EC-7: 存档重置后

**场景**：玩家选择"新游戏"，SaveManager 的 `reset()` 被调用，`current_day` 恢复为 1，`highest_day_completed` 恢复为 0，`unlock_progress` 清空。

**行为**：
- 若 ProgressManager 已在 READY 状态，需要重新计算解锁缓存
- **设计决策**：ProgressManager 暴露 `reset_progress()` 方法，由 GameState 在"新游戏"流程中显式调用
- `reset_progress()`：清空解锁缓存，重新从 SaveManager 和 WardrobeDatabase 计算初始状态，发射 `progress_loaded`
- ProgressManager 不在 SaveManager 的每次 `saved` 信号时重建缓存——`saved` 的频率太高，且大多数 save 不涉及进度重置

### EC-8: WardrobeDatabase 在 ProgressManager 查询时未就绪

**场景**：由于 Autoload 注册顺序错误或异步加载延迟，WardrobeDatabase 在 ProgressManager 的 `_ready()` 执行时尚未完成加载。

**行为**：
- ProgressManager 在 `_ready()` 中检查 `WardrobeDatabase.is_ready`
- 若 `false`：进入 WAITING_WARDROBE 子状态，连接 `WardrobeDatabase` 的就绪信号，延迟缓存计算
- 在此期间，所有查询 API（`is_item_unlocked`、`get_unlocked_items` 等）返回安全默认值（`false`、空数组）
- `is_ready` 在缓存计算完成后才设为 `true`
- 其他系统应在连接 `progress_loaded` 信号后再查询解锁状态——在 `progress_loaded` 发射前查询得到的是安全默认值

### EC-9: 查询不存在的 `item_id`

**场景**：UI 层传入了一个不存在的 `item_id`（拼写错误、已删除物品、或来自旧版存档的残留 ID）。

**行为**：
- `is_item_unlocked("nonexistent_id")` → 返回 `false`
- 不报错、不崩溃——`WardrobeDatabase.get_item_by_id()` 返回 null 时静默返回 false
- `get_items_for_day()` 返回的 ID 列表中可能包含不存在的物品（来自旧版存档残留）——消费方（UI）在尝试显示这些物品时应自行处理 null 情况

### EC-10: `advance_day()` 快速连续调用

**场景**：由于 bug 或异常流程，`advance_day()` 在短时间内被调用了两次。

**行为**：
- 第一次调用：`new_day = current_day + 1`，正常推进
- 第二次调用：`new_day` 再次 +1——这意味着玩家跳过了中间的天数
- **不做防重复调用保护**——`advance_day()` 是低频操作（每场会话最多调用 1 次），添加防重复逻辑增加复杂度而无实际收益
- 若因 bug 导致连续调用，结果会反映在存档数据中（天数异常跳跃），由 EC-4 在下一次启动时修复

## Dependencies

### 本系统依赖（上游）

| 依赖 | 类型 | 说明 |
|------|------|------|
| 保存/加载 | 强依赖 | 通过 SaveManager 只读快照/查询 API 读取 `current_day`、`highest_day_completed`、`unlock_progress`；调用 `set_current_day()`、`mark_day_completed()`、`record_unlocks()`、`save()` |
| 服装数据库 | 强依赖 | 调用 `get_unlocked_items(day)` 计算缓存和新解锁物品；调用 `get_item_by_id(item_id)` 校验单件物品；调用 `get_categories()` 过滤可见类目 |
| Godot Autoload 顺序 | 引擎约束 | `ProgressManager` 必须排在 `WardrobeDatabase` 和 `SaveManager` 之后，避免启动时查询未就绪数据 |

### 依赖本系统的系统（下游）

| 系统 | 依赖性质 | 说明 |
|------|----------|------|
| 场景/状态管理 | 强依赖 | GOODNIGHT → MAIN_MENU 时调用 `advance_day()` 并检查返回值；BOOT 时读取 `get_current_day()` / `get_highest_day_completed()` 决定启动场景或通关状态 |
| 衣橱 UI | 强依赖（未来） | 调用 `get_visible_categories()` 构建类目标签；调用 `get_unlocked_items(category)` 构建可用物品；调用 `is_item_unlocked(item_id)` 显示锁定状态 |
| 每日场景 | 强依赖（未来） | 调用 `get_current_day()` 选择当天场景和对话内容 |
| 服装解锁 | 强依赖（未来） | 监听 `items_unlocked` 或调用 `get_newly_unlocked_items()` 展示新解锁提示 |
| 主菜单/晚安 UI | 中依赖（未来） | 读取当前天数、完成天数、最后一天状态，用于显示进度和通关入口 |

### 双向依赖确认

**进度管理 ↔ 保存/加载**：
- 保存/加载 GDD 已定义 `current_day`、`highest_day_completed`、`unlock_progress` 字段，以及 `set_current_day()`、`mark_day_completed()`、`record_unlocks()`、`save()` API。
- 本 GDD 只负责进度规则和修复逻辑；SaveManager 仍只负责存取数据，不做天数合法性深度校验。

**进度管理 ↔ 服装数据库**：
- 服装数据库 GDD 已定义 `get_unlocked_items(day)`、`get_item_by_id(id)`、`get_categories()`。
- 本 GDD 不直接读取内部 `items` 数组，不依赖未公开字段。
- 类目级别的可见性由 ProgressManager 决定；服装数据库只提供类目定义和物品 `unlock_day`。

**进度管理 ↔ 场景/状态管理**：
- GameState 是 `advance_day()` 的唯一常规调用方，并必须检查返回值。
- 第 7 天完成且保存成功后，ProgressManager 只记录 `highest_day_completed == 7` 并发射 `day_completed(7)`；通关画面、菜单入口和是否允许重玩由 GameState / UI 处理。

### 实现约束

| 约束 | 影响 |
|------|------|
| `progress_loaded` 必须在 SaveManager 和 WardrobeDatabase 均就绪后发射 | 下游 UI 和场景系统应等待该信号后再查询进度 |
| 缓存更新必须早于 `items_unlocked` / `day_started` 信号，且必须晚于 `SaveManager.save()` 成功 | 监听者在信号回调中查询 ProgressManager 时能读到最新状态；保存失败时不会看到伪提交状态 |
| 对外 day 参数使用 1-based 编号 | 所有 day API 必须拒绝 0 和负数 |
| 不暴露持久化写接口给 UI | UI 查询进度，不直接修改 SaveManager；写操作集中在 GameState 调用 `advance_day()` / `reset_progress()` |

## Tuning Knobs

进度管理系统的可调参数极少——它是数据协调层，不是游戏机制。

| 参数 | 默认值 | 安全范围 | 影响 |
|------|--------|---------|------|
| `TOTAL_DAYS` | 7 | 1 – 30 | 游戏总天数。修改后影响 `is_day_available()`、`advance_day()` 的上限检查、`get_total_days()` 返回值。增大时需确保 WardrobeDatabase 中对应天数有 `unlock_day` 配置 |

### 非本系统控制的调参点

以下行为由 **其他系统** 控制，不在 ProgressManager 的 Tuning Knobs 范围内：

| 行为 | 控制方 | 说明 |
|------|--------|------|
| 每天解锁物品的数量和内容 | WardrobeDatabase | 通过每件物品的 `unlock_day` 字段配置。ProgressManager 只查询，不决定"哪些物品在哪天解锁" |
| `advance_day()` 的调用时机 | GameState | GOODNIGHT → MAIN_MENU 转换是唯一的调用点。若需改变推进时机（如手动"结束今天"按钮），由 GameState 修改 |
| 解锁提示的 UI 展示 | 服装解锁系统 | `items_unlocked` 信号发射后，是否显示"新解锁！"动画、是否展示物品详情——由 UI 层决定 |
| 类目解锁展示的视觉样式 | 衣橱 UI | ProgressManager 只返回可见类目列表，不决定标签样式、锁定动画或空类目提示 |

### 刻意不做成可调的

| 项目 | 固定值 | 原因 |
|------|--------|------|
| 解锁判定逻辑 | `unlock_day ≤ current_day` | 简单、可预测、无歧义。不需要配置——如果将来需要事件型解锁，扩展 `is_item_unlocked()` 而非替换 |
| `advance_day()` 内部调用 `save()` 并返回 bool | 固定行为 | "忘记 save"是最常见的进度丢失 bug。将 save 封装在 `advance_day()` 内部消除了这个风险；返回值让 GameState 能处理保存失败 |
| 天数从 1 开始（非 0-indexed） | 固定 | 与游戏叙事一致——"第一天"对玩家来说是 Day 1，不是 Day 0。所有对外 API 使用 1-based 天数 |
| 重玩使用全部已解锁物品 | 允许 | 重玩旧天数时玩家可以使用后期解锁的衣服——这是设计意图，不是 bug。不做"重玩时只允许当时已解锁物品"的限制 |
| 类目可见性节奏 | 1-3 天基础类目，4-5 天加入配饰/发型，6-7 天全部类目 | 这是新手引导节奏，不按存档或 UI 配置动态变化；若未来扩展为可调内容，可在 ProgressManager 增加配置表 |

## Acceptance Criteria

### 初始化和就绪

- [ ] **AC-1**: 首次启动（默认存档）后，`progress_loaded` 信号发射，`is_ready == true`
- [ ] **AC-2**: `get_current_day()` 返回 1（默认存档）
- [ ] **AC-3**: `get_highest_day_completed()` 返回 0（默认存档）
- [ ] **AC-4**: `get_total_days()` 返回 7

### 天数门控

- [ ] **AC-5**: `is_day_available(1)` 返回 `true`（day 1 永远可用）
- [ ] **AC-6**: `highest_day_completed == 0` 时，`is_day_available(2)` 返回 `false`
- [ ] **AC-7**: `highest_day_completed == 3` 时，`is_day_available(4)` 返回 `true`（下一天可用）
- [ ] **AC-8**: `highest_day_completed == 3` 时，`is_day_available(2)` 返回 `true`（已完成的天可重玩）
- [ ] **AC-9**: `highest_day_completed == 3` 时，`is_day_completed(2)` 返回 `true`
- [ ] **AC-10**: `highest_day_completed == 3` 时，`is_day_completed(4)` 返回 `false`
- [ ] **AC-11**: `is_last_day()` 在 `current_day == 7` 时返回 `true`，其他天数返回 `false`
- [ ] **AC-11a**: `is_day_available(0)` 和 `is_day_available(-1)` 返回 `false`
- [ ] **AC-11b**: `is_day_completed(0)` 和 `is_day_completed(-1)` 返回 `false`

### 物品解锁

- [ ] **AC-12**: `unlock_day == 1` 的所有物品在首次启动后通过 `is_item_unlocked()` 返回 `true`
- [ ] **AC-13**: `unlock_day == 3` 的物品在 `current_day == 2` 时 `is_item_unlocked()` 返回 `false`
- [ ] **AC-14**: `unlock_day == 3` 的物品在 `current_day == 3` 时 `is_item_unlocked()` 返回 `true`
- [ ] **AC-15**: 不存在的 `item_id` 在 `is_item_unlocked()` 中返回 `false`（不崩溃）
- [ ] **AC-16**: `get_unlocked_items()` 返回的 ID 列表不包含重复项
- [ ] **AC-17**: `get_unlocked_items("top")` 只返回类目为 `top` 的已解锁物品
- [ ] **AC-17a**: `is_category_visible("top")` 在第 1 天返回 `true`
- [ ] **AC-17b**: `is_category_visible("makeup")` 在第 1 天返回 `false`，在第 6 天返回 `true`
- [ ] **AC-17c**: `get_visible_categories()` 的返回值只包含 WardrobeDatabase 中存在的类目键

### `advance_day()`

- [ ] **AC-18**: `current_day` 为 1-6 且 `SaveManager.save()` 成功时调用 `advance_day()` 返回 `true`，`get_current_day()` 返回值 +1
- [ ] **AC-19**: `current_day` 为 1-6 且保存成功时调用 `advance_day()` 后，`get_highest_day_completed()` 返回值 +1（旧天数被标记为完成）
- [ ] **AC-20**: `current_day` 为 1-6 且保存成功时调用 `advance_day()` 后，`get_newly_unlocked_items()` 返回新解锁的物品 ID 列表
- [ ] **AC-21**: `current_day` 为 1-6 且保存成功时调用 `advance_day()` 后，新解锁物品在 `is_item_unlocked()` 中返回 `true`
- [ ] **AC-22**: `current_day == 7` 且 `highest_day_completed == 6` 且保存成功时调用 `advance_day()`——返回 `true`，`highest_day_completed` 更新为 7，`current_day` 保持 7，发射 `day_completed(7)`，不发射 `day_started`
- [ ] **AC-23**: `current_day` 为 1-6 且保存成功时调用 `advance_day()` 发射的信号顺序为：`day_completed` → `items_unlocked` → `day_started`
- [ ] **AC-23a**: `SaveManager.save()` 失败时调用 `advance_day()` 返回 `false`，通过 `SaveManager.replace_progress_fields(snapshot.current_day, snapshot.highest_day_completed, snapshot.unlock_progress)` 恢复调用前 `current_day`、`highest_day_completed`、`unlock_progress` 和解锁缓存；`unlock_progress` 必须整体替换，能删除候选推进时新增的陈旧 day key；`scene_in_progress` 由 GameState 在失败返回后恢复为 `true`，ProgressManager 不回滚该字段；不发射 `day_completed`、`items_unlocked`、`day_started`

### 存档交互

- [ ] **AC-24**: `current_day` 为 1-6 且 `advance_day()` 返回 `true` 后，SaveManager 中的 `current_day` 已更新（关闭并重新加载游戏后 `get_current_day()` 保持新值）
- [ ] **AC-25**: `current_day` 为 1-6 且 `advance_day()` 返回 `true` 后，SaveManager 中的 `unlock_progress` 包含新天数的解锁记录
- [ ] **AC-26**: 调用 `reset_progress()` 后，`get_current_day()` 返回 1，`get_highest_day_completed()` 返回 0，解锁缓存恢复为初始状态

### 数据修复

- [ ] **AC-27**: 存档中 `current_day == 10` 且 `highest_day_completed == 6` → 初始化为 `current_day == 7`，发出 `push_warning`
- [ ] **AC-27a**: 存档中 `highest_day_completed == -3` → 初始化为 `highest_day_completed == 0`，`is_day_available(1)` 返回 `true`，发出 `push_warning`
- [ ] **AC-28**: 存档中 `highest_day_completed > current_day`（如 5 > 3）→ `current_day` 被修正为 `highest_day_completed + 1`（即 6）
- [ ] **AC-28a**: 存档中 `highest_day_completed == 7` 且 `current_day < 7` → `current_day` 被修正为 7，不产生第 8 天
- [ ] **AC-28b**: 存档中 `current_day == 99` 且 `highest_day_completed == 0` → 初始化为 `current_day == 1`，不进入第 7 天，不全量解锁

### 信号

- [ ] **AC-29**: `progress_loaded` 在初始缓存计算完成后发射，且仅发射一次
- [ ] **AC-30**: `items_unlocked` 的参数 Array 包含正确的物品 ID 列表（与 `ids(WardrobeDatabase.get_unlocked_items(new_day)) - ids(WardrobeDatabase.get_unlocked_items(new_day - 1))` 的差集一致）
- [ ] **AC-30a**: `items_unlocked` 发射前，`get_unlocked_items()` 已包含本次新解锁物品

### 边界

- [ ] **AC-31**: WardrobeDatabase 未就绪时查询 API 返回安全默认值（`false`、`0`、空数组），不崩溃
- [ ] **AC-32**: `advance_day()` 在新解锁物品为空且保存成功时正常推进天数（不因空列表而跳过或报错）

### 不测试的内容

- `advance_day()` 快速连续调用的行为：低频操作，且 EC-10 已说明不做保护
- `get_items_for_day()` 返回列表中包含不存在的 ID：消费方（UI）负责容错
- 大型 `unlock_progress` 字典的序列化性能：SaveManager 已验证存档 < 2KB，ProgressManager 不增加显著开销
