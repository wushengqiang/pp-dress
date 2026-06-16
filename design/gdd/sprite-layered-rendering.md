# 精灵分层渲染 (Sprite Layered Rendering)

> **Status**: In Design
> **Author**: user + Claude Code Game Studios
> **Last Updated**: 2026-06-09
> **Implements Pillar**: 即时有感, 随心搭配

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `WardrobeDatabase`, `TextureCache`

## Overview

精灵分层渲染是角色穿搭的视觉终点。玩家从衣橱拖出一件上衣放到角色身上——这个动作最终落到这个系统：一个 `Sprite2D` 节点换掉它的纹理，角色的外观瞬间改变。系统维护 6 个精灵层（妆容→下装→鞋子→上装→配饰→发型），按 z_index 自底向上叠放，每层对应服装数据库中的一个类目槽位。换装就是找到对应类目的 Sprite2D，把 `texture` 替换成新物品的全尺寸纹理；在热缓存命中时，渲染器必须在同一帧发出变更信号并让下游能确认视觉已应用。

该系统也是「即时有感」支柱在视觉层的最终实现。资源加载器保证纹理在需要时已就绪，精灵分层渲染保证纹理一就绪就能显示。它本身不产生游戏行为——不处理拖拽、不管理库存——它只做一件事：在正确的渲染层级显示正确的服装纹理。

## Player Fantasy

精灵分层渲染没有独立的玩家幻想——玩家不会说"这个游戏的精灵层叠算法真棒"。但它支撑的体验是玩家直接感受到的：

- **"换装瞬间上身"**：拖拽一件衣服到角色身上，视觉变化在一帧之内完成——没有闪烁、没有空白、没有"先显示旧纹理再切换"的过程。这种即时性让「即时有感」支柱成为可感知的现实。
- **"搭配看起来就是我想的那样"**：6 层精灵按照服装的自然遮挡关系（妆容在底层、发型在最上层）正确叠放。围巾搭在上衣外面、发型遮住配饰——视觉层次和现实直觉一致，玩家不需要思考"为什么这件衣服显示不对"。

简言之：这个系统不创造情感，但它消除视觉摩擦——而消除"看起来不对"的摩擦本身，就是「随心搭配」支柱在视觉层的实现。

## Detailed Design

### Core Rules

**架构**：角色精灵树是一个可复用的 Godot 场景（`character.tscn`），包含一个 `Node2D` 根节点（角色锚点）和 6 个 `Sprite2D` 子节点，按类目 z_index 叠放。管理脚本（`sprite_layered_renderer.gd`）挂载在根节点上，封装全部换装逻辑。该场景被 WARDROBE 和 DAILY_SCENE 实例化使用。

**节点树结构**：

```
Character (Node2D + sprite_layered_renderer.gd)
├── makeup_sprite (Sprite2D)      z_index = categories["makeup"].z_index_default
├── bottom_sprite (Sprite2D)      z_index = categories["bottom"].z_index_default
├── shoes_sprite (Sprite2D)       z_index = categories["shoes"].z_index_default
├── top_sprite (Sprite2D)         z_index = categories["top"].z_index_default
├── accessory_sprite (Sprite2D)   z_index = categories["accessory"].z_index_default
└── hair_sprite (Sprite2D)        z_index = categories["hair"].z_index_default
```

所有 6 个 Sprite2D 是同一父节点的直接子节点——满足 Godot `CanvasItem.z_index` 对同一画布分支内 CanvasItem 排序生效的约束。MVP 要求这些 Sprite2D 的 `top_level = false`、`z_as_relative = false`，父链不启用会改变同 z 排序预期的 Y-sort；若多个层最终 `z_index` 相同，按固定类目顺序（makeup → bottom → shoes → top → accessory → hair）和节点树中的同序排列作为 tie-break。

**Sprite2D 与资产对齐契约**：
- 6 个 Sprite2D 必须使用相同 `position`、`scale`、`offset`、`centered`、`region_enabled=false`、`flip_h=false`、`flip_v=false` 配置；不得在单个服装层上做位置微调来修补资产偏移。
- 所有 `FULL` 服装纹理必须使用同一透明画布尺寸（MVP：`1024x1536`）、同一角色锚点、同一脚底/身体基线和同一导入设置；透明边界允许存在，但角色身体在画布中的坐标必须一致。
- MVP 只支持“单件物品 = 单张 FULL 纹理 = 一个 Sprite2D 层”的资产。需要前后拆分、袖子绕手、头发前后夹层等复杂遮挡的物品，必须在后续 render parts 方案中设计；不得临时用多个 item_id 伪装成一件物品进入 MVP 数据。

**初始化流程**（`_ready()`）：

1. 检查 `WardrobeDatabase.is_ready`、`TextureCache.is_ready` 和 `EMPTY_SLOT_FULL` 可加载性 → 任一未就绪或缺失时，`push_error()` 后返回
2. 从 `WardrobeDatabase.get_categories()` 获取类目定义表
3. 使用 `get_node_or_null("{category}_sprite")` 检查 6 个 Sprite2D 直接子节点；任一缺失或类型不符时 `is_ready=false` 且不发 `renderer_ready`
4. 遍历 6 个类目，将每个 Sprite2D 的 `z_index` 设为类目 `z_index_default`（初始值——后续可被 override 覆写），并验证 Sprite2D 对齐契约
5. 将发布可用的空槽纹理或透明空纹理（`EMPTY_SLOT_FULL`）设置到所有 6 个 Sprite2D；开发调试占位图不得出现在发布体验的正常路径中
6. 初始化 `_equipped_items`、`_pending_target_by_category`、`_request_generation`、`_active_batch_token` 和 `_is_disposed`
7. 设置 `is_ready = true`
8. 发出 `renderer_ready` 信号。`renderer_ready` 表示 `WardrobeDatabase`、`TextureCache`、6 个 Sprite2D 节点、空槽纹理和基础层级配置全部可用于请求/渲染；它不表示任何穿搭纹理已经应用

`Character._ready()` **不得**读取 `GameState.context`，也不得自动调用 `apply_outfit()` 或 `equip_default_outfit()`。WARDROBE、DAILY_SCENE 或其他父场景负责决定要应用保存穿搭、默认穿搭还是空穿搭，并显式调用本系统 API。这样避免 Renderer 与场景编排器重复解释 `GameState.context`，也避免 Daily Scene 中同一批穿搭被应用两次。

