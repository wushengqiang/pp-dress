# 衣橱 UI (Wardrobe UI)

> **Status**: Approved
> **Author**: user + Codex Game Studios
> **Last Updated**: 2026-06-08
> **Implements Pillar**: 随心搭配, 即时有感

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `输入管理`, `服装数据库`, `资源加载器`, `进度管理`

## Overview

衣橱 UI 是「每日穿搭」中玩家进入每日场景前进行穿搭选择的核心界面。它把服装数据库中的类目与物品、进度管理中的可见类目与解锁状态、资源加载器提供的缩略图、以及输入管理归一化后的点击/拖拽信号汇合成一个可操作的换装界面：玩家可以切换服装类目、浏览已解锁物品、查看锁定物品提示，并通过拖拽或“点击选中 → 点击角色部位”的替代操作把服装应用到角色身上。衣橱 UI 不决定物品是否解锁、不直接加载纹理文件、不负责最终精灵分层渲染；它的职责是让玩家清楚、轻松、即时地表达自己的搭配选择，同时保持 UI 退居边缘，让角色与穿搭始终是画面焦点。

## Player Fantasy

衣橱 UI 的玩家幻想是：“我打开一个只属于我的温柔衣橱，在没有评分、没有催促、没有错误答案的空间里，为今天的她挑一套衣服。”

玩家应该感到自己不是在管理库存，也不是在完成任务，而是在一个安静的试衣角落里探索审美。每个类目标签都像抽屉，每张服装卡片都像被认真摆放的小物件；点开、拖起、放下时，界面给出轻柔而即时的反馈，让玩家感觉自己的选择被画面温柔接住。锁定物品不应带来挫败感，而应像“明天也许会打开的小抽屉”一样制造期待。衣橱 UI 必须始终维护「随心搭配」的承诺：不评价搭配好坏，不暗示标准答案，只让玩家更容易看见、比较、尝试，并在每一次换装反馈中感到“这是我的选择”。

## Detailed Design

### Core Rules

**架构**：衣橱 UI 是 WARDROBE 状态中的玩家操作界面，负责展示服装类目、服装卡片、锁定状态、当前选中物品与拖拽反馈。它不拥有服装数据、不判断进度规则、不直接读取纹理文件，也不负责最终角色精灵的分层渲染；它只消费上游系统提供的数据与信号，并把玩家的选择转化为明确的 `item_id` 交互输出。

**类目标签规则**：
- 衣橱 UI 始终显示 6 个 MVP 类目：`top`, `bottom`, `shoes`, `accessory`, `hair`, `makeup`。
- `ProgressManager.get_visible_categories()` 返回的类目为可用状态，可以点击切换。
- 未包含在 `get_visible_categories()` 中的类目显示为灰色禁用标签，带锁图标，不可点击。
- 禁用类目不打开物品网格；点击或触摸时只播放轻微“不可用”反馈，不弹出惩罚性提示。
- 类目顺序遵循衣橱认知优先级：`top` → `bottom` → `shoes` → `accessory` → `hair` → `makeup`，使第 1 天的基础类目排在最前。

**物品卡片规则**：
- 当前类目可用时，衣橱 UI 从 `WardrobeDatabase.get_items_by_category(category)` 读取该类目的完整物品列表。
- 每个物品用 `ProgressManager.is_item_unlocked(item_id)` 判定显示状态。
- 已解锁物品显示缩略图、名称和当前装备/选中状态。
- 未解锁物品显示为锁定卡片：缩略图降低不透明度或使用遮罩，小锁图标可见，并显示“第 N 天解锁”。
- 若缩略图尚未加载完成，卡片显示占位图；缩略图通过 `TextureCache.get_texture_or_request(item_id, THUMB, callback)` 获取。
- 卡片文字最多显示服装数据库定义的 `name`，不得自行改写或截断成新名称；若视觉上仍溢出，UI 使用自动缩放或换行处理。

**交互方式**：
- 拖拽：玩家从已解锁物品卡片拖起服装，衣橱 UI 创建拖拽预览并跟随 `InputManager.drag_updated` 更新位置。拖拽结束时输出正式接口 `item_drag_dropped(item_id, position)` 给拖拽换装/角色区域判定。
- 点击替代：玩家点击已解锁物品卡片后，该卡片进入 selected 状态；随后点击角色或确认区域，衣橱 UI 输出正式接口 `item_selected_for_equip(item_id)`。
- 已锁定物品不可拖拽、不可进入 selected 状态；点击时只显示锁定说明。
- 禁用类目不可选中，不改变当前类目。
- 当前已装备物品在卡片上显示 equipped 状态，但不会被评分、推荐或标记为“正确”。

**反馈规则**：
- hover 只用于桌面端高亮，不作为唯一信息源。
- selected、equipped、locked、disabled 必须有颜色以外的形状或图标区分。
- 拖起时卡片源位置保留 40% 不透明度的虚线轮廓；拖拽预览 1.05x 缩放并带暖调柔影。
- 放下成功反馈由下游换装/渲染系统执行；衣橱 UI 只负责在收到装备结果同步后更新 equipped 状态。

**装备结果同步**：
- 衣橱 UI 不自行判断服装是否真正穿上。它只输出装备意图，并等待下游拖拽换装/精灵分层渲染系统返回正式接口 `outfit_apply_result(item_id, accepted, equipped_items, reason)`。
- `accepted == true`：衣橱 UI 用返回的 `equipped_items` 覆盖本地 equipped state，清除 `selected_item_id`，并更新所有相关卡片状态。
- `accepted == false`：衣橱 UI 不改写 `equipped_items`，保留或清除 `selected_item_id` 由 `reason` 决定；默认保留 selected 并显示轻量不可用反馈。
- `reason == "same_item"`：视为 no-op，不播放失败反馈，不改变 equipped state，只短暂强调该物品已装备。
- 该同步接口是衣橱 UI 与未来拖拽换装 GDD 之间的临时输出/回写契约；若拖拽换装 GDD 采用不同信号名或参数，必须回传修订本 GDD。

