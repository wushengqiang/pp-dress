# UX Spec: Main Menu / Goodnight UI

> **Status**: In Design
> **Author**: user + ux-designer
> **Platform Target**: Web
> **Last Updated**: 2026-06-22
> **Journey Phase(s)**: unknown - no journey map
> **Template**: UX Spec

---

## Purpose & Player Need

主菜单/晚安 UI 的目的，是把每日循环包装成一次温柔的“翻开与合上”：玩家打开游戏时，主菜单像穿搭日记的新一页，清楚告诉她今天是第几天、可以安心开始今天；玩家结束每日场景后，晚安页像把这一页轻轻合上，确认今天已经完成，并让她带着安静的满足回到主菜单或结束本次会话。

这个界面服务的玩家需要不是“管理进度”，而是“被温柔地接住流程”。玩家来到主菜单时，想知道自己在哪里、今天是否可以继续、下一步该做什么；玩家来到晚安页时，想获得一个不催促、不结算、不评价的收束时刻，确认今天的穿搭和小故事已经自然结束。主菜单和晚安页都必须让功能清楚可用，但语气上不能像系统菜单、任务面板或胜利结算。

如果这个界面不存在，游戏的每日节奏会失去入口和收束，玩家会感觉自己只是在切换状态；如果它难用或语气太硬，核心体验就会从“每日陪伴”变成“操作流程”。因此，主菜单/晚安 UI 必须始终保持低压力、可读、稳定，把状态转换藏在温柔的日记感之后，让玩家感觉每天开始和结束都被妥帖照顾。

---

## Player Context on Arrival

玩家到达主菜单时，通常处在一次会话的开始、一次晚安后的返回，或完成一周后的回望时刻。她可能只是刚打开网页，想轻松看看今天进行到哪里；也可能刚从晚安页回到主菜单，准备自然结束本次游玩；如果已经完成第 7 天，她则是在回看这本穿搭日记，而不是被推向第 8 天。主菜单应假设玩家情绪是放松、开放、低承诺的：她可以马上开始今天，也可以停留、离开或之后再回来。

玩家到达晚安页时，刚刚完成当天穿搭、看完每日场景和轻叙事对话。她不需要再做复杂选择，也不应该被要求确认奖励、评分或任务结果；她需要的是一个短暂停顿，确认今天已经被温柔收好。晚安页应假设玩家情绪是安静、满足、略带留恋的，界面语气要像“今天到这里就很好”，而不是“流程完成，请继续”。

晚安页采用轻量回顾策略：如果 `GameState.context["equipped_items"]` 和角色展示资源可用，可以预留角色/穿搭回顾区域，让玩家看到今天的选择被保留下来；如果上下文缺失或资源未就绪，则显示通用晚安画面和文案，不阻塞继续。这个回顾不是结算，也不评价搭配，只是让玩家感到今天的选择被温柔看见。

---

## Navigation Position

主菜单/晚安 UI 位于每日循环的两个边界位置：主菜单是一次日记循环的入口，晚安页是一次日记循环的收束。它们共同定义玩家每天“从哪里开始”和“在哪里结束”，但不承担衣橱搭配、每日场景播放或对话推进本身。

主流程位置为：

```text
Boot / Resume
  → Main Menu
  → Wardrobe UI
  → Daily Scene + Dialogue UI
  → Goodnight UI
  → Main Menu
```

主菜单是顶层入口状态，由 `MAIN_MENU` 驱动。普通模式下，它通向 `Wardrobe UI`；通关模式下，它仍停留在 `MAIN_MENU`，但切换为 completed variant，提供温柔完成提示、重玩入口或退出入口，不显示第 8 天。

