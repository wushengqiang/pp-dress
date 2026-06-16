# 服装数据库 (Wardrobe Database)

> **Status**: Approved
> **Author**: user + Claude Code Game Studios
> **Last Updated**: 2026-06-09
> **Implements Pillar**: 随心搭配, 即时有感

## Overview

服装数据库是「每日穿搭」游戏的静态数据中心。它以结构化数据定义游戏中每一件可换服装部件的完整属性——包括类目归属、显示名称、资源路径、Z 轴层序和解锁条件——供精灵分层渲染、衣橱 UI、拖拽换装和服装解锁等系统消费。

该系统本身不产生游戏行为，不处理输入，不驱动动画。它是整个换装系统的数据骨架：一次正确定义，全系统一致消费。

## Player Fantasy

此系统为纯基础设施——玩家不直接感知数据库的存在。玩家感受到的是「随心搭配」（所有服装部件准确呈现）和「即时有感」（换装反馈即时生效），而非数据库本身。无独立玩家幻想。

## Detailed Design

### 存储方案：JSON + Autoload

单个 JSON 文件存储所有服装数据。一个 Godot Autoload（`WardrobeDatabase.gd`）在 `_ready()` 中加载解析，对外提供查询接口。

选择 JSON 的理由：人可读、单文件管理、Web 端单次 HTTP 获取（~3-5KB）、版本控制友好、设计师无需 Godot 编辑即可修改。

### 数据结构

#### 类目定义（`categories`）

| 键 | label | z_index_default | 说明 |
|-----|-------|----------------|------|
| `makeup` | 妆容 | 1 | 面部贴图，最底层 |
| `bottom` | 下装 | 2 | 覆盖腿部 |
| `shoes` | 鞋子 | 3 | 覆盖脚部 |
| `top` | 上装 | 4 | 覆盖躯干 |
| `accessory` | 配饰 | 5 | 项链、围巾等 |
| `hair` | 发型 | 6 | 最顶层 |

#### 物品字段定义（`items[]`）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| `id` | string | `{category}_{descriptor}` snake_case，全局唯一 | 自文档化标识符 |
| `category` | string | `categories` 中的有效键 | 类目归属 |
| `name` | string | 中文，≤8 字 | UI 显示名称 |
| `sort_order` | int | ≥0，类目内唯一 | 衣橱 UI 同类目内的显示排序。数字越小越靠前 |
| `texture_path` | string | 相对于 `assets/textures/` | 全尺寸 PNG（1024×1536） |
| `thumbnail_path` | string | 相对于 `assets/textures/` | 衣橱缩略图（48×48） |
| `unlock_day` | int | ≥1 | 第几天解锁。`1` = 初始可用 |
| `tags` | string[] | 枚举标签数组 | 风格分类。有效值：`basic`, `cute`, `cool`, `elegant`, `sports`, `cozy`。空数组 `[]` = 未分类。**消费端**：供衣橱 UI 筛选按钮和对话系统风格匹配使用。季节/场景属性由每日场景系统管理，不在此字段中 |
| `z_index_override` | int\|null | `null` 或任意整数 | `null` = 使用类目默认 z_index；填整数 = 覆盖后经 clamp(1,10) |

#### 关键设计决策

- **`unlock_day: 1` 显式声明**：初始物品明确标记为 `1`，不用 `null` 表示"默认拥有"——消除"是忘了填还是初始物品"的歧义
- **首日解锁节奏克制**：首日每类目仅 1-2 件初始物品（共 6-8 件），之后每天解锁 3-4 件——强化"每日期待"的陪伴感，避免首日信息过载
- **`z_index_override` + clamp**：绝大多数物品（~28/30）使用类目默认层序。仅 ~2 个例外（如搭在胸前的围巾需渲染在发型之上）使用 `override`。所有 override 值经 `clamp(1, 10)` 保证输出在合法范围
- **`thumbnail_path` 独立**：UI 网格需要小缩略图（48px），渲染需要全尺寸纹理（1024px）。分开两个路径，避免强制同分辨率
- **`tags` 枚举标签体系**：标签限定为 6 个风格枚举值（`basic`, `cute`, `cool`, `elegant`, `sports`, `cozy`），避免自由文本造成的筛选不一致。空数组表示未分类。季节/场景属性（夏季/冬季等）由每日场景系统管理——服装不携带季节标签
- **`sort_order` 显示排序**：同类目内物品按 `sort_order` 升序排列，确保 UI 展示顺序确定且可预期
- **槽位独占性**：每个类目同时只能装备 1 件物品。选择新物品自动替换旧物品。此规则由精灵分层渲染 / 拖拽换装系统执行，数据库层仅提供数据——不建模槽位状态

