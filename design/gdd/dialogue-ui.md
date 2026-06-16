# 对话 UI (Dialogue UI)

> **Status**: Approved
> **Author**: user + Codex Game Studios
> **Last Updated**: 2026-06-08
> **Implements Pillar**: 每日陪伴

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `场景/状态管理`, `进度管理`

## Overview

对话 UI 是「每日穿搭」中每日场景里的轻叙事阅读界面：它以底部半透明浮层承载角色台词、旁白、当天场景提示和继续操作，让玩家在确认穿搭后自然进入一段温暖、低压力的小故事。系统从 `GameState.current_state`、`GameState.context` 与 `GameState.get_current_day()` 获取当前天数和场景上下文，用这些信息请求当天应展示的对话内容，并负责逐句呈现、文本推进、结束提示与进入晚安流程的用户意图。对话 UI 不拥有正式剧情文本库、不决定天数推进、不修改进度，也不评价玩家穿搭；它的职责是在不遮挡角色与场景重点的前提下，让玩家清楚、舒适地读完当天片段，感到“今天也和她一起度过了一小段时间”。

## Player Fantasy

对话 UI 的玩家幻想是：“我为她选好了今天的衣服，然后坐下来听她轻轻说几句话，像翻开一页只属于今天的日记。”

玩家应该感到对话不是任务结算，也不是剧情考试，而是一段安静的陪伴时间。她穿着玩家刚刚搭好的衣服出现在当天场景里，说的话温柔、短促、带一点生活气息；玩家只需要点一下继续，就能顺着文字、表情和场景氛围走完这一天的小片段。对话 UI 要让玩家觉得自己的穿搭被世界温柔接住，但不能把它变成评分、攻略或复杂分支选择。它服务的是「每日陪伴」：今天有一点新的情绪，明天还有一点新的期待；即使只读了几句，也像和角色认真见了一面。

## Detailed Design

### Core Rules

**系统定位**：对话 UI 是 `DAILY_SCENE` 中的玩家阅读与推进界面，负责展示当天线性对话片段。它不保存剧情内容、不生成对话文本、不推进天数、不写入进度；它只读取当前上下文、请求对话片段、逐句显示，并在片段结束后向每日场景发出对话完成事件。

**内容来源规则**：
- 对话 UI 在 `_ready()` 中直接读取 `GameState.current_state`、`GameState.context` 和 `GameState.get_current_day()`，而不是只等待 `state_changed` 信号。
- 若当前状态不是 `DAILY_SCENE`，对话 UI 不展示正文，只保持隐藏或 disabled 状态。
- 当 `current_state == DAILY_SCENE` 时，对话 UI 使用临时契约 `request_dialogue_sequence(day, context)` 请求当天对话序列。MVP 临时 owner 为对话 UI 内置的 fallback provider；未来 `轻叙事对话` GDD 完成后，该接口迁移到正式内容 provider。
- MVP 对话序列为线性数组，不包含玩家选项、分支结局、评分、好感度变化或失败状态。
- 每条对话行至少包含：`line_id`、`speaker_id`、`speaker_name`、`text_key` 或 `text`、`portrait_expression`、`line_type`。`line_id` 用于日志、跳过坏行和测试定位。
- `line_type` 可为 `dialogue`、`narration`、`system_hint`；MVP 中 `system_hint` 只用于温和操作提示，不承载攻略或评分。

**显示规则**：
- 对话面板固定为底部半透明浮层，不越过画面中线，不遮挡角色主体超过 30%。
- 每次只显示一条对话行。
- 文本默认逐字显示；玩家点击/确认时，如果逐字显示未完成，则立即补全文本；如果已完成，则进入下一条。
- 当前台词显示完整后，继续指示器才出现。
- 角色名显示在正文上方或同一浮层的轻量标签中；旁白行可隐藏角色名。
- 所有可见字符串必须预留本地化路径；正式实现优先使用 `text_key` + `tr()`，临时原型可读取直接 `text`。

