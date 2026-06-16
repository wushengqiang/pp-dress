# 主菜单/晚安 UI (Main Menu / Goodnight UI)

> **Status**: Approved
> **Author**: user + Codex Game Studios
> **Last Updated**: 2026-06-08
> **Implements Pillar**: 每日陪伴

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `场景/状态管理`

## Overview

主菜单/晚安 UI 是「每日穿搭」每日循环的入口与收束界面：主菜单负责以温柔、低压力的方式迎接玩家，显示当前天数，并让玩家开始今天、退出或在通关后进入重玩入口；晚安 UI 负责在每日场景与对话结束后承接当天情绪，展示“今天结束了”的安静确认，并在玩家点击继续后把用户意图交给 `GameState` 执行 `GOODNIGHT → MAIN_MENU`，由状态管理触发进度推进。该系统不拥有进度数据、不直接调用 `ProgressManager.advance_day()`、不管理服装解锁，也不评价玩家穿搭；它的职责是让玩家清楚知道“我在哪里、今天到哪一步、下一步可以安心做什么”，并把每日陪伴的开始与结束做得柔和、稳定、可读。

## Player Fantasy

主菜单/晚安 UI 的玩家幻想是：“我打开游戏时，她像已经在清晨等我；我结束今天时，游戏轻轻帮我把这一页合上。”

玩家不应该觉得自己在操作一个功能菜单，而应该觉得自己回到了一本温暖的穿搭日记。主菜单的情绪是被欢迎：当前天数清楚可见，“开始今天”像翻开新一页，而不是任务按钮；通关或重玩入口也不应显得像系统管理界面，而是“还可以回去看看以前的日子”。晚安 UI 的情绪是被安放：玩家刚刚完成穿搭、读完当天对话，画面应给出短暂的停留和温柔的收束，让玩家知道今天已经结束、明天还会继续。整个系统服务「每日陪伴」：开始时不催促，结束时不打断；每一次点击都像轻轻翻页，而不是推进流程。

## Detailed Design

### Core Rules

**系统定位**：主菜单/晚安 UI 是 `MAIN_MENU` 与 `GOODNIGHT` 状态中的玩家入口和收束界面。它负责显示当前天数、开始今天、退出、晚安确认、通关/重玩入口等玩家可见操作。它不拥有进度数据、不写保存、不推进天数、不解锁服装；所有天数与完成状态来自 `GameState` / `ProgressManager` 的只读接口，所有状态切换通过向 `GameState` 发出用户意图完成。

**主菜单规则**：
- 当 `GameState.current_state == MAIN_MENU` 时显示主菜单。
- 主菜单在 `_ready()` 中直接读取 `GameState.current_state` 与 `GameState.get_current_day()`，不只依赖 `state_changed`。
- 主菜单默认显示：游戏标题、当前天数、“开始今天”、退出。
- “开始今天”请求 `GameState.request_transition(State.WARDROBE)`。
- “退出”请求 `GameState.request_transition(State.QUIT)` 或 Web 端等价退出/告别流程。
- 若 `ProgressManager.get_highest_day_completed() >= 7`，主菜单进入通关显示模式：显示完成一周的温柔提示，并提供重玩入口；不得显示第 8 天。

**晚安规则**：
- 当 `GameState.current_state == GOODNIGHT` 时显示晚安 UI。
- 晚安 UI 读取 `GameState.get_current_day()` 与 `GameState.context["equipped_items"]`，用于显示当天结束语和未来晚安角色/穿搭回顾。
- 晚安 UI 不直接展示新解锁服装列表；新解锁提示属于未来 `服装解锁` 系统。
- 玩家点击“明天见”/“继续”时，请求 `GameState.request_transition(State.MAIN_MENU)`。
- 仅 `GOODNIGHT → MAIN_MENU` 触发 `ProgressManager.advance_day()`；该调用由 GameState 执行，不由本 UI 执行。
- 第 7 天晚安后仍请求 `GOODNIGHT → MAIN_MENU`；GameState / ProgressManager 负责保持 `current_day == 7` 并让主菜单进入通关显示模式。