### JSON 示例

```json
{
  "version": "1.0",
  "categories": {
    "makeup":    { "label": "妆容",   "z_index_default": 1 },
    "bottom":    { "label": "下装",   "z_index_default": 2 },
    "shoes":     { "label": "鞋子",   "z_index_default": 3 },
    "top":       { "label": "上装",   "z_index_default": 4 },
    "accessory": { "label": "配饰",   "z_index_default": 5 },
    "hair":      { "label": "发型",   "z_index_default": 6 }
  },
  "items": [
    {
      "id": "top_white_tee",
      "category": "top",
      "name": "白色T恤",
      "sort_order": 0,
      "texture_path": "clothing/top_white_tee.png",
      "thumbnail_path": "clothing/thumbnails/top_white_tee.png",
      "unlock_day": 1,
      "tags": ["basic"],
      "z_index_override": null
    },
    {
      "id": "accessory_scarf_front",
      "category": "accessory",
      "name": "前搭围巾",
      "sort_order": 5,
      "texture_path": "clothing/accessory_scarf_front.png",
      "thumbnail_path": "clothing/thumbnails/accessory_scarf_front.png",
      "unlock_day": 6,
      "tags": ["cozy"],
      "z_index_override": 7
    }
  ]
}
```

### 类目解锁分离

类目级别的可见性（前 3 天仅显示上装/下装/鞋子）**不存储在服装数据库中**。此逻辑属于进度管理系统——服装数据库只定义每个物品的 `unlock_day`，类目可见性由进度系统单独控制。改规则时只需修改进度配置，无需扫描所有物品。

### Autoload 接口

`WardrobeDatabase.gd` 对外提供以下接口：

> **设计决策：不使用信号，统一使用属性检查**。JSON 加载在 `_ready()` 中同步完成。信号（无论是 `database_ready` 还是 `database_error`）在 `_ready()` 内发出时没有任何消费者连接——其他 Autoload 的 `_ready()` 尚未开始，场景尚未加载。因此信号对所有消费方都是死代码。下游系统统一使用 `is_ready` + `load_error` 属性做一次性检查：Boot 场景在 `_ready()` 中读取这两个属性，据此决定是否进入游戏主流程。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `is_ready` | `bool` | `true` = 数据就绪，查询安全。下游系统必须在查询前检查此标记 |
| `load_error` | `String` | 非空字符串 = 加载失败，内容为人类可读的错误描述 |

#### 查询方法

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `get_all_items()` | — | `Array[Dict]` | 全部物品（深拷贝），按类目 `z_index_default` 升序分组，同类目内按 `sort_order` 升序 + `id` 字母序排列 |
| `get_items_by_category(cat)` | 类目键 | `Array[Dict]` | 某类目所有物品（深拷贝），按 `sort_order` 升序排列 |
| `get_items_by_tag(tag)` | 标签字符串 | `Array[Dict]` | 含指定标签的所有物品（深拷贝） |
| `get_item_by_id(id)` | 物品 ID | `Dict\|null` | 按 ID 查找（深拷贝）；不存在返回 `null` |
| `get_unlocked_items(day)` | 当前天数 | `Array[Dict]` | 当前已解锁物品（深拷贝） |
| `get_z_index(item)` | 物品 Dict | `int` | 解析 z_index（优先 override） |
| `get_categories()` | — | `Dict` | 类目定义表（深拷贝） |

> **深拷贝约定**：所有返回 `Dict` 或 `Array[Dict]` 的查询方法返回数据的深拷贝（`.duplicate(true)`），防止消费者意外修改 Autoload 内部数据。

### 初始化与错误处理

#### 加载流程

