# 服装解锁

> **Status**: Approved
> **Author**: User + Codex agents
> **Last Updated**: 2026-06-09
> **Implements Pillar**: 每日陪伴, 随心搭配, 即时有感

## Overview

服装解锁是「每日穿搭」中承接晚安后的轻量展示系统。它不负责计算哪些服装已经解锁，也不推进天数或写入进度；权威解锁结果由进度管理在 `advance_day()` 中产生，并通过 `items_unlocked` 或 `get_newly_unlocked_items()` 提供。服装解锁系统只消费这些新物品 ID，向服装数据库查询名称、类目和缩略图，并在合适的 UI 时机展示“新衣服到了”的柔和提示，同时把新物品 ID 传给衣橱 UI 用于一次性高亮。它存在的目的，是把数据层的解锁变化转化为玩家能感受到的每日小惊喜：不评分、不结算、不制造压力，只让衣橱在每天结束后自然变得更丰富。

## Player Fantasy

服装解锁服务的是“明天衣橱又多了一点点”的温柔期待。玩家不需要追求高分、达成挑战或完成任务清单；她只是在一天结束后看到几件新衣服轻轻出现，感觉角色的生活和衣橱都随着时间自然延展。这个系统应该像朋友把新衣服放进衣柜，而不是像游戏发放奖励：语气克制、反馈清楚、情绪明亮但不喧闹。玩家真正感受到的不是“我赢得了什么”，而是“她的生活又多了一种可以尝试的样子”。

## Detailed Design

### Core Rules

1. **只展示，不判定**  
   服装解锁系统不计算服装是否解锁，不读取或修改 `current_day`，不调用 `advance_day()`，不写入 `unlock_progress`。所有权威解锁结果来自 `ProgressManager.items_unlocked(new_items)` 或 `ProgressManager.get_newly_unlocked_items()`。

2. **晚安后触发**  
   当场景/状态管理（GameState）完成 `GOODNIGHT -> MAIN_MENU` 流程、ProgressManager 已执行 `advance_day()` 后，若 `items_unlocked(new_items)` 携带非空 ID 列表，服装解锁系统进入提示流程。

3. **空列表不展示**  
   若 `new_items` 为空数组，系统不显示任何解锁提示，不播放解锁音效，不向衣橱 UI 发送新物品高亮请求。

4. **物品详情来自服装数据库**  
   系统使用 `WardrobeDatabase.get_item_by_id(item_id)` 将新解锁 ID 解析为显示数据，包括 `name`、`category`、`thumbnail_path`、`tags`。若某个 ID 查不到物品数据，该 ID 被跳过，不阻断其余物品展示。

5. **提示语气轻柔**  
   解锁提示使用“新衣服到了”“衣橱多了几件新单品”一类表达，不使用“奖励”“任务完成”“达成”“结算”“稀有”等高压力或抽卡式词汇。

6. **一次性衣橱高亮**  
   系统把本次有效新物品 ID 列表传给衣橱 UI。衣橱 UI 在下一次渲染对应卡片时显示一次性新物品高亮；高亮在玩家看见或进入衣橱后自然消退，不改变物品可用性。

7. **不阻塞主循环**  
   解锁提示是软 UI。玩家可以关闭、跳过或稍后进入衣橱；提示失败、缩略图缺失或音效不可用时，不影响天数推进、主菜单进入或衣橱使用。

### States and Transitions

| State | Description | Enter | Exit |
|---|---|---|---|
| `IDLE` | 没有待展示的新解锁物品 | 默认状态；提示关闭后 | 收到非空 `items_unlocked` |
| `PENDING_PRESENTATION` | 已收到新物品 ID，等待安全 UI 时机展示 | `items_unlocked(new_items)` 且有效物品非空 | 主菜单可承载提示时 |
| `PRESENTING` | 正在展示新衣服提示 | 主菜单进入稳定状态后 | 玩家关闭提示、点击进入衣橱，或提示自动结束 |
| `HIGHLIGHT_QUEUED` | 新物品 ID 已交给衣橱 UI，等待衣橱卡片高亮 | 提示展示完成或玩家直接进入衣橱 | 衣橱 UI 确认高亮已消费 |
| `SUPPRESSED` | 本次没有可展示内容 | 空列表、所有 ID 无效、或第 7 天完成无新解锁 | 回到 `IDLE` |

