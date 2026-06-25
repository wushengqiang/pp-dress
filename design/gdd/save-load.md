# 保存/加载 (Save/Load)

> **Status**: Designed
> **Author**: user + Claude Code Game Studios
> **Last Updated**: 2026-06-12
> **Implements Pillar**: 每日陪伴

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: Godot `JSON`, `JavaScriptBridge`, `FileAccess`; downstream contracts with `GameState`, `ProgressManager`

## Overview

保存/加载是「每日穿搭」的数据持久层。它将游戏进度——当前天数、穿搭记录、场景进行中标记——序列化为 JSON 字符串，通过浏览器 `localStorage` API 持久化到客户端。系统本身不产生游戏行为，不渲染 UI：它是一个在关键时刻被调用的数据管道。

该系统的存在理由很简单：Web 游戏中，浏览器刷新 = 进程销毁 = 内存状态全部丢失。没有保存系统，玩家关闭标签页后第二天回来只能从头开始——7 天的叙事进度和精心搭配的穿搭全部消失。保存系统通过关键流程的自动保存（穿搭确认时、晚安画面后，且解锁记录随 ProgressManager 的进度推进一并保存）消除这种"刷新焦虑"，让「每日陪伴」支柱跨会话持续。

## Player Fantasy

保存/加载没有独立的玩家幻想——玩家不会说"这个游戏的 localStorage 序列化策略真棒"。但它支撑的体验直接关系到「每日陪伴」支柱的跨会话连续性：

- **"昨天的进度还在"**：关闭浏览器、第二天打开——天数没有重置、解锁的衣服还在、上次的穿搭可以继续。这是「每日陪伴」支柱的技术基础——陪伴感不能只持续一个浏览器标签页的生命周期。
- **"刷新浏览器也不怕"**：Web 端游戏中，意外刷新是最常见的"进度丢失"场景。自动保存在穿搭确认后立即执行——玩家不需要记得"保存"，系统替她记住了。

简言之：这个系统不创造情感，但它消除"我昨天的进度还在不在"的焦虑——而消除这种焦虑，是「每日陪伴」支柱跨天生效的前提。

## Detailed Design

### Core Rules

**架构**：一个 Godot Autoload 单例（`save_manager.gd`，注册名 `SaveManager`）管理全部持久化。它拥有一个内存中的 `SaveData` 数据对象（实现为独立脚本 `save_data.gd`，`class_name SaveData`，继承 `RefCounted`，不是 Resource；运行时必须通过 `to_dict()` / `from_dict()` 转换为 JSON 原生 Dictionary），在游戏启动时从 `localStorage` 反序列化加载，在关键时刻由外部调用触发序列化写回。

SaveManager 是**持久化管道**，不是进度规则权威。它可以提供低层字段写入方法，但调用边界必须固定：
- ProgressManager 是 `current_day`、`highest_day_completed`、`unlock_progress` 的唯一常规写入者和规则修复者
- GameState 只在场景流程中写入 `equipped_items` 与 `scene_in_progress`
- UI、服装解锁展示、每日场景和其他下游系统不得直接写 SaveManager；它们必须通过 GameState 或 ProgressManager 的正式接口间接触发保存

**Autoload 注册顺序**：

```
1. WardrobeDatabase
2. GameState
3. SaveManager        ← 本系统（在 GameState 之后；GameState 不得在同一帧直接访问尚未 ready 的 SaveManager）
4. TextureCache
5. InputManager
6. ProgressManager
```

> **顺序说明**：Autoload 注册顺序不同于 BOOT 业务初始化顺序。Autoload 顺序只保证全局单例存在，并且全项目唯一链固定为 `WardrobeDatabase → GameState → SaveManager → TextureCache → InputManager → ProgressManager`。因为 `GameState._ready()` 早于 `SaveManager._ready()`，GameState 不得在 `_ready()` 同帧启动 BOOT 并访问 SaveManager；必须在 `_ready()` 中使用 `call_deferred("_boot")` 启动 BOOT 编排。BOOT 业务顺序由 GameState 编排并必须遵循 `WardrobeDatabase → SaveManager → ProgressManager → TextureCache → InputManager` 的就绪检查；每个系统均采用“先查 `is_ready`，否则连接 ready/loaded/progress_loaded 信号”的双路径，不使用固定等待帧数作为唯一同步机制。后续系统读取 SaveManager 时也必须使用 `is_ready` 双路径：若 `SaveManager.is_ready == true`，直接读取；否则连接 `loaded` 等待。

**加载生命周期**：SaveManager 是自己的加载入口。`SaveManager._ready()` 必须自动执行一次内部加载流程，从当前平台后端读取存档、构造 `data`、设置 `is_ready = true`，并发出一次 `loaded(data)`。GameState BOOT 不直接调用 `SaveManager.load()` 来启动加载；它只等待 `SaveManager.is_ready` 或 `loaded`。公开 `load()` 是“一次性加载/缓存读取”入口：若 `is_ready == false`，执行同一加载流程并在完成时发出 `loaded`；若 `is_ready == true`，直接返回当前 `data`，不得重复读取后端，也不得再次发出 `loaded`。调试或测试若需要强制重新读取后端，必须调用独立的 `reload_from_backend_for_tests()`，该方法仅允许测试/调试工具使用，不属于正常游戏流程。

**数据 Schema**：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `save_version` | int | 1 | Schema 版本号，用于未来迁移 |
| `current_day` | int | 1 | 当前游戏天数 |
| `equipped_items` | Array[String] | [] | 上次穿搭确认的物品 ID 列表 |
| `scene_in_progress` | bool | false | 是否存在未完成的会话 |
| `highest_day_completed` | int | 0 | 已完成的最高天数（day=0 = 尚未完成任何一天） |
| `unlock_progress` | Dictionary[String, Array[String]] | {} | 每日解锁记录。key=day (str), value=该天解锁的物品 id 列表 |

**API 接口**：

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `save()` | — | bool | 将当前 `SaveData` 序列化为 JSON 写入 `localStorage`。返回成功/失败 |
| `load()` | — | SaveData | 显式读取入口。正常启动由 `_ready()` 自动调用一次；若已 ready，返回当前 `data` 且不重复发出 `loaded` |
| `reload_from_backend_for_tests()` | — | SaveData | **测试/调试 only**。强制重新读取平台后端并更新内存 `data`；正常 GameState/ProgressManager 流程不得调用 |
| `get_data_snapshot()` | — | SaveData | 返回当前 `SaveData` 的深拷贝快照；下游读取存档字段时优先使用该方法 |
| `reset()` | — | bool | 删除持久化存档键/恢复文件，并将内存 `data` 恢复为默认值。仅当目标平台要求清理的持久化对象全部删除或确认不存在时返回 `true`；任一必要删除失败返回 `false`，设置 `last_save_status = SAVE_RESET_FAILED`。不立即写回 `localStorage`；下一次显式 `save()` 才重新创建存档键；不发出 `loaded` 或 `saved` |
| `is_save_exists()` | — | bool | `localStorage` 中是否存在存档键 |
| `acknowledge_default_overwrite()` | — | void | 仅当 `last_load_status == LOAD_EXISTING_FAILED_DEFAULT_LOCKED` 且玩家确认重新开始后调用；解除默认存档覆盖保护 |
| `set_current_day(day)` | int | void | **内部/ProgressManager only**。更新天数（仅内存，需调用 `save()` 持久化） |
| `set_equipped_items(items)` | Array[String] | void | **GameState only**。WARDROBE 确认穿搭时更新穿搭列表 |
| `set_scene_in_progress(in_progress)` | bool | void | **GameState only**。设置会话进行中标记 |
| `mark_day_completed(day)` | int | void | **内部/ProgressManager only**。标记某天已完成，更新 `highest_day_completed` |
| `record_unlocks(day, item_ids)` | int, Array[String] | void | **内部/ProgressManager only**。记录某天的解锁物品；同一天重复调用覆盖该 day key 的数组，不追加、不合并 |
| `replace_progress_fields(current_day, highest_day_completed, unlock_progress)` | int, int, Dictionary[String, Array[String]] | void | **内部/ProgressManager rollback only**。用于 `advance_day()` 保存失败时原子恢复 SaveManager 内的进度字段。必须深拷贝 `unlock_progress`，并以传入字典整体替换现有字段，以便删除候选推进时写入的陈旧 day key；不得作为普通 gameplay 写入口 |