1. `WardrobeDatabase` 必须在 Godot 项目设置的 Autoload 列表中排在**第一位**——所有下游 Autoload 在其 `_ready()` 中查询数据库时，WardrobeDatabase 的 `_ready()` 已执行完毕。**严禁在 `_ready()` 中使用 `await`**——任何异步调用都会导致 `_ready()` 提前返回，破坏 Autoload 初始化顺序保证
2. `_ready()` 中使用 `FileAccess.open("res://assets/data/wardrobe.json", FileAccess.READ)` 打开文件，检查返回值是否为 `null`（区分"文件不存在"和"空文件"），然后调用 `get_as_text()` 读取内容；使用 `JSON.new().parse()` 解析（实例方法，提供 `get_error_line()` 和 `get_error_message()`）
3. 解析成功后，构建 `id → Dict` 索引字典（O(1) 查询），校验全部数据（按 Edge Cases 表格逐项检查）
4. 校验通过 → 设置 `is_ready = true`
5. 校验失败 → 设置 `is_ready = false`，`load_error` 记录错误描述。Boot 场景通过 `is_ready` + `load_error` 检测并展示错误画面

#### 错误展示约定

WardrobeDatabase 本身不显示 UI。错误展示由 **Boot 场景**（归属场景/状态管理系统）负责：Boot 场景在 `_ready()` 中检查 `WardrobeDatabase.is_ready`，若为 `false` 则读取 `load_error` 并显示错误画面，阻止进入游戏主流程。

> **创意方向——错误展示语调**：数据库加载失败是技术异常，但面向玩家的错误画面必须与"每日陪伴"支柱保持一致。避免技术化的错误描述（如 `"JSON 解析错误: 第 5 行"`），改用温暖、安抚性的语言（如 `"衣橱正在整理中，请稍后再来..."`），将 `load_error` 中的技术细节记录到日志而非直接展示给玩家。Boot 场景的详细设计见场景/状态管理 GDD。

#### Web 导出配置

`wardrobe.json` 必须包含在 Web 导出的 `.pck` 包中。

- 将 `wardrobe.json` 放置在 `res://assets/data/` 目录下
- `res://` 下的文件默认包含在导出中，无需额外配置
- 如有自定义排除规则，在 `export_presets.cfg` 的 `[preset.N.options]` 段中确保 `include_filter` 包含 `res://assets/data/wardrobe.json`

若缺少此配置，`FileAccess.open()` 在 Web 端返回 `null`，游戏将加载失败。

## Formulas

服装数据库是纯数据系统，无复杂数学公式。以下两个解析逻辑定义了数据到行为的转换规则，多个消费系统依赖其输出一致性。

### Z-Index 解析

```
raw_z = item.z_index_override ?? categories[item.category].z_index_default
effective_z = clamp(raw_z, 1, 10)
```

| 变量 | 类型 | 范围 | 来源 | 说明 |
|------|------|------|------|------|
| `item.z_index_override` | int\|null | null 或任意整数 | items[].z_index_override | 物品级覆盖值；null 时回退到类目默认 |
| `item.category` | string | categories 中有效键 | items[].category | 物品所属类目 |
| `categories[cat].z_index_default` | int | 1–6 | categories 表 | 类目默认渲染层级 |

**预期输出范围**: 1–10（始终——clamp 保证）

> **语义注意**：`z_index_override: 0` **不等于** "使用默认值"。GDScript 的 `??` 运算符仅在左值为 `null` 时才取右值，`0` 不是 `null`，所以 `raw_z = 0`，经 clamp 后 `effective_z = 1`。如果需要"使用类目默认 z_index"，请将 `z_index_override` 设为 `null`。

**示例**:
- `top_white_tee`（category=top, override=null）→ `clamp(categories["top"].z_index_default, 1, 10)` = **4**
- `accessory_scarf_front`（category=accessory, override=7）→ `clamp(7, 1, 10)` = **7**（覆盖类目默认 5）
- override=0 的物品 → `clamp(0, 1, 10)` = **1**（clamp 下限 + 警告）
- override=15 的物品 → `clamp(15, 1, 10)` = **10**（clamp 上限 + 警告）

### 解锁判定