晚安页是独立的 `GOODNIGHT` 状态，而不是每日场景内的覆盖层。它从 `Daily Scene + Dialogue UI` 完成后进入，玩家点击“明天见/继续”后请求 `GOODNIGHT → MAIN_MENU`。进度推进、天数保持和第 7 天完成语义由 GameState / ProgressManager 处理，主菜单/晚安 UI 只负责显示当前位置并发出用户意图。

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Boot / Resume | 游戏初始化完成，`GameState.current_state == MAIN_MENU` | 当前天数、最高完成天数、是否有未完成会话、主菜单模式 |
| Goodnight UI | 玩家点击“明天见/继续”，GameState 完成 `GOODNIGHT → MAIN_MENU` | 刚结束的一天、可能产生的新解锁提示、下一次可开始的天数 |
| Wardrobe UI | 玩家取消当天搭配并确认返回 | 当前天数、本次临时穿搭编辑被放弃 |
| Completed Week Flow | 第 7 天晚安后返回主菜单 | `highest_day_completed >= 7`，进入 completed variant，不显示第 8 天 |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Wardrobe UI | 玩家在普通主菜单点击“开始今天” | 请求 `GameState.request_transition(State.WARDROBE)`；按钮在请求期间临时锁定，避免重复触发 |
| Goodnight UI | 每日场景/对话结束后请求 `DAILY_SCENE → GOODNIGHT` | 进入独立 `GOODNIGHT` 状态，显示当天结束语和继续按钮 |
| Main Menu | 玩家在晚安页点击“明天见/继续” | 请求 `GameState.request_transition(State.MAIN_MENU)`；进度推进由 GameState / ProgressManager 执行 |
| Completed Main Menu | 第 7 天晚安后继续 | 返回主菜单 completed variant，显示一周完成提示、重玩入口或退出入口 |
| Farewell / Safe Idle | 玩家点击退出，或 Web 端 `QUIT` 不可关闭窗口 | 发出退出意图；若浏览器不能关闭页面，显示温柔告别状态，不展示技术错误 |
| Replay Flow Placeholder | 通关模式下玩家点击重玩入口 | UI 只发出 `replay_day_requested` 或等价意图；具体重玩日选择由后续 UX / GameState 设计决定 |

---

## Layout Specification

### Information Hierarchy

主菜单/晚安 UI 的信息层级遵循“情绪先到、操作清楚、系统退后”的原则。画面可以用角色、房间或日记式背景建立陪伴感，但可交互信息必须保持极简，避免像任务面板或系统菜单。

**Main Menu Default**
1. 游戏标题 / 日记入口感
2. 当前天数或今日标题
3. “开始今天”主操作
4. 退出入口
5. 新衣提示入口或轻量提示（仅当服装解锁系统在主菜单稳定后接入）

**Goodnight Summary**
1. 今日结束语
2. 角色/穿搭轻量回顾区域
3. 当前天数或今日标题
4. “明天见/继续”主操作
5. 安静结束本次会话的语义

**Main Menu Completed**
1. 一周完成提示
2. 回望 / 重玩入口
3. 退出入口
4. 第 7 天或完成状态提示

**Farewell / Safe Idle**
1. 告别文案
2. 返回主菜单的弱入口
3. 稍后再来 / 可关闭浏览器的语义

主菜单允许展示背景中的角色或日记场景，强化“她在等你”的陪伴感；但角色不是可操作对象，也不应抢走“开始今天”的主操作焦点。晚安页的穿搭回顾同样是情绪承接，而不是结算、评分或奖励展示。

### Layout Zones

主菜单/晚安 UI 采用“上文案、下主视觉”的共用骨架，让主菜单、晚安页、通关模式和 Web 告别态共享同一套空间逻辑，只在内容密度上变化。

**桌面端**
- 顶部文案区：标题、当前天数或今日标题、结束语 / 完成提示
- 中部主视觉区：角色、房间、穿搭回顾或安全告别画面
- 底部操作区：主按钮（开始今天 / 明天见 / 重玩入口）
- 角落辅助区：退出入口、轻量提示或返回主菜单弱入口