**重玩规则**：
- MVP 可在通关模式中显示“重看某一天”入口，但真正的重玩选择流程若超出主菜单简单按钮，应延后到后续 UX spec。
- 若实现重玩入口，主菜单只发出 `replay_day_requested(day)` 或等价用户意图；是否允许重玩、如何设置 day 由 GameState / ProgressManager 决定。
- 重玩不调用 `advance_day()`。

**显示与输入规则**：
- 所有按钮均支持鼠标、触摸、键盘和手柄确认。
- Godot 4.6 中 hover 与 keyboard/gamepad focus 分离，按钮必须分别显示 `hover`、`pressed`、`keyboard_focus`。
- 所有可见文本使用 `tr()` 本地化 key。
- 所有可交互热区不小于 44×44px。
- UI 不显示评分、正确/错误穿搭、失败语气或惩罚性提示。

### States and Transitions

```text
HIDDEN
  → MAIN_MENU_DEFAULT
  → MAIN_MENU_COMPLETED
  → GOODNIGHT_SUMMARY
```

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|----------|----------|
| `HIDDEN` | 当前不是主菜单或晚安状态 | `current_state` 非 `MAIN_MENU` / `GOODNIGHT` | 进入 MAIN_MENU 或 GOODNIGHT |
| `MAIN_MENU_DEFAULT` | 普通主菜单 | `current_state == MAIN_MENU` 且未完成第 7 天 | 点击开始今天、退出 |
| `MAIN_MENU_COMPLETED` | 一周完成后的主菜单 | `highest_day_completed >= 7` | 点击重玩、退出 |
| `GOODNIGHT_SUMMARY` | 当天结束收束页 | `current_state == GOODNIGHT` | 点击继续/明天见 |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|----------|
| 场景/状态管理 | 强依赖 | 读取 `GameState.current_state`、`GameState.context`、`GameState.get_current_day()`；请求 WARDROBE / MAIN_MENU / QUIT 状态转换 |
| 进度管理 | 间接只读 | 读取 `get_highest_day_completed()`、`is_last_day()` 等完成状态用于通关显示；不调用 `advance_day()` |
| 对话 UI | 上游流程相关 | 对话 UI 完成后，每日场景请求进入 GOODNIGHT，本系统显示晚安收束页 |
| 每日场景 | 上游流程相关 | 每日场景进入 GOODNIGHT 后，本系统承接当天结束画面 |
| 服装解锁 | 未来下游 | 可在晚安后或主菜单返回时展示新解锁提示；本系统不拥有解锁列表 |
| 音频管理 | 未来弱依赖 | 播放开始、继续、晚安、退出等轻柔 UI 音效 |

## Formulas

主菜单/晚安 UI 不包含经济或成长公式，但需要定义 UI 状态选择、通关显示和可交互启用条件。

### UI 状态选择

```text
if current_state == MAIN_MENU and highest_day_completed >= TOTAL_DAYS:
    ui_mode = MAIN_MENU_COMPLETED
elif current_state == MAIN_MENU:
    ui_mode = MAIN_MENU_DEFAULT
elif current_state == GOODNIGHT:
    ui_mode = GOODNIGHT_SUMMARY
else:
    ui_mode = HIDDEN
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `current_state` | enum | `GameState.State` | 当前游戏状态 |
| `highest_day_completed` | int | `0..7` | 已完成最高天数 |
| `TOTAL_DAYS` | int | `7` | 游戏总天数，来自进度管理 |
| `ui_mode` | enum | `HIDDEN`, `MAIN_MENU_DEFAULT`, `MAIN_MENU_COMPLETED`, `GOODNIGHT_SUMMARY` | 当前应显示的 UI 模式 |

**输出**：当前 UI 模式。

**规则**：通关后不显示第 8 天，主菜单进入完成模式。

### 当前天数显示

```text
display_day = clamp(GameState.get_current_day(), 1, TOTAL_DAYS)
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `display_day` | int | `1..7` | UI 显示给玩家的天数 |
| `GameState.get_current_day()` | int | expected `1..7` | 当前天数 Facade |
| `TOTAL_DAYS` | int | `7` | 总天数 |

**输出**：显示用天数。

**规则**：若数据异常，UI 只做显示 clamp，不修正进度。