### States and Transitions

衣橱 UI 内部状态不等于 GameState 状态；它只在 WARDROBE 场景内运行。

```
LOADING
  → READY(category=first_visible_category)
  → CATEGORY_SELECTED(category)
  → ITEM_SELECTED(item_id)
  → DRAGGING(item_id)
  → READY / CATEGORY_SELECTED
```

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|----------|----------|
| `LOADING` | 等待 WardrobeDatabase、ProgressManager、TextureCache 就绪 | WARDROBE 场景 `_ready()` | 全部依赖就绪 |
| `READY` | 默认浏览状态 | 依赖就绪后 | 选择类目、点击物品、开始拖拽 |
| `CATEGORY_SELECTED` | 某个可见类目正在展示 | 点击可用类目标签 | 切换类目、离开衣橱 |
| `ITEM_SELECTED` | 一个已解锁物品被点击选中，等待应用 | 点击已解锁卡片 | 点击角色/确认区域应用，或点击其他物品替换选中 |
| `DRAGGING` | 正在拖拽服装卡片 | `InputManager.drag_started` 携带的 `region_id` 可解析为已解锁卡片 | `InputManager.drag_ended` |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|----------|
| 输入管理 | 本系统依赖 | 为每张可交互服装卡片调用 `register_gesture_region(region_id, rect, options)`；监听 `drag_started` / `drag_updated` / `drag_ended` / `clicked` / `hovered`，并用事件 Dictionary 中的 `region_id` 映射到 `item_id` |
| 服装数据库 | 本系统依赖 | 读取类目定义、物品列表、物品名称、缩略图路径、标签和 `unlock_day` |
| 资源加载器 | 本系统依赖 | 通过 `get_texture_or_request(item_id, THUMB, callback)` 获取卡片缩略图；切换类目时调用 `preload_category_thumbnails(category)` |
| 进度管理 | 本系统依赖 | 调用 `get_visible_categories()` 决定类目启用/禁用；调用 `is_item_unlocked(item_id)` 决定卡片锁定状态 |
| 场景/状态管理 | 本系统被调度 | WARDROBE 场景进入时创建衣橱 UI；取消或确认穿搭后由 GameState 切换状态 |
| 拖拽换装 | 依赖本系统 | 接收衣橱 UI 输出的 `item_id` 和拖拽落点，执行装备判定，并返回 `outfit_apply_result(item_id, accepted, equipped_items, reason)` |
| 精灵分层渲染 | 间接依赖 | 换装成功后更新角色显示；衣橱 UI 根据装备结果同步 equipped 状态，不直接改 Sprite2D 层级 |

## Formulas

衣橱 UI 不包含数值成长或经济公式，但包含一组必须稳定执行的状态判定、排序和布局约束。所有公式均用于 UI 展示与交互状态，不改变进度或服装数据。

### 类目可用判定

```
category_enabled(category) = category in ProgressManager.get_visible_categories()
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `category` | String | WardrobeDatabase 中的类目键 | 当前被渲染的类目标签 |
| `ProgressManager.get_visible_categories()` | Array[String] | 当前天数可见类目 | 进度管理提供的类目可见性真相源 |

**输出**：boolean

### 输入热区映射

衣橱 UI 拥有服装卡片身份映射；InputManager 只负责命中热区和生成统一输入信号，不携带 `item_id`、Node 或服装数据引用。

```text
region_id = StringName("wardrobe_card:%s" % item_id)
region_to_item_id[region_id] = item_id
```

当类目切换、卡片重建、分页/滚动布局刷新或衣橱退出时，衣橱 UI 必须注销旧热区并清理映射。收到 `drag_started` / `clicked` / `hovered` 时，若 `region_id` 不存在于当前映射，必须取消该输入，不得根据坐标或旧卡片状态猜测物品。

**示例**：第 1 天 `top` 返回 `true`，`hair` 返回 `false`。`hair` 标签仍显示，但为灰色禁用状态。

### 卡片状态判定

```
if category_enabled(item.category) == false:
    card_state = "disabled_category"
elif ProgressManager.is_item_unlocked(item.id) == false:
    card_state = "locked"
elif item.id in equipped_items:
    card_state = "equipped"
elif item.id == selected_item_id:
    card_state = "selected"
else:
    card_state = "available"
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `item` | Dictionary | WardrobeDatabase 物品字典 | 当前卡片对应的服装物品 |
| `equipped_items` | Array[String] | 当前已装备物品 ID | 来自衣橱 UI 当前会话状态或下游换装系统同步 |
| `selected_item_id` | String\|null | 一个物品 ID 或 null | 点击替代操作中的当前选中物品 |

**输出**：`disabled_category`, `locked`, `equipped`, `selected`, `available`

**优先级说明**：禁用类目优先级最高，其次锁定；锁定物品不能进入 selected/equipped 状态。`equipped` 优先于 `selected`，避免已穿上的物品被误读为“待确认”。

### 类目排序