**移动端**
- 顶部文案区：标题、天数、结束语
- 中部主视觉区：角色或通用晚安/告别画面
- 底部操作区：主按钮，放在拇指易触区域但不贴底
- 底部或角落辅助区：退出入口、重玩入口或轻提示

这个布局的原则是：文案先把玩家“安放”住，主视觉负责情绪，最后才出现操作按钮。这样主菜单不会像登录页，晚安页不会像结算页，通关模式也不会像管理面板。主按钮永远在视觉焦点附近，但不压过标题或回顾内容。

### Component Inventory

**顶部文案区**
- 标题文本：显示游戏标题或晚安页标题；非交互
- 当前天数 / 今日标题：显示 `第 {day} 天` 或完成状态；非交互
- 结束语 / 完成提示：显示当日收束文案或一周完成提示；非交互

**中部主视觉区**
- 主背景图：房间、晨光、台灯或通用告别画面；非交互
- 角色 / 穿搭回顾区：展示当前穿搭或晚安回顾；非交互
- 安全告别画面：Web 退出不可关闭时的静态告别表现；非交互
- 新衣提示卡组：仅在解锁系统接入主菜单时出现；可交互卡片或可关闭面板

**底部操作区**
- 主按钮：`开始今天` / `明天见` / `重玩入口`；交互主按钮
- 次要按钮：`退出`；交互按钮，弱化显示
- 弱返回入口：告别态返回主菜单；交互按钮，仅安全 idle 时出现

**角落辅助区**
- 轻量提示文本：如“第 7 天完成了”“稍后再来”；非交互
- 关闭图标按钮：关闭新衣提示或告别附加层；交互
- 轻提示徽标：用于新衣提示或 completed 状态的温和标记；非交互

这里有两个默认假设：
- `新衣提示卡组` 只在服装解锁系统接入主菜单时出现，不属于这次主菜单核心骨架。
- `安全告别画面` 不是一个新流程，只是 Web `QUIT` 不可关闭时的降级表现。

### ASCII Wireframe

```text
桌面端 - Main Menu / Goodnight / Completed
┌────────────────────────────────────────────────────────────┐
│                    游戏标题 / 日记入口感                    │
│                   第 N 天 / 今日结束语 / 完成提示          │
├────────────────────────────────────────────────────────────┤
│                                                            │
│                                                            │
│                 主背景图 / 角色 / 回顾画面                  │
│                                                            │
│             [穿搭回顾]   [安全告别画面]   [新衣提示]        │
│                                                            │
├────────────────────────────────────────────────────────────┤
│            [开始今天 / 明天见 / 重玩入口]                  │
│                        [退出]                              │
│                 [返回主菜单弱入口 / 关闭]                  │
└────────────────────────────────────────────────────────────┘

移动端 - Main Menu / Goodnight / Completed
┌────────────────────────────────────────────────────────────┐
│                   游戏标题 / 今日标题                      │
│                 第 N 天 / 结束语 / 完成提示                │
├────────────────────────────────────────────────────────────┤
│                                                            │
│                    主背景图 / 角色 / 回顾                   │
│                                                            │
│                                                            │
├────────────────────────────────────────────────────────────┤
│             [开始今天 / 明天见 / 重玩入口]                 │
│                        [退出]                              │
│                 [关闭 / 返回主菜单弱入口]                  │
└────────────────────────────────────────────────────────────┘
```

这个草图的意图很直接：
- 顶部只负责把玩家放进情绪里
- 中部是情绪主视觉，不是操作区
- 底部才是主行动
- `新衣提示` 作为可选浮层，不抢主菜单骨架
- 告别态和 completed mode 只是同骨架的内容替换

有两个细节我先标出来：
1. `新衣提示` 要不要在 wireframe 里保留为“可插入浮层”，还是完全不画进这份 spec，留给 `clothing-unlock`？
2. `退出` 和 `返回主菜单弱入口` 是否都要保留在移动端底部，还是只留一个弱入口就够？

---

## States & Variants

