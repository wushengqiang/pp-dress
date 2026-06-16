# 场景/状态管理 (Scene & State Management)

> **Status**: Approved
> **Author**: user + Claude Code Game Studios
> **Last Updated**: 2026-06-11
> **Implements Pillar**: 每日陪伴

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

场景/状态管理系统是「每日穿搭」游戏的状态机骨架。它定义游戏从启动到退出的完整生命周期——Boot 初始化、主菜单、衣橱、每日场景、晚安画面——以及这些状态之间的合法转换规则。系统本身不产生游戏内容，但它确保每个场景在正确的时机、以正确的顺序、携带正确的上下文被加载和卸载。

对于玩家来说，这个系统是透明的：玩家点击"开始今天"后进入衣橱，搭配完成后进入每日场景，夜晚到达晚安画面——这些自然流转就是这个系统在背后调度。它是一个 Foundation 层系统，零外部依赖，所有下游系统（UI、每日场景、进度管理）通过统一的状态切换接口消费场景变更事件。

## Player Fantasy

场景/状态管理系统没有独立的玩家幻想——玩家不会说"我喜欢这个游戏的状态机"。玩家感受到的是它调度出来的体验：

- **"每一刻都很自然"**：从主菜单进入衣橱、从衣橱进入每日场景、从场景进入晚安画面——每个过渡都平滑、没有卡顿或逻辑断裂。玩家不会注意到系统在管理状态转换，就像读者不会注意到书页在翻动。
- **"每天都是一个完整的小故事"**：游戏日循环（菜单 → 衣橱 → 每日场景 → 晚安）给玩家一个清晰的开始、中间和结束。这种节奏感直接服务于"每日陪伴"支柱——打开游戏像翻开一篇日记，有始有终。
- **"永远不会迷路"**：没有复杂的状态分支。每个状态只有一到两个出口、上一个状态总是清晰的。玩家在任意时刻都知道自己在哪里、接下来可以做什么。如果误入了衣橱，可以在确认穿搭前取消返回——不会有"被困住"的感觉。

简言之：这个系统不创造情感，但它确保情感不会被中断打断。

## Detailed Design

### Core Rules

**架构**：一个 Godot Autoload 单例（`game_state.gd`，Autoload 注册名为 `GameState`）管理全部状态。它拥有当前状态、处理状态转换、在状态变更时发出信号。Godot 场景系统负责实际的场景加载/卸载。

> **文件命名**：文件使用 `game_state.gd`（snake_case），匹配项目命名规范。Godot Autoload 注册名使用 `GameState`（PascalCase），作为全局单例标识符。

**Autoload 注册顺序**（Project Settings → Autoload 列表，从上到下）：
1. `WardrobeDatabase`（服装数据库——GameState 的 BOOT 阶段依赖其就绪状态）
2. `GameState`（本系统——必须在 WardrobeDatabase 之后注册，确保 `_ready()` 调用时 DB 已初始化）
3. `SaveManager`（保存/加载——GameState BOOT 流程等待其就绪并读取存档）
4. `TextureCache`（资源加载器——GameState BOOT 流程检查纹理预加载状态）
5. `InputManager`（输入管理——GameState BOOT 流程检查交互入口）
6. `ProgressManager`（进度管理——必须在 WardrobeDatabase 与 SaveManager 之后注册）

> **顺序说明**：这是全项目唯一 Autoload 链：`WardrobeDatabase → GameState → SaveManager → TextureCache → InputManager → ProgressManager`。它不同于 BOOT 业务初始化顺序；BOOT 仍由 GameState 按 `WardrobeDatabase → SaveManager → ProgressManager → TextureCache → InputManager` 做就绪检查和恢复编排。因为 `GameState._ready()` 早于后续 Autoload 的 `_ready()`，GameState 必须通过 `call_deferred()`、等待一帧或等待 Foundation ready 标记后再执行 BOOT，不得在 `_ready()` 同帧访问 SaveManager / ProgressManager。

**状态枚举**：

| # | 状态 | 含义 | 可达自 | 
|---|------|------|--------|
| 0 | `BOOT` | 启动初始化 | —（起始状态）, ERROR（重试） |
| 1 | `MAIN_MENU` | 主菜单，等待玩家点击"开始今天" | BOOT, GOODNIGHT, WARDROBE（取消搭配） |
| 2 | `WARDROBE` | 衣橱搭配界面 | MAIN_MENU |
| 3 | `DAILY_SCENE` | 当日叙事场景 | WARDROBE, BOOT（恢复进行中的会话） |
| 4 | `GOODNIGHT` | 晚安/当日收束画面 | DAILY_SCENE |
| 5 | `ERROR` | 致命初始化失败 | BOOT, WARDROBE, DAILY_SCENE, MAIN_MENU（运行时文件缺失） |
| 6 | `QUIT` | 退出游戏 | MAIN_MENU, GOODNIGHT |