```
category_order = ["top", "bottom", "shoes", "accessory", "hair", "makeup"]
visible_label_list = category_order filtered by keys existing in WardrobeDatabase.get_categories()
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `category_order` | Array[String] | 6 个 MVP 类目 | 衣橱 UI 固定显示顺序 |
| `WardrobeDatabase.get_categories()` | Dictionary | 已定义类目 | 用于过滤不存在的类目，避免显示无效标签 |

**输出**：用于渲染的类目标签列表。

**示例**：标准 MVP 数据下始终输出 `top, bottom, shoes, accessory, hair, makeup`。第 1 天后 3 个基础类目为 enabled，其余为 disabled。

### UI 覆盖与触控约束

```
ui_covered_character_area_ratio = ui_overlap_area / character_body_area
ui_covered_character_area_ratio <= 0.30

touch_target_width >= 44px
touch_target_height >= 44px
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `ui_overlap_area` | float | ≥0 | UI 面板覆盖角色主体区域的面积 |
| `character_body_area` | float | >0 | 角色主体可见区域面积 |
| `touch_target_width` / `touch_target_height` | float | ≥0 px | 可点击/触摸控件的实际热区尺寸 |

**输出**：布局合法性判定。

**规则**：任何衣橱面板、网格或浮层不得覆盖角色主体 30% 以上；所有可交互标签、卡片、按钮的触控热区不得小于 44×44px。

## Edge Cases

### EC-1: 点击禁用类目标签

**场景**：第 1 天玩家点击灰色的 `hair` 或 `makeup` 类目标签。

**行为**：衣橱 UI 不切换当前类目，不打开物品网格，不改变 selected item。播放轻微不可用反馈（如标签 0.95x 轻缩 + 锁图标微亮），可显示短提示“明天以后会打开”。提示语不得带惩罚或失败语气。

### EC-2: 点击锁定物品卡片

**场景**：当前类目已可见，但某件物品 `unlock_day > current_day`。

**行为**：卡片不可进入 selected 状态，不可拖拽，不输出 `item_selected_for_equip` 或 `item_drag_dropped`。点击时显示“第 N 天解锁”，其中 N 来自该物品的 `unlock_day` 字段。锁定卡片保留缩略图轮廓或低透明预览，用于制造期待。

### EC-3: 当前类目没有任何物品

**场景**：`WardrobeDatabase.get_items_by_category(category)` 返回空数组。

**行为**：物品网格显示温和空状态（如“这个抽屉还在整理中”），不报错、不自动跳转到其他类目。类目标签仍保持选中状态，方便内容开发阶段发现该类目为空。

### EC-4: 缩略图加载失败或尚未完成

**场景**：`TextureCache.get_texture_or_request(item_id, THUMB, callback)` 回调返回 `null`，或异步加载尚未完成。

**行为**：卡片显示占位图。若该物品已解锁，卡片仍可点击和拖拽；若未解锁，仍按 locked 状态处理。缩略图失败不改变物品可用性。

### EC-5: ProgressManager 未就绪

**场景**：WARDROBE 场景进入时 `ProgressManager.is_ready == false`。

**行为**：衣橱 UI 进入 `LOADING` 状态，显示轻量加载状态，不渲染类目启用/禁用和物品锁定状态。收到 `progress_loaded` 后重新构建类目与卡片。若超过 GameState 的场景就绪超时仍未就绪，由场景/状态管理处理错误流程。

### EC-6: WardrobeDatabase 返回异常数据

**场景**：类目缺失、物品字段缺失、`get_item_by_id()` 返回 null，或数据中存在 UI 无法渲染的条目。

**行为**：衣橱 UI 过滤无法渲染的条目并记录 warning；不崩溃、不显示破损卡片。若全部条目被过滤，则按 EC-3 空类目处理。数据正确性仍由 WardrobeDatabase 负责，衣橱 UI 只做消费端容错。

### EC-7: 移动端无 hover

**场景**：玩家在触摸设备上操作衣橱。

**行为**：所有 hover 才能看到的信息必须也能通过点击/选中状态看到。锁定说明、物品名称、选中状态、已装备状态均不得只依赖 hover。触摸设备不发射 `hovered` 时，UI 功能完整不降级。

### EC-8: 拖拽中切换类目或离开 WARDROBE

**场景**：玩家拖拽物品时触发类目切换、取消衣橱、场景转换或浏览器刷新。

**行为**：衣橱 UI 立即取消拖拽，清理拖拽预览和源卡片 ghost 状态，不输出装备事件。若 InputManager 已发出 `drag_ended(interrupted=true)`，衣橱 UI 按取消处理。离开 WARDROBE 时不保留 selected item。

### EC-9: 视口过窄或方向变化

**场景**：移动端竖屏、浏览器窗口很窄，或运行中发生横竖屏切换。

**行为**：布局切换为上下分区：角色区域优先保留，类目标签与物品网格移动到底部。所有触控热区仍 ≥44×44px，UI 覆盖角色主体比例仍 ≤30%。若无法同时满足，优先保证触控热区和角色可见性，减少同屏卡片数量。

### EC-10: 已装备物品被再次点击

**场景**：玩家点击当前已经装备的物品卡片。

**行为**：卡片保持 equipped 状态，可短暂显示 selected 外观但不重复触发换装。只有玩家执行确认应用或拖拽放下时，才输出装备事件；下游换装系统可识别同一 `item_id` 并 no-op。UI 不把重复点击当作错误。

## Dependencies

### 本系统依赖（上游）