### 按钮启用条件

```text
start_today_enabled = (ui_mode == MAIN_MENU_DEFAULT)
continue_enabled = (ui_mode == GOODNIGHT_SUMMARY)
replay_enabled = (ui_mode == MAIN_MENU_COMPLETED)
exit_enabled = (ui_mode == MAIN_MENU_DEFAULT or ui_mode == MAIN_MENU_COMPLETED)
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `start_today_enabled` | bool | true/false | “开始今天”是否可用 |
| `continue_enabled` | bool | true/false | 晚安页继续按钮是否可用 |
| `replay_enabled` | bool | true/false | 通关后重玩入口是否可用 |
| `exit_enabled` | bool | true/false | 退出按钮是否可用 |

**输出**：按钮启用状态。

**规则**：按钮隐藏或 disabled 都必须保持焦点路径合法，不让键盘/手柄焦点落到不可用按钮上。

### 触控热区约束

```text
interactive_target_width >= 44px
interactive_target_height >= 44px
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `interactive_target_width` | float | `>=0px` | 按钮、重玩入口、退出入口的热区宽度 |
| `interactive_target_height` | float | `>=0px` | 按钮、重玩入口、退出入口的热区高度 |

**输出**：交互控件是否合法。

**规则**：所有可点击/触摸控件热区不得小于 44×44px。

## Edge Cases

- **当前状态不是 `MAIN_MENU` 或 `GOODNIGHT`**：UI 进入 `HIDDEN`，不显示主菜单或晚安控件，不接受按钮输入。
- **`GameState.get_current_day()` 返回非法值**：显示层将天数 clamp 到 `1..7`，记录 warning；不直接修正存档或调用 ProgressManager 写接口。
- **`highest_day_completed >= 7`**：主菜单进入 `MAIN_MENU_COMPLETED`，显示一周完成提示和重玩入口；不得显示“第 8 天”或“开始第 8 天”。
- **第 7 天晚安后点击继续**：晚安 UI 仍请求 `GOODNIGHT → MAIN_MENU`；GameState / ProgressManager 负责保持 `current_day == 7` 并标记完成。
- **玩家快速重复点击“开始今天”或“继续”**：按钮在第一次请求状态转换后临时 disabled，直到状态切换完成或失败；不得重复请求同一转换。
- **玩家在 `GOODNIGHT` 页面刷新浏览器**：由场景/状态管理和保存/加载决定恢复位置；本 UI 不自行恢复进度，只按当前 `GameState.current_state` 渲染。
- **`context["equipped_items"]` 缺失**：晚安 UI 仍可显示通用晚安文案；不显示破损穿搭回顾，不阻塞继续。
- **ProgressManager 未就绪**：主菜单显示安全默认天数或轻量加载状态；不得把未就绪误判为通关。
- **Web 端退出无效**：如果 `GameState.request_transition(State.QUIT)` 在 Web 平台不能关闭窗口，显示静态告别画面或返回安全 idle 状态，不展示技术错误。
- **键盘/手柄焦点落到隐藏按钮**：刷新 focus neighbors 或主动把焦点移到第一个可用按钮；不可用按钮不得接收确认。
- **本地化文本过长**：按钮和标题自动换行或使用更宽容布局，不溢出、不遮挡主要操作。
- **状态转换失败或被拒绝**：按钮恢复可用，并显示温和提示；不得卡在 disabled 状态。

## Dependencies

| Dependency | Type | Contract |
|------------|------|----------|
| 场景/状态管理 | Strong | 提供 `GameState.current_state`、`GameState.context`、`GameState.get_current_day()`，并接收 `request_transition(State.WARDROBE / State.MAIN_MENU / State.QUIT)`。本 UI 必须在 `_ready()` 主动读取当前状态，不能只依赖 `state_changed`。 |
| 进度管理 | Indirect read-only | 提供 `get_highest_day_completed()`、`is_last_day()`、`get_total_days()` 等只读信息，用于通关显示和天数文案。本 UI 不调用 `advance_day()`、不写保存数据。 |
| 对话 UI | Upstream flow | 对话 UI 完成后由每日场景进入 `GOODNIGHT`，本 UI 从该状态开始显示晚安收束页；不直接监听对话行级事件。 |
| 每日场景 | Upstream flow | 每日场景负责在对话完成后请求 `DAILY_SCENE → GOODNIGHT`；本 UI 不决定每日场景何时结束。 |
| 服装解锁 | Future optional | 未来可在晚安后或返回主菜单时展示新解锁提示；本 UI 不计算解锁物品、不展示物品列表，除非服装解锁 GDD 明确接入。 |
| 音频管理 | Future optional | 播放主菜单进入、按钮点击、晚安继续、退出/告别等轻柔 UI 音效；本 UI 只发 UI 事件，不管理音频资源。 |