| State / Variant | Trigger | What Changes |
|-----------------|---------|--------------|
| `MAIN_MENU_DEFAULT` | `GameState.current_state == MAIN_MENU` 且 `highest_day_completed < 7` | 显示标题、当前天数、开始今天和退出入口；主操作可用，布局保持温柔欢迎感 |
| `MAIN_MENU_COMPLETED` | `GameState.current_state == MAIN_MENU` 且 `highest_day_completed >= 7` | 替换开始今天为温柔完成提示与重玩入口；不显示第 8 天，不改变主菜单骨架 |
| `GOODNIGHT_SUMMARY` | `GameState.current_state == GOODNIGHT` | 显示当天结束语、当前天数、继续按钮；若有 `equipped_items` 可显示轻量回顾区 |
| `FAREWELL_SAFE_IDLE` | Web 端 `QUIT` 无法关闭窗口，或玩家触发退出但平台不能真正退出 | 显示静态告别画面或安静结束状态；提供弱返回主菜单入口或关闭提示，不显示技术错误 |
| `ERROR_RETRY` | 状态切换失败、必要数据缺失且无法安全渲染当前主状态 | 显示温和错误提示与重试入口；保留最近一次可用主按钮或返回主菜单入口，不展示技术报错文案 |
| `UNLOCK_PROMPT` | `ProgressManager.items_unlocked(new_items)` 且主菜单进入稳定状态后可承载提示 | 显示新衣提示卡组和关闭/去衣橱操作；这是可关闭、可跳过的轻量浮层，不打断主菜单主流程 |
| `HIDDEN` | 当前状态不是 `MAIN_MENU` 或 `GOODNIGHT`，且没有安全告别/解锁提示需要显示 | UI 不显示主菜单或晚安主界面；不接收主流程输入 |
| `TRANSITION_LOCKED` | 玩家点击主按钮后，状态转换已请求但尚未完成 | 主按钮暂时 disabled，防止重复触发；按钮恢复后回到对应基础状态 |
| `LOADING_SAFE` | `GameState` 或 `ProgressManager` 尚未就绪，但主菜单需要显示安全界面 | 显示轻量加载或安静等待状态，不误判为通关，不显示错误 |

---

## Interaction Map

| Component | Action | Input | Feedback | Outcome |
|---|---|---|---|---|
| `开始今天` 主按钮 | 开始今日流程 | 点击 / 触摸 | 按钮高亮、轻微缩放、柔和确认音 | 请求 `GameState.request_transition(State.WARDROBE)`；按钮进入短暂锁定 |
| `明天见/继续` 主按钮 | 结束今天并回主菜单 | 点击 / 触摸 | 按钮高亮、短暂停留后确认音 | 请求 `GameState.request_transition(State.MAIN_MENU)`；由 GameState / ProgressManager 处理 `GOODNIGHT -> MAIN_MENU` |
| `退出` 次要按钮 | 发出退出意图 | 点击 / 触摸 | 弱高亮、轻柔收束音 | 发出 `State.QUIT` 或等价退出意图；Web 不可退出时进入安全告别态 |
| `重玩入口` | 进入重玩流程占位 | 点击 / 触摸 | 主按钮级高亮但弱于开始今天 | 发出 `replay_day_requested(day)` 或等价意图，不直接改天数 |
| `关闭新衣提示` | 关闭解锁浮层 | 点击 / 触摸 | 面板淡出、轻提示音可选 | 关闭 `UNLOCK_PROMPT`，保留衣橱一次性高亮 |
| `去衣橱` | 关闭解锁浮层并进入衣橱 | 点击 / 触摸 | 提示卡收起、主按钮确认音 | 关闭提示并请求进入衣橱；新物品高亮继续保留给衣橱 UI |
| `返回主菜单弱入口` | 从告别态返回主菜单 | 点击 / 触摸 | 弱按钮高亮 | 关闭安全告别态，回到 `MAIN_MENU_DEFAULT` 或 `MAIN_MENU_COMPLETED` |
| 背景 / 主视觉区 | 无操作 | 点击 / 触摸 | 无或仅轻微视觉反馈 | 不发生状态变化，避免误触跳转 |