**结束规则**：
- 对话序列播放到最后一条后，对话 UI 显示温和的结束操作，例如 `晚安` 或 `继续`。
- 玩家确认结束后，对话 UI 发出临时契约 `dialogue_sequence_finished(day)`。MVP 中该事件由每日场景接收，再由每日场景请求 `GameState.request_transition(State.GOODNIGHT)` 或等价状态转换入口。
- 对话 UI 不直接调用 `ProgressManager.advance_day()`；天数推进仍只发生在 `GOODNIGHT → MAIN_MENU`。
- 对话 UI 不直接调用 `GameState.request_transition(State.GOODNIGHT)`；它只发出“对话已完成”的用户意图，状态转换由每日场景或上层状态承接者执行。

**输入规则**：
- 鼠标点击、触摸点击、键盘确认键、手柄确认键都必须能推进文本。
- hover 不能承载必要信息。
- Godot 4.6 中鼠标/触摸焦点与键盘/手柄焦点分离；对话 UI 必须分别显示 `hover`、`pressed`、`keyboard_focus`，且不会互相覆盖。
- 快速连续点击不会跳过多条已读文本；一次确认最多执行一个推进动作：补全文本或进入下一条。

**限制规则**：
- MVP 不做玩家选项。
- MVP 不做分支结局。
- MVP 不显示“正确/错误穿搭”。
- MVP 不把台词长度设计成大段小说；每条文本应适合在一个底部浮层中舒适阅读。
- 服装影响台词属于未来 `轻叙事对话` GDD 的扩展；本 GDD 只保留 `context["equipped_items"]` 可传入对话请求，不定义服装文本分支规则。

### States and Transitions

对话 UI 内部状态只描述阅读流程，不等同于 `GameState`。

```text
HIDDEN
  → LOADING_SEQUENCE
  → LINE_REVEALING
  → LINE_WAITING_INPUT
  → ADVANCING
  → COMPLETE_WAITING_CONFIRM
  → FINISHED
```

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|----------|----------|
| `HIDDEN` | 未处于 DAILY_SCENE 或无需显示 | 场景不是 DAILY_SCENE；被上层场景显式禁用 | 进入 DAILY_SCENE 并请求对话 |
| `LOADING_SEQUENCE` | 等待当天对话序列 | 读取 day/context 后发出请求 | 成功收到序列；请求失败 |
| `LINE_REVEALING` | 当前行逐字显示中 | 有可显示行 | 玩家确认补全；逐字显示完成 |
| `LINE_WAITING_INPUT` | 当前行完整显示，等待推进 | 当前行显示完成 | 玩家确认 |
| `ADVANCING` | 切换到下一行的短暂状态 | 玩家确认推进 | 下一行开始或序列结束 |
| `COMPLETE_WAITING_CONFIRM` | 全部文本结束，等待进入晚安 | 最后一行显示完成并被确认 | 玩家点击 `晚安` / `继续` |
| `FINISHED` | 已发出结束意图 | 玩家确认结束 | 每日场景或 GameState 接管转换 |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|----------|
| 场景/状态管理 | 本系统依赖 | 读取 `GameState.current_state`、`GameState.context`、`GameState.get_current_day()`；结束时发出进入 GOODNIGHT 的用户意图 |
| 进度管理 | 间接依赖 | ProgressManager 是天数权威源，但对话 UI 不直接调用它；对话 UI 通过 `GameState.get_current_day()` 或 `GameState.context["current_day"]` 获取当前天数 |
| 每日场景 | 依赖本系统（未来） | 每日场景承载角色、背景和对话 UI；MVP 中接收 `dialogue_sequence_finished(day)` 后请求 `DAILY_SCENE → GOODNIGHT` |
| 轻叙事对话 | 被本系统依赖（未来） | 未来提供 `request_dialogue_sequence(day, context)` 的正式内容来源；决定台词文本、角色表情和未来可能的服装响应 |
| 衣橱 UI | 间接相关 | 衣橱 UI 写入 `context["equipped_items"]`；对话 UI 可把该 context 传给对话内容系统，但不直接解释服装数据 |
| 音频管理 | 弱依赖（未来） | 播放轻柔点击音、文本推进音、结束提示音；对话 UI 只发出 UI 事件，不直接管理音频资产 |