**Dependency Constraints**
- 主菜单/晚安 UI 是状态消费者和用户意图发起者，不是进度 owner。
- `GOODNIGHT → MAIN_MENU` 的进度推进必须由 GameState 调用 `ProgressManager.advance_day()`。
- 若后续主菜单支持重玩具体天数，必须由 GameState / ProgressManager 定义重玩 day 的合法设置方式。
- 若 `服装解锁` 系统接入晚安或主菜单，需要回传修订本 GDD，避免两个 UI 同时显示解锁结果。

## Tuning Knobs

| Knob | Default | Range | Notes |
|------|---------|-------|-------|
| `BUTTON_DEBOUNCE_MS` | `200` | `120..400` | 防止重复点击“开始今天”或“继续”产生多次状态转换请求。 |
| `MENU_FADE_IN_MS` | `500` | `300..800` | 主菜单进入淡入时长，保持“被温柔迎接”的感觉。 |
| `GOODNIGHT_HOLD_MS` | `600` | `300..1200` | 晚安页出现后，继续按钮可用前的短暂停留时间，避免玩家误触立刻跳过收束。 |
| `TRANSITION_INTENT_LOCK_MS` | `1000` | `500..2000` | 发出状态转换请求后按钮锁定的最长时间；若转换失败或超时，按钮恢复。 |
| `TITLE_MAX_WIDTH_RATIO` | `0.80` | `0.65..0.90` | 标题与提示文本最大宽度，避免宽屏文字过长一行。 |
| `PRIMARY_BUTTON_MIN_WIDTH` | `160px` | `140..240px` | 主按钮最小宽度，需兼容本地化文本。 |
| `SAFE_AREA_MARGIN_PX` | `24` | `12..48` | UI 与视口边缘的安全距离，移动端需适配浏览器/设备安全区。 |
| `COMPLETED_MESSAGE_KEY` | `menu.completed_week` | localized string key | 通关提示文案 key。 |
| `GOODNIGHT_LABEL_KEY` | `goodnight.continue` | localized string key | 晚安页继续按钮文案 key。 |

**非本系统控制的调参**
- `TOTAL_DAYS` 由进度管理控制。
- 是否展示新解锁物品由 `服装解锁` 系统控制。
- 状态切换合法性与超时由 `GameState` 控制。
- 场景过渡统一动画若后续独立为转场系统，本 UI 只触发意图，不拥有全局转场规则。

## Visual/Audio Requirements

### Visual Requirements

- 主菜单视觉情绪为“被温柔迎接”：清晨暖光、低反差、大面积晨光白留白，符合 Art Bible 的主菜单/首页方向。
- 晚安 UI 视觉情绪为“温柔收束与满足”：夜晚台灯暖光、柔暗低反差，不做强烈结算页或奖励页。
- 主菜单/晚安 UI 使用居中极简布局，不做信息密集面板，不使用营销式 hero 或复杂卡片。
- 标题、天数和主按钮形成清晰视觉层级；标题不压过角色/背景氛围。
- 通关提示使用温柔完成语气，不使用“胜利”“满分”“失败/成功评价”等挑战语汇。
- 背景可使用当前状态对应的温暖场景图或柔和日记式背景；不得使用抽象渐变、强装饰图形或与角色/穿搭无关的氛围图。
- 按钮状态必须包含颜色 + 形状/亮度/焦点描边双信号源。
- 所有文本对比度不低于 4.5:1。
- 所有可交互热区不小于 44×44px。
- 转场使用 0.8 秒以内的晨光白翻页式淡入淡出方向，避免生硬跳切。