### Interactions with Other Systems

| System | Direction | Interaction |
|---|---|---|
| 进度管理 | 输入 | 监听 `items_unlocked(Array[String])`；必要时读取 `get_newly_unlocked_items()`。不调用 `advance_day()`，不写进度。 |
| 服装数据库 | 输入 | 调用 `get_item_by_id(item_id)` 获取名称、类目、缩略图和标签，用于提示卡展示。 |
| 衣橱 UI | 输出 | 发送 `newly_unlocked_item_ids` 或等价接口，让新物品卡片显示一次性高亮。 |
| 主菜单/晚安 UI | 时机协调 | 提示出现在晚安流程结束、返回主菜单后的安全 UI 时机；不嵌入晚安 UI 内部结算。 |
| 音频管理 | 输出 | 请求音频事件 `progress.items_unlocked`；音频管理将其映射到 `progress.unlock_soft` 或等价轻提示音资产。音频失败不影响 UI。 |
| 保存/加载 | 间接依赖 | 不直接读写存档；解锁记录由进度管理和保存/加载系统维护。 |

## Formulas

本系统不新增权威解锁公式。服装是否解锁、每日新增哪些物品，均由进度管理系统计算并提供。本系统只引用进度管理已定义的公式：

```text
new_items(day) = ids(WardrobeDatabase.get_unlocked_items(day)) - ids(WardrobeDatabase.get_unlocked_items(day - 1))
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| 当前天数 | `day` | int | 1-7（MVP） | 由 ProgressManager 维护的当前游戏天数 |
| 当日新增物品 | `new_items` | Array[String] | 0-4 常规；允许为空 | ProgressManager 在 `advance_day()` 后计算出的新增服装 ID 列表 |
| 有效展示物品 | `valid_display_items` | Array[Dictionary] | 0 到 `new_items.size()` | `new_items` 中能被 `WardrobeDatabase.get_item_by_id()` 成功解析的物品详情 |

展示过滤规则：

```text
valid_display_items = [
  WardrobeDatabase.get_item_by_id(id)
  for id in new_items
  if WardrobeDatabase.get_item_by_id(id) != null
]
```

**Output Range**:  
`valid_display_items.size()` 通常为 3-4；允许为 0。若为 0，系统不展示提示，也不请求音频或衣橱高亮。

**Example**:  
`new_items = ["top_cardigan", "shoes_canvas", "hair_ribbon"]`，其中 `hair_ribbon` 在服装数据库中查不到，则：

```text
valid_display_items = [
  top_cardigan_data,
  shoes_canvas_data
]
```

系统展示 2 件新衣服，并只把这 2 个有效 ID 传给衣橱 UI 高亮。

## Edge Cases

- **If `items_unlocked` 收到空数组**: 不显示解锁提示，不请求音频事件 `progress.items_unlocked`，不向衣橱 UI 发送高亮列表；系统回到 `IDLE`。空解锁是合法设计状态，不应被当作错误。
- **If `new_items` 中包含无效 `item_id`**: 对每个 ID 调用 `WardrobeDatabase.get_item_by_id(item_id)`；返回 `null` 的 ID 被跳过。若仍有有效物品，继续展示有效物品；若全部无效，不显示提示并回到 `IDLE`。
- **If 新解锁物品的缩略图加载失败**: 提示卡显示占位缩略图或仅显示名称与类目；该物品仍被视为有效展示物品，并仍可传给衣橱 UI 高亮。资源失败不改变解锁状态。
- **If 第 7 天完成时没有 `items_unlocked` 信号**: 系统不展示新解锁提示。第 7 天完成只由进度管理标记通关；服装解锁系统不尝试创建第 8 天提示。
- **If 提示尚未展示时玩家快速进入衣橱**: 系统跳过主菜单弹层，直接把有效新物品 ID 交给衣橱 UI；衣橱卡片显示一次性高亮。玩家不需要返回主菜单才能看到新物品。
- **If 提示正在展示时玩家点击进入衣橱**: 提示立即关闭，状态进入 `HIGHLIGHT_QUEUED`，并请求衣橱 UI 高亮对应物品。关闭提示不丢失本次新物品列表。
- **If 衣橱 UI 尚未初始化**: 系统保留 `newly_unlocked_item_ids` 到本次会话内的待消费队列；衣橱 UI 初始化完成并请求时再交付。该队列不写入存档。
- **If 衣橱 UI 已消费高亮**: 系统清空本次待高亮列表并回到 `IDLE`。同一批物品不会在同一次会话中反复高亮。
- **If `items_unlocked` 重复发射相同列表**: 系统按 `item_id` 去重；已经处于 `PRESENTING` 或 `HIGHLIGHT_QUEUED` 的同一 ID 不重复加入，不重复播放音效。
- **If 音频管理不可用或 Web 音频尚未解锁**: 解锁提示仍正常显示。音频事件可以被音频管理丢弃或按自身队列规则处理；服装解锁系统不显示技术错误。
- **If 主菜单无法承载提示层**: 系统保持 `PENDING_PRESENTATION`，直到主菜单进入稳定状态；若玩家直接进入衣橱，则按“快速进入衣橱”规则处理。
- **If 玩家关闭提示但不进入衣橱**: 系统仍保留一次性高亮队列，直到下一次衣橱 UI 展示对应卡片后消费。提示关闭只表示不看弹层，不表示放弃新物品高亮。
- **If 存档重置或新游戏开始**: 本系统清空所有本次会话内待展示、待高亮列表。初始 `unlock_day = 1` 的服装是默认可用物品，不通过服装解锁提示展示。
- **If 旧天数重玩后返回主菜单**: 不展示新解锁提示。重玩旧天数不会触发新的 `advance_day()` 解锁结果，玩家可使用已解锁的后期服装，但不会再次收到“新衣服到了”。
- **If 新解锁物品属于当前不可见类目**: 仍可在提示中展示该物品名称和缩略图，但衣橱 UI 高亮只在该类目可见时消费；若该类目仍显示为灰色标签，高亮等待可见后再显示，或由衣橱 UI 以“新”标记附着在灰色类目标签上。

## Dependencies

| System | Dependency Level | Interface / Data | Design Contract |
|---|---|---|---|
| 进度管理 | 强依赖 | `items_unlocked(Array[String])`、`get_newly_unlocked_items()` | 服装解锁只消费新解锁 ID；不调用 `advance_day()`，不修改 `current_day`、`highest_day_completed` 或 `unlock_progress`。 |
| 服装数据库 | 强依赖 | `get_item_by_id(item_id)`；读取 `name`、`category`、`thumbnail_path`、`tags`、`unlock_day` | 用于把 ID 解析为可展示内容。找不到的 ID 跳过，不阻断其他物品。 |
| 衣橱 UI | 强依赖 | `newly_unlocked_item_ids` 或等价高亮接口；类目标签与物品卡片渲染状态 | 接收本次有效新物品 ID，并在下一次进入衣橱时显示一次性高亮。未可见类目仍以灰色标签出现，新物品标记可附着在灰色标签上。 |
| 主菜单/晚安 UI | 中依赖 | `GOODNIGHT -> MAIN_MENU` 后的安全 UI 时机；提示层承载位置 | 解锁提示出现在晚安流程结束后的主菜单阶段，不嵌入晚安 UI 结算；若主菜单无法承载，则降级为衣橱高亮。 |
| 音频管理 | 弱依赖 | 音频事件 `progress.items_unlocked`，映射资产 `progress.unlock_soft` 或等价轻提示音 | 提供柔和提示音。音频不可用、Web 音频未解锁或事件被丢弃时，不影响视觉提示和衣橱高亮。 |
| 保存/加载 | 间接依赖 | `unlock_progress` 由进度管理维护 | 本系统不直接读写存档。一次性提示/高亮队列只存在于本次会话，不持久化。 |
| 资源加载器 | 弱依赖 | 缩略图加载结果、占位图 | 缩略图成功时展示服装卡；失败时使用占位图或仅显示名称/类目，不改变解锁状态。 |
| 场景/状态管理（GameState） | 中依赖 | 场景状态、主菜单稳定状态、衣橱进入事件 | 用于判断何时从 `PENDING_PRESENTATION` 进入 `PRESENTING`，或何时直接交付衣橱高亮。 |

**Dependency Rules**

- 进度管理是解锁事实的唯一权威来源。
- 服装数据库是服装展示数据的唯一权威来源。
- 衣橱 UI 是物品卡片和类目标签表现的唯一承载系统。
- 服装解锁系统不拥有任何长期存档字段。
- 任一弱依赖失败时，系统必须降级而不是阻断每日循环。

## Tuning Knobs

| Knob | Default | Safe Range | Owner | Effect |
|---|---:|---:|---|---|
| `UNLOCK_PROMPT_MIN_VISIBLE_SECONDS` | `1.5` | `0.8-3.0` | UI/UX | 解锁提示最短可见时间。过短会让玩家看不清新衣服；过长会让晚安后的返回节奏变慢。 |
| `UNLOCK_PROMPT_AUTO_DISMISS_SECONDS` | `0` | `0-8.0` | UI/UX | 自动关闭时间。`0` 表示不自动关闭，等待玩家点击。MVP 推荐 `0`，避免玩家错过新物品。 |
| `MAX_UNLOCK_CARDS_VISIBLE` | `4` | `1-6` | UI/UX | 提示中同时展示的新物品卡片数量。MVP 每天通常 3-4 件，默认 4 可完整展示常规解锁。 |
| `UNLOCK_CARD_STAGGER_SECONDS` | `0.12` | `0-0.25` | UI/Animation | 多张新物品卡依次出现的间隔。过大像结算动画；过小则缺少“轻轻出现”的感觉。 |
| `WARDROBE_NEW_HIGHLIGHT_DURATION_SECONDS` | `2.0` | `0.8-5.0` | UI/UX | 衣橱中新物品高亮持续时间。高亮结束后卡片回到普通已解锁状态。 |
| `WARDROBE_NEW_BADGE_CONSUME_MODE` | `on_seen` | `on_seen` / `on_enter_wardrobe` / `on_item_click` | UI/UX | 一次性新物品标记何时消费。MVP 推荐 `on_seen`：卡片实际出现在视口后消费。 |
| `UNLOCK_SFX_ENABLED` | `true` | `true/false` | Audio | 是否请求轻提示音。关闭后只显示视觉提示。 |
| `UNLOCK_PROMPT_ALLOW_SKIP` | `true` | `true/false` | UI/UX | 玩家是否能立即关闭提示或进入衣橱。MVP 必须保持 `true`，避免提示阻塞每日循环。 |
| `INVALID_ITEM_LOG_LEVEL` | `warning` | `silent` / `warning` / `error` | QA/Tools | 无效 `item_id` 的日志级别。MVP 推荐 `warning`，不阻断展示但便于排查数据问题。 |

**Non-Tunable Boundaries**

- 每日解锁数量不由本系统调整；它来自服装数据库的 `unlock_day` 分布和进度管理的差集计算。
- 当前天数、最高完成天数、`unlock_progress` 不由本系统调整。
- 物品是否可用不由提示是否看过决定；只由进度管理判定。
- 初始服装不通过本系统提示展示。

## Visual/Audio Requirements

服装解锁的视觉与音频反馈必须保持“轻轻出现”的氛围：它是一阵柔和的新鲜感，不是结算、抽卡或成就弹窗。

### Visual Requirements

- 解锁提示使用轻量面板或覆盖层，出现在主菜单可承载的安全区域，不遮挡核心导航超过必要时间。
- 新物品卡片以缩略图、名称、类目标签组成；卡片尺寸应足以辨认服装轮廓，但不需要展示完整穿搭预览。
- 多件物品出现时使用短间隔的淡入或轻微上移，不使用爆闪、粒子爆发、强旋转、稀有度光柱或宝箱式表现。
- 未能加载缩略图时，显示统一占位图或以名称 + 类目标签替代，保持布局稳定。
- 衣橱中新物品高亮使用柔和描边、微光或小型“新”标签；不得改变锁定/已解锁状态的颜色语义。
- 若新物品属于当前不可见类目，灰色类目标签仍应出现，并可附着温和的新物品提示标记；标记不得让玩家误以为该类目已经完全开放。
- 动画应在低端 Web 设备上保持轻量，避免大量透明叠层、复杂 shader 或持续粒子。

### Audio Requirements

- 解锁提示请求音频管理播放事件 `progress.items_unlocked`；音频管理负责将该事件映射到 `progress.unlock_soft` 或等价轻提示音资产。
- 音效情绪应是“小惊喜、柔光浮现”，可以比普通 UI 点击稍亮，但不得使用 fanfare、强上升音阶、老虎机/抽卡式音效或成就音。
- 同一批新物品只触发一次提示音；多张卡片依次出现时不逐张重复播放完整解锁音。
- Web 音频尚未解锁、玩家静音或音频管理不可用时，视觉提示仍正常展示。
- 若玩家快速跳过提示并进入衣橱，不补播已错过的解锁音效。

### Performance Requirements

- 解锁提示最多同时展示 `MAX_UNLOCK_CARDS_VISIBLE` 张卡片。
- 动画总时长应短于玩家等待感阈值，默认不超过 2 秒进入可关闭状态。
- 提示层不应触发主菜单、衣橱 UI 或角色渲染的大规模重排。

## UI Requirements

服装解锁 UI 由两个轻量触点组成：晚安后返回主菜单时的新衣提示，以及下一次进入衣橱时的新物品高亮。两者共享同一批有效 `item_id`，但都不改变物品可用性。

### Unlock Prompt

- 提示出现在 `GOODNIGHT -> MAIN_MENU` 完成、主菜单进入稳定状态之后。
- 提示标题使用柔和表达，例如“新衣服到了”或“衣橱多了几件新单品”。
- 提示正文避免“奖励”“结算”“任务完成”“达成”等词。
- 每张新物品卡显示缩略图、物品名称、类目标签。
- 当新物品数量 ≤ `MAX_UNLOCK_CARDS_VISIBLE` 时，全部显示。
- 当新物品数量 > `MAX_UNLOCK_CARDS_VISIBLE` 时，显示前 `MAX_UNLOCK_CARDS_VISIBLE` 件，并提供“还有 N 件在衣橱里”等克制提示；不使用稀有度或排行。展示上限不影响衣橱高亮，所有有效新物品 ID 仍传递给衣橱 UI。
- 提示至少提供两个操作：
  - 关闭/稍后再看：关闭提示，保留衣橱一次性高亮。
  - 去衣橱：关闭提示并请求进入衣橱，衣橱消费同一批高亮 ID。
- 提示不得阻止玩家继续使用主菜单；若提示层存在，主菜单关键导航仍应可通过关闭或跳转恢复。

### Wardrobe Highlight

- 衣橱 UI 接收 `newly_unlocked_item_ids` 后，在对应已解锁物品卡上显示一次性“新”标记、柔和描边或短暂微光。
- 高亮不改变卡片的锁定/已解锁判定；卡片可用性仍由 `ProgressManager.is_item_unlocked(item_id)` 决定。
- 当玩家实际看见新物品卡片后，按 `WARDROBE_NEW_BADGE_CONSUME_MODE` 消费该物品的新标记。
- 若新物品位于当前未选中的类目，类目标签可显示小型“新”提示点，引导玩家切换。
- 若新物品属于当前不可见类目，该类目仍以灰色标签显示，并可附着温和“新”提示点；点击灰色标签时不进入该类目，只显示原有“第 N 天开放/解锁”类提示。
- 新标记不能让玩家误以为未开放类目已经可用。
- 若玩家关闭主菜单提示但稍后进入衣橱，高亮仍应出现一次。
- 若衣橱高亮已消费，同一批物品不在本次会话内重复显示“新”。

### Accessibility and Input

- 所有按钮触控目标不小于 44×44 px。
- 关闭和去衣橱按钮必须支持鼠标点击、触摸点击和键盘/手柄焦点确认。
- 提示层打开时，焦点应进入提示层；关闭后焦点返回触发前的主菜单安全位置。
- 玩家应能通过明确的关闭按钮退出提示，不依赖自动消失。
- 卡片动画不得是理解信息的唯一方式；名称和类目文本必须可读。
- 若玩家启用减少动态效果设置，卡片使用淡入而不是位移或弹性动效。

## Acceptance Criteria

- [ ] **AC-1**: **GIVEN** ProgressManager 发射 `items_unlocked(["top_cardigan", "shoes_canvas"])`，**WHEN** 主菜单进入稳定状态，**THEN** 服装解锁系统展示新衣提示，并显示 2 张有效新物品卡。
- [ ] **AC-2**: **GIVEN** `items_unlocked([])` 被发射，**WHEN** 服装解锁系统收到信号，**THEN** 不显示提示、不请求音频事件 `progress.items_unlocked`、不向衣橱 UI 发送高亮列表。
- [ ] **AC-3**: **GIVEN** `new_items` 包含一个无效 ID，**WHEN** `WardrobeDatabase.get_item_by_id(invalid_id)` 返回 `null`，**THEN** 系统跳过该 ID，并继续展示其他有效物品。
- [ ] **AC-4**: **GIVEN** `new_items` 中所有 ID 都无效，**WHEN** 系统完成展示过滤，**THEN** 不显示提示、不请求音频、不发送衣橱高亮，并回到 `IDLE`。
- [ ] **AC-5**: **GIVEN** 新物品缩略图加载失败，**WHEN** 提示卡渲染，**THEN** 卡片显示占位缩略图或名称 + 类目，不影响该物品进入衣橱高亮列表。
- [ ] **AC-6**: **GIVEN** 服装解锁提示正在展示，**WHEN** 玩家点击关闭/稍后再看，**THEN** 提示关闭，主菜单恢复可操作，并且本批新物品 ID 仍保留给衣橱一次性高亮。
- [ ] **AC-7**: **GIVEN** 服装解锁提示正在展示，**WHEN** 玩家点击去衣橱，**THEN** 提示关闭，场景/状态管理（GameState）收到进入衣橱请求，衣橱 UI 接收同一批 `newly_unlocked_item_ids`。
- [ ] **AC-8**: **GIVEN** 玩家在提示出现前快速进入衣橱，**WHEN** 衣橱 UI 初始化完成，**THEN** 系统不强制返回主菜单展示提示，而是直接交付新物品高亮列表。
- [ ] **AC-9**: **GIVEN** 衣橱 UI 接收 `newly_unlocked_item_ids`，**WHEN** 对应物品卡片渲染且物品已解锁，**THEN** 卡片显示一次性“新”标记、柔和描边或等价高亮。
- [ ] **AC-10**: **GIVEN** 新物品卡片已在衣橱中实际出现在视口，**WHEN** `WARDROBE_NEW_BADGE_CONSUME_MODE == "on_seen"`，**THEN** 该物品的新标记被消费，并且本次会话内不再次显示。
- [ ] **AC-11**: **GIVEN** 新物品属于未选中的可见类目，**WHEN** 衣橱类目标签渲染，**THEN** 对应类目标签显示小型“新”提示点，直到该类目内新物品高亮被消费。
- [ ] **AC-12**: **GIVEN** 新物品属于当前不可见类目，**WHEN** 衣橱类目标签渲染，**THEN** 该类目仍以灰色标签出现，可附着温和“新”提示点，但点击后不进入该类目，只显示开放/解锁提示。
- [ ] **AC-13**: **GIVEN** 同一批 `items_unlocked` 被重复发射，**WHEN** 系统处于 `PRESENTING` 或 `HIGHLIGHT_QUEUED`，**THEN** 同一 `item_id` 不重复加入列表，不重复播放提示音。
- [ ] **AC-14**: **GIVEN** 音频管理可用且 `UNLOCK_SFX_ENABLED == true`，**WHEN** 有效新物品提示开始展示，**THEN** 系统请求一次音频事件 `progress.items_unlocked`，由音频管理映射到 `progress.unlock_soft` 或等价轻提示音资产。
- [ ] **AC-15**: **GIVEN** 音频管理不可用、Web 音频未解锁或玩家静音，**WHEN** 有效新物品提示展示，**THEN** 视觉提示仍正常显示，且系统不报阻断错误。
- [ ] **AC-16**: **GIVEN** 第 7 天完成时 ProgressManager 只发射 `day_completed(7)` 且不发射 `items_unlocked`，**WHEN** 返回主菜单，**THEN** 服装解锁系统不创建第 8 天提示。
- [ ] **AC-17**: **GIVEN** 玩家开始新游戏或存档重置，**WHEN** 进度管理重新初始化，**THEN** 服装解锁系统清空本次会话内所有待展示和待高亮列表。
- [ ] **AC-18**: **GIVEN** 初始 `unlock_day = 1` 的服装在首次启动时可用，**WHEN** 主菜单或衣橱首次显示，**THEN** 服装解锁系统不把这些初始物品作为“新衣服到了”提示展示。
- [ ] **AC-19**: **GIVEN** 玩家重玩旧天数后返回主菜单，**WHEN** 没有新的 `items_unlocked` 信号，**THEN** 不显示新衣提示，也不重新高亮旧物品。
- [ ] **AC-20**: **GIVEN** 提示层打开，**WHEN** 使用鼠标、触摸或键盘焦点操作关闭/去衣橱按钮，**THEN** 两个操作均可完成，且按钮触控目标不小于 44×44 px。
- [ ] **AC-21**: **GIVEN** 提示层正在展示，**WHEN** 玩家关闭提示或进入衣橱，**THEN** 日常循环、主菜单导航和衣橱进入不被解锁提示阻塞。
- [ ] **AC-22**: **GIVEN** 有效新物品数量超过 `MAX_UNLOCK_CARDS_VISIBLE`，**WHEN** 提示渲染，**THEN** 同屏最多显示 `MAX_UNLOCK_CARDS_VISIBLE` 张卡片，并以克制文案提示剩余数量；所有有效新物品 ID 仍进入衣橱高亮列表。

## Open Questions

| Question | Owner | Target Resolution | Notes |
|---|---|---|---|
| 解锁提示层在主菜单中的具体位置与尺寸如何定义？ | UX Designer | UX spec 阶段 | GDD 已定义出现时机和行为；若提示层复用主菜单 modal 组件，可并入 `/ux-design main-menu-goodnight-ui`；若包含独立动效和卡片布局，应运行 `/ux-design clothing-unlock`。 |
| 衣橱 UI 如何判断“玩家实际看见了新物品卡片”？ | UI Programmer / UX Designer | 实现设计前 | MVP 推荐基于卡片进入可见视口消费 `on_seen`，但需要结合衣橱滚动/分页实现确认。 |
| 灰色未可见类目上的“新”提示点采用什么样式？ | UI Artist / UX Designer | UI visual pass | 必须避免让玩家误以为类目已经开放；建议使用低饱和小圆点或轻量标签。 |
| `newly_unlocked_item_ids` 是由服装解锁系统主动推给衣橱 UI，还是衣橱 UI 进入时拉取？ | UI Programmer / Architect | ADR 或实现前 | GDD 只要求交付同一批 ID；具体通信方式应在架构设计中决定。 |
| 是否需要为服装解锁提示单独创建 UX spec？ | Producer / UX Designer | Pre-Production gate | 若提示层复用主菜单 modal 组件，可合并进 `/ux-design main-menu-goodnight-ui`；若包含独立动效和卡片布局，应单独运行 `/ux-design clothing-unlock`。 |