**属性**：

| 属性 | 类型 | 说明 |
|------|------|------|
| `is_ready` | bool | `load()` 完成后设为 true |
| `data` | SaveData | 当前存档数据的只读快照入口。getter 必须返回深拷贝或不可变快照，不得返回内部可变引用；外部不得直接修改字段，写入必须走 SaveManager 的限定 API |
| `last_load_status` | LoadStatus | 最近一次加载结果，用于 GameState/UI 区分首次无档、正常加载、存储不可用、已有档读取失败等路径 |
| `last_save_status` | SaveStatus | 最近一次保存结果，用于 GameState/UI 展示低压提示或重试 |
| `storage_available` | bool | 最近一次平台后端读写是否可用；Web wrapper 或非 Web 文件系统失败时为 false |
| `default_overwrite_locked` | bool | 已有存档读取失败并回退默认数据时为 true；在玩家确认重新开始前，`save()` 必须拒绝覆盖主存档 |

**加载状态枚举**：

| 值 | 含义 | UI/调用方用途 |
|----|------|---------------|
| `LOAD_NONE` | 尚未加载 | 仅启动前内部状态 |
| `LOAD_NO_SAVE` | 后端可用但没有存档 | 首次玩家流程 |
| `LOAD_OK` | 正常读取已有存档 | 正常继续 |
| `LOAD_STORAGE_UNAVAILABLE` | 后端不可用，使用默认数据 | 显示“本次可能无法保存”的低压提示 |
| `LOAD_EXISTING_FAILED_DEFAULT_LOCKED` | 检测到已有存档但无法读取：Web 为当前 `SAVE_KEY` 读取/解析失败；非 Web 为主档和 `.bak` 均不可用。使用默认数据且禁止自动覆盖 | 显示非责备提示；玩家确认重新开始前不得写回默认档 |
| `LOAD_RECOVERED_FROM_BACKUP` | **非 Web only**。主档失败但从 `.bak` 恢复 | 可继续，并可在日志/QA 证据中记录 |

**保存状态枚举**：

| 值 | 含义 |
|----|------|
| `SAVE_NONE` | 尚未保存 |
| `SAVE_OK` | 最近一次保存成功 |
| `SAVE_STORAGE_UNAVAILABLE` | 存储后端不可用 |
| `SAVE_WRITE_FAILED` | 写入、校验或替换失败 |
| `SAVE_BLOCKED_DEFAULT_OVERWRITE` | 因坏档保护锁拒绝覆盖默认档 |
| `SAVE_RESET_FAILED` | 新游戏/重置时删除持久化对象失败 |

**信号**：

| 信号 | 参数 | 说明 |
|------|------|------|
| `loaded` | SaveData | 启动时存档加载完成（或已创建默认存档） |
| `saved` | — | `save()` 成功写入 localStorage 后发出 |

> **`loaded` 信号时序约定**：`loaded` 可能在 `SaveManager._ready()` 内发出，后注册或后初始化的系统可能错过该信号。下游系统必须先检查 `SaveManager.is_ready`；若已为 `true`，通过 `get_data_snapshot()` 或正式查询 API 读取；若仍为 `false`，再连接 `loaded` 等待加载完成。

**自动保存触发点**（由 GameState 和 ProgressManager 调用 `SaveManager.save()`；进度推进由 ProgressManager 封装保存）：

| 时机 | 调用方 | 保存前更新的字段 |
|------|--------|---------------|
| WARDROBE 确认穿搭 | GameState | `equipped_items`, `scene_in_progress = true`；`current_day` 只从 `ProgressManager.get_current_day()` 读取并写入 GameState context，不写 SaveManager |
| GOODNIGHT → MAIN_MENU | GameState + ProgressManager | GameState 先在内存中清除 `scene_in_progress = false`；`ProgressManager.advance_day()` 计算下一进度并尝试持久化；只有返回成功后才进入 MAIN_MENU / 展示新一天或新解锁；失败时 GameState 仅在内存中恢复 `scene_in_progress = true`，不再二次保存 |
| `ProgressManager.advance_day()` 内记录新解锁 | ProgressManager | `highest_day_completed`、`current_day`、`unlock_progress`；同一次最终 `save()` 成功后才提交为玩家可见进度 |

**WARDROBE 保存伪代码**：

```
on_outfit_confirmed(confirmed_items):
    day = ProgressManager.get_current_day()
    GameState.context["current_day"] = day
    GameState.context["equipped_items"] = confirmed_items
    SaveManager.set_equipped_items(confirmed_items)
    SaveManager.set_scene_in_progress(true)
    SaveManager.save()
```

GameState 不得在该流程中调用 `SaveManager.set_current_day()`；`current_day` 的持久化写入只由 ProgressManager 负责。

**GOODNIGHT 保存顺序约束**：GameState 必须先调用 `set_scene_in_progress(false)`，再调用 `ProgressManager.advance_day()`。`advance_day()` 返回 `true` 才表示“完成当天 + 推进进度 + 持久化”全部成功；此时持久化快照必须包含 `scene_in_progress = false`，避免刷新后以新天数和旧恢复标记错误进入 DAILY_SCENE。若 `advance_day()` 返回 `false`，GameState 必须调用 `set_scene_in_progress(true)` 仅恢复内存语义，停留在 GOODNIGHT 的未安全结束状态，提供“再试一次”作为主操作，不得进入 MAIN_MENU，不得展示新一天、新解锁或“明天见”的完成感。失败路径不得再次调用 `SaveManager.save()`：因为当前失败原因可能仍存在，二次保存只会覆盖 `last_save_status` 或制造循环失败；此时刷新浏览器应按最后一次成功保存的 `scene_in_progress = true` 恢复当天 DAILY_SCENE，而不是恢复到已完成的新一天。

**进度提交失败契约**：`ProgressManager.advance_day()` 可以在内存中构造候选进度，但在 `SaveManager.save()` 成功前不得发出 `day_completed`、`items_unlocked`、`day_started`，也不得让 UI 读取到已提交的新一天/新解锁状态。保存失败时必须恢复调用前的进度快照，并通过 `SaveManager.replace_progress_fields()` 恢复 SaveManager 内的进度字段；`scene_in_progress` 不由 ProgressManager 回滚，而由 GameState 在 `advance_day() == false` 后恢复为 `true`。GameState/UI 只根据 `advance_day() == true` 进入成功路径。

**BOOT 恢复契约**：`scene_in_progress == true` 只表示存在可尝试恢复的未完成会话，不足以直接跳转 DAILY_SCENE。GameState 必须先等待 `ProgressManager.progress_loaded`，使用 `ProgressManager.get_current_day()` 取得修复后的天数，并过滤 `equipped_items`（存在、已解锁、类目冲突可归一化）。若 `equipped_items` 字段存在且可解析为 `Array[String]`，无论过滤后结果是非空数组还是空数组，GameState 都应在 `BOOT → DAILY_SCENE` 前写入 `GameState.context["current_day"]` 和 `GameState.context["equipped_items"]`；只有当字段缺失、为 `null`、不是数组或无法解析为字符串数组时，才调用 `SaveManager.set_scene_in_progress(false)` 并立即 `SaveManager.save()` 持久化修复，再进入 MAIN_MENU，避免下次刷新反复尝试恢复同一坏状态。

### States and Transitions