**GameState 上下文语义（调用方契约）**：
- `GameState.context` 缺少 `equipped_items` 或值为 `null`：表示没有保存穿搭上下文，调用方按自身场景规则决定是否调用 `equip_default_outfit(day)`
- `GameState.context["equipped_items"] == []`：表示明确空穿搭，调用方若传给 `apply_outfit([])`，本系统必须清空并完成结算
- 非空数组：调用方负责验证为 `Array[String]` 后传给 `apply_outfit(item_ids)`；Renderer 不直接从 `GameState.context` 读取该值

**预装备逻辑**（`equip_default_outfit(day)`）：

1. 调用 `WardrobeDatabase.get_unlocked_items(day)` 获取当日已解锁物品
2. 按 `category` 分组
3. 每组内取 `sort_order` 最小的物品（每个类目 1 件）
4. 将选中的物品组成 `default_item_ids`
5. 调用 `apply_outfit(default_item_ids)`。因此默认穿搭继承 `apply_outfit()` 的全部批次语义：同类目归一化、失败也完成 pending 结算、最终发出 `outfit_applied(applied_item_ids)`

**API 接口**：

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `equip_item(item_id)` | String | void | 装备单件物品。同类别旧物品被替换。异步——不阻塞等待纹理加载 |
| `unequip_category(category)` | String | void | 卸下指定类目，精灵恢复为空槽纹理 |
| `apply_outfit(item_ids)` | Array[String] | void | 批量装备完整穿搭。不在最终目标集合中的类目被卸下。每个目标请求无论成功或失败都完成结算后发出 `outfit_applied` |
| `get_equipped_items()` | — | Array[String] | 当前穿搭的物品 ID 列表，按当前 Sprite2D effective z_index 从底层到顶层排序；同 z 时按固定类目顺序 |
| `get_equipped_item_for_category(category)` | String | String\|null | 某类目当前装备的物品 ID；空槽位返回 null |
| `equip_default_outfit(day)` | int | void | 从当日解锁物品中为每个类目自动选第一件装备 |
| `clear_outfit()` | — | void | 卸下全部，所有精灵恢复为空槽纹理 |

**属性**：

| 属性 | 类型 | 说明 |
|------|------|------|
| `is_ready` | bool | 初始化完成后设为 true |

> **GDScript 类型说明**：文档中的 `String|null` 是设计语义。Godot 4.6 GDScript 实现中，nullable 返回值/信号参数应使用 `Variant`、项目约定 sentinel，或其他已批准的 nullable 表达方式；不要直接把 `String|null` 写成 GDScript 类型。

**信号**：

| 信号 | 参数 | 说明 |
|------|------|------|
| `renderer_ready` | — | 初始化完成，精灵树已就绪；不代表穿搭纹理已全部显示。不得复用 Godot `Node.ready` 作为自定义语义 |
| `outfit_changed(category, old_item_id, new_item_id)` | String, Variant, Variant | 单个槽位变更（old_item_id 或 new_item_id 可为 null；GDScript 实现中使用 nullable `Variant` 或项目约定 sentinel 表达空装备） |
| `equip_item_completed(item_id, category, status, equipped_items)` | String, Variant, String, Array[String] | 单件装备请求完成或被拒绝。`status` 固定为 `"equipped"`、`"same_item"`、`"invalid_item"`、`"invalid_category"`、`"texture_failed"`、`"renderer_not_ready"`、`"cancelled_stale"` 之一；`category` 可为 null |
| `outfit_applied(applied_item_ids)` | Array[String] | 批量穿搭应用完成。参数为批次结算后的当前最终穿搭列表，即 `get_equipped_items()` 的快照；加载失败的目标若未改变当前状态则不会新增到列表中，旧装备若被保留则仍会出现在列表中 |

**请求失效与完成信号规则**：
- 每个会修改穿搭的公开 API（`equip_item()`、`apply_outfit()`、`unequip_category()`、`clear_outfit()`、`equip_default_outfit()`）在开始时递增 `_request_generation`；每个新 `apply_outfit()`、`clear_outfit()` 和 `equip_default_outfit()` 同时递增 `_active_batch_token`。
- `equip_item()` 会使同类目的旧 pending 失效，并使当前批次 token 失效，避免单件换装与批量恢复交叉提交。
- `unequip_category(category)` 会使该类目的 pending 失效；`clear_outfit()` 会使全部 pending 和当前 batch 失效。
- 本系统不得因为实例级取消而调用 `TextureCache.cancel_request()` 取消共享纹理请求；TextureCache 的取消会通知所有等待方 `callback(null)`，可能影响其他 `Character` 实例。实例生命周期取消一律通过本地 generation/token 丢弃迟到回调。
- `equip_item_completed` 必须覆盖当前 active 单件请求的成功、no-op、输入拒绝、纹理失败、未就绪和主动取消路径；拖拽换装不得再把“没有 `outfit_changed`”当作主要失败判定。若旧请求已被后续公开 API 覆盖，其迟到回调只做本地丢弃，不再向旧请求发 `cancelled_stale`，调用方通过自身 pending token 忽略过期等待。

**`equip_item()` 详细流程**：