我的默认假设是：
- 背景点击全部是 no-op，避免主菜单变得像“到处都能退出”的面板
- `去衣橱` 只在 `UNLOCK_PROMPT` 存在时出现
- `重玩入口` 先作为流程占位，不展开具体天数选择
- 没有把键盘/手柄写成主路径，因为项目当前输入配置是鼠标 + 触摸

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| 点击“开始今天” | `ui.menu.start_pressed` | `{ "current_day": day, "ui_mode": "MAIN_MENU_DEFAULT" }` |
| 点击“明天见/继续” | `ui.goodnight.continue_pressed` | `{ "current_day": day, "has_equipped_items": bool }` |
| 点击“退出” | `ui.menu.exit_pressed` | `{ "current_day": day, "ui_mode": ui_mode }` |
| 点击重玩入口 | `ui.menu.replay_pressed` | `{ "current_day": day, "highest_day_completed": highest_day_completed }` |
| 关闭新衣提示 | `progress.items_unlocked_prompt_closed` | `{ "item_ids": newly_unlocked_item_ids }` |
| 点击“去衣橱” | `progress.items_unlocked_prompt_enter_wardrobe` | `{ "item_ids": newly_unlocked_item_ids }` |
| Web 端进入安全告别态 | `ui.menu.exit_safe_idle` | `{ "reason": "quit_unavailable", "current_day": day }` |
| 进入 completed 主菜单 | `ui.menu.completed_entered` | `{ "highest_day_completed": highest_day_completed }` |

---

## Transitions & Animations

- 主菜单进入：0.5 秒以内的晨光式淡入，顶部文案先出现，中部主视觉随后完成显现，主按钮最后稳定下来。
- 晚安页进入：从每日场景自然切入的柔和淡出 / 淡入组合，像把今天翻到下一页，不做硬切。
- 主菜单退出到衣橱：主按钮点击后快速锁定，主界面轻微收拢并淡出到下一状态。
- 晚安页退出到主菜单：继续按钮点击后，当前页轻轻收束，先退主视觉，再回到主菜单骨架。
- `UNLOCK_PROMPT` 出现：轻微上移 + 淡入，卡片可短暂错峰出现，但总时长保持很短，不像结算动画。
- `UNLOCK_PROMPT` 关闭：淡出收起，保留衣橱高亮队列，不做强烈飞走动画。
- `FAREWELL_SAFE_IDLE`：尽量静态，只给极轻的停留感，不额外做复杂动画，避免 Web 退出状态显得“被卡住”。
- `TRANSITION_LOCKED`：按钮只做轻微压暗，不做明显抖动或警报反馈。
- 减少动态效果：如果系统存在 reduced motion 选项，所有进入/退出动画都降为快速淡入淡出，取消位移与错峰出现。

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| 当前游戏状态 | `GameState` / 场景状态管理 | Read | 用于决定显示 `MAIN_MENU`、`GOODNIGHT`、completed mode 或隐藏态 |
| 当前天数 | `GameState.get_current_day()` / `ProgressManager` | Read | 主菜单显示 `第 {day} 天`，晚安页显示当天结束语；显示层只做 clamp，不修正进度 |
| 最高完成天数 | `ProgressManager` | Read | 决定是否进入 `MAIN_MENU_COMPLETED`，以及是否显示重玩入口 |
| 当日穿搭上下文 | `GameState.context["equipped_items"]` | Read | 用于晚安页轻量回顾；缺失时使用通用晚安画面 |
| 新解锁物品 ID | `ProgressManager.items_unlocked(new_items)` | Read | 由服装解锁系统消费，用于主菜单提示与衣橱高亮 |
| 服装展示信息 | `WardrobeDatabase` | Read | 通过 `item_id` 解析 `name`、`category`、`thumbnail_path`、`tags` |
| 解锁提示显示状态 | `Unlock Prompt` 本地 UI 状态 | Write | 仅存于当前会话，用于关闭/跳过/进入衣橱的交互，不写存档 |
| 主菜单开始请求 | `GameState.request_transition(State.WARDROBE)` | Write | UI 只发出意图，不直接切场景 |
| 晚安继续请求 | `GameState.request_transition(State.MAIN_MENU)` | Write | 由 GameState / ProgressManager 处理 `GOODNIGHT -> MAIN_MENU` 与 `advance_day()` |
| 退出意图 | `GameState.request_transition(State.QUIT)` 或等价 | Write | Web 平台若无法关闭窗口，进入 `FAREWELL_SAFE_IDLE` |
| 重玩意图 | `replay_day_requested(day)` 或等价事件 | Write | UI 只发出占位意图，不直接修改 `current_day` |
| 音频事件 | `AudioManagement` 事件总线 | Write | 只发 `ui.menu.*`、`ui.goodnight.*`、`progress.items_unlocked` 等事件，不直接管理播放器 |
| 本地化 key | `tr()` / 本地化系统 | Read | 所有可见字符串必须走本地化，不硬编码文案 |