```
UNINITIALIZED ──_ready()──→ LOADING ──成功──→ READY
                                │               │
                                │               ├── save() ──→ READY（发出 saved）
                                │               ├── reset() ──→ READY（持久化键删除 + 内存 data 恢复默认）
                                │               └── set_*() ──→ READY（仅内存，等待 save）
                                │
                                └──失败──→ READY（使用默认存档 + push_warning）
```

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|---------|
| 场景/状态管理 | 依赖本系统 | BOOT 中等待 `SaveManager.is_ready` 或 `loaded`；读取 SaveManager 提供的只读快照/查询 API 决定是否尝试恢复 DAILY_SCENE；状态转换时调用 `save()` |
| 进度管理 | 依赖本系统 | GOODNIGHT → MAIN_MENU 时由 `ProgressManager.advance_day()` 作为唯一常规写入口，内部调用 SaveManager 的限定写入 API 并最终 `save()`；通过只读快照/查询 API 获知持久化进度 |

## Formulas

保存/加载系统不包含数学公式，但包含以下数据约束和转换规则：

### 存档键构造

```
SAVE_KEY = "pp-dress-save-v1"
```

单键、硬编码字符串。`v1` 后缀对应 `save_version = 1`，用于区分当前 Schema。真实发布后的 Schema 升级需优先迁移旧数据，不得默认通过更换 key 名称让旧存档不可见。

### 默认存档数据

当 `localStorage` 中不存在存档或存档损坏时，`load()` 返回以下默认数据：

| 字段 | 默认值 | 含义 |
|------|--------|------|
| `save_version` | 1 | 当前 Schema 版本 |
| `current_day` | 1 | 第 1 天 |
| `equipped_items` | [] | 尚未穿搭 |
| `scene_in_progress` | false | 没有未完成的会话 |
| `highest_day_completed` | 0 | 尚未完成任何一天 |
| `unlock_progress` | {} | 无解锁记录 |

### JSON 序列化

`save()` 使用 `JSON.stringify(data.to_dict())` 将 `SaveData` 转换后的 Dictionary 序列化为 JSON 字符串。`load()` 使用 `JSON.new().parse(raw_text)` 反序列化，以便在解析失败时取得错误信息；解析成功后使用 `SaveData.from_dict(parsed_dict)` 生成内存对象。

**序列化保证**：
- 所有字段类型均为 JSON 原生类型（number, bool, string, array, object），无需自定义序列化器
- `Array[String]` → JSON array
- `Dictionary[String, Array[String]]` → JSON object with array values
- `SaveData` 对象本体不直接序列化；只有 `to_dict()` 的返回值进入 JSON

**Godot JSON 解析步骤**：
1. `var json := JSON.new()`
2. `var err := json.parse(raw_text)`
3. 若 `err != OK`，读取 `json.get_error_message()` / `json.get_error_line()`，`push_warning()` 后返回默认存档
4. `var parsed: Variant = json.data`
5. 必须检查 `typeof(parsed) == TYPE_DICTIONARY`
6. 调用 `SaveData.from_dict(parsed)`，逐字段验证并复制到 typed 字段

`JSON.parse()` 读出的数组和字典是 Variant/普通容器。`SaveData.from_dict()` 必须手动重建 `Array[String]` 与 `Dictionary[String, Array[String]]`，逐项复制字符串；不得直接把 parsed Variant 赋给 typed 字段。

**实现类型约束**：`Dictionary[String, Array[String]]` 是设计类型。若 Godot 4.6 的 GDScript 嵌套泛型在编译或赋值时不稳定，允许内部字段实现为普通 `Dictionary`，但所有写入和读取 API 必须通过 schema helper 保证 key 为 String、value 可重建为 `Array[String]`。

所有 setter 必须复制输入数组后再写入内部 `data`；所有公开读取数组或字典的 API 必须返回副本，避免外部代码通过可变引用修改 `equipped_items` 或返回数组来绕过限定写入 API。

### Schema 基础校验

`load()` 在 `JSON.new().parse(raw_text)` 成功后必须执行基础 schema 校验。校验只覆盖持久层能够安全判断的结构要求，不执行游戏规则范围修复。

| 字段 | 必须类型 | 校验失败行为 |
|------|----------|--------------|
| parsed root | Dictionary | 返回默认存档，`push_warning()` |
| `save_version` | 整数值 number（int 或整值 float） | 返回默认存档，`push_warning()` |
| `current_day` | 整数值 number（int 或整值 float） | 返回默认存档，`push_warning()` |
| `equipped_items` | Array，且元素均为 String | 返回默认存档，`push_warning()` |
| `scene_in_progress` | bool | 返回默认存档，`push_warning()` |
| `highest_day_completed` | 整数值 number（int 或整值 float） | 返回默认存档，`push_warning()` |
| `unlock_progress` | Dictionary，key 为 String，value 为 Array[String] | 返回默认存档，`push_warning()` |

SaveManager 使用统一 `_read_int()` helper 读取整数值 number，接受 `3` 或 `3.0`，拒绝 `3.5`、String、bool 和 null。SaveManager 不校验 `current_day` 是否在 `1..TOTAL_DAYS`、`highest_day_completed` 是否与 `current_day` 一致、物品 ID 是否存在等业务规则；这些仍由 ProgressManager 和消费方处理。`TOTAL_DAYS` 来自实体注册表/ProgressManager 常量，当前值为 7。

**业务范围边界**：字段缺失或基础类型错误 → 全档默认；业务范围异常但结构安全（如 `current_day = 99`、`highest_day_completed = -3`、`equipped_items` 含不存在 ID、`unlock_progress` 含无效 day key）→ SaveManager 保留结构化数据，由 ProgressManager、GameState 或消费方修复/过滤。

**字段级约束**：
- 多余字段允许存在，但 `SaveData.from_dict()` 必须忽略，不写入内存 `data`，下一次 `save()` 不再输出这些字段
- `equipped_items` 保持数组顺序；SaveManager 不去重、不按类目修复，重复 ID 和类目冲突由 GameState/Wardrobe 消费方过滤
- `unlock_progress` 的 key 只要求为 String；是否代表合法 day 由 ProgressManager 判断
- `unlock_progress` 的 value 必须为 Array[String]；空数组 key 允许保留，表示该天完成但无新增解锁
- 业务异常但结构安全的数据不得在 SaveManager 层悄悄修改；任何修复必须由权威系统执行并显式 `save()`

### 命名规则表达式

```
read_int(value) =
    if typeof(value) == TYPE_INT: ok(value)
    if typeof(value) == TYPE_FLOAT AND is_equal_approx(value, floor(value)): ok(int(value))
    else: error

version_is_supported(version) = (version == CURRENT_SAVE_VERSION)

save_success_web(result) = (result.ok == true)

save_success_file =
    tmp_open_ok
    AND store_string_ok
    AND tmp_json_parse_ok
    AND replace_ok
```

| 变量 | 类型 | 说明 |
|------|------|------|
| `CURRENT_SAVE_VERSION` | int | 当前固定为 1 |
| `tmp_open_ok` | bool | `FileAccess.open(TMP_PATH, FileAccess.WRITE)` 返回非 null |
| `store_string_ok` | bool | `FileAccess.store_string(serialized) == true` 且随后 `file.get_error() == OK`；随后释放写入句柄（`file = null`）再读回校验 |
| `tmp_json_parse_ok` | bool | 临时文件释放写入句柄后可读、非空、可解析为 JSON Dictionary |
| `replace_ok` | bool | `DirAccess.rename_absolute()` / `remove_absolute()` / 恢复 `.bak` 的每一步返回 `OK`，且最终正式文件存在并可读 |

`save()` 只有在对应平台的成功表达式为 true 时才返回 `true` 并发出 `saved`。

> **Godot 4.6 约束**：本设计依赖 Godot 4.6 中 `FileAccess.store_string()` 返回 `bool` 的语义；非 Web fallback 必须同时检查返回值和 `file.get_error()`。不得按旧版 Godot “无返回值/只看 close” 的写法实现。

**示例**：
- `read_int(3.0)` → `ok(3)`
- `read_int(3.5)` → `error`
- `version_is_supported(1)` → `true`
- `version_is_supported(0)` / `version_is_supported(2)` → `false`
- `save_success_file == false` 时，`save()` 返回 `false` 且不发 `saved`