**状态转换图**：

```
                  ┌──"重试"──┐
                  ↓          │
BOOT ──成功──→ MAIN_MENU ──"开始今天"──→ WARDROBE ──"确认穿搭"──→ DAILY_SCENE
  │               ↑          ←──"取消"──    │                        │
  └──失败──→ ERROR              (确认前)     │                        ↓
       ↑                                  │        GOODNIGHT ←──"晚安"──┘
       └──任意状态──运行时文件缺失────────┘          │       (玩家确认后)
                                                   ↓
MAIN_MENU ←──"继续（下一天）"── GOODNIGHT
    │                              │
    └──"退出"──→ QUIT              └──"退出"──→ QUIT

条件转换：
  BOOT ──(scene_in_progress == true 且 ProgressManager 已修复进度且 equipped_items 字段存在并为 Array[String]，可为空)──→ DAILY_SCENE（恢复中断的会话）
```

**关键规则**：
1. 穿搭确认前：玩家可自由取消并返回 MAIN_MENU（`WARDROBE → MAIN_MENU`）。穿搭确认后：不可逆（`WARDROBE → DAILY_SCENE` 是单向的）
2. 当前状态存储在 `GameState.current_state: GameState.State` 枚举中
3. **信号时序**：`SceneTree.change_scene_to_file()` 在 Godot 4.x 中是延迟的——场景切换在当前帧结束时才执行。因此 `state_changed(from, to)` 信号不能在新场景节点就绪前发出。正确时序为：GameState 调用 `change_scene_to_file()` → 新场景 `_ready()` 中调用 `GameState._on_scene_ready()` 确认就绪 → GameState 发出 `state_changed(from, to)` + 重置 `is_transitioning = false`
4. `current_day` 由 ProgressManager 作为权威源持有。GameState 保留 `get_current_day()` Facade 给 UI 和场景读取；未接入 ProgressManager 的临时阶段返回 1。每天从 MAIN_MENU → WARDROBE 时不变，GOODNIGHT → MAIN_MENU 时由 GameState 调用 `ProgressManager.advance_day()`；只有返回 `true` 才完成当天并在可推进时进入下一天。
5. 场景加载使用 `SceneTree.change_scene_to_file()` —— 每次状态转换对应一次场景切换。必须检查返回值（`Error` enum）：`ERR_CANT_OPEN` 触发 ERROR 转换（文件缺失或不可读），其他错误码记录日志后触发 ERROR
6. 上下文数据存储在 `GameState.context: Dictionary` 中，跨场景传递。`state_changed` 信号发出时附带 `context.duplicate(true)`（深拷贝），防止下游系统意外修改污染其他消费者
7. `is_transitioning` 守卫有 5 秒超时——若超时未收到 `_on_scene_ready()`，强制重置 `is_transitioning = false` 并转换到 ERROR（防止永久死锁）
8. 文件缺失（运行时）：任何非终端状态在 `change_scene_to_file()` 返回 `ERR_CANT_OPEN` 时均转换到 ERROR。ERROR 状态可通过"重试"按钮触发 `ERROR → BOOT` 重新初始化

**Context Schema**：

| Key | Type | Written By | Read By | Description |
|-----|------|-----------|---------|-------------|
| `current_day` | `int` | ProgressManager（GameState Facade 暴露） | 主菜单 UI, 晚安 UI, 对话 UI, 每日场景 | 当前游戏天数，1-7 |
| `equipped_items` | `Array[String]` | 衣橱 UI（WARDROBE 确认时） | 每日场景, 晚安 UI | 当日穿搭的物品 ID 列表 |
| `scene_in_progress` | `bool` | Save/Load 系统（未来） | GameState（BOOT 时检测） | 是否存在未完成的会话，用于 `BOOT → DAILY_SCENE` 恢复 |

> 下游系统应通过 `context` 读取数据，不应直接写入（衣橱 UI 除外，其在 WARDROBE 确认时写入 `equipped_items`）。写入新 key 前需更新此 schema 表。

### States and Transitions