### Audio Requirements

- 主菜单进入：极轻纸页/晨间铃音质感，不抢占注意力。
- 点击“开始今天”：柔和确认音，像翻开日记，不像系统按钮。
- 晚安页出现：可使用低音量纸页合上、轻柔布料或台灯开关感音效。
- 点击“明天见/继续”：短促、温暖、低音量，不播放胜利结算音。
- 退出/告别：轻柔收束音，不制造失败感或强制结束感。
- 所有 UI 音效由未来音频管理系统承接；本 UI 只发事件，不直接管理音频资源。

### Asset Spec Flag

后续需要 `/asset-spec system:main-menu-goodnight-ui` 生成：主菜单背景、晚安背景、主按钮状态、通关提示装饰、告别静态画面、焦点/hover/pressed 状态资源。

## UI Requirements

### Shared Requirements

- 主菜单和晚安 UI 都必须在 `_ready()` 中主动读取 `GameState.current_state`，不能只等待 `state_changed`。
- 所有可见字符串必须使用 `tr()` 和本地化 key。
- 所有按钮实际热区必须 ≥44×44px。
- 桌面、移动、键盘、手柄路径都必须可完成主流程。
- Godot 4.6 中 `hover` 与 `keyboard_focus` 可同时落在不同控件，UI 必须分别显示，不互相覆盖。
- 隐藏或 disabled 的按钮不得留在键盘/手柄 focus path 中。
- 不显示评分、任务评级、穿搭评价、失败提示或红色惩罚态。

### Main Menu Layout

桌面端：
- 标题位于画面中央偏上。
- 当前天数位于标题下方，格式如 `第 {day} 天`，不得显示大于 7 的天数。
- 主按钮“开始今天”位于视觉焦点区域。
- 退出入口弱化显示，不能与主按钮竞争。
- 通关模式下，用温柔提示替换“开始今天”，并显示重玩入口。

移动端：
- 标题、天数、主按钮纵向排列。
- 主按钮位于拇指易触区域，但不贴底。
- 文本和按钮不能被浏览器安全区遮挡。
- 宽度不足时文字换行，不压缩到不可读。

### Goodnight Layout

- 晚安页显示当天结束语、当前天数和“明天见/继续”按钮。
- 若 `context["equipped_items"]` 可用，可预留角色/穿搭回顾区域；若不可用则显示通用晚安画面。
- “继续”按钮在 `GOODNIGHT_HOLD_MS` 后启用，避免误触跳过。
- 晚安页不显示新解锁物品列表，除非未来服装解锁系统明确接入。
- 第 7 天晚安页不暗示第 8 天，只使用“这一周完成了”或等价温柔收束文案。

### Focus Order

主菜单默认焦点：
1. `开始今天` 或通关模式的主入口
2. `重玩入口`（仅通关模式）
3. `退出`

晚安默认焦点：
1. `明天见/继续`

### UX Flag

后续需要 `/ux-design main-menu-goodnight-ui` 细化主菜单、晚安页、通关模式、Web 退出/告别画面的具体布局与焦点图。

## Acceptance Criteria