**非 Web 替换步骤的 `replace_ok` 定义**：
1. 若旧 `.bak` 存在，先删除旧 `.bak`；删除失败则停止，保留正式文件和 tmp，返回 `false`
2. 若正式文件存在，将正式文件 rename 为 `.bak`；rename 失败则停止，保留正式文件和 tmp，返回 `false`
3. 将 tmp rename 为正式文件；若失败，尝试把 `.bak` rename 回正式文件，返回 `false`
4. 若正式文件可读且 JSON parse 成功，`replace_ok = true`
5. 任一失败路径不得同时删除正式文件和 `.bak`；旧正式文件优先保留

**非 Web 失败后磁盘状态表**：

| 失败点 | 正式文件 | `.bak` | `.tmp` | 下次 `load()` 优先级 |
|--------|----------|--------|--------|---------------------|
| 删除旧 `.bak` 失败 | 保持原状 | 保持原状 | 保留 | 正式文件 → `.bak` |
| 正式文件 rename 为 `.bak` 失败 | 保持原状 | 旧 `.bak` 已不存在或已清理 | 保留 | 正式文件 |
| tmp rename 为正式文件失败且 `.bak` 恢复成功 | 恢复旧正式文件 | 不要求保留 | tmp 可保留供诊断 | 正式文件 |
| tmp rename 为正式文件失败且 `.bak` 恢复失败 | 可能缺失 | 保留或恢复失败残留 | 保留 | `.bak` → 默认锁定 |
| 正式文件写成后读回校验失败 | 保留失败正式文件并可重命名为 `.corrupt` | 若 `.bak` 可用则优先恢复 | tmp 可删除或保留供诊断 | `.bak` → 默认锁定 |

### 大小估算

| 场景 | 估算大小 | 计算依据 |
|------|---------|---------|
| 默认存档（第 1 天，无穿搭） | ~120 bytes | 6 个字段各具默认值 |
| 第 3 天，每日 4-5 件穿搭 | ~400 bytes | 每个物品 ID ~20 chars × 15 件 |
| 第 7 天完成，全套解锁记录 | ~800 bytes | 7 天 × 5 件 × 20 chars + 结构开销 |
| localStorage 上限 | 5 MB | 浏览器标准限制 |
| 安全水位 | < 2 KB | 约占上限的 0.04% |

即使 7 天完整进度的存档也远低于 5MB 限制，无需压缩或分片策略。

### 损坏数据处理

当 `JSON.new().parse(raw_text)` 返回错误，或解析结果缺少必需字段、字段基础类型错误时，`load()` 返回默认存档数据并发出 `push_warning()`。

SaveManager 不在持久层执行复杂业务修复，但异常路径必须遵循“尽量不破坏玩家连续性”的原则：结构完整的数据即使业务范围异常也交给 ProgressManager/GameState 修复；只有 JSON 语法损坏、根类型错误、必需字段缺失或基础类型错误时才回退到默认内存数据。默认值不会在 `load()` 中自动写回，除非调用方随后显式调用 `save()`。

损坏原文不得在 `load()` 中被自动覆盖；这有助于保留调试证据，也避免无意把默认存档写成玩家的新存档。若检测到已有存档但主档/备份都无法读取，`load()` 返回默认数据时必须设置 `last_load_status = LOAD_EXISTING_FAILED_DEFAULT_LOCKED` 与 `default_overwrite_locked = true`。在玩家明确确认“重新开始”并由 GameState 调用 `acknowledge_default_overwrite()` 前，`save()` 必须返回 `false`、设置 `last_save_status = SAVE_BLOCKED_DEFAULT_OVERWRITE`，不得把默认 Day 1 写回原存档键。

## Edge Cases

### EC-1: localStorage 不可用

**场景**：浏览器隐私模式、存储配额已满、或用户拒绝存储权限导致 `localStorage` 不可用。

**行为**：
- Web 分支必须通过 JavaScript 侧 wrapper 捕获 `localStorage` 异常，并向 GDScript 返回 JSON 字符串格式的结构化结果；GDScript 再用 `JSON.parse()` 解析。wrapper 不直接返回 JS object，避免 `JavaScriptBridge.eval()` 的 Variant 映射差异
- GDScript 传入 JS 的 `SAVE_KEY` 与存档 JSON 必须安全转义。不得用字符串拼接把原始 key/value 直接嵌入 `JavaScriptBridge.eval()`；每次调用必须使用自包含 IIFE wrapper，并通过 `_js_literal(value)` helper 生成 JS 字符串字面量：`_js_literal(value) = JSON.stringify(str(value))`。例如 `var key_literal := _js_literal(SAVE_KEY)`、`var value_literal := _js_literal(serialized)`，再嵌入 `localStorage.setItem(%s, %s)`。不得依赖前一次 `eval()` 中定义的局部函数跨调用存在
- `getItem` 成功但 key 不存在必须与失败区分：`{"ok":true,"exists":false,"value":"","error":""}`；成功且存在为 `{"ok":true,"exists":true,"value":"...","error":""}`；失败为 `{"ok":false,"exists":false,"value":"","error":"..."}`。`setItem` / `removeItem` 返回 `{"ok":true,"error":""}` 或 `{"ok":false,"error":"..."}`
- `save()` 在 wrapper 返回失败时返回 `false`，发出 `push_warning("localStorage unavailable, save failed")`，且不发 `saved`
- `load()` 在 wrapper 返回失败时返回默认存档数据，`is_ready` 仍设为 `true`，并发出 `loaded(default_data)`——游戏以默认状态继续运行
- `is_save_exists()` 返回 `false`，同时 `storage_available = false`、`last_load_status = LOAD_STORAGE_UNAVAILABLE`
- `reset()` 调用 wrapper `removeItem()`；失败时不得崩溃，需 `push_warning()`，返回 `false` 并设置 `last_save_status = SAVE_RESET_FAILED`
- 游戏不因存储不可用而崩溃或阻塞
- **玩家体验契约**：SaveManager 是数据层，不直接渲染 UI；但 GameState/UI 必须根据 `save()` 返回值、`last_load_status`、`last_save_status` 或 `storage_available` 给出低压提示，例如“今天可以继续玩，但这个浏览器现在可能记不住进度。”提示不得使用技术术语、不得责备玩家，也不得阻塞继续游玩。

**Web wrapper IIFE 伪代码**：

```
_js_literal(value):
    return JSON.stringify(str(value))

web_get_item(key):
    key_literal = _js_literal(key)
    script = "(function(){try{var v=localStorage.getItem(" + key_literal + ");return JSON.stringify({ok:true,exists:v!==null,value:v||'',error:''});}catch(e){return JSON.stringify({ok:false,exists:false,value:'',error:String(e)});}})()"

web_set_item(key, value):
    key_literal = _js_literal(key)
    value_literal = _js_literal(value)
    script = "(function(){try{localStorage.setItem(" + key_literal + "," + value_literal + ");return JSON.stringify({ok:true,error:''});}catch(e){return JSON.stringify({ok:false,error:String(e)});}})()"

web_remove_item(key):
    key_literal = _js_literal(key)
    script = "(function(){try{localStorage.removeItem(" + key_literal + ");return JSON.stringify({ok:true,error:''});}catch(e){return JSON.stringify({ok:false,error:String(e)});}})()"
```

`JavaScriptBridge.eval(script)` 的返回值仍必须是 JSON 字符串；GDScript 侧统一用 `JSON.new().parse(result)` 校验 `ok` / `exists` / `value` / `error` 字段。

### EC-1a: 关键流程保存失败

**场景**：WARDROBE 确认、GOODNIGHT 进度推进或 BOOT 恢复修复时，`save()` 返回 `false`。