---

## Accessibility

- 所有主操作都必须可通过鼠标和触摸完成：开始今天、明天见/继续、退出、重玩入口、关闭提示、去衣橱、返回主菜单弱入口都不能只依赖 hover。
- 所有可交互元素都必须有清晰的焦点态或可感知状态；鼠标 hover、点击 pressed、以及键盘可达状态不能彼此覆盖到看不清。
- 所有按钮和可点击热区最小尺寸不小于 44×44px，尤其是退出、关闭提示和次要入口。
- 文本和按钮状态不能只靠颜色区分；主操作、弱操作、禁用态和完成态必须同时使用形状、描边、亮度、位置或图标进行区分。
- 主菜单、晚安页和告别态中的所有文案都必须保证足够对比度，正文与背景至少达到可读基线；低对比装饰文字只能作为辅助，不承担主信息。
- `UNLOCK_PROMPT` 的关闭和去衣橱按钮必须具备明确的可达路径，且关闭后焦点应返回触发它的主菜单安全位置。
- `TRANSITION_LOCKED` 状态下按钮只做轻微压暗，不应只用颜色表示“不可用”，并且应在状态恢复后重新进入可操作焦点顺序。
- 动画必须提供减少动态效果的替代路径：如果系统存在 reduced motion 偏好，进入/退出转场和解锁提示的位移、错峰出现和轻微缩放都应降级为快速淡入淡出。
- 晚安页的 `GOODNIGHT_HOLD_MS` 不应让继续按钮永远不可达；在等待期间应给出清楚的可见反馈，避免看起来像卡死。
- 安全告别态必须仍然能让玩家理解当前发生了什么，不能只留空白静止页；如果浏览器无法关闭窗口，至少要提供清晰的返回主菜单或关闭提示。
- 由于项目当前没有单独定义 accessibility tier，本节默认以 WCAG-AA 级别的可读性和操作性作为基线；如果后续定义更高层级，需同步修订本节。

---

## Localization Considerations

- 标题文本是最长的固定文案之一，必须预留约 40% 的扩展空间；如果本地化后过长，优先换行，不要压缩主按钮。
- `第 {day} 天`、`一周完成`、`今天结束了` 这类短文案在不同语言里长度波动较大，顶部文案区需要允许两行排布。
- `开始今天`、`明天见/继续`、`重玩入口`、`退出` 是布局最敏感的按钮文案；这些按钮必须支持更长译文而不破坏底部操作区的主次关系。
- `新衣服到了` / `衣橱多了几件新单品` 这类解锁提示标题要保持短而柔和；如果翻译变长，允许降级为更短的本地化短句。
- 晚安页结束语和完成提示必须支持句子级换行，不应强制单行显示。
- Web 告别态文案要留出足够空间容纳更礼貌或更长的退出表达，避免和返回主菜单弱入口挤在一起。
- 数字、日期和天数显示必须使用本地化格式或模板，不在 UI 中硬拼接固定中文句式。
- 如果未来接入 `UNLOCK_PROMPT`，卡片名称和类目标签要按更长译文预留宽度，避免遮挡缩略图或“新”标记。