```
is_unlocked = item.unlock_day <= current_day
```

| 变量 | 类型 | 范围 | 来源 | 说明 |
|------|------|------|------|------|
| `item.unlock_day` | int | ≥1 | items[].unlock_day | 物品解锁所需天数 |
| `current_day` | int | ≥0 | 进度管理系统 | 玩家当前游戏天数。day=0 表示游戏尚未开始，`get_unlocked_items(0)` 返回空数组 |

**预期输出**: boolean

**示例**:
- `top_white_tee`（unlock_day=1）在 day=1 → **true**（初始即拥有）
- `accessory_scarf_front`（unlock_day=6）在 day=3 → **false**（尚未解锁）

## Edge Cases

| 场景 | 预期行为 | 理由 |
|------|----------|------|
| JSON 文件解析失败（格式错误） | Autoload 在 `_ready()` 中检测解析错误，打印带行号的错误信息，阻止游戏进入可交互状态 | 服装数据是换装系统的骨架——数据坏了，游戏无法正确运行。与其带着坏数据进入游戏然后出现诡异行为，不如在启动时就明确失败 |
| 物品 `id` 重复 | Autoload 检测重复 id，打印两个冲突物品的名称，加载失败 | 唯一 id 是所有查询方法的前提。`get_item_by_id()` 必须返回唯一结果 |
| 物品的 `category` 不在 `categories` 表中 | Autoload 检测无效引用，打印物品 id 和无效的 category 值，加载失败 | 孤立的 category 会导致 `get_z_index()` 和 `get_items_by_category()` 行为未定义 |
| 必填字段缺失（id / name / texture_path） | Autoload 检测缺失字段，打印物品索引和缺失字段名，加载失败 | 这三个字段是渲染和 UI 的必要数据，缺失任何一个物品都无法正常工作 |
| `z_index_override` 超出 1–10 范围 | Autoload 将超出范围的值 clamp 到合法边界（<1→1, >10→10），打印警告但继续加载 | 覆盖值只影响渲染层序，clamp 到边界不会导致崩溃，仅产生微小视觉偏差。警告足以让设计师修正 |
| `unlock_day` < 1 | Autoload 检测非法值，打印物品 id 和实际值，加载失败 | unlock_day=0 或负数没有明确的游戏语义，一定是数据录入错误 |
| `unlock_day` 为 `null` 或字段缺失 | Autoload 检测缺失/空值，打印物品 id，加载失败 | GDScript 中 `null` 在数值比较时被强制转换为 `0`，`null <= 1` 返回 `true`——缺失 unlock_day 的物品会静默变为始终解锁。必须显式检测并阻止 |
| `unlock_day` 超出内容窗口（如 `unlock_day = 999`） | 打印 `push_warning()` 警告（含物品 id 和实际值），继续加载 | `unlock_day` 远超 MVP 的 7 天窗口可能是数据录入错误（如多打了 9），但不排除设计意图（预留远期内容）。警告足以提醒设计师检查 |
| `items` 数组为空 | 正常加载，所有查询返回空数组。游戏可以启动但衣橱为空——这在开发早期是合法状态 | 空数据库不是错误，是开发过程中的正常中间态 |
| JSON 文件不存在 | Autoload 检测文件缺失，打印预期路径，加载失败 | 与解析失败同理——没有服装数据，游戏无法运行 |
| `categories` 字典为空（`{}`） | Autoload 检测空字典，加载失败 | `categories` 为空意味着所有物品的 `category` 引用都无法解析，`get_z_index()` 会在查询时崩溃。必须在加载阶段阻止 |
| `tags` 数组为空 | 正常处理。空数组表示该物品无特殊风格标签 | tags 是可选筛选用途，空数组是合法的"未分类"状态 |
| `thumbnail_path` 指向的文件不存在 | 数据库不验证此情况 | 文件存在性属于资源加载器的职责，数据库只存储路径字符串 |
| `categories` 中某个类目的 `z_index_default` 字段缺失 | `categories[cat].z_index_default` 返回 `null`，`get_z_index()` 中 `??` 回退为 `null`，`clamp(null, 1, 10)` 在 GDScript 中 `null` 强制转换为 `0` 后 clamp 到 `1`——静默退化，无警告。加载阶段须检测此情况并触发加载失败 | 类目缺少 `z_index_default` 是数据定义错误，`get_z_index()` 的静默回退行为会掩盖该错误 |
| 类目键大小写不一致（如 item 中写 `"Top"` 而 categories 定义的是 `"top"`） | 不匹配，`categories["Top"]` 返回 null → 加载失败（同无效 category 引用） | JSON 键区分大小写。加载时做严格匹配，不做自动修正 |
| `id` 前缀与 `category` 不一致（如 `id: "top_white_tee"` 但 `category: "hair"`） | 加载失败，打印物品 id 和冲突的两个值 | `id` 的 `{category}_{descriptor}` 格式是约定——不一致说明数据录入错误 |
| `name` 超过 8 个字符 | 加载失败，打印物品 id 和实际长度 | `name` 用于 UI 显示，长度限制保证衣橱网格排版不溢出 |
| `sort_order` 在同类目内重复 | 打印警告，按 `sort_order` 升序排列，相同 `sort_order` 的物品以 `id` 字母序为二级排序键继续加载 | 排序重复是设计问题不是数据损坏，不应阻止加载。以 `id` 字母序作为平局规则保证输出确定性，不依赖 JSON 中出现顺序 |
| `tags` 包含未定义的枚举值（如 `"street"`） | 打印警告（含物品 id 和无效标签值），跳过该标签，继续加载 | 允许未来扩展枚举时不破坏旧数据；无效标签被忽略。有效枚举值限定为 6 个：`basic`, `cute`, `cool`, `elegant`, `sports`, `cozy` |
| `tags` 全部为无效枚举值（如 `["street", "vintage"]`） | 打印警告，物品以 `tags: []`（空数组）加载，继续运行。不触发加载失败 | 所有标签均无效时，物品降级为"未分类"状态。空 tags 是合法状态（见上），不应阻止加载 |
| JSON 包含 schema 未定义的额外字段（如 `"texturepath"` 拼写错误） | 打印 `push_warning()`（含物品 id 和未知字段名），忽略该字段，继续加载 | 向前兼容仍有效——但必须警告未知字段，避免拼写错误导致静默数据丢失（如设计师写了 `"texturepath"` 而非 `"texture_path"`，纹理永远不会渲染且无提示）