1. 若 `is_ready == false`，`push_warning()`，发出 `equip_item_completed(item_id, null, "renderer_not_ready", get_equipped_items())` 后返回
2. 从 `WardrobeDatabase.get_item_by_id(item_id)` 获取物品数据 → 若 null，`push_warning()`，发出 `equip_item_completed(item_id, null, "invalid_item", get_equipped_items())` 后返回
3. 提取 `category = item["category"]`；若不是 MVP 类目集合成员，发出 `equip_item_completed(item_id, category, "invalid_category", get_equipped_items())` 后返回
4. 找到对应 Sprite2D 节点（按命名约定 `{category}_sprite`）
5. 若 `_equipped_items[category] == item_id`，无操作并发出 `equip_item_completed(item_id, category, "same_item", get_equipped_items())`；不重复加载、不发 `outfit_changed`
6. 解析 `effective_z = WardrobeDatabase.get_z_index(item)`，但**不立即写入** Sprite2D
7. 递增实例级 `_request_generation` 和 `_active_batch_token`，并将 `_pending_target_by_category[category] = { item_id, generation }` 写入。此步骤必须发生在任何纹理请求之前，因为 `TextureCache` 的 Hot/Warm 路径可能同步回调
8. 旧 `item_id`（若存在）记录用于信号参数
9. 调用 `TextureCache.get_texture_or_request(item_id, FULL, Callable(_on_single_texture_ready).bind(category, item_id, effective_z, old_item_id, generation))`。回调上下文必须绑定 `category`、`item_id`、`effective_z`、`old_item_id` 和 `generation`，不得在回调中重新猜测当前请求
10. 在 `_on_single_texture_ready(texture, category, item_id, effective_z, old_item_id, generation)` 回调中，先检查：
   - `is_inside_tree() == true`
   - `is_queued_for_deletion() == false`
   - `_is_disposed == false`
   - `_pending_target_by_category[category].generation == generation`
   - `_pending_target_by_category[category].item_id == item_id`
11. 若任一检查失败，静默丢弃结果，不修改 texture、不发 `outfit_changed`。只有调用方显式取消当前 active 单件请求且仍需要结果收口时，才发出 `equip_item_completed(item_id, category, "cancelled_stale", get_equipped_items())`；被后续 API 覆盖的旧请求不发完成信号
12. 若 texture 为 null（加载失败、TextureCache 未就绪、evict 或共享请求取消），清除该 category 的 pending target；保持旧 texture、旧 `z_index` 和 `_equipped_items` 不变；不发 `outfit_changed`，发出 `equip_item_completed(item_id, category, "texture_failed", get_equipped_items())`
13. 若 texture 有效，原子提交：`sprite.texture = texture`、`sprite.z_index = effective_z`、`_equipped_items[category] = item_id`、清除 pending target，发出 `outfit_changed(category, old_item_id, item_id)`，再发出 `equip_item_completed(item_id, category, "equipped", get_equipped_items())`

**`apply_outfit()` 详细流程**：

1. 按输入顺序解析 `item_ids`，通过 `WardrobeDatabase.get_item_by_id(item_id)` 取得每件物品的 `category`
2. 构建最终目标集合 `target_by_category`。若同一类目出现多个 item_id，后出现的 item_id 覆盖先出现的 item_id；无效 item_id 记录 warning 并跳过
3. 递增 `_active_batch_token`，创建 batch state：`pending_count`、`settled_count`、`target_by_category`、`batch_token`、`cancelled=false`。新 batch 开始后，旧 batch 的迟到回调不得修改 texture、不得发 `outfit_applied`
4. 遍历全部 6 个类目，不在 `target_by_category` 中的调用内部卸下方法 `_unequip_category_for_batch(category, batch_token)`：恢复空槽纹理、恢复类目默认 `z_index`、移除 `_equipped_items[category]`，若原本有装备则发出 `outfit_changed(category, old_id, null)`
5. 若归一化后的 `target_by_category` 为空（输入为空、全部无效、或无可用默认物品），立即完成结算并发出 `outfit_applied([])`；该行为必须同步或在同一 idle tick 内完成，不得等待超时
6. 在发起任何纹理请求前，为所有最终目标 category 写入 `_pending_target_by_category[category] = { item_id, generation, batch_token }`，并设置 `pending_count`
7. 按固定类目顺序（makeup → bottom → shoes → top → accessory → hair）遍历最终目标，依次调用 `TextureCache.get_texture_or_request(item_id, FULL, Callable(_on_batch_texture_ready).bind(category, item_id, effective_z, old_item_id, generation, batch_token))`
8. 每个目标请求的回调都必须完成一次批次结算：若 token/generation 仍有效且 texture 有效，则原子提交 `texture + z_index + _equipped_items` 并发出 `outfit_changed`；若 texture 为 null 或 token 已过期，则不修改视觉状态。两种路径都必须推进 `settled_count/pending_count`，但不得把“成功列表”作为最终信号来源
9. 当当前 batch 的 `pending_count` 归零且 `batch_token == _active_batch_token`、`_is_disposed == false` 时，发出 `outfit_applied(get_equipped_items())`。该参数是批次结算后的当前最终穿搭快照，不是“本批次成功请求列表”

> **批次完成保证**：`apply_outfit()` 不得因为纹理加载失败、无效 item_id、同类目重复输入、空数组、全部无效输入、场景仍在树中但个别纹理缺失或旧批次迟到而永久挂起。每日场景可以有自己的超时兜底，但本系统必须在可判定完成时主动发出当前 batch 的 `outfit_applied`。过期 batch 不得发出 stale `outfit_applied`。

> **退出树保护**：`_exit_tree()` 必须设置 `_is_disposed = true`，递增 `_request_generation` 和 `_active_batch_token` 以废弃所有未完成回调，并清空本实例 pending 记录。不得调用共享的 `TextureCache.cancel_request()` 来取消实例级请求。任何迟到回调都必须同时检查 `is_inside_tree()`、`is_queued_for_deletion()`、`_is_disposed` 和 token/generation；`_exit_tree()` 后不得发出 stale `outfit_changed`、`equip_item_completed` 或 `outfit_applied`。

**拖拽换装交互约定**：

拖拽换装系统通过 `equip_item()` 与本系统交互——不直接操作精灵节点：
- 玩家从衣橱拖拽某物品到角色上 → 拖拽换装系统调用 `sprite_layered_renderer.equip_item(item_id)`
- 拖拽换装系统连接 `equip_item_completed` 作为装备结果真相源；仅当结果为 `"equipped"` 且有对应 `outfit_changed` 时，才播放成功换装反馈（粒子/音效）
- 本系统不关心拖拽的起始/结束坐标——那是输入管理的职责

### States and Transitions

精灵分层渲染本身无复杂玩法状态机，但有明确的异步请求状态。穿搭状态即 `_equipped_items: Dictionary[String, String]`（category → item_id），加载中目标由 `_pending_target_by_category` 与 batch/generation token 保护。状态变更由外部方法调用驱动：