| 状态 | 入口条件 | 行为 | 出口 | 触发 |
|------|---------|------|------|------|
| `BOOT` | 游戏启动 或 ERROR 重试 | 按依赖顺序初始化 Foundation/Core 入口系统（数据库→保存/加载→进度管理→资源加载器→输入管理），全部成功→MAIN_MENU | MAIN_MENU | 全部初始化成功 |
| | | 任一失败→ERROR | ERROR | 初始化失败 |
| | | 若保存系统就绪、`scene_in_progress == true`、ProgressManager 已完成修复，且 `equipped_items` 字段存在并可过滤为 `Array[String]`（允许空数组作为明确空穿搭），可跳过 MAIN_MENU 直接恢复 | DAILY_SCENE | 恢复进行中的会话 |
| `MAIN_MENU` | BOOT 成功、GOODNIGHT 的"继续"、或 WARDROBE 取消 | 显示标题画面 + "开始今天"按钮。`current_day` 显示在 UI 上 | WARDROBE | 玩家点击"开始今天" |
| | | | QUIT | 玩家关闭/退出 |
| `WARDROBE` | MAIN_MENU 的"开始今天" | 加载衣橱 UI，玩家为当天的 `current_day` 搭配服装 | MAIN_MENU | 玩家取消（穿搭确认前） |
| | | | DAILY_SCENE | 玩家确认穿搭 |
| `DAILY_SCENE` | WARDROBE 确认穿搭 或 BOOT 恢复 | 加载当日场景 + 角色对话。对话结束后显示"晚安"提示，玩家确认后触发 GOODNIGHT | GOODNIGHT | 玩家点击"晚安"（对话结束后显示） |
| `GOODNIGHT` | DAILY_SCENE 对话结束 + 玩家确认 | 晚安画面——角色穿着当天的穿搭做回顾。玩家点击继续时，GameState 先清除 `scene_in_progress`，再调用 `ProgressManager.advance_day()`；保存成功才显示完成感 | MAIN_MENU | `advance_day() == true`。未通关：进入下一天；已完成第 7 天：返回主菜单并显示通关/重玩入口 |
| | | 若 `advance_day() == false`，停留在 GOODNIGHT 未安全结束状态，显示低压重试入口，不展示新一天/新解锁 | GOODNIGHT | 保存失败，玩家选择重试 |
| | | | QUIT | 玩家点击"退出" |
| `ERROR` | BOOT 初始化失败 或 运行时场景文件缺失 | 显示安抚性错误画面 + "重试"按钮。技术细节写入日志 | BOOT | 玩家点击"重试" |
| `QUIT` | MAIN_MENU 或 GOODNIGHT | Web 端：显示告别画面，停止游戏循环（`get_tree().quit()` 在 Web 端可能无效，需显示静态告别 UI + 停止 `_process`） | — | 终端状态 |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|---------|
| 服装数据库 | 本系统依赖 | BOOT 阶段检查 `WardrobeDatabase.is_ready`；失败时读取 `load_error` 展示错误画面 |
| 保存/加载 | 本系统依赖 | BOOT 阶段等待保存系统就绪，读取存档（含 `current_day`、`highest_day_completed`、`scene_in_progress`、`equipped_items`）。**接口要求**：保存系统须提供 `scene_in_progress: bool` 标记和已保存穿搭；GameState 只有在 ProgressManager 修复完成且 `equipped_items` 字段存在并为数组时才恢复中断会话，`[]` 表示明确空穿搭而不是无效恢复 |
| 资源加载器 | 本系统依赖 | BOOT 阶段检查资源加载器就绪状态；正式实现中 `skip_resource_loader = false`，资源加载器不可用时进入可恢复错误流程或安全 loading 流程 |
| 输入管理 | 本系统依赖 | BOOT 阶段检查输入管理器就绪状态；正式实现中 `skip_input_manager = false`，输入管理不可用时不得进入可交互 WARDROBE |
| 对话 UI | 依赖本系统 | 在新场景 `_ready()` 中调用 `GameState._on_scene_ready()` 触发 `state_changed` 信号；通过 `GameState.get_current_day()` 或 `context["current_day"]` 选择对话内容 |
| 主菜单/晚安 UI | 依赖本系统 | 同样通过 `_on_scene_ready()` 回调触发信号；通过 `GameState.get_current_day()` 或 `context["current_day"]` 显示天数；触发 WARDROBE / QUIT 转换 |
| 每日场景 | 依赖本系统 | 同样通过 `_on_scene_ready()` 回调触发信号；从 `context` 读取 `current_day` 和 `equipped_items` |
| 精灵分层渲染 | 无直接交互 | 每个场景独立管理自己的精灵节点树 |
| 衣橱 UI | 无直接交互 | 衣橱 UI 通过 WARDROBE 场景内的节点树独立运行 |
| 进度管理 | 本系统依赖 | ProgressManager 是 `current_day` 和完成进度的权威来源。GameState 保持为 `current_day` 的公开访问点（Facade），内部委托 `ProgressManager.get_current_day()`；GOODNIGHT → MAIN_MENU 时调用 `ProgressManager.advance_day()` 并检查返回值 |

> **正式实现约定**：资源加载器、输入管理和进度管理均已完成 GDD 设计，正式实现默认不得跳过。各 `skip_*` 标志只允许在受控原型或隔离测试中临时启用；进入 MVP 主流程前必须恢复为 `false`。

> **信号时序约定**：下游系统不应在 `_ready()` 中连接 `state_changed` 信号（因为信号由 `_on_scene_ready()` 触发，此时 `_ready()` 尚未返回，存在时序竞争）。下游系统应在 `_ready()` 中直接读取 `GameState.current_state` 和 `GameState.context` 获取当前上下文，然后决定是否连接 `state_changed` 监听后续转换。