## Dependencies

| 系统 | 方向 | 依赖性质 |
|------|------|----------|
| 精灵分层渲染 | 依赖本系统 | 通过 `get_z_index(item)` 获取渲染层序；通过 `get_item_by_id(id)` 获取 `texture_path`。**架构约束**：Godot `CanvasItem.z_index` 仅对同一父节点的直接子节点排序。精灵分层渲染系统必须将所有服装精灵放置在同一父节点下，本 GDD 中的 z_index 值（1–10）才能产生指定的前后遮挡关系。若精灵分散在不同父节点下，z_index 值无意义 |
| 进度管理 | 依赖本系统 | 通过 `get_unlocked_items(day)` 获取当前可用的物品列表；通过 `get_categories()` 获取类目定义用于类目解锁逻辑 |
| 衣橱 UI | 依赖本系统 | 通过 `get_items_by_category(cat)` 获取各类目物品列表；通过 `get_all_items()` 构建完整衣橱视图；读取 `name`、`thumbnail_path`、`tags` 用于 UI 展示 |
| 服装解锁 | 依赖本系统 | 使用 `get_item_by_id(id)` 解析新解锁物品的名称、类目、缩略图、标签和 `unlock_day`；新解锁差集由进度管理计算，本系统只提供静态展示数据 |
| 拖拽换装 | 间接依赖（通过精灵分层渲染 + 衣橱 UI） | 不直接调用本系统 API，通过中间层获取物品数据 |

本系统不依赖任何其他系统——服装数据库是 Foundation 层，零外部依赖。它依赖以下 Godot 内置 API：

| API | 用途 |
|-----|------|
| `FileAccess` | 打开并读取 `wardrobe.json` 文件内容为字符串，通过 `open()` + null 检查区分"文件不存在"和"空文件" |
| `JSON`（实例方法 `new().parse()`） | 解析 JSON 字符串并返回行号级错误信息 |