**临时契约说明**：
- `request_dialogue_sequence(day, context)` 在 MVP 中由对话 UI 内置 fallback provider 实现，返回每天一组安全线性文本；未来迁移给 `轻叙事对话` 系统。
- `dialogue_sequence_finished(day)` 是对话 UI 向每日场景传递“当天对话读完”的临时事件；每日场景负责请求进入 `GOODNIGHT`。
- 若后续 `每日场景` 或 `轻叙事对话` GDD 采用不同接口，必须回传修订本 GDD。

## Formulas

对话 UI 不包含经济、成长或剧情分支公式，但包含一组用于文本显示、输入推进和布局合法性的 UI 判定公式。所有公式只影响显示和交互状态，不改变剧情内容、天数或进度。

### 当前行索引推进

```text
next_line_index = min(current_line_index + 1, sequence_length - 1)
is_last_line = current_line_index == sequence_length - 1
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `current_line_index` | int | `0..sequence_length-1` | 当前正在显示的对话行索引 |
| `sequence_length` | int | `>=0` | 当前对话序列中的行数 |
| `next_line_index` | int | `0..sequence_length-1` | 下一条要显示的对话行 |
| `is_last_line` | bool | true/false | 当前行是否为序列最后一行 |

**输出**：下一行索引和是否结束。

**边界**：`sequence_length == 0` 时不进入行推进，直接走空序列处理。

### 文本显示进度

```text
visible_char_count = min(floor(elapsed_reveal_time * chars_per_second), total_char_count)
line_fully_visible = visible_char_count >= total_char_count
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `elapsed_reveal_time` | float | `>=0s` | 当前行开始逐字显示后的经过时间 |
| `chars_per_second` | float | `15..60` | 每秒显示字符数 |
| `total_char_count` | int | `>=0` | 当前行本地化后文本字符数 |
| `visible_char_count` | int | `0..total_char_count` | 当前实际可见字符数 |
| `line_fully_visible` | bool | true/false | 当前行是否已经完整显示 |

**输出**：当前可见字符数。

**默认值**：`chars_per_second = 30`。

**边界**：`total_char_count == 0` 时视为已完整显示，但该行应被记录 warning 并可被跳过。

### 单次输入推进规则

```text
if input_confirmed and line_fully_visible == false:
    action = "reveal_full_line"
elif input_confirmed and line_fully_visible == true and is_last_line == false:
    action = "advance_to_next_line"
elif input_confirmed and line_fully_visible == true and is_last_line == true:
    action = "show_complete_confirm"
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `input_confirmed` | bool | true/false | 本帧是否收到鼠标/触摸/键盘/手柄确认 |
| `line_fully_visible` | bool | true/false | 当前行是否完整显示 |
| `is_last_line` | bool | true/false | 当前行是否最后一行 |
| `action` | enum | `reveal_full_line`, `advance_to_next_line`, `show_complete_confirm` | 本次输入允许执行的唯一动作 |

**输出**：单次输入动作。

**规则**：一次确认最多执行一个动作，不能在同一次输入中同时补全文本并跳到下一行。

### 面板覆盖约束

```text
dialogue_panel_top_y >= viewport_height * 0.50
panel_height <= min(viewport_height * PANEL_MAX_HEIGHT_RATIO, viewport_height * 0.50 - PANEL_BOTTOM_MARGIN_PX)
ui_covered_character_area_ratio = ui_overlap_area / character_body_area
ui_covered_character_area_ratio <= 0.30
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `dialogue_panel_top_y` | float | `0..viewport_height` | 对话面板顶部 y 坐标 |
| `panel_height` | float | `>=0` | 对话面板实际高度 |
| `viewport_height` | float | `>0` | 当前视口高度 |
| `PANEL_MAX_HEIGHT_RATIO` | float | `0.30..0.42` | 面板最大高度比例 |
| `PANEL_BOTTOM_MARGIN_PX` | float | `>=0px` | 面板底部安全距离 |
| `ui_overlap_area` | float | `>=0` | 对话 UI 覆盖角色主体区域的面积 |
| `character_body_area` | float | `>0` | 角色主体可见区域面积 |
| `ui_covered_character_area_ratio` | float | `0..1` | 对话 UI 覆盖角色主体比例 |