| 依赖 | 类型 | 接口/数据 | 说明 |
|------|------|----------|------|
| 输入管理 | 强依赖 | `register_gesture_region(id, rect, options)`、`unregister_gesture_region(id)`、`drag_started`、`drag_updated`、`drag_ended`、`clicked`、`hovered`；事件 Dictionary 中的 `region_id` / `owner_id` / `source_key` | 提供鼠标/触摸统一后的交互信号。衣橱 UI 不直接解析原始 `InputEvent`，也不要求 InputManager 携带 `item_id` |
| 服装数据库 | 强依赖 | `get_categories()`、`get_items_by_category(category)`、`get_item_by_id(item_id)` | 提供类目定义、物品列表、物品名称、`thumbnail_path`、`tags`、`unlock_day` |
| 资源加载器 | 强依赖 | `get_texture_or_request(item_id, THUMB, callback)`、`preload_category_thumbnails(category)` | 提供卡片缩略图与类目预加载。衣橱 UI 不直接加载纹理文件 |
| 进度管理 | 强依赖 | `get_visible_categories()`、`is_item_unlocked(item_id)`、`get_current_day()` | 提供类目启用/禁用、物品锁定状态和解锁提示所需的当前天数 |
| 场景/状态管理 | 强依赖 | WARDROBE 状态进入/退出、取消/确认穿搭转换 | 负责调度衣橱场景。衣橱 UI 不直接切换 GameState，只发出用户意图 |

### 依赖本系统的系统（下游）

| 系统 | 依赖性质 | 接口/数据 | 说明 |
|------|----------|----------|------|
| 拖拽换装 | 强依赖 | 正式接口：`item_drag_dropped(item_id, position)`、`item_selected_for_equip(item_id)`、`outfit_apply_result(item_id, accepted, equipped_items, reason)` | 消费衣橱 UI 输出的物品选择与拖拽落点，执行装备判定，并把装备结果回写给 UI |
| 精灵分层渲染 | 间接依赖 | equipped state 同步 | 换装成功后更新角色显示；衣橱 UI 根据 `outfit_apply_result` 中的 `equipped_items` 更新卡片 equipped 状态 |
| 服装解锁 | 中依赖（未来） | 新解锁 item_id 列表、卡片高亮入口 | 可在衣橱 UI 中对新解锁物品播放一次性高亮或提示 |
| 主菜单/晚安 UI | 弱依赖（未来） | 共享 UI 视觉规范 | 不消费衣橱 UI 数据，但需要保持同一套温暖、克制的 UI 风格 |

### 双向依赖确认

**衣橱 UI ↔ 输入管理**：
- 输入管理 GDD 已列出衣橱 UI 为强依赖下游。
- 衣橱 UI 仅监听 InputManager 信号，不持有原始输入事件处理逻辑。

**衣橱 UI ↔ 服装数据库**：
- 服装数据库 GDD 已列出衣橱 UI 通过 `get_items_by_category(cat)`、`get_all_items()` 和物品字段构建衣橱视图。
- 衣橱 UI 不修改数据库返回数据；所有查询结果视为只读。

**衣橱 UI ↔ 资源加载器**：
- 资源加载器 GDD 已列出衣橱 UI 通过 `get_texture_or_request(id, THUMB, callback)` 获取缩略图，并在进入 WARDROBE 或切换类目时预加载类目缩略图。
- 衣橱 UI 必须处理 callback 返回 `null` 的情况。

**衣橱 UI ↔ 进度管理**：
- 进度管理 GDD 已列出衣橱 UI 通过 `get_visible_categories()`、`get_unlocked_items(category)`、`is_item_unlocked(item_id)` 构建类目与锁定状态。
- `systems-index.md` 已将衣橱 UI 的 Depends On 补充为包含 `进度管理`，与本 GDD 保持一致。

### 实现约束

| 约束 | 影响 |
|------|------|
| 衣橱 UI 不直接读写 SaveManager | 进度状态通过 ProgressManager 查询，避免 UI 修改持久化数据 |
| 衣橱 UI 不直接加载 `thumbnail_path` 文件 | 缩略图统一通过 TextureCache 获取，避免重复加载和缓存绕路 |
| 衣橱 UI 不直接改角色 Sprite2D | 装备应用由拖拽换装/精灵分层渲染处理，UI 只输出 `item_id` 意图 |
| 所有可交互元素必须支持鼠标与触摸 | 交互入口来自 InputManager 或 Godot Control 标准信号，不能只做桌面 hover |
| 未可见类目仍显示 | 系统必须同时渲染 enabled 和 disabled 类目标签，而不是只渲染可见类目 |
| 装备状态必须由下游回写确认 | UI 不得在输出 `item_drag_dropped` 或 `item_selected_for_equip` 后立即假定装备成功 |

## Tuning Knobs

衣橱 UI 的调参点集中在布局密度、触控可用性和反馈强度。所有调参都必须服从两条上位约束：角色与穿搭保持视觉焦点，所有触控目标不小于 44×44px。

| 参数 | 默认值 | 安全范围 | 影响 |
|------|--------|----------|------|
| `CARD_SIZE` | 72×88px | 56×72 到 96×120 | 服装卡片尺寸。增大可提升可读性和展示感，但减少同屏数量；减小可显示更多物品，但可能压缩名称和触控空间 |
| `THUMB_SIZE` | 48×48px | 固定 | 缩略图尺寸来自资源标准和 TextureCache，不由衣橱 UI 调整 |
| `CATEGORY_TOUCH_TARGET` | 44×44px | ≥44×44px | 类目标签触控热区。不得低于 44×44px |
| `GRID_GAP` | 8px | 6–16px | 卡片间距。增大提升呼吸感，减小提升信息密度 |
| `DRAG_PREVIEW_SCALE` | 1.05 | 1.0–1.12 | 拖拽预览缩放。过高会显得跳脱，过低则拖起反馈不明显 |
| `FEEDBACK_DURATION_MS` | 200–400ms | 120–500ms | 点击、拖起、不可用反馈、锁定提示等微交互时长。过短不够柔和，过长会显得迟钝 |
| `LOCKED_CARD_OPACITY` | 45% | 30–70% | 锁定卡片透明度。过低会失去“未来期待”的可见性，过高会被误认为可用 |
| `MAX_CHARACTER_COVERAGE` | 30% | 固定上限 | UI 覆盖角色主体的最大比例。来自 art bible，不建议调高 |
| `VISIBLE_CARDS_PER_ROW` | 响应式计算 | 由容器宽度决定 | 每行卡片数量不硬编码，由 `CARD_SIZE`、`GRID_GAP` 和可用宽度计算 |