> **实现注意**：必须使用 `JSON.new().parse(text)` 实例方法而非 `JSON.parse_string(text)` 静态方法——后者不提供错误行号，无法满足 AC-10 的行号报告需求。

## Tuning Knobs

| 参数 | 当前值 | 安全范围 | 增大效果 | 减小效果 |
|------|--------|----------|----------|----------|
| `categories` 数量 | 6 | 3–10 | 更多搭配维度，但增加 UI 复杂度和 Z 层管理负担 | 更简单的换装体验，但限制搭配自由度 |
| `items` 数量 | ~30（MVP） | 5–200 | 更多搭配选择 → 更高重玩价值，但 JSON 文件增大、衣橱 UI 需适配 | 更快的加载速度，更简洁的衣橱，但搭配多样性降低 |
| `z_index_default` | 1–6（每类目一个值） | 1–10 | 高值类目渲染在上层。调整可改变类目间的覆盖关系 | 同上，反向 |
| `z_index_override` | null（~28/30 物品） | null 或 1–10 | 特定物品覆盖默认层序，解决特殊遮挡需求 | 物品使用类目默认值 |
| `unlock_day` | 1–7（MVP），首日 6-8 件，之后每天 3-4 件 | 1–365 | 物品解锁更晚 → 更慢的进度节奏，延长内容消耗周期 | 物品解锁更早 → 更快的满足感，适合短周期体验 |
| `tags` 数组长度 | 1–3（MVP） | 0–6 | 更细粒度的风格标签，支持更精准的筛选 | 更粗的分类粒度，筛选能力降低 |
| `name_max_length` | 8 | 4–16 | 允许更长的物品名称，UI 需要适配更宽文本 | 更短的名称，更具约束性。低于 4 对中文不实用 |
| `sort_order` | 0–N（每类目内连续） | 0–999 | 同类目中排序靠后，UI 中显示靠后 | 排序靠前，UI 中优先展示 |

所有旋钮都在 JSON 文件中修改，不需要改代码。设计师可以直接编辑 `wardrobe.json`，重启游戏即可看到效果。

## Acceptance Criteria