---

## Acceptance Criteria

- [ ] 主菜单在 `GameState.current_state == MAIN_MENU` 时能在 500ms 内进入可交互状态，并显示标题、当前天数和主操作按钮。
- [ ] 晚安页在 `GameState.current_state == GOODNIGHT` 时能显示当天结束语、当前天数和继续按钮；若 `equipped_items` 缺失，仍显示通用晚安画面且不阻塞继续。
- [ ] 玩家点击“开始今天”后，UI 只请求一次 `GameState.request_transition(State.WARDROBE)`，不会重复触发。
- [ ] 玩家在晚安页点击“明天见/继续”后，UI 只请求一次 `GameState.request_transition(State.MAIN_MENU)`，且主菜单/晚安 UI 不直接调用 `ProgressManager.advance_day()`。
- [ ] 第 7 天返回主菜单时，不显示第 8 天相关文案，并进入 completed mode，显示一周完成提示与重玩入口。
- [ ] 当 `GameState.get_current_day()` 返回 0、负数或大于 7 时，界面仍能显示合法天数范围内的文本，不崩溃。
- [ ] 任意可交互按钮的实际热区均不小于 44×44px。
- [ ] 鼠标 hover、点击 pressed 和可达状态在视觉上可区分，不会互相覆盖到无法辨认。
- [ ] 本地化文本较长时，标题、按钮和完成提示均能换行或重排，不遮挡主按钮或溢出布局。
- [ ] Web 平台点击退出时，如果无法真正关闭窗口，UI 会进入安全告别态而不是显示技术错误。
- [ ] `UNLOCK_PROMPT` 出现时，玩家可以关闭提示或直接进入衣橱；关闭后新物品高亮仍保留给衣橱 UI。
- [ ] 该屏幕的核心目的成立：玩家能清楚区分“开始今天”“今天结束了”“这一周完成了”三种状态，并完成相应操作。
- [ ] 在 1366x768、1280x720、390x844 和 360x800 视口下，标题、当前天数、主按钮、安全区与主视觉均不重叠、不溢出，且主按钮保持可见可点。
- [ ] 当状态切换失败或必要数据缺失时，界面进入 `ERROR_RETRY` 并提供温和重试或返回入口，不显示技术错误文案。

---

## Open Questions

- Player journey map 仍未创建。若后续要补，建议先运行 `/ux-design` 的 player journey 流程，或手动创建 `design/player-journey.md`，这样主菜单/晚安页的情绪节奏会更准确。
- 当前项目没有单独定义 accessibility tier。此 spec 先按 WCAG-AA 作为基线；如果后续定义更高等级，需要同步修订本节与验收标准。
- 通关后的重玩入口目前只定义为占位意图 `replay_day_requested(day)`，还未决定是“重看这一周”单按钮，还是允许选具体天数。
- Web 平台 `QUIT` 无法关闭窗口时的最终表现仍需与场景/状态管理统一：静态告别页、返回主菜单，还是隐藏到安全 idle。
- 晚安页是否要始终显示角色/穿搭回顾，还是只在 `GameState.context["equipped_items"]` 和资源就绪时显示轻量回顾，目前仍保留为可选。
- `UNLOCK_PROMPT` 这次已作为主菜单浮层纳入本 spec，但如果未来它要发展成更丰富的卡片式提示，可能需要独立的 `clothing-unlock` UX spec。
- 由于当前项目没有 `design/ux/interaction-patterns.md`，本 spec 中的按钮、提示和安全告别态模式还没有进入 pattern library。后续如果开始复用这些模式，建议补建 pattern library。