### 非本系统控制的调参点

| 行为 | 控制方 | 说明 |
|------|--------|------|
| 类目何时启用 | 进度管理 | 衣橱 UI 只显示 enabled/disabled，不决定解锁节奏 |
| 每类物品数量和排序 | 服装数据库 | 由 `items[]`、`sort_order` 和内容配置决定 |
| 缩略图加载策略 | 资源加载器 | 衣橱 UI 请求缩略图，不决定缓存层级 |
| 拖拽判定阈值 | 输入管理 | `drag_threshold` 属于 InputManager |
| 换装成功动画 | 拖拽换装 / 精灵分层渲染 | 衣橱 UI 只负责卡片和拖拽预览，不负责角色 Sprite 替换特效 |

### 刻意不做成可调的

| 项目 | 固定值 | 原因 |
|------|--------|------|
| 类目显示数量 | 6 个 MVP 类目始终显示 | 玩家应能看到未来会打开的抽屉，形成期待 |
| 锁定物品是否展示 | 展示 | 不展示会削弱收集期待；完全隐藏会让进度感变弱 |
| 是否支持点击替代操作 | 必须支持 | 无障碍要求，不能只依赖拖拽 |
| 是否显示评分/推荐 | 不显示 | 与「随心搭配」反评分承诺冲突 |

## Visual/Audio Requirements

衣橱 UI 是玩家最常停留的操作界面之一，视觉与音频必须严格服务「随心搭配」与「即时有感」：界面提供清晰操作入口，但不抢走角色与穿搭的注意力。

### Visual Requirements

| 事件/元素 | 视觉要求 | 目的 |
|----------|----------|------|
| 整体布局 | UI 浮于画面边缘，角色与穿搭居中；任何面板不得覆盖角色主体 30% 以上 | 保持穿搭为视觉焦点 |
| 类目标签 | 轻量胶囊标签或圆角标签，触控热区 ≥44×44px | 保证触控可用性和轻盈感 |
| 可用类目 | 使用暖杏/樱茶系激活态，带轻微外发光或底色变化 | 表示可点击，不引入强烈对比 |
| 禁用类目 | 灰化/低透明 + 小锁图标 + 不可用反馈 | 让未来类目可见但不误导为可用 |
| 服装卡片 | 浅色圆角卡片，缩略图居中，名称位于下方或卡片底部 | 让物品像被认真摆放的小物件 |
| 锁定卡片 | `LOCKED_CARD_OPACITY` 约 45%，小锁图标，显示“第 N 天解锁” | 制造期待，避免挫败 |
| selected 状态 | 暖杏外发光、轻微缩放或选中角标 | 支持点击替代操作 |
| equipped 状态 | 独立角标或衣架/对勾图标，与 selected 明确区分 | 避免把“已穿上”和“待应用”混淆 |
| 拖起反馈 | 服装预览 1.05x 缩放 + 暖调柔影；源卡片保留 40% 不透明度 ghost 轮廓 | 强化“拿起衣服”的即时感 |
| hover 高亮 | 桌面端可用，轻微亮度/阴影变化；不得承载唯一信息 | 避免移动端信息缺失 |
| 空类目状态 | 温和文字 + 轻量占位图，不使用错误样式 | 兼容内容开发和缺物品情况 |

### Audio Requirements

| 事件 | 音频要求 | 说明 |
|------|----------|------|
| 点击类目 | 轻柔纸页声或小木扣声，短促、低音量 | 像打开抽屉，不像菜单机器音 |
| 点击服装卡片 | 轻微布料触碰音或柔和 tick | 强化“触摸服装”的质感 |
| 拖起服装 | 极轻布料摩擦音，音量低，不循环 | 避免长拖拽造成疲劳 |
| 禁用类目/锁定物品 | 短、轻、圆润的不可用反馈音 | 不得使用刺耳失败音，避免破坏「随心搭配」 |
| 放下成功 | 由拖拽换装/精灵分层渲染系统播放 | 衣橱 UI 不重复播放成功音，避免叠音 |

### Style Constraints

- 颜色使用 art bible 的 `晨光白`、`暖杏`、`樱茶`、`山吹茶`、`小豆色` 系列。
- 状态区分必须使用“颜色 + 图标/形状/位置”双信号源。
- 不使用红色错误态、强烈警告音或震动式失败反馈。
- UI 动画时长遵循 200–400ms 的柔和 ease-out，不做弹窗式打断。
- 卡片和标签可以圆润，但不得厚重；衣服缩略图永远比 UI 框更重要。

### Asset Spec Flag

衣橱 UI 需要后续资产规格：类目图标、小锁图标、选中角标、已装备角标、占位缩略图、拖拽 ghost 样式、不可用反馈粒子/微光。Art Bible 完成后应运行 `/asset-spec system:wardrobe-ui` 生成具体资产规格。

## UI Requirements

衣橱 UI 是完整的玩家操作界面，必须在桌面端和移动端都能完成浏览、选择、拖拽、点击替代、取消与确认穿搭。

### 桌面布局（≥768px）