**行为**：
- WARDROBE 确认保存失败：允许继续进入 DAILY_SCENE，但 GameState/UI 必须显示低压提示，说明本次穿搭可能无法保留，并在下一个安全点重试保存
- GOODNIGHT 进度保存失败：GameState/UI 不得让玩家误以为新一天或新解锁已经安全保存；必须停留在 GOODNIGHT 未安全结束状态，默认操作为“再试一次”。可提供次要离开选项，但必须明确“今天可能还没被记住”，且不得进入新一天或展示新解锁
- `ProgressManager.advance_day()` 内部最终 `SaveManager.save()` 的返回值必须通过 `advance_day() -> bool` 可观察；GameState/UI 不得忽略失败
- 保存失败提示不得出现 `localStorage`、JSON、堆栈、异常名等技术词，不得暗示是玩家做错了什么

### EC-2: 存档版本不匹配

**场景**：未来版本更新了 `save_version`（如从 1 → 2），玩家浏览器中仍有旧版本存档。

**行为（MVP，当前版本 `save_version = 1`）**：
- `load()` 在反序列化后检查 `data.save_version`
- 若 `data.save_version > 1`（来自更新版本的存档）：发出 `push_warning("Save version mismatch: got {version}, expected 1")`，丢弃存档，返回默认值
- 若 `data.save_version == 1`：正常加载
- 若 `data.save_version < 1` 或缺失：视为损坏数据，返回默认值
- **发布门禁**：MVP 不实现正式迁移表。任何真实发布后的 `save_version` 升级必须先另开迁移设计/故事并通过迁移测试；在该门禁完成前，不得把“返回默认值”作为发布环境的升级策略
- `save_version > CURRENT_SAVE_VERSION` 通常表示玩家用旧客户端打开了新客户端写入的存档。当前 MVP 的默认回退只作为防御性测试；发布前必须替换为兼容策略或阻止不兼容客户端覆盖存档

### EC-3: 快速连续保存

**场景**：穿搭确认和进度更新在极短时间内连续触发 `save()`（如 WARDROBE 确认 → 立即触发解锁 → 两次 save() 几乎同时）。

**行为**：
- `save()` 是同步操作（`JSON.stringify` + `localStorage.setItem`），每次调用都完整序列化当前 `data` 并覆盖写入
- 连续两次 `save()` 中，后一次覆盖前一次——最终存储的是最新的完整状态
- 不会出现"部分更新"或"数据竞争"——每次 `save()` 写入的是 `data` 的完整快照
- **不做防抖/节流**：save() 调用频率极低（每场会话最多 2-3 次），防抖逻辑只会增加复杂度而无实际收益

### EC-4: 存档数据被外部篡改

**场景**：玩家或浏览器扩展手动修改了 localStorage 中的存档 JSON。

**行为**：
- `load()` 的 `JSON.new().parse(raw_text)` 可能因语法错误失败 → 返回默认值
- 若 JSON 语法有效但字段缺失或基础类型错误（如 `current_day` 是字符串）→ schema 基础校验失败，返回默认值并 `push_warning()`
- 若字段类型正确但业务值异常（如 `current_day = 99`、物品 ID 不存在）→ SaveManager 接受该值，交由 ProgressManager 或消费方做业务修复
- **设计决策**：SaveManager 做基础结构校验，不做深度业务校验。它保证“读出的数据结构可被下游安全消费”，但不判断进度是否合法
- **安全边界**：localStorage 是不可信输入。篡改进度不需要防作弊，但所有消费方必须防崩溃：GameState 不得在 ProgressManager 修复前用原始 `current_day` 加载场景；每日场景/渲染层不得假设 `equipped_items` 中的 ID 一定存在；`unlock_progress` 不得作为衣橱可用性或装备许可来源

### EC-5: 场景恢复时穿搭数据缺失或为空

**场景**：`scene_in_progress = true`，但 `equipped_items` 字段缺失、为 `null`、不是数组，或为显式空数组 `[]`。

**行为**：
- SaveManager 不处理此逻辑——它只负责存取数据
- 由 GameState 在 BOOT 阶段等待 ProgressManager 修复完成后检查：若 `equipped_items` 字段缺失、为 `null`、不是数组，或包含无法归一化为 `String` 的值，则视为不可恢复状态，重置为 `scene_in_progress = false`，从 MAIN_MENU 正常开始
- 若 `equipped_items == []`，则保留为玩家明确确认的空穿搭语义，允许恢复到 DAILY_SCENE，并由 Daily Scene 调用 `apply_outfit([])`；不得改为默认穿搭，也不得仅因数组为空而清除恢复标记
- 若数组中的 ID 经过 WardrobeDatabase/ProgressManager 过滤后变为空，但原始字段类型有效，GameState 仍按明确空穿搭恢复；具体无效 ID 应记录 warning，而不是破坏玩家的会话恢复
- 此逻辑详见 `design/gdd/scene-state-management.md` 的 Edge Cases 部分和 `docs/architecture/adr-0004-scene-transition-and-state-machine-contract.md`

### EC-6: 新游戏/重置流程

**场景**：玩家选择新游戏或调试流程调用 `reset()`。

**行为**：
- SaveManager `reset()` 删除持久化键/文件，并将内存 `data` 恢复默认值；不立即写回默认存档
- 非 Web 下 `reset()` 必须同时删除或失效化正式文件、`.tmp`、`.bak`、`.corrupt` 以及任何恢复标记；Web 下必须删除当前 `SAVE_KEY`。Web MVP 不维护 backup key。重置后不得从旧 `.bak` 复活进度
- `reset()` 返回 `true` 时，调用方才允许执行 `ProgressManager.reset_progress()`、清除恢复上下文并回到 MAIN_MENU / Day 1
- `reset()` 返回 `false` 时，内存 `data` 仍恢复默认值，但 GameState/UI 必须停留在重置确认/错误处理路径，显示非技术提示并允许重试；不得把“重置已安全完成”展示给玩家，也不得立即调用 `ProgressManager.reset_progress()` 作为完成态
- `reset()` 不发出 `loaded` 或 `saved` 信号
- 只有 `reset() == true` 后，调用方才刷新依赖缓存：`ProgressManager.reset_progress()` 或等价初始化逻辑，清除恢复上下文，并回到 MAIN_MENU / Day 1
- SaveManager 不主动通知 UI，也不直接调用 ProgressManager；这是 GameState 的编排职责
- 玩家主动“新游戏/重置”必须由 UI 提供二次确认，文案明确说明会清除当前进度且不可撤销；确认文案保持温和，不使用技术术语

### EC-7: 浏览器清除数据后首次启动

**场景**：玩家手动清除浏览器数据（或浏览器自动清理），localStorage 中所有数据被删除。

**行为**：
- `is_save_exists()` 返回 `false`
- `load()` 返回默认存档数据——与全新玩家体验完全一致
- 游戏从第 1 天正常开始，不显示裸错误或技术提示
- 不把“静默重置”作为唯一体验原则。若调用方能通过外部入口、平台状态或未来元数据判断玩家可能是旧玩家，则应显示安抚性说明；若无法判断，按首次玩家流程进入，但不得暗示旧进度仍存在

### EC-7a: 存在存档但读取失败

**场景**：`is_save_exists()` 为 true，或非 Web 主档/`.bak` 存在，但 JSON/schema 读取失败且无法恢复。

**行为**：
- 该路径不得与“首次玩家无存档”完全静默等同
- GameState/UI 必须显示非技术、非责备提示，例如“我们没能读到上次的进度，你可以从今天重新开始。”
- 非 Web 若 `.bak` 或可验证字段可恢复，优先恢复到最接近的安全进度；无法恢复时才回到 Day 1
- Web MVP 只有单个 `SAVE_KEY`，不维护 `.bak` 或 backup key；Web 已有 key 读取失败时直接进入 `LOAD_EXISTING_FAILED_DEFAULT_LOCKED`，等待玩家确认后才能覆盖
- 提示不得出现“损坏 JSON”“localStorage”“schema”等技术词

### EC-8: SAVE_KEY 冲突

**场景**：同一域名下其他应用恰好使用了相同的 localStorage key。

**行为**：
- 概率极低（key 包含项目名 `pp-dress` + 版本后缀 `v1`）
- 不添加域名前缀或哈希——当前项目是单应用部署，过度设计无价值
- 若未来需要同一域名部署多个游戏 → 可通过 Tuning Knobs 修改 `SAVE_KEY`