```
START ──_ready()──→ READY
                      │
                      ├── equip_item(id) ──→ token登记 → 纹理就绪/失败 → 原子提交或保留旧状态 → equip_item_completed
                      ├── apply_outfit(ids) ──→ batch登记 → 批次全部结算 → outfit_applied
                      ├── unequip_category(cat) ──→ 精灵→empty slot
                      ├── equip_default_outfit(day) ──→ apply_outfit(default_item_ids)
                      └── clear_outfit() ──→ 全部→empty slot + outfit_applied([])
```

- `equip_item_completed` → 拖拽换装系统确认装备结果
- `outfit_changed` → 仅在成功装备或卸下时提供视觉/音频反馈触发点
- `outfit_applied` → 每日场景得知角色穿搭已就绪，可开始叙事

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|---------|
| 服装数据库 | 本系统依赖 | `get_item_by_id(id)` 获取物品数据；`get_z_index(item)` 解析渲染层序；`get_categories()` 获取类目定义；`get_unlocked_items(day)` 用于预装备 |
| 资源加载器 | 本系统依赖 | `get_texture_or_request(id, FULL, callback)` 获取全尺寸纹理；Hot/Warm 命中可能同步回调，因此本系统必须先登记 token/pending 再请求 |
| 场景/状态管理 | 间接 | 本系统不读取 `GameState.context`；WARDROBE、DAILY_SCENE 或衣橱 UI 读取 context 后显式调用 `apply_outfit()` / `equip_default_outfit()` / `clear_outfit()`；衣橱 UI 确认穿搭时从本系统 `get_equipped_items()` 写入 `GameState.context["equipped_items"]` |
| 拖拽换装 | 依赖本系统 | 调用 `equip_item(id)` 执行换装；监听 `equip_item_completed` 作为装备结果真相源，监听 `outfit_changed` 只用于成功视觉/音效反馈 |
| 每日场景 | 依赖本系统 | 实例化 Character 后等待 `renderer_ready`，再按自身场景规则显式调用 `apply_outfit()` 或 `equip_default_outfit()`；连接 `outfit_applied(applied_item_ids)` 等待角色视觉批次结算 |

## Formulas

### 精灵节点映射

```
sprite_node_name = category + "_sprite"
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `category` | String | `{"makeup", "bottom", "shoes", "top", "accessory", "hair"}` | 类目键 |

**示例**：`category = "top"` → 节点路径 `"top_sprite"`

**输出范围**：必须解析到当前 `Character` 场景的直接子节点；节点缺失时 `_ready()` 失败并保持 `is_ready == false`。实现应使用 `get_node_or_null()` 以便输出包含缺失节点名的错误。

### Z-Index 解析（引用）

本系统使用服装数据库定义的 z_index 解析公式：

```
effective_z = clamp(item.z_index_override ?? categories[item.category].z_index_default, 1, 10)
```

（完整变量定义和边界行为见 `design/gdd/wardrobe-database.md` Formulas 节）

每次 `equip_item()` 或 `apply_outfit()` 成功应用纹理时，将解析出的 `effective_z` 与新 texture 同一回调中原子写入对应 Sprite2D 的 `z_index` 属性——处理 `z_index_override` 物品（如围巾覆写为 7）。纹理加载失败时不得提前写入或保留新 `z_index`。

`1..10` 是项目数据约束，不是 Godot 引擎限制。Godot 实现仍使用 `CanvasItem.z_index` 的实际 API 范围；本项目通过数据库 clamp 保持服装层级可控。

### 默认穿搭选择

```
default_item_per_category = argmin(sort_order) for item in get_unlocked_items(day) where item.category == target_category
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `sort_order` | int | ≥0 | 物品排序权重 |
| `day` | int | ≥1 | 当前天数 |
| `target_category` | String | 有效类目键 | 当前处理的类目 |

**平局规则**：若同类目内 `sort_order` 相同，取 `id` 字母序靠前的物品（与服装数据库 `get_items_by_category()` 的排序一致）。

**示例**（day=1）：
- `top` 类目解锁 2 件：`top_white_tee`（sort_order=0）、`top_striped`（sort_order=1）→ 选 `top_white_tee`
- `makeup` 类目解锁 1 件：`makeup_natural`（sort_order=0）→ 选 `makeup_natural`

### 纹理加载延迟

| 路径 | 延迟上限 | 机制 |
|------|---------|------|
| 热缓存命中（texture 已在 Hot） | <1ms | `get_texture_or_request` 同步回调——同一帧内完成 |
| 暖缓存命中（texture 在 Warm） | <5ms | 回调同步执行（从 Warm 提升到 Hot，无 I/O） |
| 冷缓存（需异步加载） | 不作为即时换装硬承诺 | `get_texture_or_request` 在异步加载完成后回调；Web 端实际耗时受线程、PNG 解码和 GPU upload 影响 |

热缓存命中时，`equip_item()` 调用 → `outfit_changed` 与 `equip_item_completed(..., "equipped", ...)` 发出必须在同一帧内完成，满足「即时有感」的交互时序约束。冷缓存路径由资源加载器和调用方预热策略保障；若冷纹理未就绪，下游不得提前播放“成功装备”反馈。

## Edge Cases