## Formulas

场景/状态管理系统无复杂数学公式。以下两个规则定义了系统的核心行为逻辑：

### 状态转换有效性

```
transition_is_valid = (from_state, to_state) in valid_transitions
```

| 变量 | 类型 | 说明 |
|------|------|------|
| `from_state` | `State` enum | 当前状态 |
| `to_state` | `State` enum | 目标状态 |
| `valid_transitions` | `Set[(State, State)]` | 预定义的合法转换集合 |

**合法转换集合**：
- `(BOOT, MAIN_MENU)`
- `(BOOT, ERROR)`
- `(BOOT, DAILY_SCENE)` — 条件：`scene_in_progress == true` 且 `ProgressManager.is_ready == true` 且 `equipped_items` 字段存在并过滤为 `Array[String]`；数组允许为空，`[]` 表示明确空穿搭
- `(MAIN_MENU, WARDROBE)`
- `(MAIN_MENU, QUIT)`
- `(WARDROBE, MAIN_MENU)` — 仅穿搭确认前（`outfit_confirmed == false`）
- `(WARDROBE, DAILY_SCENE)`
- `(DAILY_SCENE, GOODNIGHT)`
- `(GOODNIGHT, MAIN_MENU)`
- `(GOODNIGHT, QUIT)`
- `(ERROR, BOOT)` — 玩家点击重试

**运行时故障转换**（不依赖 `from_state`，由 `change_scene_to_file()` 返回值驱动）：
- 任何非终端状态（BOOT, MAIN_MENU, WARDROBE, DAILY_SCENE, GOODNIGHT）→ `ERROR`：当 `change_scene_to_file()` 返回 `ERR_CANT_OPEN` 时触发。此转换绕过 `valid_transitions` 集合检查，因为它是引擎级故障恢复而非设计级状态转换。

任何不在上述集合中的设计级转换被拒绝，使用条件日志（`push_warning()` 仅在 debug 构建或 `--verbose` 模式下输出，release Web 构建中静默）。

### 进度推进委托