**输出**：布局合法性。

**规则**：对话面板不得越过画面中线，且不得覆盖角色主体 30% 以上。面板高度必须同时受最大高度比例与中线剩余空间约束，避免 bottom margin 叠加后越线。

### 触控热区约束

```text
interactive_target_width >= 44px
interactive_target_height >= 44px
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `interactive_target_width` | float | `>=0px` | 继续、晚安、关闭提示等可交互元素热区宽度 |
| `interactive_target_height` | float | `>=0px` | 可交互元素热区高度 |

**输出**：交互控件是否合法。

**规则**：所有可点击/触摸的控件热区不得小于 44×44px，即使视觉图标本身更小。

## Edge Cases

- **当前状态不是 `DAILY_SCENE`**：对话 UI 保持隐藏或 disabled，不请求对话序列，不显示残留文本。
- **对话序列为空**：记录 warning，进入 fallback line 或 `COMPLETE_WAITING_CONFIRM`，显示一条温和兜底文本，例如“今天就安静地结束吧。”，并允许玩家进入结束确认；不得崩溃或卡死。空序列不进入 `HIDDEN`。
- **对话请求失败或未来内容系统未接入**：使用同一兜底路径，确保玩家仍能进入 `GOODNIGHT`。
- **缺少 `text_key` 或本地化缺失**：优先回退到直接 `text`；若二者都缺失，跳过该行并记录 warning。若所有行都无效，走空序列处理。
- **`current_day` 缺失、非法或超出范围**：优先信任 `GameState.get_current_day()` 或 `GameState.context["current_day"]` 的校正值；若仍非法，使用 day 1 兜底内容或不可用提示，不自行修正进度，也不直接调用 ProgressManager。
- **`context["equipped_items"]` 缺失**：仍加载每日对话；服装响应是未来扩展，MVP 不因缺少穿搭上下文阻塞阅读。
- **快速点击、长按确认或输入重复触发**：每次确认只消费一个动作；输入需经过去抖，不能一帧内补全文本并跳过下一行。
- **文本过长**：正文必须自动换行并受面板高度约束；无法舒适容纳时应分页或拆行，而不是溢出面板、遮挡角色或缩小到不可读。
- **视口过矮或移动端横屏**：优先保持 44×44px 触控热区、文本可读性和角色主体可见；若无法完全满足中线规则，应记录布局风险并使用最小可读面板。
- **场景在文本显示中离开**：取消逐字显示计时器，隐藏 UI，不再接受输入，不重复发出 `dialogue_sequence_finished(day)`。
- **未知 `portrait_expression`**：使用 neutral 表情或默认头像；不得显示破损资源占位。
- **最后一天**：对话 UI 仍按普通流程结束；第 7 天后的进度语义由进度管理与晚安流程处理。

## Dependencies

| Dependency | Type | Contract |
|------------|------|----------|
| 场景/状态管理 | Strong | 提供 `GameState.current_state`、`GameState.context`、当前天数读取入口，以及 `DAILY_SCENE → GOODNIGHT` 的状态转换承接。对话 UI 必须在 `_ready()` 主动读取当前状态，不能只依赖 `state_changed`。 |
| 进度管理 | Indirect read-only | 作为 `GameState.get_current_day()` 背后的天数权威源存在。对话 UI 不直接调用 ProgressManager、不调用 `advance_day()`、不写保存数据。 |
| 每日场景 | Future strong | 负责承载角色、背景、穿搭结果和对话 UI；MVP 中接收 `dialogue_sequence_finished(day)` 后请求进入晚安流程。 |
| 轻叙事对话 | Future strong | 未来接管 `request_dialogue_sequence(day, context)` 的正式内容来源，拥有台词、旁白、表情和未来服装响应规则。MVP 未接入时由对话 UI fallback provider 返回安全线性文本。 |
| 衣橱 UI | Indirect | 在玩家确认穿搭后写入 `context["equipped_items"]`；对话 UI 可透传 context，但不解析服装评分或类别逻辑。 |
| 输入管理 | Optional | 对话 UI 的 MVP 推进可使用 Godot Control `gui_input`、Button `pressed` 和 InputMap confirm action；若后续接入 InputManager，只消费其 `clicked` 信号，不把它列为强依赖。 |
| 音频管理 | Optional future | 播放文字推进、确认、结束等轻量 UI 音效；对话 UI 只发事件或调用薄接口，不直接管理音频资源生命周期。 |

**Dependency Constraints**
- 对话 UI 是状态和内容的消费者，不是剧情、进度或保存数据的 owner。
- `request_dialogue_sequence(day, context)` 与 `dialogue_sequence_finished(day)` 是临时契约；MVP owner 分别为对话 UI fallback provider 与每日场景。后续对应 GDD 若改变接口，必须同步回改本 GDD。
- 所有进度推进必须保留在 `GOODNIGHT → MAIN_MENU` 路径，避免每日对话结束时提前增加天数。
- 对话 UI 不直接调用 `GameState.request_transition(State.GOODNIGHT)`；该调用属于每日场景或状态承接者。

## Tuning Knobs

| Knob | Default | Range | Notes |
|------|---------|-------|-------|
| `CHARS_PER_SECOND` | `30` | `15..60` | 逐字显示速度。低于 15 会显得拖沓，高于 60 接近瞬显。 |
| `INPUT_DEBOUNCE_MS` | `120` | `80..200` | 防止快速点击或长按一次跳过多步。 |
| `PANEL_MAX_HEIGHT_RATIO` | `0.42` | `0.30..0.42` | 对话面板最大高度；必须与中线剩余空间共同取最小值，保护角色主体可见。 |
| `PANEL_BOTTOM_MARGIN_PX` | `24` | `12..40` | 面板与视口底部的安全距离，需适配移动端安全区。 |
| `CONTINUE_INDICATOR_DELAY_MS` | `180` | `0..500` | 当前行完整显示后，继续提示出现的延迟。 |
| `MAX_VISIBLE_TEXT_LINES` | `3` | `2..4` | 单页正文最大可见行数；超出时应拆分内容或分页。 |
| `END_CONFIRM_LABEL` | `晚安` | localized string | 结束确认按钮文案，必须走本地化。 |
| `FALLBACK_LINE_KEY` | `dialogue.fallback.daily_quiet` | localized string key | 对话序列为空或请求失败时使用的兜底文本。 |

## Visual/Audio Requirements

- 对话面板使用底部半透明浮层，视觉上温暖、轻柔、克制，符合 Art Bible 的舞台式 UI 方向。
- 面板顶部默认不得越过画面中线，且不得覆盖角色主体超过 30%。
- 正文与背景的对比度不低于 4.5:1；半透明面板必须在亮色和暗色背景上都可读。
- 字体使用圆润、清晰的无衬线风格；正文尺寸以 14px 等效尺寸为下限，避免为了容纳长文本牺牲可读性。
- 角色名标签应轻量，不抢占正文；旁白行可以隐藏角色名或使用更柔和的样式。
- 继续提示应是低干扰的微动效或图标，不使用强闪烁。
- 文本逐字显示应平滑，不伴随尖锐、高频或持续的打字噪声。
- 音效方向为轻柔点击、翻页、布料或纸张质感，音量低，不能打断每日陪伴氛围。
- 需要后续 `/asset-spec system:dialogue-ui` 为对话面板、继续指示、角色名标签、按钮状态和默认头像/表情占位生成资产规格。

## UI Requirements

- 首屏体验必须直接呈现每日场景和底部对话层，不出现教学页或说明卡。
- 鼠标点击、触摸点击、键盘确认和手柄确认都能推进文本；hover 不承载必要信息。
- 所有可交互热区不得小于 44×44px。
- Godot 4.6 的鼠标/触摸焦点与键盘/手柄焦点需要分别验证：`hover`、`pressed`、`keyboard_focus` 状态都必须可见且不互相覆盖。
- 文本使用 `tr()` 路径，支持本地化、自动换行和长字符串预览。
- 面板、角色名、正文、继续提示和结束按钮不得重叠；在移动端窄屏下优先换行或分页。
- 当前行未完整显示时，确认输入补全文本；当前行完整显示后，确认输入推进到下一行。
- 最后一行确认后显示 `晚安` / `继续` 结束操作，玩家再次确认才发出完成事件。
- UI 不显示评分、正确/错误穿搭、好感度变化、失败提示或分支选项。
- 需要后续 `/ux-design dialogue-ui` 细化布局、焦点顺序、控件状态和可访问性验收图。

## Acceptance Criteria

1. Given `GameState.current_state == DAILY_SCENE`, When 对话 UI `_ready()` 执行, Then 它通过 `GameState.get_current_day()` 或 `GameState.context["current_day"]` 读取当前 day/context，并请求 `request_dialogue_sequence(day, context)`。
2. Given 当前状态不是 `DAILY_SCENE`, When 对话 UI 初始化或收到输入, Then 它保持隐藏/disabled 且不显示正文。
3. Given 对话序列包含多条有效行, When 玩家逐次确认, Then 每次只补全当前文本或推进一行，不会一次跳过多行。
4. Given 当前行正在逐字显示, When 玩家确认, Then 当前行立即完整显示且不进入下一行。
5. Given 当前行已完整显示且不是最后一行, When 玩家确认, Then UI 切换到下一行并重新开始逐字显示。
6. Given 当前行是最后一行且已完整显示, When 玩家确认, Then UI 显示 `晚安` / `继续` 结束确认。
7. Given 玩家在结束确认上确认, When 完成事件尚未发出, Then UI 发出一次 `dialogue_sequence_finished(day)`。
8. Given 完成事件已经发出, When 玩家继续点击或场景切换, Then UI 不重复发出完成事件。
9. Given 对话序列为空、请求失败或内容系统缺失, When UI 加载对话, Then 使用兜底文本或直接进入结束确认，玩家仍可到达 `GOODNIGHT`。
10. Given 某行缺少 `text_key` 或本地化缺失, When 该行显示, Then UI 回退到 `text`；若无可用文本，则跳过并记录 warning。
11. Given `context["equipped_items"]` 缺失, When 请求每日对话, Then UI 仍能加载并完成对话流程。
12. Given 对话流程完成, When 检查进度写入, Then 对话 UI 没有调用 `ProgressManager.advance_day()` 或直接修改保存数据。
13. Given 对话流程完成, When 检查状态切换调用, Then 对话 UI 没有直接调用 `GameState.request_transition(State.GOODNIGHT)`，只发出 `dialogue_sequence_finished(day)`。
14. Given 常见桌面和移动视口, When 显示对话面板, Then 面板不越过画面中线且不覆盖角色主体超过 30%，除非进入明确记录的极端视口兜底。
15. Given 对话面板使用默认 bottom margin, When 计算 `panel_height`, Then `panel_height <= min(viewport_height * PANEL_MAX_HEIGHT_RATIO, viewport_height * 0.50 - PANEL_BOTTOM_MARGIN_PX)`。
16. Given 鼠标、触摸、键盘和手柄输入, When 分别操作对话 UI, Then 确认、hover、pressed、keyboard focus 状态均可识别。
17. Given 本地化长文本, When 文本显示在面板中, Then 正文自动换行、保持可读，不溢出、不遮挡结束按钮。
18. Given 某行被跳过或记录 warning, When 查看日志或测试输出, Then 该行可通过 `line_id` 定位。

## Open Questions

- `request_dialogue_sequence(day, context)` 的长期 owner 是否为 `轻叙事对话` 系统，还是独立 DialogueProvider？MVP 临时 owner 已定为对话 UI fallback provider。
- `dialogue_sequence_finished(day)` 长期是否仍由每日场景接收，还是由 GameState 直接订阅？MVP 临时 owner 已定为每日场景。
- MVP 是否需要默认角色头像/表情资产，还是全部表情由每日场景角色立绘承担？
- 服装响应台词是否完全延后到 `轻叙事对话`，还是需要在本系统预留一条非评分式 flavor line 插槽？
- `晚安` 结束按钮是否统一归属于对话 UI，还是后续并入 `主菜单/晚安 UI` 的视觉组件库？