| # | 场景 | 预期行为 | 理由 |
|---|------|----------|------|
| 1 | `equip_item(id)` 传入不存在的 item_id | `WardrobeDatabase.get_item_by_id()` 返回 null → `push_warning()` 输出无效 id，操作被忽略，并发出 `equip_item_completed(id, null, "invalid_item", get_equipped_items())` | 无效 id 由数据库层判定，但公开请求必须有确定结果 |
| 2 | `is_ready == false` 时调用任一修改 API（`equip_item()` / `apply_outfit()` / `unequip_category()` / `clear_outfit()` / `equip_default_outfit()`） | `equip_item()` 发出 `equip_item_completed(item_id, null, "renderer_not_ready", get_equipped_items())`；`apply_outfit()` 和 `equip_default_outfit()` 必须发出 `outfit_applied([])`；其他修改 API `push_warning()` 后忽略 | 未初始化时精灵节点可能不存在；公开调用不能悬挂 |
| 3 | 同一类目快速连续 `equip_item()`（如玩家狂点两件上衣） | 第二次调用写入新的 generation 和 pending target；旧回调 token 不匹配时静默丢弃。最终只允许最新 item 原子提交 texture、z_index 和 `_equipped_items` | 防止旧纹理覆盖新选择 |
| 4 | `z_index_override=7` 的配饰与 `z_index_default=6` 的发型竞争 | 配饰 `z_index=7` > 发型 `z_index=6` → 配饰渲染在发型之上。该物品必须通过 override 截图矩阵验证后才能进入发布内容 | z_index_override 是资产级例外，必须验证视觉结果而不只是数值 |
| 5 | 全部纹理加载失败（如网络断开） | 单件 `equip_item()` 失败时保持旧 texture、旧 z_index 和旧 `_equipped_items` 不变，并发出 `equip_item_completed(..., "texture_failed", get_equipped_items())`；`apply_outfit()` 批次中每个失败项仍完成 pending 结算，最终发出当前 `get_equipped_items()` 快照 | 不应阻止游戏运行，也不应显示半应用状态 |
| 6 | 纹理在场景切换或节点销毁后完成加载（延迟回调） | 回调同时检查 `is_inside_tree()`、`is_queued_for_deletion()`、`_is_disposed` 和 token/generation；任一失败则静默丢弃结果，不设 texture，不发 `outfit_changed`、`equip_item_completed` 或 `outfit_applied` | 节点可能已被替换或正在释放，旧回调无意义 |
| 7 | `equip_default_outfit(day)` 中 `day=0` 或无效值 | `WardrobeDatabase.get_unlocked_items(0)` 返回空数组 → 所有类目保持空槽纹理。对 day>7 的行为由 `get_unlocked_items()` 决定——它按 `unlock_day <= day` 筛选，超出内容窗口自然返回所有物品 | 空结果是合法状态——服装数据库已定义此行为 |
| 8 | `apply_outfit([])` 空数组 | 等同于 `clear_outfit()`——卸下全部，恢复空槽纹理和类目默认 z_index，并立即或同 idle tick 发出 `outfit_applied([])` | 空穿搭是合法、明确的穿搭状态 |
| 9 | `Character` 场景在 `WardrobeDatabase.is_ready == false` 时实例化 | `_ready()` 中输出 `push_error()`，`is_ready` 保持 false，全部精灵为 null texture。后续任何 API 调用按 #2 处理 | 启动顺序错误——应通过 Autoload 顺序保证 |
| 10 | 同一 item_id 被 `equip_item()` 两次（已在装备中） | 检测 `_equipped_items[category] == item_id` → 无操作（不重复加载、不发 `outfit_changed`），并发出 `equip_item_completed(item_id, category, "same_item", get_equipped_items())` | 幂等且结果明确——避免不必要的纹理重载，也避免拖拽换装靠超时判断 no-op |
| 11 | `equip_default_outfit()` 时某类目无已解锁物品 | 该类目保持空槽纹理；若所有类目均无默认物品，则 `apply_outfit([])` 并发出 `outfit_applied([])`。首日 MVP 目标是每个可见类目至少有 1 件可渲染默认物品，除非该类目的空槽视觉是自然透明 | 运行时允许空结果，但首日发布体验不应暴露技术占位 |
| 12 | `apply_outfit()` 含同类目多个物品（如 `["top_a", "top_b"]`） | 在发起纹理请求前按类目归一化目标集合，后者覆盖前者。仅对最终目标 `top_b` 发起装备请求；批次结束时 `outfit_applied` 返回 `get_equipped_items()` 的最终快照 | 批量穿搭需要确定性结果，避免早期请求参与 pending 计数或异步回调语义 |
| 13 | 精灵子节点缺失（`.tscn` 文件损坏或手动删除） | `_ready()` 中 `get_node_or_null("{category}_sprite")` 返回 null → `push_error()` 含缺失节点名，`is_ready = false`，`renderer_ready` 不发出 | 场景结构损坏是致命错误——不能带着缺失图层继续运行 |
| 14 | 同一场景中有多个 `Character` 实例 | 每个实例有自己的 `_equipped_items` 字典和信号总线——互不干扰。但多个实例会向 `TextureCache` 请求相同纹理——由 `TextureCache` 的去重逻辑处理 | 例如 DAILY_SCENE 中可能需要镜中倒影 |
| 15 | `get_equipped_items()` 在空穿搭（全空槽）时调用 | 返回空数组 `[]` | 空数组明确区分"无装备"和"null/错误" |
| 16 | `equip_item()` 的纹理加载成功但精灵已被 `unequip_category()` / `clear_outfit()` / 新 batch 覆盖 | 回调 token/generation 不匹配，丢弃结果 | 后续卸下或新批次应压倒并发加载结果 |
| 17 | `apply_outfit(["nonexistent_id"])` 或全无效输入 | 所有无效 id 输出 warning；归一化目标为空，按 `apply_outfit([])` 结算并发出 `outfit_applied([])` | 无效输入不能永久挂起 Daily Scene |
| 18 | `apply_outfit(["top_good", "bottom_missing"])` 部分成功、部分失败 | 成功项原子提交并发 `outfit_changed`；失败项保持旧状态不变；批次归零时发出 `outfit_applied(get_equipped_items())`。若新实例此前为空，结果通常为 `["top_good"]`；若旧 bottom 有效保留，结果仍包含旧 bottom | 批次信号反映最终当前穿搭，失败项不污染状态 |
| 19 | 新 `apply_outfit()` 在旧 batch 未完成时开始 | 新 batch 递增 `_active_batch_token`；旧 batch 迟到回调只结算内部记录，不改 texture、不发 stale `outfit_applied` | 防止旧批次覆盖新穿搭或让场景误判视觉就绪 |
| 20 | `TextureCache.get_texture_or_request()` 返回 `callback(null)`（not ready、invalid resolution、加载失败、evict 或共享 cancel） | 单件请求按 `"texture_failed"` 完成；批量请求结算该目标但不修改视觉状态。若该 null 来源于实例级过期请求，则只丢弃，不影响当前 active 请求 | TextureCache 的 null 是统一失败/取消通道，Renderer 必须用本地 token 解释它 |

## Dependencies