```
GOODNIGHT → MAIN_MENU:
    SaveManager.set_scene_in_progress(false)
    if ProgressManager.advance_day() == false:
        SaveManager.set_scene_in_progress(true)    // 仅恢复内存语义，不再二次 save
        stay in GOODNIGHT_UNSAVED view
        show retry as primary action
        return
    current_day = ProgressManager.get_current_day()
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `current_day` | int | 1–7 | ProgressManager 返回的当前天数 |
| `highest_day_completed` | int | 0–7 | ProgressManager 记录的最高完成天数 |

仅在 `GOODNIGHT → MAIN_MENU` 转换时触发。GameState 不直接执行 `current_day + 1`；天数下限、上限、第 7 天通关语义和存档写入都由 ProgressManager 处理。GameState 必须先在内存中清除 `scene_in_progress`，再调用 `advance_day()`，因为 `advance_day()` 内部执行最终保存。若 `advance_day()` 返回 `false`，ProgressManager 已回滚进度字段；GameState 必须恢复/保持 `scene_in_progress = true` 的未安全结束内存语义，但不得在失败路径再次调用 `SaveManager.save()`。这样刷新浏览器时仍按最后一次成功保存的 `scene_in_progress = true` 恢复当天 DAILY_SCENE，而不是进入新一天或展示新解锁。第 7 天完成且保存成功后，`current_day` 保持 7，`highest_day_completed == 7`，UI 显示通关/重玩入口。

## Edge Cases

| # | Scenario | Expected Behavior | Rationale |
|---|----------|------------------|-----------|
| 1 | 非法状态转换（e.g., WARDROBE 确认后 → MAIN_MENU） | 条件日志记录警告（仅 debug/verbose 模式），转换被拒绝，停留在当前状态 | 穿搭确认后的转换是单向的。Release Web 构建中不输出到浏览器控制台 |
| 2 | 在转换进行中触发第二次转换 | `is_transitioning` 守卫拒绝第二次转换，条件日志记录 | 防止竞态条件。5 秒超时防止永久死锁：若 `_on_scene_ready()` 未在 5 秒内回调，强制重置 `is_transitioning` 并转 ERROR |
| 3 | 目标场景 `.tscn` 文件缺失 | `change_scene_to_file()` 返回 `ERR_CANT_OPEN` → 转换到 ERROR 状态，显示"游戏资源加载失败"画面 + 重试按钮，日志记录缺失的文件路径 | 致命但可恢复——玩家可点击重试重新跑 BOOT |
| 4 | `highest_day_completed == 7`（一周完成） | GameState 返回 MAIN_MENU，主菜单/晚安 UI 显示通关/重玩入口，不再尝试推进到第 8 天 | 第 7 天完成语义由 ProgressManager 处理；状态机只负责路由到正确 UI |
| 5 | 玩家在 WARDROBE 中刷新浏览器 | 游戏从 BOOT 重新启动，`current_day` 从存档恢复（若有保存系统）或重置为 1（若无） | Web 端刷新 = 新进程启动，游戏状态不保留在内存中。进度恢复依赖保存系统 |
| 6 | 玩家在 DAILY_SCENE 中途刷新浏览器 | BOOT 重启，场景进度丢失。若保存系统就绪且此前在 WARDROBE 确认时自动保存了 `scene_in_progress = true`，GameState 必须等待 ProgressManager 修复完成，并过滤已保存的 `equipped_items`；只有有效穿搭非空时才恢复进入 DAILY_SCENE（从当天对话开头重放），否则清除恢复标记并进入 MAIN_MENU | 进度恢复由保存系统提供入口，由 ProgressManager/GameState 保证业务安全 |
| 7 | 浏览器后退按钮 | 禁用以防止意外退出——Godot Web 导出默认截获后退事件。若玩家强制后退，等同于刷新 (#5) | Web 端无法完全阻止浏览器后退，但 Godot 默认行为已提供基本防护 |
| 8 | 浏览器标签页切换（切出再切回） | 使用 `NOTIFICATION_WM_WINDOW_FOCUS_OUT` 暂停音频/动画，`NOTIFICATION_WM_WINDOW_FOCUS_IN` 恢复。不使用 `get_tree().paused`（会阻塞延迟的场景转换）。不触发状态转换 | 防止后台标签页累积时间差。可选：在 GOODNIGHT 画面跳过暂停（允许玩家切出去分享截图）。窗口通知比 `get_tree().paused` 更安全，不会干扰正在进行的场景转换 |
| 9 | `current_day` 存档值异常（≤0 或 >7） | BOOT 初始化 ProgressManager 时修复为合法范围；GameState 通过 Facade 读取修复后的值 | 天数合法性属于 ProgressManager 职责，GameState 不自行修复 |
| 10 | `context` Dictionary 被下游系统修改 | `GameState` 在 `state_changed` 信号发出时附带 `context.duplicate(true)`（浅层深拷贝——对 Array 也复制）。下游系统修改自己的副本不会污染其他消费者 | 数据安全优先：context 数据量小（几个 key），深拷贝开销 <0.1ms |
| 11 | `SceneTree.change_scene_to_file()` 调用失败（非 `ERR_CANT_OPEN` 错误码） | 检查返回值：`ERR_CANT_OPEN` → ERROR（可恢复）；其他错误码（`ERR_FILE_CORRUPT` 等）记录 `push_error()` 后也转 ERROR | 所有非成功的场景加载都应触发 ERROR 恢复流程，而非静默失败或崩溃 |
| 12 | BOOT 中某个 Foundation 系统初始化超时 | 当前设计不实现超时机制——假设同步初始化均在 1 帧内完成。若未来引入异步初始化，应添加超时 + 重试逻辑 | MVP 阶段所有 Foundation 系统均为同步轻量初始化，超时问题不会发生 |
| 13 | `state_changed` 信号无接收方 | 信号发出但无槽连接——Godot 默认行为是静默（不报错） | 合法场景：某些状态转换可能没有下游消费者。下游系统也可通过直接读取 `GameState.current_state` 获取当前状态，无需连接信号 |
| 14 | 下游系统在 `state_changed` 信号发出后才连接 | 下游系统可通过 `GameState.current_state` 直接读取当前状态，并通过 `GameState.context` 获取上下文数据 | 信号用于"接下来发生什么"，当前状态用于"现在是什么"。两者互补 |
| 15 | `WARDROBE → MAIN_MENU`（取消搭配）触发 | 仅当 `outfit_confirmed == false` 时允许。衣橱 UI 显示"取消今天？"确认提示，玩家确认后执行转换 | 防止穿搭确认前的误入困境。确认穿搭后 `outfit_confirmed = true`，此时不可取消 |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| 服装数据库 | 本系统依赖 | BOOT 阶段调用 `WardrobeDatabase.is_ready` 检查数据库状态；失败时读取 `load_error` 展示错误画面 |
| 保存/加载 | 本系统依赖 | BOOT 阶段等待保存系统就绪；ProgressManager 从存档读取 `current_day` / `highest_day_completed`。**接口要求**：保存系统须提供 `scene_in_progress: bool` 和 `equipped_items`，支持 WARDROBE 确认时自动保存（`equipped_items`、`scene_in_progress = true`；`current_day` 只从 ProgressManager 读取），GOODNIGHT → MAIN_MENU 转换时清除 `scene_in_progress` |
| 资源加载器 | 本系统依赖 | BOOT 阶段初始化或检查资源加载器。正式实现不得跳过；若不可用，GameState 不进入依赖纹理的可交互流程 |
| 输入管理 | 本系统依赖 | BOOT 阶段初始化或检查输入管理器。正式实现不得跳过；若不可用，GameState 不进入可交互 WARDROBE |
| 对话 UI | 依赖本系统 | 在 `_ready()` 中读取 `GameState.current_state` 和 `GameState.context`；检测 DAILY_SCENE 进入时从 `GameState.get_current_day()` 或 `context["current_day"]` 选择对话内容 |
| 主菜单/晚安 UI | 依赖本系统 | 在 `_ready()` 中读取 `GameState.current_state`；检测 MAIN_MENU / GOODNIGHT 进入；从 `GameState.get_current_day()` 或 `context["current_day"]` 显示天数；触发 WARDROBE / QUIT 转换 |
| 每日场景 | 依赖本系统 | 在 `_ready()` 中读取 `GameState.current_state`；检测 DAILY_SCENE 进入；从 `context` 读取 `current_day` 和 `equipped_items` 选择场景内容和渲染穿搭 |
| 进度管理 | 强依赖 | GameState 不自维护 `current_day`。GameState 保持为 `current_day` 的唯一公开访问点（Facade 模式），内部委托 `ProgressManager.get_current_day()`；GOODNIGHT → MAIN_MENU 时调用 `ProgressManager.advance_day()` 并只在返回 `true` 时转换 |

> **原型开关说明**：若某个 Foundation/Core 系统在隔离原型中被有意跳过，必须在原型记录中说明影响范围。正式 MVP 实现中必须将 `skip_progress_manager`、`skip_save_system`、`skip_resource_loader` 和 `skip_input_manager` 全部设为 `false`。

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `skip_progress_manager` | `false`（正式实现） | `true` / `false` | — | 原型阶段可临时跳过进度系统，正式实现必须关闭 |
| `current_day` Facade 默认值 | 1 | 固定 | — | 仅在 `skip_progress_manager == true` 时使用 |
| Boot 初始化顺序 | DB → Save → Progress → Resource → Input | 任意排列（依赖链允许） | 无性能影响（均为同步初始化，<16ms 总量） | 若违反依赖链（如 Progress 在 Save 之前），进度缓存可能读取未加载的存档 |
| `skip_save_system` | `false`（正式实现） | `true` / `false` | — | 原型阶段可临时跳过保存系统，正式实现必须关闭 |
| `skip_resource_loader` | `false`（正式实现） | `true` / `false` | — | 原型阶段可临时跳过资源加载器，正式实现必须关闭 |
| `skip_input_manager` | `false`（正式实现） | `true` / `false` | — | 原型阶段可临时跳过输入管理器，正式实现必须关闭 |
| `is_transitioning` 超时 | 5 秒 | 2–10 秒 | 给慢速设备更多时间加载场景 | 更快检测死锁，但可能误判慢速加载为故障 |

> **说明**：场景/状态管理系统是纯状态机骨架——它不产生游戏内容、不涉及数值平衡。上表中的"参数"本质是架构开关，而非传统意义上的游戏调优参数。此系统设计目标是一次配置完成、之后不再调整。

## Visual/Audio Requirements

场景/状态管理系统是纯基础设施——无视觉或音频输出。所有视觉和音频反馈由下游系统（主菜单 UI、衣橱 UI、每日场景）负责。

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| 状态转换 | 无——由下游场景的加载画面提供 | 无——由音频管理系统在适当时机触发 | — |

> 状态转换本身不产生过渡动画或音效。如果未来需要统一的场景过渡效果（e.g.，淡入淡出），应在资源加载器或专门的过渡管理系统中实现，而非在 GameState 中。

## UI Requirements

场景/状态管理系统不渲染任何 UI。所有 UI 由下游系统负责：

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| `current_day` | 主菜单 UI、晚安 UI | 状态进入时读取一次（`_ready()` 中读取 `GameState.get_current_day()` 或 `GameState.context`） | 天数由 ProgressManager 提供，GameState 作为 Facade 暴露 |
| 错误信息 + 重试按钮 | ERROR 画面 | ERROR 进入时展示 | ERROR 画面显示安抚性提示 + "重试"按钮（触发 `GameState.request_transition(State.BOOT)`） |
| 确认取消对话框 | 衣橱 UI | WARDROBE 中玩家点击取消时 | "确定要取消今天的穿搭吗？" → 确认后触发 WARDROBE → MAIN_MENU |

> GameState 通过 `context` Dictionary + `current_state` 属性提供数据——UI 层在 `_ready()` 中读取。状态机不持有 UI 节点引用。

## Acceptance Criteria

**BOOT 流程**
- [ ] AC-1：游戏启动时，GameState 在 `_ready()` 中进入 BOOT 状态，`current_state == State.BOOT`
- [ ] AC-2：BOOT 中按 DB → Save → Progress → Resource → Input 顺序初始化入口系统。每个系统初始化时向 `init_order: Array[String]` 追加名称（e.g., `["db", "save", "progress", "resource", "input"]`），测试验证数组顺序与预期一致
- [ ] AC-3：WardrobeDatabase 未就绪时，BOOT 转换到 ERROR 状态，不进入 MAIN_MENU
- [ ] AC-4a：所有 Foundation 系统初始化成功后，调用 `change_scene_to_file()` 加载 MAIN_MENU 场景
- [ ] AC-4b：MAIN_MENU 场景的 `_ready()` 调用 `GameState._on_scene_ready()` 后，`state_changed(BOOT, MAIN_MENU)` 信号发出
- [ ] AC-4c：GameState `_ready()` 不在同帧访问 SaveManager / ProgressManager；BOOT 通过 deferred boot、等待一帧或等待 Foundation ready 标记启动
- [ ] AC-5：未设计的 Foundation 系统被跳过时，系统名称追加到 `skipped_systems: Array[String]`，BOOT 继续执行并最终转换到 MAIN_MENU（验证 `skipped_systems` 含预期名称且 `current_state == State.MAIN_MENU`）

**状态转换**
- [ ] AC-6：MAIN_MENU → WARDROBE 转换：调用 `change_scene_to_file()` 后 `current_state` 更新，WARDROBE 场景就绪后信号发出
- [ ] AC-7：WARDROBE → DAILY_SCENE 转换（确认穿搭后）：转换成功，`outfit_confirmed == true`
- [ ] AC-8：DAILY_SCENE → GOODNIGHT 转换（玩家点击"晚安"后）：转换成功
- [ ] AC-9a：GOODNIGHT → MAIN_MENU 转换成功，`current_state == State.MAIN_MENU`
- [ ] AC-9b：GOODNIGHT → MAIN_MENU 时 GameState 调用 `ProgressManager.advance_day()` 一次；若返回 `true` 且当前天为 1-6，`GameState.get_current_day()` 返回下一天
- [ ] AC-9c：第 7 天 GOODNIGHT → MAIN_MENU 后，`advance_day()` 返回 `true`，`GameState.get_current_day()` 仍返回 7，`ProgressManager.get_highest_day_completed() == 7`，主菜单显示通关/重玩入口
- [ ] AC-9d：GOODNIGHT 中 `ProgressManager.advance_day()` 返回 `false` 时，GameState 恢复内存 `scene_in_progress = true` 但不再次调用 `SaveManager.save()`，停留在 GOODNIGHT 未安全结束状态，不进入 MAIN_MENU，不展示新一天/新解锁，并提供重试入口
- [ ] AC-10：MAIN_MENU → QUIT 转换：触发清理流程，停止游戏循环
- [ ] AC-11：GOODNIGHT → QUIT 转换：触发清理流程，停止游戏循环

**WARDROBE 取消**
- [ ] AC-12a：WARDROBE 中 `outfit_confirmed == false` 时，WARDROBE → MAIN_MENU 转换成功
- [ ] AC-12b：WARDROBE 中 `outfit_confirmed == true` 时，WARDROBE → MAIN_MENU 被拒绝

**非法转换拒绝**
- [ ] AC-13：DAILY_SCENE → WARDROBE 被拒绝，条件日志记录，停留在当前状态
- [ ] AC-14：任意状态 → BOOT 被拒绝（ERROR → BOOT 除外，BOOT 的合法入口仅为游戏启动和 ERROR 重试）
- [ ] AC-15：ERROR 状态下仅有 ERROR → BOOT 转换被允许，其他转换（e.g., ERROR → MAIN_MENU）被拒绝

**信号**
- [ ] AC-16：每次合法状态转换发出一次且仅一次 `state_changed(from, to)` 信号
- [ ] AC-17：`state_changed` 信号的 `from` 和 `to` 参数与实际状态一致
- [ ] AC-18：非法转换不发出 `state_changed` 信号
- [ ] AC-19：`state_changed` 信号在新场景的 `_on_scene_ready()` 回调之后才发出，而非在 `change_scene_to_file()` 调用后立即发出

**current_day Facade**
- [ ] AC-20：BOOT 完成且无存档时，`GameState.get_current_day() == 1`
- [ ] AC-21：存档中 `current_day = -1` 时，BOOT 后 `GameState.get_current_day() == 1`（由 ProgressManager 修复）
- [ ] AC-22：存档中 `current_day = 0` 时，BOOT 后 `GameState.get_current_day() == 1`（由 ProgressManager 修复）
- [ ] AC-22a：`scene_in_progress == true` 但 `equipped_items` 字段缺失、为 `null` 或不是可过滤的 `Array[String]` 时，BOOT 清除恢复标记并进入 MAIN_MENU，不进入 DAILY_SCENE
- [ ] AC-22b：`scene_in_progress == true` 且 `equipped_items == []` 时，BOOT 保留恢复语义并进入 DAILY_SCENE；Daily Scene 必须按明确空穿搭调用 `apply_outfit([])`，不得走默认穿搭兜底

**Context**
- [ ] AC-23：`context` Dictionary 在 BOOT 时初始化为空 `{}`
- [ ] AC-24：下游系统可在状态转换前写入 `context`（e.g., WARDROBE 确认时衣橱 UI 写入 `equipped_items`）
- [ ] AC-25：DAILY_SCENE 可读取 `context["equipped_items"]` 获取穿搭数据
- [ ] AC-26：`context` Dictionary 的内容在场景切换后持久存在——WARDROBE 写入的值在 DAILY_SCENE 加载后仍可读取
- [ ] AC-27：`state_changed` 信号携带的 `context` 是深拷贝（`context.duplicate(true)`），下游修改它不影响 `GameState.context`

**守卫**
- [ ] AC-28：`is_transitioning == true` 期间，第二次转换请求被拒绝
- [ ] AC-29：新场景 `_ready()` 调用 `_on_scene_ready()` 后 `is_transitioning` 恢复为 `false`
- [ ] AC-30：若 `is_transitioning` 在 5 秒内未恢复为 `false`（`_on_scene_ready()` 未被调用），超时强制重置并转换到 ERROR

**场景文件缺失**
- [ ] AC-31：当 `change_scene_to_file()` 返回 `ERR_CANT_OPEN` 时（通过注入 mock `scene_loader` callable 模拟），GameState 转换到 ERROR 状态，日志包含目标路径
- [ ] AC-32：ERROR 画面显示"游戏资源加载失败"提示 + "重试"按钮，不显示裸错误堆栈

**场景管理**
- [ ] AC-33：场景切换后，旧场景节点已从 SceneTree 中移除（验证旧场景特有的标记节点 `is_inside_tree() == false`）
- [ ] AC-34：下游系统在信号发出后连接 `state_changed`，仍可通过 `GameState.current_state` 获取当前状态，通过 `GameState.context` 获取上下文

**ERROR 重试**
- [ ] AC-35：ERROR → BOOT 转换触发完整的 BOOT 初始化流程（等同于游戏启动时的 BOOT）
- [ ] AC-36：连续 3 次 ERROR → BOOT 重试后仍失败，ERROR 画面显示"多次重试失败"提示（防止无限重试循环）

**初始化顺序**
- [ ] AC-37：BOOT 初始化顺序为 DB → Save → Progress → Resource → Input（验证 `init_order` 数组严格匹配）。Autoload 注册顺序确保 WardrobeDatabase 在 GameState 之前初始化，ProgressManager 在 SaveManager 与 WardrobeDatabase 之后初始化

**性能**
- [ ] AC-38：GameState 禁用 `_process()` 和 `_physics_process()`（`set_process(false)` + `set_physics_process(false)`）——状态机完全由方法调用驱动，不需每帧轮询
- [ ] AC-39：BOOT 初始化全部入口系统总耗时 <10ms（为 Web 首帧渲染留出至少 6ms 预算）。使用 `Time.get_ticks_usec()` 测量，排除 WASM 编译时间

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| 保存/加载系统设计后，`current_day` 的加载接口是什么？ | 保存/加载 GDD 作者 | 保存/加载 GDD 设计时 | 已决议：ProgressManager 从 SaveManager 读取 `current_day`，GameState 通过 Facade 读取 ProgressManager |
| 是否需要异步 BOOT（e.g.，资源预加载耗时 >1 帧）？ | 资源加载器 GDD 作者 | 资源加载器 GDD 设计时 | 当前 MVP 假设同步初始化。若资源加载器引入异步，GameState 的 BOOT 需改为多帧等待 |
| ERROR 重试按钮设计（已决议） | — | 2026-06-05 | 已添加 `(ERROR, BOOT)` 转换 + 最多 3 次重试限制 |
| `context["equipped_items"]` 的数据格式（已决议） | — | 2026-06-05 | `Array[String]`（物品 ID 列表），每日场景按需从服装数据库查询详情 |
| 中端会话恢复（`BOOT → DAILY_SCENE`）需要保存系统提供什么接口？ | 保存/加载 GDD 作者 | 保存/加载 GDD 设计时 | 保存系统需提供 `scene_in_progress: bool`、已保存的 `current_day` 和 `equipped_items`。GameState 在 BOOT 中检查 `scene_in_progress` 决定是否跳过 MAIN_MENU 直接进入 DAILY_SCENE |
| `current_day` → 进度系统交接时 Facade 接口的具体方法签名？ | 进度管理 GDD 作者 | 进度管理 GDD 设计时 | 已决议：GameState 保持为 `current_day` 的唯一公开访问点。内部委托给 `ProgressManager.get_current_day()`；GOODNIGHT → MAIN_MENU 时调用 `ProgressManager.advance_day()` 并检查返回值 |