1. **GIVEN** `GameState.current_state == MAIN_MENU` 且 `highest_day_completed < 7`，**WHEN** 主菜单 UI `_ready()` 执行，**THEN** `ui_mode == MAIN_MENU_DEFAULT`，并显示标题、当前天数、“开始今天”和退出入口。
2. **GIVEN** `GameState.current_state == MAIN_MENU` 且 `highest_day_completed >= 7`，**WHEN** 主菜单 UI 渲染，**THEN** `ui_mode == MAIN_MENU_COMPLETED`，不显示“第 8 天”，并显示一周完成提示。
3. **GIVEN** `GameState.current_state == GOODNIGHT`，**WHEN** 晚安 UI `_ready()` 执行，**THEN** `ui_mode == GOODNIGHT_SUMMARY`，并显示当天结束语和继续按钮。
4. **GIVEN** 当前状态不是 `MAIN_MENU` 或 `GOODNIGHT`，**WHEN** UI 初始化或收到输入，**THEN** UI 进入 `HIDDEN`，不显示主菜单/晚安控件。
5. **GIVEN** 主菜单处于 `MAIN_MENU_DEFAULT`，**WHEN** 玩家点击“开始今天”，**THEN** UI 请求 `GameState.request_transition(State.WARDROBE)` 一次。
6. **GIVEN** 晚安页处于 `GOODNIGHT_SUMMARY`，**WHEN** 玩家点击“明天见/继续”，**THEN** UI 请求 `GameState.request_transition(State.MAIN_MENU)` 一次。
7. **GIVEN** 晚安页点击继续，**WHEN** 检查进度写入，**THEN** 主菜单/晚安 UI 没有直接调用 `ProgressManager.advance_day()`。
8. **GIVEN** 第 7 天晚安页，**WHEN** 玩家点击继续，**THEN** UI 仍请求 `GOODNIGHT → MAIN_MENU`，且不显示第 8 天相关文案。
9. **GIVEN** `GameState.get_current_day()` 返回 0、负数或大于 7，**WHEN** UI 显示天数，**THEN** `display_day` 被 clamp 到 `1..7`，并记录 warning。
10. **GIVEN** 玩家快速连续点击同一主按钮，**WHEN** 第一次转换请求已经发出，**THEN** 按钮临时 disabled，不重复发出转换请求。
11. **GIVEN** 状态转换失败或被拒绝，**WHEN** `TRANSITION_INTENT_LOCK_MS` 到达或收到失败反馈，**THEN** 按钮恢复可用。
12. **GIVEN** `context["equipped_items"]` 缺失，**WHEN** 晚安 UI 渲染，**THEN** 显示通用晚安画面，不阻塞继续。
13. **GIVEN** `ProgressManager` 未就绪，**WHEN** 主菜单渲染，**THEN** 不误判为通关模式。
14. **GIVEN** 任意可交互按钮，**WHEN** 检查实际热区，**THEN** 宽高均 ≥44px。
15. **GIVEN** Godot 4.6 双焦点系统，**WHEN** 鼠标 hover 和键盘 focus 位于不同按钮，**THEN** 两种状态均可见且不互相覆盖。
16. **GIVEN** 隐藏或 disabled 按钮，**WHEN** 使用键盘/手柄导航，**THEN** 焦点不会落到该按钮上。
17. **GIVEN** 本地化文本较长，**WHEN** 主菜单或晚安页渲染，**THEN** 文本自动换行或重排，不溢出、不遮挡主按钮。
18. **GIVEN** Web 平台 `QUIT` 无法关闭窗口，**WHEN** 玩家点击退出，**THEN** UI 显示安全告别状态或等价静态画面，不展示技术错误。
19. **GIVEN** 通关模式启用重玩入口，**WHEN** 玩家请求重玩某天，**THEN** UI 只发出 `replay_day_requested(day)` 或等价用户意图，不直接修改当前天数。
20. **GIVEN** UI 任意可见文案，**WHEN** 检查实现，**THEN** 使用 `tr()` 和本地化 key，不硬编码玩家可见字符串。

## Open Questions

| Question | Owner | Target Resolution |
|----------|-------|-------------------|
| 通关后的重玩入口是单按钮“重看这一周”，还是允许选择具体第几天？ | UX 设计 / GameState 设计 | `/ux-design main-menu-goodnight-ui` 或每日场景设计前 |
| 晚安页是否显示角色穿搭回顾，还是 MVP 只显示通用晚安背景与文案？ | 每日场景 / UX 设计 | 每日场景 GDD 设计时 |
| Web 端 `QUIT` 的最终表现是静态告别页、返回主菜单，还是浏览器内隐藏游戏画面？ | 场景/状态管理 / UX 设计 | 主菜单 UX spec 前 |
| 新解锁服装提示是在晚安页后立即显示，还是返回主菜单后由服装解锁系统插入？ | 服装解锁系统 | 服装解锁 GDD 设计时 |
| 通关完成文案是否使用固定文本，还是由轻叙事对话系统提供一段收束旁白？ | 轻叙事对话 / Narrative | 轻叙事对话 GDD 设计时 |