| 系统 | 方向 | 依赖性质 |
|------|------|----------|
| 服装数据库 | 本系统依赖 | 硬依赖。`get_item_by_id()` 获取物品数据；`get_categories()` 初始化精灵层；`get_z_index()` 解析渲染层序；`get_unlocked_items()` 预装备默认穿搭 |
| 资源加载器 | 本系统依赖 | 硬依赖。`get_texture_or_request(id, FULL, callback)` 是获取纹理的唯一入口——本系统不直接调用 `ResourceLoader`；Hot/Warm 命中可能同步回调 |
| 场景/状态管理 | 间接 | 本系统不直接读取 `GameState.context`；调用方负责解释 `equipped_items` 缺失/null/[] 并显式调用 Renderer API；衣橱 UI 在确认穿搭时从本系统 `get_equipped_items()` 写入 `GameState.context["equipped_items"]` |
| 拖拽换装 | 依赖本系统 | 调用 `equip_item()` 执行换装；监听 `equip_item_completed` 信号确认成功、no-op、失败和取消结果；`outfit_changed` 仅表示可播放成功反馈的视觉变更 |
| 每日场景 | 依赖本系统 | 等待 `renderer_ready` 后显式调用 `apply_outfit()` 或 `equip_default_outfit()`；连接 `outfit_applied(applied_item_ids)` 等待角色视觉批次结算 |

本系统依赖以下 Godot 内置 API：

| API | 用途 |
|-----|------|
| `Sprite2D.texture` | 设置/替换精灵纹理 |
| `Sprite2D.z_index` | 设置渲染层序（每装备一件物品时更新） |
| `Node.get_node_or_null(path)` | 按命名约定查找精灵子节点，并允许自定义错误输出 |
| `Node.is_inside_tree()` / `Node.is_queued_for_deletion()` | 场景切换与销毁回调保护 |

## Tuning Knobs

| 参数 | 当前值 | 安全范围 | 说明 |
|------|--------|----------|------|
| `EMPTY_SLOT_FULL_PATH` | `"res://assets/textures/ui/empty_slot_full.png"` | 有效透明/自然空槽 PNG 路径 | 未装备类目显示的发布可用空槽纹理；不得呈现 debug 占位感 |
| `DEBUG_PLACEHOLDER_FULL_PATH` | `"res://assets/textures/ui/placeholder_full.png"` | 有效 PNG 路径，仅 debug 构建或 QA 场景启用 | 资源缺失诊断用占位纹理；不得出现在发布体验正常路径 |
| `CHARACTER_SCENE_PATH` | `"res://src/character/character.tscn"` | 有效 `.tscn` 路径 | 角色场景文件位置 |

> **说明**：精灵分层渲染是薄封装层——核心可调参数（z_index 值、纹理尺寸、热缓存上限）均由依赖系统管理。本系统的调优空间仅限空槽纹理、debug 占位纹理和场景路径。MVP 的可渲染槽位固定为 6 个 Sprite2D；`WardrobeDatabase.get_categories()` 数据驱动这些槽位的 z/order，但新增或删除类目必须同步更新 `character.tscn`。

## Visual/Audio Requirements

精灵分层渲染的输出是纯视觉的——6 层精灵叠放组成的角色穿搭图像。但它不产生自己的视觉特效或音频。

| 事件 | 视觉反馈 | 音频反馈 | 优先级 |
|------|---------|---------|--------|
| 换装（`equip_item` 完成） | 单个精灵纹理替换——角色外观瞬间改变。无内置特效 | 无——由拖拽换装系统通过 `outfit_changed` 信号触发音效 | — |
| 批量穿搭就绪（`outfit_applied`） | 6 层精灵全部更新为当日穿搭——角色在场景中"完整出现" | 无——由每日场景在收到信号后触发入场动画/音效 | — |
| 纹理加载中 | 精灵保持旧纹理或空槽纹理——无视觉闪烁；下游不得提前播放成功反馈 | 无 | — |
| 纹理加载失败 | 精灵保持旧纹理、旧 z_index 和旧装备状态；空槽仍为空槽。发布体验不得显示 debug placeholder | 无 | — |

> 换装粒子特效、拖拽动画、音效均由下游系统（拖拽换装、音频管理）负责。本系统只提供视觉画布和变更信号。

**视觉验收要求**：
- 每个使用 `z_index_override` 的物品必须通过截图矩阵验证，覆盖可能遮挡它的发型、上衣、配饰等组合
- 发布构建的正常路径不得显示 `DEBUG_PLACEHOLDER_FULL_PATH`
- 首日默认穿搭应让每个可见 MVP 类目具备可渲染默认物品，除非该类目的空槽视觉被美术确认为自然透明且不会显得缺资源

## UI Requirements

精灵分层渲染不渲染任何 UI。角色精灵树是游戏世界对象，而非 UI 元素。角色在以下场景的画布区域中显示：

| 场景 | 角色显示区域 | 布局约束 |
|------|------------|---------|
| WARDROBE | 屏幕中央偏左（衣橱网格在右侧） | 角色需完整可见——6 层精灵的父节点定位在角色锚点。场景根节点的布局由衣橱 UI 系统管理 |
| DAILY_SCENE | 场景构图中角色位置 | 由每日场景的构图设计决定——角色精灵树作为子场景嵌入 |

> 角色锚点位置、缩放比例、画布边距由各场景的布局系统管理，不属于本系统职责。

## Acceptance Criteria

**初始化**

- [ ] AC-1：`Character` 场景 `_ready()` 后，`WardrobeDatabase.is_ready == true`、`TextureCache.is_ready == true`、`EMPTY_SLOT_FULL` 已加载，6 个 Sprite2D 子节点 z_index 与 `WardrobeDatabase.get_categories()` 中各类目 `z_index_default` 一致，所有精灵纹理为 `EMPTY_SLOT_FULL`，`is_ready == true`，`renderer_ready` 信号发出
- [ ] AC-2：`WardrobeDatabase.is_ready == false`、`TextureCache.is_ready == false` 或 `EMPTY_SLOT_FULL` 缺失时，`_ready()` 输出 `push_error()`，`is_ready` 保持 false，`renderer_ready` 信号不发出
- [ ] AC-3：`_ready()` 不读取 `GameState.context`，不调用 `apply_outfit()`，不调用 `equip_default_outfit()`；穿搭应用只能由父场景或调用方显式触发
- [ ] AC-3a：6 个 Sprite2D 的 `top_level=false`、`z_as_relative=false`、`region_enabled=false`、`position/scale/offset/centered` 配置一致，父链 `y_sort_enabled=false`；任一配置不符合时构建检查失败