| 区域 | 位置 | 要求 |
|------|------|------|
| 角色展示区 | 画面中央 | 角色与当前穿搭始终是最大视觉焦点，不被 UI 覆盖超过 30% |
| 类目标签 | 左侧竖列 | 6 个类目始终显示；每个标签触控/点击热区 ≥44×44px |
| 服装网格 | 底部横向滚动 | 展示当前类目的卡片；滚动不改变角色位置 |
| 操作按钮 | 右下或底部边缘 | `取消`、`确认穿搭` 两个主操作，不覆盖服装卡片 |
| 选中提示 | 靠近底部网格或角色侧边 | 点击替代流程中显示当前 selected item 的轻量提示 |

### 移动布局（<768px）

| 区域 | 位置 | 要求 |
|------|------|------|
| 角色展示区 | 上方/中央 | 优先保证角色完整可见；UI 不遮挡主体超过 30% |
| 类目标签 | 底部上排或横向标签条 | 6 个类目都必须进入标签条数据源；窄屏可横向滚动访问全部类目，但不得从数据中过滤禁用类目 |
| 服装网格 | 底部 | 横向滚动或两行紧凑网格；所有卡片热区 ≥44×44px |
| 操作按钮 | 底部固定边缘 | 确认/取消必须在拇指可达区域，但不遮挡当前拖拽路径 |
| 锁定说明 | 卡片内或底部轻提示 | 不依赖 hover，不使用弹窗阻断操作 |

### 类目标签

- 类目标签显示顺序固定为 `top`, `bottom`, `shoes`, `accessory`, `hair`, `makeup`。
- 可用类目显示正常状态；当前类目显示 selected 状态。
- 禁用类目显示灰色/低透明 + 小锁图标，不可点击切换。
- 标签文本使用 WardrobeDatabase `categories` 中的 label；若 label 缺失，回退显示类目 key 并记录 warning。
- 类目状态不得只靠颜色区分，必须有锁图标、选中底色或位置变化等第二信号。

### 服装卡片

每张卡片必须包含：
- 缩略图区域（48×48）
- 服装名称
- locked 状态图标/提示（如适用）
- selected 状态标记（如适用）
- equipped 状态标记（如适用）

卡片尺寸保持稳定，不因缩略图加载、名称长短、锁定提示出现而改变布局。名称过长时优先换行或缩小字号，不允许溢出卡片边界。

### 操作流程

**拖拽流程**：
1. 玩家按下已解锁卡片并移动超过 InputManager 阈值。
2. 卡片进入 dragging 状态，源卡显示 ghost。
3. 拖拽预览跟随指针/触点。
4. `drag_ended` 后输出正式接口 `item_drag_dropped(item_id, position)`。
5. 下游换装系统返回 `outfit_apply_result(item_id, accepted, equipped_items, reason)`。
6. `accepted == true` 时，衣橱 UI 用返回的 `equipped_items` 更新 equipped 状态；`accepted == false` 时不改写 equipped state，只播放轻量不可用反馈。

**点击替代流程**：
1. 玩家点击已解锁卡片。
2. 卡片进入 selected 状态。
3. 玩家点击角色区域或确认应用区域。
4. 衣橱 UI 输出正式接口 `item_selected_for_equip(item_id)`。
5. 下游换装系统返回 `outfit_apply_result(item_id, accepted, equipped_items, reason)`。
6. `accepted == true` 时，衣橱 UI 清除 selected 并更新 equipped 状态；`accepted == false` 时默认保留 selected，方便玩家重新尝试。

**取消与确认**：
- `取消`：先显示轻量确认提示“确定要取消今天的穿搭吗？”。玩家确认后，衣橱 UI 清除 selected/dragging 临时状态，向 GameState 发出取消/返回 MAIN_MENU 意图，不保存本次未确认穿搭变更；玩家取消该提示时，保持在 WARDROBE。
- `确认穿搭`：提交当前 `equipped_items` 给 GameState / 下游系统，进入 DAILY_SCENE。`equipped_items == []` 是合法的明确空穿搭，不得被 UI 自动替换为默认穿搭。
- 若玩家未主动更换任何服装，允许使用默认/当前穿搭确认，不弹出错误提示；只有 `equipped_items` 缺失或尚未初始化时才使用默认/当前穿搭兜底。

### Godot 4.6 Focus Requirements

- `hover`：只代表鼠标悬停，用于桌面端轻量反馈。
- `selected`：代表点击替代流程中的当前待应用物品。
- `equipped`：代表当前已穿到角色身上的物品。
- `keyboard_focus`：代表键盘/手柄当前焦点，必须与 `hover` 分开显示。
- 由于 Godot 4.6 鼠标/触摸焦点与键盘/手柄焦点分离，衣橱 UI 必须测试鼠标、触摸、键盘/手柄三种路径。

### Accessibility

- 所有可交互元素热区 ≥44×44px。
- 所有状态使用颜色 + 图标/形状/位置双信号源。
- 锁定说明、选中状态、已装备状态不得只依赖 hover。
- 不使用评分、红色错误态或刺耳失败反馈。
- UI 文本应预留本地化空间，短标签优先；可见字符串后续进入 localization 流程。

### UX Flag

本系统包含完整 UI 需求。进入 Pre-Production 前，应运行 `/ux-design wardrobe-ui` 生成衣橱界面的 UX spec；后续故事应引用 `design/ux/wardrobe-ui.md`，而不是只引用本 GDD。

## Acceptance Criteria

### 初始化与就绪