## Dependencies

### 本系统依赖（上游）

保存/加载是 Foundation 层系统，不依赖任何其他游戏系统。

| 依赖 | 类型 | 说明 |
|------|------|------|
| Godot `JSON` 类 | 引擎内置 | 序列化/反序列化 |
| `JavaScriptBridge` | 引擎 API | Web 平台上访问 `localStorage` |
| `FileAccess` | 引擎内置 | 非 Web 平台 fallback，读写 `user://save-data.json` |

### 依赖本系统的系统（下游）

| 系统 | 依赖性质 | 说明 |
|------|---------|------|
| 场景/状态管理 | 强依赖 | BOOT 中等待 SaveManager 就绪；检查 `scene_in_progress` 和过滤后的 `equipped_items` 决定是否尝试恢复场景；状态转换时调用 `save()` |
| 进度管理 | 强依赖 | GOODNIGHT → MAIN_MENU 时作为进度规则权威推进天数与完成进度；通过限定写入 API 更新 SaveData 并调用 `save()`；查询 `current_day`、`highest_day_completed`、`unlock_progress` 获取持久化快照 |

### 双向依赖确认

**场景/状态管理** ↔ **保存/加载**：
- 保存/加载 GDD 的 "Interactions with Other Systems" 表记录了 GameState 对 SaveManager 的调用
- 场景/状态管理 GDD 的 Detailed Design 中应包含 BOOT 阶段等待 SaveManager 就绪、读取 SaveManager 只读快照/查询 API、以及状态转换时调用 `save()` 的契约

### 引擎平台约束

| 约束 | 影响 |
|------|------|
| `JavaScriptBridge` 仅在 Web 导出时可用 | `save()` 和 `load()` 需 `OS.has_feature("web")` 守卫；Web 分支通过 JS wrapper 返回 JSON 字符串结果；非 Web 平台使用 `FileAccess` 读写 `user://save-data.json` |
| `localStorage` 同步 API | `save()` 和 `load()` 均为同步操作，无需 `await` |
| `localStorage` 5MB 上限 | 存档 < 2KB，不构成限制 |

**平台后端契约**：
- `is_save_exists()`：Web 查询 localStorage key；非 Web 查询 `FileAccess.file_exists(FALLBACK_SAVE_PATH)`
- `reset()`：Web 调用 wrapper `removeItem()` 并以 wrapper `ok == true` 为成功；非 Web 删除或失效化 `FALLBACK_SAVE_PATH`、`save-data.tmp`、`save-data.bak`、`save-data.corrupt`，全部成功或确认不存在才返回 `true`
- `save()`：Web 成功以 JS wrapper JSON 结果 `ok == true` 为准；非 Web 成功以临时文件完整写入、校验通过并成功替换正式文件为准。`FileAccess` 没有“关闭成功”返回值，不得把 close 当作成功条件
- 非 Web fallback 必须写入 `user://save-data.tmp`，确认 `store_string()` 成功、临时文件可读、非空且 JSON parse 成功后，再替换 `FALLBACK_SAVE_PATH`
- 非 Web 替换流程不得假设 `DirAccess.rename()` 会覆盖目标文件。推荐顺序：写 `save-data.tmp` → 读回校验 → 若正式文件存在则先 rename 为 `save-data.bak` → rename tmp 为正式文件 → 若 tmp rename 失败则恢复 `.bak` 为正式文件并返回 `false`
- 该流程不是跨平台强原子保证，而是“尽量不破坏旧档”的崩溃恢复流程。任何失败都不得同时删除旧正式文件和 `.bak`
- 非 Web `load()` 遇到正式文件损坏时，若 `.bak` 可解析，应优先恢复 `.bak`，设置 `LOAD_RECOVERED_FROM_BACKUP`；恢复成功后可用 `.bak` 覆盖正式文件。若正式文件和 `.bak` 都不可用，才返回默认存档并 warning
- Web `load()` 不产生 `LOAD_RECOVERED_FROM_BACKUP`；Web 已有 `SAVE_KEY` 但读取/解析/schema 失败时，返回默认存档并设置 `LOAD_EXISTING_FAILED_DEFAULT_LOCKED`
- 坏档原文不得被自动覆盖。非 Web 可将坏档重命名为 `.corrupt` 或保留原文件供诊断；Web 不主动覆盖 raw text
- `saved` 信号只在最终持久化确认成功后发出

**状态更新时间表**：

| 操作/路径 | `last_load_status` | `last_save_status` | `storage_available` | `default_overwrite_locked` |
|-----------|--------------------|--------------------|---------------------|----------------------------|
| 无存档加载成功 | `LOAD_NO_SAVE` | 不变 | true | false |
| 正常存档加载成功 | `LOAD_OK` | 不变 | true | false |
| Web 存储不可用加载 | `LOAD_STORAGE_UNAVAILABLE` | 不变 | false | false |
| 非 Web `.bak` 恢复成功 | `LOAD_RECOVERED_FROM_BACKUP` | 不变 | true | false |
| 已有档读取失败且无可用备份 | `LOAD_EXISTING_FAILED_DEFAULT_LOCKED` | 不变 | true | true |
| `save()` 成功 | 不变 | `SAVE_OK` | true | false |
| `save()` 存储不可用 | 不变 | `SAVE_STORAGE_UNAVAILABLE` | false | 不变 |
| `save()` 写入/校验/替换失败 | 不变 | `SAVE_WRITE_FAILED` | true | 不变 |
| 坏档锁定期间 `save()` | 不变 | `SAVE_BLOCKED_DEFAULT_OVERWRITE` | true | true |
| `reset()` 成功 | `LOAD_NO_SAVE` | `SAVE_OK` | true | false |
| `reset()` 失败 | 不变 | `SAVE_RESET_FAILED` | 按失败原因更新 | 不变 |
| `acknowledge_default_overwrite()` | 不变 | `SAVE_NONE` | 不变 | false |

**调用频率约束**：`save()`、`load()` 和 `is_save_exists()` 均不得在 `_process()`、拖拽/hover、动画播放循环或高频 UI 交互中轮询调用。自动保存只允许发生在流程确认点：WARDROBE 确认、GOODNIGHT 完成进度推进、新游戏/重置确认后的显式流程。

## Tuning Knobs

保存/加载系统的可调参数很少——它是一条数据管道，不是游戏机制。

| 参数 | 默认值 | 安全范围 | 影响 |
|------|--------|---------|------|
| `SAVE_KEY` | `"pp-dress-save-v1"` | 任意唯一字符串 | localStorage 键名。修改后旧存档不可见（等效于重置）；真实发布后不得把改 key 当作默认升级策略，除非已有迁移/补偿方案 |
| `save_version` | 1 | 正整数 | 存档 Schema 版本。递增后必须先设计迁移策略；MVP 无旧版本时可保持 v1 单 key |
| `FALLBACK_SAVE_PATH` | `"user://save-data.json"` | 有效 `user://` 路径 | 非 Web 平台的 FileAccess fallback 路径。MVP 主要用于编辑器/本地测试 |

### 非本系统控制的调参点

以下行为由 **调用方** 控制，不在 SaveManager 的 Tuning Knobs 范围内：

| 行为 | 控制方 | 说明 |
|------|--------|------|
| 自动保存触发时机 | GameState | WARDROBE 确认、GOODNIGHT → MAIN_MENU 等时机由场景/状态管理系统决定 |
| 进度记录频率 | 进度管理系统 | 何时调用 `record_unlocks()` 由进度管理决定 |
| 存档重置触发 | GameState / UI | 是否提供"新游戏"按钮、何时调用 `reset()` 由场景/状态管理和 UI 决定 |

### 刻意不做成可调的

| 项目 | 固定值 | 原因 |
|------|--------|------|
| 序列化格式 | JSON | Godot 内置支持，Web 原生兼容。无替代方案需求 |
| 存储后端 | localStorage | MVP 仅 Web。多平台时通过 `OS.has_feature()` 分支而非配置切换 |
| 多存档槽 | 不支持 | 游戏设计为单线进度，无多存档需求 |