**装备**

- [ ] AC-4：`equip_item("top_white_tee")` 在纹理加载成功后，`top_sprite.texture`、`top_sprite.z_index`、`_equipped_items["top"]` 在同一回调中原子更新，`outfit_changed("top", null, "top_white_tee")` 和 `equip_item_completed("top_white_tee", "top", "equipped", equipped_items)` 信号发出
- [ ] AC-5：`equip_item("top_striped")` 在同一类目已有 `top_white_tee` 时，成功回调后 `top_sprite.texture` 更新为 `top_striped` 纹理，`outfit_changed("top", "top_white_tee", "top_striped")` 发出
- [ ] AC-6：`equip_item("top_white_tee")` 当该物品已在装备中时，不重复加载，不发出 `outfit_changed`，并发出 `equip_item_completed("top_white_tee", "top", "same_item", equipped_items)`
- [ ] AC-7：`equip_item("nonexistent_id")` 输出 `push_warning()`，不修改任何精灵纹理，不发出 `outfit_changed`，并发出 `equip_item_completed("nonexistent_id", null, "invalid_item", equipped_items)`
- [ ] AC-8：`is_ready == false` 时 `equip_item(any)` 输出 `push_warning()` 并发出 `equip_item_completed(item_id, null, "renderer_not_ready", equipped_items)`；`unequip_category(any)`、`clear_outfit()` 输出 `push_warning()` 后忽略；`apply_outfit(any)` 和 `equip_default_outfit(day)` 输出 `push_warning()` 后发出 `outfit_applied([])`
- [ ] AC-9：`equip_item()` 对 override 物品如 `accessory_scarf_front` 成功后，对应 Sprite2D 的 `z_index` 为 `WardrobeDatabase.get_z_index(item)` 返回值；若纹理加载失败，旧 texture、旧 z_index 和旧 `_equipped_items` 全部保持不变

**卸下**

- [ ] AC-10：`unequip_category("top")` 后，`top_sprite.texture` 恢复为 `EMPTY_SLOT_FULL`，`top_sprite.z_index` 恢复类目默认值，`_equipped_items` 中移除 "top" 键，`outfit_changed("top", old_id, null)` 发出（若当前有装备）

**批量穿搭**

- [ ] AC-11：`apply_outfit(["top_white_tee", "bottom_jeans"])` 先创建 batch token 和所有 pending target，再发起任何纹理请求；成功项原子提交，不在最终目标集合中的其他类目被卸下。全部目标请求完成结算后 `outfit_applied(applied_item_ids)` 发出，参数等于当时 `get_equipped_items()` 的最终快照
- [ ] AC-12：`apply_outfit([])` 等同于 `clear_outfit()` ——全部精灵恢复 `EMPTY_SLOT_FULL` 和默认 z_index，`_equipped_items` 为空，并立即或同 idle tick 发出 `outfit_applied([])`
- [ ] AC-12a：`apply_outfit(["nonexistent_id"])` 或全部无效输入输出 warning，归一化目标为空，并按 AC-12 发出 `outfit_applied([])`
- [ ] AC-12b：新 `apply_outfit()` 在旧 batch 未完成时开始，旧 batch 的迟到回调不得修改 texture、不得发出 stale `outfit_applied`

**默认穿搭**

- [ ] AC-13：`equip_default_outfit(1)` 对当日有解锁物品的类目，每类目选择 `sort_order` 最小的物品；若 `sort_order` 相同，选择 `id` 字母序靠前者。随后调用 `apply_outfit(default_item_ids)`，默认穿搭完成后按 `apply_outfit()` 规则发出 `outfit_applied(applied_item_ids)`

**查询**

- [ ] AC-14：`get_equipped_items()` 返回当前装备的全部物品 ID 数组，顺序按当前 Sprite2D effective z_index 从底层到顶层排列；同 z 时按固定类目顺序；空穿搭返回 `[]`
- [ ] AC-15：`get_equipped_item_for_category("top")` 返回当前装备的上装 ID；空槽位返回 null
- [ ] AC-16：`clear_outfit()` 后 `get_equipped_items()` 返回 `[]`，所有精灵纹理为 `EMPTY_SLOT_FULL`，所有 z_index 恢复类目默认值

**信号**

- [ ] AC-17：`outfit_changed(category, old_id, new_id)` 参数值准确反映变更前后的物品 ID
- [ ] AC-18：`outfit_applied(applied_item_ids)` 在 `apply_outfit()` 的所有最终目标请求完成结算后发出。成功项已设置到对应精灵，失败项不发出 `outfit_changed`；`applied_item_ids` 等于结算后的 `get_equipped_items()` 快照，而不是仅本批次成功项列表
- [ ] AC-18a：`apply_outfit(["top_missing_texture"])` 的纹理加载回调返回 `null` 时，批次 pending 计数仍归零并发出 `outfit_applied([])`；旧 texture、旧 z_index 和旧 `_equipped_items` 保持不变
- [ ] AC-18b：`apply_outfit(["top_a", "top_b", "bottom_jeans"])` 在发起纹理请求前按类目归一化，仅最终目标 `top_b` 和 `bottom_jeans` 参与批次 pending；若二者成功，`outfit_applied(applied_item_ids)` 按 effective z_index 排序发出
- [ ] AC-18c：`apply_outfit(["top_good", "bottom_missing"])` 部分成功时，成功项发出 `outfit_changed`；失败项不发 `outfit_changed`，不污染 texture/z_index/_equipped_items；最终 `outfit_applied` 返回当前最终穿搭快照
- [ ] AC-18d：`TextureCache.get_texture_or_request()` 因未就绪、无效 resolution、加载失败、evict 或共享 cancel 返回 `callback(null)` 时，单件请求发出 `equip_item_completed(..., "texture_failed", equipped_items)`，批量请求完成 pending 结算且不永久挂起

**竞态保护**