- [ ] **AC-1**: **GIVEN** WARDROBE 场景进入，**WHEN** `WardrobeDatabase.is_ready == true`、`ProgressManager.is_ready == true`、`TextureCache.is_ready == true`，**THEN** 衣橱 UI 进入 `READY` 状态并渲染类目标签。
- [ ] **AC-2**: **GIVEN** `ProgressManager.is_ready == false`，**WHEN** WARDROBE 场景进入，**THEN** 衣橱 UI 显示 loading 状态，不渲染错误类目或错误卡片。
- [ ] **AC-3**: **GIVEN** `progress_loaded` 信号发出，**WHEN** 衣橱 UI 当前处于 `LOADING`，**THEN** UI 重新构建类目标签与物品卡片并进入 `READY`。

### 类目标签

- [ ] **AC-4**: **GIVEN** 标准 MVP 类目数据，**WHEN** 衣橱 UI 渲染，**THEN** 始终显示 6 个类目标签：`top`, `bottom`, `shoes`, `accessory`, `hair`, `makeup`。
- [ ] **AC-5**: **GIVEN** 当前为第 1 天，**WHEN** 渲染类目标签，**THEN** `top`、`bottom`、`shoes` 为 enabled，`accessory`、`hair`、`makeup` 为 disabled 且带锁图标。
- [ ] **AC-6**: **GIVEN** 玩家点击 disabled 类目，**WHEN** 点击事件触发，**THEN** 当前类目不变，物品网格不切换，播放不可用反馈。
- [ ] **AC-7**: **GIVEN** 玩家点击 enabled 类目，**WHEN** 点击事件触发，**THEN** 当前类目切换到该类目，并调用 `TextureCache.preload_category_thumbnails(category)`。

### 物品卡片

- [ ] **AC-8**: **GIVEN** 当前类目为 enabled，**WHEN** 衣橱 UI 构建物品网格，**THEN** 使用 `WardrobeDatabase.get_items_by_category(category)` 返回的物品列表生成卡片。
- [ ] **AC-9**: **GIVEN** 物品已解锁，**WHEN** 卡片渲染，**THEN** 卡片显示缩略图区域、服装名称，并可点击/拖拽。
- [ ] **AC-10**: **GIVEN** 物品未解锁，**WHEN** 卡片渲染，**THEN** 卡片显示 locked 状态、小锁图标和“第 N 天解锁”，不可点击选中，不可拖拽。
- [ ] **AC-11**: **GIVEN** 物品 ID 在 `equipped_items` 中，**WHEN** 卡片渲染，**THEN** 卡片显示 equipped 状态，且该状态不同于 selected 状态。
- [ ] **AC-12**: **GIVEN** 服装名称接近或达到 8 个中文字符，**WHEN** 卡片渲染，**THEN** 文本不溢出卡片边界，卡片尺寸不发生跳动。

### 缩略图

- [ ] **AC-13**: **GIVEN** 卡片需要缩略图，**WHEN** 卡片创建，**THEN** 调用 `TextureCache.get_texture_or_request(item_id, THUMB, callback)`。
- [ ] **AC-14**: **GIVEN** 缩略图 callback 返回 Texture2D，**WHEN** 回调执行，**THEN** 卡片缩略图更新为该纹理。
- [ ] **AC-15**: **GIVEN** 缩略图 callback 返回 `null`，**WHEN** 回调执行，**THEN** 卡片显示占位图，交互状态不被改变。

### 拖拽流程

- [ ] **AC-16**: **GIVEN** 玩家从已解锁卡片开始拖拽，**WHEN** `InputManager.drag_started` 触发且事件 `region_id` 能在当前 `region_to_item_id` 中解析为已解锁 `item_id`，**THEN** 衣橱 UI 进入 `DRAGGING(item_id)`，显示拖拽预览和源卡 ghost。
- [ ] **AC-17**: **GIVEN** UI 处于 `DRAGGING`，**WHEN** `InputManager.drag_updated` 触发，**THEN** 拖拽预览位置跟随输入位置更新。
- [ ] **AC-18**: **GIVEN** UI 处于 `DRAGGING`，**WHEN** `InputManager.drag_ended` 触发，**THEN** 衣橱 UI 输出正式接口 `item_drag_dropped(item_id, position)` 并清理拖拽预览。
- [ ] **AC-19**: **GIVEN** 玩家试图拖拽 locked 卡片，**WHEN** `drag_started` 触发且 `region_id` 解析出的 `item_id` 当前未解锁，**THEN** 衣橱 UI 不进入 `DRAGGING`，不创建拖拽预览。
- [ ] **AC-19b**: **GIVEN** 衣橱 UI 已重建卡片或切换类目，**WHEN** 收到旧 `region_id` 的 `drag_started` / `clicked` / `hovered`，**THEN** 衣橱 UI 忽略该输入并清理候选状态，不根据坐标或旧数据猜测 `item_id`。
- [ ] **AC-19a**: **GIVEN** 衣橱 UI 已输出 `item_drag_dropped(item_id, position)`，**WHEN** 下游尚未返回 `outfit_apply_result`，**THEN** equipped state 不被立即改写。

### 点击替代流程