## Visual/Audio Requirements

N/A — 保存/加载是纯数据层系统，不产生任何视觉或音频输出。

## UI Requirements

N/A — SaveManager 没有 UI 界面。存档状态的 UI 展示（如"保存中..."提示、"上次保存时间"等）属于对应 UI 系统的职责，不在本系统范围内。

## Acceptance Criteria

### Evidence 分层

| 层级 | 证据路径 | 覆盖范围 |
|------|----------|----------|
| Unit | `tests/unit/save_load/` | SaveData、schema、序列化、信号、平台 wrapper mock |
| File Backend Integration | `tests/integration/save_file_backend/` | 非 Web `FileAccess` tmp/bak/rename/restore 路径 |
| Game Flow Integration | `tests/integration/save_progress_boot/` | GameState、ProgressManager、BOOT 恢复、GOODNIGHT 推进 |
| Manual/UI Evidence | `production/qa/evidence/save-load/manual-walkthrough.md` + screenshots | 玩家可见提示、重置确认、坏档提示、发布门禁说明 |
| Performance | `production/qa/perf/save-load/perf-report.md` | 容量、P50/P95/max、设备/浏览器记录 |
| Static/Review | `production/qa/evidence/save-load/static-review.md` | 高频调用禁用、代码审查确认项 |

### Unit: SaveData 与生命周期

- [ ] **AC-U1**: 首次启动无存档时，`SaveManager._ready()` 自动加载默认 SaveData，`is_ready == true`，发出一次 `loaded(default_data)`
- [ ] **AC-U2**: `load()` 在 `is_ready == true` 时直接返回当前 `data`，不读取后端，不重复发出 `loaded`
- [ ] **AC-U3**: `save()` 成功时返回 `true`，发出一次 `saved`
- [ ] **AC-U4**: `save()` 失败时返回 `false`，不发出 `saved`
- [ ] **AC-U5**: `reset()` 删除持久化数据并恢复内存默认值；成功时返回 `true`，不写回默认存档，不发出 `loaded` 或 `saved`
- [ ] **AC-U6**: `reset() == true` 后下一次显式 `save()` 才重新创建存档，`is_save_exists()` 才返回 `true`
- [ ] **AC-U7**: setter 写入数组时复制输入；公开读取数组/字典时返回副本，外部修改副本不改变内部 `data`
- [ ] **AC-U8**: `reset()` 任一必要持久化对象删除失败时返回 `false`，设置 `last_save_status == SAVE_RESET_FAILED`，不发出 `saved`
- [ ] **AC-U9**: `reload_from_backend_for_tests()` 在 `is_ready == true` 时仍重新读取后端并更新内存 `data`；正常 GameState/ProgressManager 流程不调用该方法

### Unit: Round Trip 与字段约束

- [ ] **AC-D1**: ProgressManager 或测试夹具通过限定 API 设置 `current_day = 3` 后保存，重建 SaveManager 后 `data.current_day == 3`
- [ ] **AC-D2**: `set_equipped_items(["top-001", "bottom-002"])` 保存后 round-trip 保持相同顺序
- [ ] **AC-D3**: `set_equipped_items(["top-001", "top-001"])` 保存后 round-trip 保留重复项，SaveManager 不去重
- [ ] **AC-D4**: `set_scene_in_progress(true)` 保存后 round-trip 为 `true`
- [ ] **AC-D5**: `mark_day_completed(3)` 保存后 round-trip 为 `highest_day_completed == 3`
- [ ] **AC-D6**: `record_unlocks(2, ["acc-001", "hair-002"])` 保存后 round-trip 保持同一数组和顺序
- [ ] **AC-D7**: `record_unlocks(3, [])` 保存后 round-trip 保留空数组 key
- [ ] **AC-D8**: 多余字段被 `from_dict()` 忽略，不写入内存 `data`，下一次 `save()` 输出不包含该多余字段
- [ ] **AC-D9a**: `current_day = 99, highest_day_completed = 0` 且结构类型正确时，SaveManager 加载后保留原始 `current_day`，不 clamp、不默认
- [ ] **AC-D9b**: `highest_day_completed = -3` 且结构类型正确时，SaveManager 加载后保留原始值，交由 ProgressManager 修复
- [ ] **AC-D9c**: `equipped_items = ["missing_item"]` 且结构类型正确时，SaveManager 加载后保留该 ID，交由 GameState/Wardrobe 消费方过滤
- [ ] **AC-D9d**: `unlock_progress = {"99": ["fake_item"]}` 且结构类型正确时，SaveManager 加载后保留该 key/value，交由 ProgressManager 判定是否可用

### Unit: Schema 与错误输入

以下每一行都是独立参数化用例，期望均为：返回完整默认 SaveData，发出 warning，不自动覆盖原 raw text。

| 用例 | 输入 |
|------|------|
| **AC-S1** | raw text 为空字符串 |
| **AC-S2** | JSON 为 `null` |
| **AC-S3** | JSON root 为 Array |
| **AC-S4** | JSON root 为 scalar |
| **AC-S5** | 缺少任一必需字段 |
| **AC-S6** | `save_version` 非整数值 number |
| **AC-S7** | `current_day` 非整数值 number |
| **AC-S8** | `highest_day_completed` 非整数值 number |
| **AC-S9** | `equipped_items` 非 Array |
| **AC-S10** | `equipped_items` 含非 String 元素 |
| **AC-S11** | `scene_in_progress` 非 bool |
| **AC-S12** | `unlock_progress` 非 Dictionary |
| **AC-S13** | `unlock_progress` value 非 Array[String] |

- [ ] **AC-S14**: `_read_int(3)` 与 `_read_int(3.0)` 成功返回 `3`
- [ ] **AC-S15**: `_read_int(3.5)`、String、bool、null 均失败
- [ ] **AC-S16**: `save_version == 1` 正常加载
- [ ] **AC-S17**: `save_version < 1`、`save_version == 0`、负数版本均视为 unsupported，返回默认 SaveData
- [ ] **AC-S18**: `save_version > 1` 在 MVP 防御性路径中返回默认 SaveData、设置 `last_load_status = LOAD_EXISTING_FAILED_DEFAULT_LOCKED`、不自动覆盖 raw text
- [ ] **AC-S19**: `load()` 完成后内部 `data` 更新为本次加载结果；无存档、坏档、正常存档三条路径均覆盖

### Unit: 平台后端