- [ ] AC-19：快速连续 `equip_item("top_a")` 后立即 `equip_item("top_b")`，最终 `top_sprite.texture` 为 `top_b` 的纹理，不会出现 `top_a` 覆盖 `top_b` 的结果；测试必须验证旧 generation 回调被丢弃
- [ ] AC-20：`equip_item()` 的纹理在场景切换、`queue_free()` 或 `_exit_tree()` 后完成加载时，若 `is_inside_tree() == false`、`is_queued_for_deletion() == true`、`_is_disposed == true` 或 token/generation 过期，回调静默丢弃——不修改 texture、不发出信号
- [ ] AC-20a：`equip_item()` 后立刻 `clear_outfit()`，迟到的装备回调不得覆盖空槽状态
- [ ] AC-20b：`apply_outfit()` pending 期间触发 `_exit_tree()` 时，实例递增 `_active_batch_token` 并设置 `_is_disposed=true`；迟到回调不得修改 texture，不得发出 stale `outfit_applied`
- [ ] AC-20c：`equip_item()`、`apply_outfit()`、`unequip_category()`、`clear_outfit()` 快速交叉调用时，只有最新 generation/token 可提交；测试覆盖单件覆盖批次、批次覆盖单件、卸下覆盖加载中请求三种组合

**精灵节点完整性**

- [ ] AC-21：任一 `{category}_sprite` 子节点缺失时，`_ready()` 使用 `get_node_or_null()` 检测失败，输出 `push_error()` 含缺失节点名，`is_ready = false`，`renderer_ready` 不发出
- [ ] AC-21a：所有发布 `FULL` 纹理均为 `1024x1536` 同画布、同锚点、同基线；资产检查证据归档到 `production/qa/evidence/sprite-layered-rendering/asset-canvas-check.md`

**多实例**

- [ ] AC-22：同一场景中两个 `Character` 实例，对实例 A 调用 `equip_item("top_white_tee")` 不影响实例 B 的精灵和 `_equipped_items`
- [ ] AC-22a：同一场景中两个 `Character` 实例同时 `apply_outfit()` 请求相同 FULL 纹理时，TextureCache 去重不得串改任一实例的 token、texture 或 `_equipped_items`
- [ ] AC-22b：两个 `Character` 实例共享同一 LOADING 纹理时，实例 A `_exit_tree()` 不得调用 `TextureCache.cancel_request()`；实例 B 仍能收到有效 callback 并完成装备

**跨系统集成**

- [ ] AC-23（Integration evidence）：WARDROBE 或 Daily Scene 在收到 `renderer_ready` 后，由场景/调用方读取 `GameState.context` 并显式调用 `apply_outfit()` 或 `equip_default_outfit()`；Renderer `_ready()` 不承担该职责
- [ ] AC-24（Integration evidence）：衣橱 UI 确认穿搭后，从 `sprite_layered_renderer.get_equipped_items()` 读取穿搭列表写入 `GameState.context["equipped_items"]`；新场景实例由父场景读取 context 后显式恢复相同穿搭
- [ ] AC-24a（Integration evidence）：`GameState.context["equipped_items"] == []` 时，调用方必须将其视为明确空穿搭并调用 `apply_outfit([])`；不得改为默认穿搭兜底

**性能**

- [ ] AC-25a：自动化测试使用热缓存 mock 同步回调，记录调用帧和信号顺序，断言 `equip_item()` 发起后 `outfit_changed` 在同一帧发出，且 pending/token 在回调前已登记
- [ ] AC-25b（Web evidence）：目标 Web release 构建中，WARDROBE 与 DAILY_SCENE 各 1 个 6 层角色静态显示时 frame time p95 ≤16.7ms、p99 ≤25ms；证据归档到 `production/qa/perf/sprite-layered-rendering/perf-report.md`
- [ ] AC-25c：热缓存连续 100 次单件换装中，`equip_item()` 到 `equip_item_completed(..., "equipped", ...)` 为同帧或 `<16ms`；包含 texture assignment 的帧 p95 ≤16.7ms
- [ ] AC-25d：暖缓存装备回调 CPU 处理耗时 ≤5ms，且发信号前完成 token 校验与原子提交；冷缓存不承诺同帧成功，但不得在有效 texture callback 前发出成功结果
- [ ] AC-25e：单个 `Character` 的 Sprite2D 额外 CanvasItem draw call ≤6；MVP 同屏最多 2 个 `Character` 实例。若活跃 FULL 纹理估算总量超过 250MB 或 frame time 阈值失败，按顺序采取：收紧缓存上限、裁剪透明边界、启用 Basis、降低 FULL 分辨率、减少同屏实例、延期 render parts、预合成整套穿搭
- [ ] AC-25f：性能截图、Profiler trace 和 overdraw/draw-call 证据归档到 `production/qa/evidence/sprite-layered-rendering/`

**视觉资产**

- [ ] AC-26：发布构建正常路径中不得显示 `DEBUG_PLACEHOLDER_FULL_PATH`；空槽使用 `EMPTY_SLOT_FULL` 或透明自然空槽
- [ ] AC-27：所有 `z_index_override` 物品通过截图矩阵验证，覆盖与发型、上衣、配饰等可能遮挡类目的组合；截图结果作为资产验收证据

## Open Questions

| 问题 | 负责人 | 截止 | 决议 |
|------|--------|------|------|
| 空槽纹理的视觉设计——各类目空槽应为透明、自然裸槽，还是角色基础层的一部分？ | 美术总监 | 资产管线启动前 | 发布体验不得显示 debug placeholder。建议将 `EMPTY_SLOT_FULL` 作为发布资产规格，将 `DEBUG_PLACEHOLDER_FULL_PATH` 仅用于 QA/开发诊断 |
| DAILY_SCENE 中角色是否需要不同尺寸/缩放？WARDROBE 中角色较大（换装焦点），DAILY_SCENE 中角色是场景的一个元素 | 场景设计师 | 每日场景设计时 | 建议 `Character` 场景不做硬编码缩放——由父场景在实例化后设置 `scale` |
| 是否需要角色换装过渡动画（如短暂的 crossfade）？ | 创意总监 | `/prototype` 阶段 | MVP 建议不做——直接纹理替换已满足「即时有感」。若 prototype 发现切换太生硬再考虑 |