- [ ] **AC-20**: **GIVEN** 玩家点击已解锁卡片，**WHEN** `clicked` 触发且事件 `region_id` 能解析为已解锁 `item_id`，**THEN** 卡片进入 selected 状态，`selected_item_id == item_id`。
- [ ] **AC-21**: **GIVEN** 已有 selected item，**WHEN** 玩家点击角色区域或确认应用区域，**THEN** 衣橱 UI 输出正式接口 `item_selected_for_equip(selected_item_id)`。
- [ ] **AC-22**: **GIVEN** 玩家点击 locked 卡片，**WHEN** `clicked` 触发，**THEN** `selected_item_id` 不改变，并显示锁定说明。
- [ ] **AC-23**: **GIVEN** 玩家点击另一个已解锁卡片，**WHEN** `clicked` 触发，**THEN** selected 状态转移到新卡片，旧卡片取消 selected。
- [ ] **AC-23a**: **GIVEN** 下游返回 `outfit_apply_result(item_id, true, equipped_items, reason)`，**WHEN** 衣橱 UI 处理该结果，**THEN** 本地 `equipped_items` 被返回值覆盖，`selected_item_id` 被清除，相关卡片显示 equipped 状态。
- [ ] **AC-23b**: **GIVEN** 下游返回 `outfit_apply_result(item_id, false, equipped_items, reason)`，**WHEN** 衣橱 UI 处理该结果，**THEN** 本地 `equipped_items` 不被改写，UI 播放轻量不可用反馈且不显示失败/惩罚语气。

### 取消与确认

- [ ] **AC-24**: **GIVEN** 玩家点击 `取消`，**WHEN** 当前处于 WARDROBE，**THEN** 衣橱 UI 显示轻量确认提示“确定要取消今天的穿搭吗？”，不立即切换 GameState。
- [ ] **AC-24a**: **GIVEN** 取消确认提示已显示，**WHEN** 玩家确认取消，**THEN** selected/dragging 临时状态被清除，并向 GameState 发出 WARDROBE → MAIN_MENU 的取消/返回意图，不保存未确认变更。
- [ ] **AC-24b**: **GIVEN** 取消确认提示已显示，**WHEN** 玩家关闭或否定该提示，**THEN** UI 保持在 WARDROBE，当前 selected/equipped 状态不变。
- [ ] **AC-25**: **GIVEN** 玩家点击 `确认穿搭`，**WHEN** 当前存在 `equipped_items`（包括 `[]`）或可用默认/当前穿搭兜底，**THEN** 衣橱 UI 提交 `equipped_items` 并请求进入 DAILY_SCENE；`[]` 不得被自动替换为默认穿搭。
- [ ] **AC-26**: **GIVEN** 玩家未主动更换服装，**WHEN** 点击 `确认穿搭`，**THEN** 使用默认/当前穿搭继续，不弹出错误提示。

### 响应式与无障碍

- [ ] **AC-27**: **GIVEN** 视口宽度 ≥768px，**WHEN** 衣橱 UI 布局，**THEN** 类目标签位于左侧，服装网格位于底部，角色居中。
- [ ] **AC-28**: **GIVEN** 视口宽度 <768px，**WHEN** 衣橱 UI 布局，**THEN** 类目标签和服装网格位于底部区域，角色主体可见且 UI 覆盖比例 ≤30%。
- [ ] **AC-29**: **GIVEN** 任意可交互类目、卡片、按钮，**WHEN** 检查其实际热区，**THEN** 宽高均 ≥44px。
- [ ] **AC-30**: **GIVEN** 移动端无 hover，**WHEN** 玩家只使用触摸操作，**THEN** 锁定说明、选中状态、已装备状态仍可被看见或触发。
- [ ] **AC-31**: **GIVEN** Godot 4.6 双焦点系统，**WHEN** 鼠标 hover 与键盘 focus 位于不同控件，**THEN** UI 同时显示各自状态且不互相覆盖。
- [ ] **AC-32**: **GIVEN** 任意状态差异（locked/disabled/selected/equipped），**WHEN** 仅移除颜色差异，**THEN** 仍可通过图标、形状或位置区分状态。

### 稳定性与性能

- [ ] **AC-33**: **GIVEN** 当前类目为空，**WHEN** 衣橱 UI 渲染网格，**THEN** 显示空状态，不报错、不自动切换类目。
- [ ] **AC-34**: **GIVEN** 拖拽中发生场景离开或 `drag_ended(interrupted=true)`，**WHEN** 衣橱 UI 收到中断，**THEN** 清理拖拽预览，不输出装备事件。
- [ ] **AC-35**: **GIVEN** 标准 MVP 数据集（约 30 件物品），**WHEN** 切换类目，**THEN** UI 重建/更新卡片耗时 <16ms，不造成可感知卡顿。
- [ ] **AC-36**: **GIVEN** 连续快速点击类目标签 10 次，**WHEN** UI 处理切换，**THEN** 最终显示最后一次点击的 enabled 类目，不出现重复卡片或空引用错误。

## Open Questions

| 问题 | 负责人 | 截止 | 决议 |
|------|--------|------|------|
| `systems-index.md` 是否应将衣橱 UI 的依赖补充为包含 `进度管理`？ | 系统设计师 | 已完成 | 已补充。衣橱 UI 实际依赖 `ProgressManager.get_visible_categories()` 和 `is_item_unlocked()`，系统索引已与 GDD 保持一致 |
| 拖拽换装系统最终是否沿用 `item_drag_dropped(item_id, position)` 与 `item_selected_for_equip(item_id)` 作为输入接口？ | 拖拽换装 GDD 作者 | 已完成 | 已确认沿用。`design/gdd/drag-dress-up.md` 已将该组接口正式化；若未来改名，必须同步修订衣橱 UI 与拖拽换装 GDD |
| 点击替代流程中的“角色区域/确认应用区域”具体 UX 如何呈现？ | UX 设计师 | `/ux-design wardrobe-ui` | 本 GDD 只定义行为要求；具体点击区域、提示文案、焦点路径在 UX spec 中细化 |
| 类目图标是否需要独立资产，还是 MVP 先使用文字 + 锁图标？ | 美术总监 / UI 设计师 | 资产规格阶段 | MVP 可先使用文字标签 + 锁图标；若 art bible/UX spec 要求图标化类目，则在 `/asset-spec system:wardrobe-ui` 中补充 |