- [ ] **AC-P1**: Web `getItem` wrapper 返回 JSON 字符串，并区分 `ok == true && exists == false` 与 `ok == false`
- [ ] **AC-P2a**: Web `setItem` wrapper 成功时返回 JSON 字符串 `{"ok":true,"error":""}`
- [ ] **AC-P2b**: Web `setItem` wrapper 在配额、安全策略或隐私模式异常时返回 JSON 字符串 `{"ok":false,...}`，不抛出未处理异常
- [ ] **AC-P2c**: Web `removeItem` wrapper 成功和失败均返回 JSON 字符串结果，不抛出未处理异常
- [ ] **AC-P3**: 传入 `JavaScriptBridge.eval()` 的 key/value 已安全转义；含引号、反斜杠、换行的存档 JSON 不破坏 JS 语法
- [ ] **AC-P3a**: Web wrapper 使用 `_js_literal(value) = JSON.stringify(str(value))` 生成 `SAVE_KEY` 与 serialized JSON 的 JS 字符串字面量；测试覆盖引号、反斜杠、换行和 Unicode 字符
- [ ] **AC-P4**: Web localStorage 不可用时，`save()` 返回 `false`，不发 `saved`
- [ ] **AC-P5**: Web localStorage 不可用时，`load()` 返回默认 SaveData，`is_ready == true`，`storage_available == false`，`last_load_status == LOAD_STORAGE_UNAVAILABLE`，发出 `loaded(default_data)`
- [ ] **AC-P6**: 非 Web 无正式文件时，`load()` 返回默认 SaveData
- [ ] **AC-P7**: 非 Web 保存写入 `save-data.tmp`，写入句柄释放后校验可读、非空、JSON parse 成功，才尝试替换正式文件
- [ ] **AC-P8**: 非 Web 替换前若旧 `.bak` 存在，先删除旧 `.bak`；删除失败时保留正式文件和 tmp，`save()` 返回 `false`
- [ ] **AC-P9**: 非 Web 替换前若正式文件存在，先 rename 为 `.bak`；rename 失败时保留正式文件和 tmp，`save()` 返回 `false`
- [ ] **AC-P10**: 非 Web tmp rename 为正式文件失败时，恢复 `.bak` 为正式文件，`save()` 返回 `false`，不发 `saved`
- [ ] **AC-P11**: 非 Web 主档损坏但 `.bak` 可解析时，`load()` 恢复 `.bak`，`last_load_status == LOAD_RECOVERED_FROM_BACKUP`
- [ ] **AC-P12**: 非 Web 主档与 `.bak` 都不可用时，`load()` 返回默认 SaveData，`last_load_status == LOAD_EXISTING_FAILED_DEFAULT_LOCKED`，`default_overwrite_locked == true`
- [ ] **AC-P13**: 非 Web `reset()` 清理正式文件、`.tmp`、`.bak`、`.corrupt`，重置后旧备份不会复活进度
- [ ] **AC-P14**: Web MVP 不维护 backup key；Web 已有 `SAVE_KEY` 但读取/解析/schema 失败时不产生 `LOAD_RECOVERED_FROM_BACKUP`，而是进入 `LOAD_EXISTING_FAILED_DEFAULT_LOCKED`
- [ ] **AC-P15**: 非 Web 替换流程每个失败点均符合磁盘状态表：不同时删除正式文件和 `.bak`，下次 `load()` 能按正式文件 → `.bak` → 默认锁定的顺序恢复

### Integration: GameState / ProgressManager

- [ ] **AC-I1**: GameState `_ready()` 不在同帧访问 SaveManager；BOOT 通过 deferred boot、等待一帧或 Foundation ready 标记启动
- [ ] **AC-I2**: GameState 和 ProgressManager 访问 SaveManager 时使用 `is_ready` 双路径
- [ ] **AC-I3**: WARDROBE 确认时 GameState 不调用 `SaveManager.set_current_day()`
- [ ] **AC-I4**: BOOT 恢复 DAILY_SCENE 前等待 ProgressManager 修复完成，并使用修复后的 `ProgressManager.get_current_day()`
- [ ] **AC-I5**: `scene_in_progress == true` 且 `equipped_items` 字段缺失、为 `null`、不是数组或包含无法归一化为 `String` 的值时，GameState 清除恢复标记、调用 `SaveManager.save()` 持久化修复，并进入 MAIN_MENU；若 `equipped_items == []` 或有效数组过滤后为空，则保留为空穿搭恢复语义并进入 DAILY_SCENE
- [ ] **AC-I6**: GOODNIGHT → MAIN_MENU 时先 `set_scene_in_progress(false)`，再调用 `ProgressManager.advance_day()`；只有 `advance_day() == true` 才允许进入 MAIN_MENU
- [ ] **AC-I7**: `ProgressManager.advance_day() == true` 且 MAIN_MENU 已进入后立即刷新，不恢复已完成 DAILY_SCENE
- [ ] **AC-I8**: `current_day = 99, highest_day_completed = 0` 经 ProgressManager 修复后，不进入 day 7，不全量解锁
- [ ] **AC-I9**: `unlock_progress = {"99": ["fake_item"]}` 不影响 `ProgressManager.is_item_unlocked()` 或衣橱装备许可
- [ ] **AC-I10**: `ProgressManager.advance_day()` 的最终 `SaveManager.save()` 失败时，`advance_day()` 返回 `false`，GameState 停留在 GOODNIGHT 未安全结束状态，且不展示新一天/新解锁
- [ ] **AC-I11**: `last_load_status == LOAD_EXISTING_FAILED_DEFAULT_LOCKED` 时，未调用 `acknowledge_default_overwrite()` 前任何自动 `save()` 均返回 `false` 且不覆盖原存档键
- [ ] **AC-I12**: GOODNIGHT 保存失败时，ProgressManager 已回滚 `current_day`、`highest_day_completed`、`unlock_progress`，GameState 仅在内存中恢复 `scene_in_progress = true`，且失败路径不再次调用 `SaveManager.save()`
- [ ] **AC-I13**: GOODNIGHT 保存失败后刷新浏览器时，按最后一次成功保存的 `scene_in_progress = true` 尝试恢复当天 DAILY_SCENE，不进入新一天、不展示新解锁
- [ ] **AC-I14**: `acknowledge_default_overwrite()` 只解除 `default_overwrite_locked` 并将 `last_save_status` 置为 `SAVE_NONE`；不会伪造 `LOAD_OK` 或自动写回默认档

### Manual/UI 与发布策略

- [ ] **AC-M1**: 存储不可用提示包含“本次进度可能无法保存”或等价含义，不包含技术错误、堆栈、`localStorage`、JSON、schema 等技术词
- [ ] **AC-M2**: WARDROBE 保存失败时允许继续，但提示本次穿搭可能无法保留，并安排下个安全点重试
- [ ] **AC-M3**: GOODNIGHT 保存失败时停留在未安全结束状态；默认操作为重试，不展示“新一天/新解锁已安全保存”的完成感
- [ ] **AC-M4**: 存在存档但读取失败时，与首次无存档不同，显示非责备提示说明未能读取上次进度，并要求玩家确认后才允许覆盖旧进度
- [ ] **AC-M5**: 玩家主动新游戏/重置必须经过二次确认；确认文案说明当前进度会清除且不可撤销
- [ ] **AC-M6**: MVP 证据记录“正式迁移表不在本系统当前范围内”；任何发布后的 `save_version` 升级故事必须先提供迁移测试和玩家可见降级策略，作为发布门禁
- [ ] **AC-M7**: `reset() == false` 时，UI 不展示“重置完成”，保留重试入口，并使用非技术、非责备文案说明暂时没能清除本机进度

### Performance / Capacity

- [ ] **AC-F1**: 默认存档、MVP 7 天完整合法存档、MVP 最大合法样本三者 JSON UTF-8 字节数均 < 2KB
- [ ] **AC-F2**: 性能报告记录 10KB 为未来重新评估阈值；本 AC 只验证阈值被记录，不要求当前存档达到该大小
- [ ] **AC-F3**: `save()` Web release 全链路至少测量 100 次，报告 P50/P95/max、浏览器、设备、构建类型、JSON 字节数
- [ ] **AC-F4**: `load()` Web release 全链路至少测量 100 次，报告 P50/P95/max、浏览器、设备、构建类型、JSON 字节数
- [ ] **AC-F5**: 性能报告明确是否剔除首次 WASM 启动成本、冷/热启动定义，并使用同一设备/浏览器基线
- [ ] **AC-F6**: P95 < 5ms 为 PASS；超出需 technical-director 明确豁免
- [ ] **AC-R1**: 静态/代码审查确认 `save()`、`load()`、`is_save_exists()` 不在 `_process()`、拖拽/hover、动画循环或高频 UI 交互中轮询调用

### 不测试的内容

- 深度跨浏览器兼容性矩阵不在 MVP 范围；但 Web 存档 smoke 必须至少覆盖一个 Chromium 浏览器和一个 WebKit/Safari 或移动 WebKit 路径的读写/失败提示
- 存档加密/防作弊：不在 MVP 范围内
- 云存档、多存档槽、正式迁移表：不在 MVP 范围内

## Open Questions

1. **上次保存时间是否显示**：存储不可用、保存失败、重置确认和迁移失败已有玩家体验契约；是否额外常驻显示"上次保存时间"仍由 UI 系统设计时决定。
2. **首次 Schema 升级迁移表**：真实发布后的首次 `save_version` 升级前，需要单独设计迁移表或补偿策略；不得默认通过更换 `SAVE_KEY` 等效清档。