- [ ] **AC-1a**: `wardrobe.json` 被成功解析，`WardrobeDatabase.is_ready == true`，`load_error == ""`
- [ ] **AC-1b**: `get_all_items()` 返回非空数组，每件物品均包含全部必填字段：`id`、`name`、`sort_order`、`texture_path`、`thumbnail_path`、`category`、`unlock_day`、`tags`、`z_index_override`。以具体物品验证：`get_item_by_id("top_white_tee")["id"] == "top_white_tee"`，`["name"] == "白色T恤"`，`["category"] == "top"`，`["sort_order"] == 0`，`["tags"]` 为数组
- [ ] **AC-1c**: `get_categories()` 返回的类目键集合为 `{"makeup", "bottom", "shoes", "top", "accessory", "hair"}`，每个类目的 `label` 和 `z_index_default` 与 JSON 定义一致
- [ ] **AC-2**: `get_item_by_id("nonexistent_id")` 返回 `null`，不触发任何副作用
- [ ] **AC-3**: `get_items_by_category("hair")` 返回的所有元素 `category == "hair"`，且按 `sort_order` 升序排列。返回的集合与 `get_all_items()` 按 `category == "hair"` 过滤后的集合完全一致（无遗漏，无多余）
- [ ] **AC-4**: `get_unlocked_items(1)` 返回所有 `unlock_day == 1` 的物品，不包含任何 `unlock_day > 1` 的物品。精确数量由内容决定，独立于本 AC 验证
- [ ] **AC-5**: `get_unlocked_items(3)` 仅包含 `unlock_day <= 3` 的物品，不包含 `unlock_day = 6` 的物品。`get_unlocked_items(6)` 包含 `unlock_day = 6` 的物品（验证 `<=` 的 inclusive 边界）
- [ ] **AC-6**: `get_z_index(get_item_by_id("accessory_scarf_front"))` 返回 `7`（override）；`get_z_index(get_item_by_id("top_white_tee"))` 返回 `4`（类目默认）；`get_z_index` 对 `z_index_override = 0` 的物品返回 `1`（clamp 下限），对 `z_index_override = 15` 的物品返回 `10`（clamp 上限）。超出范围时通过 `push_warning()` 输出警告
- [ ] **AC-7**: 包含重复 `id` 的 JSON 触发加载失败，`load_error` 包含两个冲突物品的名称
- [ ] **AC-8**: 包含无效 `category`（如 `"hat"`）的 JSON 触发加载失败，`load_error` 包含物品 id 和无效值
- [ ] **AC-9**: 缺少必填字段（id / name / texture_path）的 JSON 触发加载失败，`load_error` 包含物品索引和缺失字段名
- [ ] **AC-10**: 格式错误的 JSON 触发加载失败，`load_error` 包含行号
- [ ] **AC-11a**: `get_item_by_id()` 和 `get_z_index()` 查询时间不随物品数量增长（O(1)）。测试方法：分别对 30 件和 200 件数据集各调用 100 次，平均耗时差异 <2x
- [ ] **AC-11b**: 修改任意查询方法返回的 Dict/Array（如修改 `get_item_by_id("top_white_tee")["name"]` 的返回值），不影响数据库内部状态。再次调用相同查询返回原始未修改数据。此条验证深拷贝行为——是 GDD 的核心设计保证
- [ ] **AC-11c**: `get_all_items()` 对 30 件物品连续调用 50 次，总耗时不超过一帧预算（<16ms）
- [ ] **AC-12**: `wardrobe.json` 文件大小 <10KB（30 件物品的标准数据集）
- [ ] **AC-13**: `wardrobe.json` 文件不存在时（删除或移动 `res://assets/data/wardrobe.json`），`WardrobeDatabase.is_ready == false`，`load_error` 包含字符串 `"res://assets/data/wardrobe.json"`
- [ ] **AC-14**: `items` 数组为空时，`is_ready == true`，所有查询方法返回空结果（`get_all_items()` 返回 `[]`，`get_item_by_id(any)` 返回 `null`），不触发错误
- [ ] **AC-15**: `get_items_by_category("nonexistent_category")` 返回空数组，不产生错误
- [ ] **AC-16**: `get_unlocked_items(0)` 返回空数组（所有物品的 `unlock_day >= 1`，`is_unlocked` 公式对 day=0 返回 `false`），不产生错误
- [ ] **AC-17**: 类目键大小写不一致（JSON 中 item 写 `"Top"` 而 categories 定义的是 `"top"`）触发加载失败，`load_error` 包含无效 category 值
- [ ] **AC-18**: `tags` 数组为空的物品正常加载，`get_item_by_id(id)["tags"]` 返回 `[]`
- [ ] **AC-19**: `get_z_index()` 对采样边界值返回结果始终在 1–10 范围内。测试值：`z_index_override = -999 → 1`, `-1 → 1`, `0 → 1`, `1 → 1`, `10 → 10`, `11 → 10`, `999 → 10`。另选取 10 个随机值在 [-999, 999] 范围内验证输出均在 [1, 10]。若实现使用 `clamp(raw, 1, 10)`，边界测试足以证明正确性
- [ ] **AC-20**: JSON 中包含 schema 未定义的额外字段时，通过 `push_warning()` 打印警告（含物品 id 和未知字段名），加载继续，额外字段被忽略。验证方法：在测试 JSON 的物品中添加 `"texturepath": "wrong.png"`（拼写错误），断言加载成功但日志/控制台输出包含对该字段的警告
- [ ] **AC-21**: `id` 前缀与 `category` 字段不一致（如 `id: "top_white_tee"` 但 `category: "hair"`）触发加载失败，`load_error` 包含物品 id 和冲突的两个值
- [ ] **AC-22**: `name` 超过 8 个字符触发加载失败，`load_error` 包含物品 id 和实际字符长度
- [ ] **AC-23**: `sort_order` 在同类目内重复时，打印 `push_warning()` 警告，加载继续。`get_items_by_category(cat)` 对相同 `sort_order` 的物品按 `id` 字母序作为二级排序键，保证输出确定性
- [ ] **AC-24**: `tags` 包含未定义的枚举值（如 `"street"`）时，打印 `push_warning()` 警告（含物品 id 和无效标签），跳过无效标签，加载继续
- [ ] **AC-25**: `get_items_by_tag("cute")` 返回所有 `tags` 数组中包含 `"cute"` 的物品，不包含没有 `"cute"` 标签的物品
- [ ] **AC-26**: 未初始化状态下（`is_ready == false`）调用所有七个查询方法返回安全空值，不触发错误或崩溃：`get_all_items()` → `[]`，`get_item_by_id(any)` → `null`，`get_items_by_category(any)` → `[]`，`get_items_by_tag(any)` → `[]`，`get_unlocked_items(any)` → `[]`，`get_categories()` → `{}`，`get_z_index(any)` → `1`（安全默认值）
- [ ] **AC-27a**: 非整数 `unlock_day`（如 `2.5` 或 `"2"`）触发加载失败，`load_error` 包含物品 id 和实际类型
- [ ] **AC-27b**: `unlock_day < 1`（如 `0` 或 `-3`）触发加载失败，`load_error` 包含物品 id 和实际值
- [ ] **AC-27c**: `unlock_day` 为 `null` 或字段缺失触发加载失败，`load_error` 包含物品 id，明确指出字段缺失
- [ ] **AC-27d**: `sort_order` 为非整数（如 `2.5` 或 `"0"`）触发加载失败，`load_error` 包含物品 id 和实际类型
- [ ] **AC-27e**: `tags` 为非数组（如 `"basic"` 字符串、`null`、或缺失）触发加载失败，`load_error` 包含物品 id 和实际类型
- [ ] **AC-27f**: `name` 为非字符串（如 `123`、`null`）或空字符串 `""` 触发加载失败，`load_error` 包含物品 id 和实际类型
- [ ] **AC-27g**: `texture_path` 为非字符串（如 `123`、`null`）或空字符串 `""` 触发加载失败，`load_error` 包含物品 id 和实际类型
- [ ] **AC-28**: `categories` 字典为空（`{}`）触发加载失败，`load_error` 包含描述信息，`is_ready == false`
- [ ] **AC-28a**: `categories` 中某个类目缺少 `z_index_default` 字段触发加载失败，`load_error` 包含该类目的键名
- [ ] **AC-29**: `tags` 全部为无效枚举值（如 `["street", "vintage"]`）时，打印 `push_warning()` 警告，物品以 `tags: []` 加载，加载继续（`is_ready == true`）
- [ ] **AC-30**: `get_items_by_tag("nonexistent_tag")` 返回空数组 `[]`，不产生错误
- [ ] **AC-31**: `sort_order` 为负数（如 `-1`）触发加载失败，`load_error` 包含物品 id 和实际值（字段定义要求 `≥0`）
- [ ] **AC-32**: `name` 字段边界测试——恰好 8 个字符通过加载（如 `"八八八八八八八"`），9 个字符触发加载失败
- [ ] **AC-33**: `get_all_items()` 返回的物品按类目分组——类目间按 `z_index_default` 升序排列（底层→顶层），同类目内按 `sort_order` 升序 + `id` 字母序排列。顺序是确定性的——连续两次调用返回完全相同的顺序

## Open Questions

| 问题 | 负责人 | 截止 | 决议 |
|------|--------|------|------|
| `tags` 的具体标签体系是什么？需要枚举值还是一个自由文本数组？ | 游戏设计师 | 内容填充前 | **已决议**：使用 6 个风格枚举标签——`basic`, `cute`, `cool`, `elegant`, `sports`, `cozy`。无效标签值在加载时打印警告并跳过。季节/场景属性（如 summer/winter）由每日场景系统管理，不从服装标签中获取 |
| 是否需要 `name_i18n` 字段预留多语言支持？ | 技术总监 | MVP 后 | MVP 仅中文，schema 可后续扩展 `name_i18n: { zh: "...", en: "..." }` |
| MVP 的 30 件物品按什么比例分配到 6 个类目和 7 天？ | 游戏设计师 | 内容填充前 | **已决议**：首日每类目 1-2 件（共 6-8 件初始物品），之后每天解锁 3-4 件，强化"每日期待"的陪伴感。第 7 天全解锁 |
