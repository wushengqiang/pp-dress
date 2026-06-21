# 轻叙事对话 (Light Narrative Dialogue)

> **Status**: Approved
> **Author**: user + Codex Game Studios
> **Last Updated**: 2026-06-09
> **Implements Pillar**: 每日陪伴, 随心搭配

> **Quick reference** - Layer: `Feature` · Priority: `MVP` · Key deps: `每日场景`, `对话 UI`, `进度管理`

## Overview

轻叙事对话是「每日穿搭」中每日场景的正式内容来源，负责根据当前 `day`、`scene_id`、`equipped_items` 和 `dialogue_context_tags` 返回一组短小、线性、温柔的每日对话序列。它不渲染 UI、不推进天数、不请求状态切换、不评价穿搭，也不拥有服装数据；它只把“今天是什么日子、角色在哪里、玩家刚刚确认了什么穿搭”转化为对话 UI 可播放的台词、旁白、表情 key 和轻量 flavor。MVP 采用 7 天线性内容表：每天固定 3-5 行文本，可带一条非评分式服装/氛围 flavor 行，但不做玩家选项、分支剧情、好感度、评分或失败反馈。它的目标是让玩家在确认穿搭后听到角色轻轻回应今天，感到自己的搭配被故事温柔接住。

## Player Fantasy

玩家幻想是：“她真的注意到了我为今天选的衣服，然后用几句话把今天变成一页小日记。”

玩家不应该感觉自己在读任务说明、剧情考试或穿搭评价，而是在每日场景里听角色自然地说几句话：也许是清晨房间里的一句问候，也许是出门前对天气和衣服的小小回应，也许是一天结束前温柔的收束。无论玩家穿什么，台词都应该认可这份选择，不暗示“搭得好/不好”，只让衣服成为今天氛围的一部分。轻叙事对话服务「每日陪伴」和「随心搭配」：每天有一点新的情绪，但永远轻、短、无压力。

## Detailed Design

### Core Rules

**系统定位**：轻叙事对话是每日内容 provider，负责响应对话 UI 发来的 `request_dialogue_sequence(day, context)`，返回当天可播放的 `DialogueSequence`。它不显示 UI、不处理输入、不推进文本、不请求 GOODNIGHT、不调用 `ProgressManager.advance_day()`，也不修改存档或服装数据。

**调用路由规则**：
- 对话 UI 是 `request_dialogue_sequence(day, context)` 的唯一常规请求方。
- 每日场景负责组装并传递 `day`、`scene_id`、`equipped_items`、`dialogue_context_tags` 上下文，承载对话 UI，并接收 `dialogue_sequence_finished(day)`。
- 每日场景不直接请求轻叙事对话 provider，除非对话 UI 不可用且每日场景进入 emergency fallback；该路径只允许请求 emergency fallback sequence，不得并行启动正式对话流程。
- 轻叙事对话不订阅 `dialogue_sequence_finished(day)`，不承接 GOODNIGHT，也不决定每日场景何时结束。

**内容范围**：
- MVP 使用 7 天线性内容表，每天一个主序列。
- 每天默认 3-5 行文本，最多 6 行。
- 每条文本必须短，适合对话 UI 底部浮层阅读。
- MVP 不做玩家选项、分支结局、好感度、评分、失败、任务评价。
- 内容可以回应场景 mood、day、scene_id 和轻量 tags。
- 服装响应只允许作为非评分式 flavor，不判断搭配优劣。

**请求契约**：
- 输入：`day: int`，`context: Dictionary`
- `context` 可包含：`scene_id`、`equipped_items`、`dialogue_context_tags`
- `day` 必须合法化到 `1..7`，但本系统不写回 ProgressManager 或 SaveManager。
- 若 `scene_id` 缺失，使用 day 对应默认场景内容。
- 若 `equipped_items` 缺失或为空，仍返回完整每日文本。
- 若 `dialogue_context_tags` 超过上限，只消费前 `MAX_DIALOGUE_CONTEXT_TAGS` 个。

**返回契约**：
- 返回 `DialogueSequence`
- `DialogueSequence` 至少包含：`sequence_id`、`day`、`scene_id`、`lines`
- `lines` 是线性数组，每个 `DialogueLine` 至少包含：
  - `line_id`
  - `speaker_id`
  - `speaker_name_key`
  - `text_key`
  - `portrait_expression`
  - `line_type`
- `line_type` 可为：`dialogue`、`narration`、`flavor`
- 玩家可见文本优先使用 `text_key` + `tr()`，不把正式文案硬编码在 UI 层。

**DialogueLine 兼容映射**：

| Provider field | Dialogue UI field | Requirement |
|----------------|-------------------|-------------|
| `speaker_name_key` | `speaker_name` / rendered speaker label | 正式内容输出 `speaker_name_key`；对话 UI 负责 `tr(speaker_name_key)` 后显示。 |
| `text_key` | `text_key` / rendered text | 正式内容输出 `text_key`；对话 UI 负责 `tr(text_key)`。Prototype-only `text` 只允许在内容表未本地化前临时使用。 |
| `line_type` | `line_type` | 正式 provider 只输出 `dialogue`、`narration`、`flavor`；`system_hint` 保留给对话 UI fallback/操作提示，不由轻叙事对话输出。 |
| `portrait_expression` | `portrait_expression` | 轻叙事对话提供 key；UI 或每日场景决定实际头像/立绘表现。 |

**内容数据载体规则**：
- MVP 内容表可以实现为 Godot `Resource`、`.tres`、JSON-like `Dictionary` 或同等静态数据结构，但必须在实现前固定为一个 provider API。
- 最小数据根为 `dialogue_sequences: Dictionary[int, DialogueSequence]`，必须含 `1..7` day key。
- 本地化文本表与内容表分离：内容表只保存 `text_key` 和 `speaker_name_key`，正式玩家可见文字由 ADR-0011 确认的 Godot Translation CSV 导入资源提供。
- 内容 provider 拥有数据校验职责：启动或测试阶段必须校验 day key、必填字段、line count、禁用评价语义、fallback sequence 和文本长度风险。

**服装 flavor 规则**：
- MVP 最多插入 1 条服装/氛围 flavor 行。
- flavor 只能表达“今天这身很适合这个场面”“这个颜色让今天更轻一点”这类认可式回应。
- 禁止使用“更好”“不合适”“失败”“正确搭配”“分数”“评级”等评价语义。
- 若无法识别服装类别或没有匹配 flavor，跳过 flavor，不影响主序列。
- 服装 flavor 不改变 day、解锁、进度或状态。

**内容安全规则**：
- 每天内容基调温暖、短促、生活化。
- Day 1 应像开始一本日记；Day 7 应温柔收束，但不显示通关、胜利或结算语气。
- 台词不得制造压力、催促、输赢、惩罚或强任务感。
- 不写复杂世界观设定，不引入第二角色主线，不制造后续必须兑现的大剧情悬念。
- 所有 fallback 文本也必须保持温和，不暴露资源错误或技术原因。

### States and Transitions

轻叙事对话是内容查询系统，不拥有玩家可见流程状态。内部状态只描述一次内容请求生命周期：

```text
IDLE
  -> RESOLVING_CONTEXT
  -> SELECTING_SEQUENCE
  -> APPLYING_FLAVOR
  -> RETURNING_SEQUENCE
  -> IDLE
```

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|----------|----------|
| `IDLE` | 无请求处理中 | 系统初始化完成或上次请求结束 | 收到 `request_dialogue_sequence(day, context)` |
| `RESOLVING_CONTEXT` | 合法化 day、scene_id、tags、equipped_items | 收到请求 | 上下文解析完成 |
| `SELECTING_SEQUENCE` | 从 7 天内容表选择基础序列 | 上下文合法化完成 | 找到 day/scene 对应序列或 fallback 序列 |
| `APPLYING_FLAVOR` | 可选插入一条非评分式 flavor | 基础序列存在 | flavor 应用或跳过 |
| `RETURNING_SEQUENCE` | 返回对话 UI 可播放的数据 | 序列组装完成 | 返回成功或 fallback 序列 |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|----------|
| 每日场景 | 本系统依赖其上下文 | 每日场景提供 `day`、`scene_id`、`equipped_items`、`dialogue_context_tags`，并承载对话 UI。轻叙事对话不请求 GOODNIGHT。 |
| 对话 UI | 对话 UI 依赖本系统 | 对话 UI 是 `request_dialogue_sequence(day, context)` 的唯一常规请求方，消费返回序列，并负责逐字显示、输入推进和 `dialogue_sequence_finished(day)`。 |
| 进度管理 | 间接只读 | day 的权威来源仍由 GameState/ProgressManager 提供。本系统只消费 day，不推进、不修正、不保存。 |
| 服装数据库 | 可选间接 | MVP 不直接查询服装数据库；若需要识别类别，优先消费 `equipped_items` 与未来上游提供的轻量 tags。 |
| 音频管理 | 无直接依赖 | 本系统不触发音频；对话 UI 或每日场景可根据 line_type/scene mood 触发轻量 UI 音效。 |
| 服装解锁 | 无直接依赖 | 本系统不展示新解锁，不读取新解锁列表，不影响解锁结果。 |

## Formulas

轻叙事对话不包含评分、好感度、情绪数值或分支权重。这里的公式只用于安全选择每日内容、限制上下文规模，以及确保 flavor 行不会膨胀范围。

### Day 合法化

```text
dialogue_day = clamp(requested_day, 1, TOTAL_DAYS)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `requested_day` | int | any int | 调用方传入的 day |
| `TOTAL_DAYS` | int | `7` | MVP 总天数 |
| `dialogue_day` | int | `1..7` | 本次对话实际使用的 day |

**Rule:** 合法化只影响本次内容选择；本系统不写回 ProgressManager 或 SaveManager。

### Sequence Selection

```text
sequence = dialogue_sequences.get(dialogue_day, dialogue_sequences[1])
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `dialogue_sequences` | Dictionary | keys `1..7` expected | 7 天线性内容表 |
| `dialogue_day` | int | `1..7` | 合法化后的 day |
| `sequence` | DialogueSequence | valid sequence | 返回给对话 UI 的基础序列 |

**Rule:** day 对应序列缺失时回退到 day 1 safe fallback sequence，并记录 warning。day 1 fallback sequence 必须存在且至少包含 1 条有效 line。

### Tags 裁剪

```text
usable_tags = dialogue_context_tags.slice(0, MAX_DIALOGUE_CONTEXT_TAGS)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `dialogue_context_tags` | Array[String] | `0..N` | 每日场景传入的轻量上下文 tags |
| `MAX_DIALOGUE_CONTEXT_TAGS` | int | default `4` | 本系统最多消费的 tags 数量 |
| `usable_tags` | Array[String] | `0..4` | 本次请求实际使用的 tags |

**Rule:** 超出上限的 tags 被忽略；不报错、不改变上下文原值。

### Flavor 插入上限

```text
flavor_line_count = min(candidate_flavor_lines.size(), MAX_FLAVOR_LINES_PER_SEQUENCE)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `candidate_flavor_lines` | Array[DialogueLine] | `0..N` | 根据 tags 或穿搭上下文找到的候选 flavor |
| `MAX_FLAVOR_LINES_PER_SEQUENCE` | int | default `1` | 每个序列最多插入的 flavor 行数 |
| `flavor_line_count` | int | `0..1` | 实际插入数量 |

**Rule:** MVP 每次最多插入 1 条 flavor line；若无安全候选，则插入 0 条。Flavor 不改变基础序列结尾语义。

## Edge Cases

- **If `requested_day` is missing or invalid**: use day 1 fallback content, record warning, and do not modify ProgressManager or SaveManager.
- **If `requested_day` is outside `1..7`**: clamp locally to `1..7`, record warning, and return a valid sequence.
- **If `dialogue_sequences[dialogue_day]` is missing**: use day 1 fallback sequence and record warning.
- **If day 1 fallback sequence is missing or empty**: return a built-in emergency safe sequence with one localized fallback key, record error, and mark content data as not implementation-ready.
- **If a sequence has zero lines**: treat it as invalid and use fallback.
- **If a line is missing `line_id`**: generate or attach a temporary diagnostic id for logging, but content data should fail validation before release.
- **If a line is missing `text_key`**: skip that line unless a prototype-only `text` fallback exists; formal content must use localization keys.
- **If all lines in a sequence are invalid**: use fallback sequence.
- **If `scene_id` is missing**: select by day only.
- **If `scene_id` is unknown**: select by day only and record warning.
- **If `dialogue_context_tags` is missing, empty, too long, or contains unknown tags**: ignore invalid tags, crop to max count, and still return the base sequence.
- **If `equipped_items` is missing or empty**: skip clothing flavor and return the base sequence.
- **If `equipped_items` contains invalid item ids**: ignore them; do not block the base sequence.
- **If multiple flavor candidates match**: choose at most one by deterministic priority, not random, so tests and localization remain stable.
- **If flavor candidate text implies judgement or scoring**: reject it during validation; do not include it in runtime output.
- **If Day 7 content is requested**: return normal final-day sequence with warm closure, not victory/ending/credits UI copy.
- **If content provider is unavailable**: caller may fall back to Dialogue UI fallback line; this system should also expose an emergency fallback sequence for direct use.
- **If localization key is missing at runtime**: caller/UI should show a safe fallback or skip line; content validation should catch this before implementation handoff.

## Dependencies

### Strong Dependencies

| Dependency | Type | Contract |
|------------|------|----------|
| 每日场景 | Strong | 提供 `day`、`scene_id`、`equipped_items`、`dialogue_context_tags` 上下文，并承载对话 UI。每日场景仍负责接收 `dialogue_sequence_finished(day)` 并请求 GOODNIGHT。 |
| 对话 UI | Strong | 作为唯一常规请求方调用 `request_dialogue_sequence(day, context)`，消费返回结果，负责逐字显示、输入推进、结束确认和 `dialogue_sequence_finished(day)`。 |
| 进度管理 | Indirect read-only | 提供 MVP 总天数和当前 day 语义。轻叙事对话只消费调用方传入的 day，不直接调用 `advance_day()`、不写进度。 |

### Optional / Future Dependencies

| Dependency | Type | Contract |
|------------|------|----------|
| 服装数据库 | Optional future | MVP 不直接查询。未来若需要更精确的服装 flavor，可通过每日场景或轻量标签传入类别/风格摘要，而不是让本系统解析完整服装数据。 |
| 音频管理 | Optional future | 本系统不播放音频。未来可在 `DialogueLine` 中提供 `mood_key` 或 `line_type` 给对话 UI/每日场景触发轻量音效。 |
| 本地化资源 | Production dependency | 正式内容必须使用 `text_key`、`speaker_name_key` 和 `tr()` 路径；实现前需要生成本地化表。 |
| 资产规格 | Production dependency | 表情 key、头像/立绘表情映射、每日 mood key 需要在资产规格或角色表现规格中对齐。 |

### Data Contract

| Data | Owner | Consumer | Notes |
|------|-------|----------|-------|
| `DialogueSequence` | 轻叙事对话 | 对话 UI / 每日场景 | 每日可播放内容的返回对象 |
| `DialogueLine` | 轻叙事对话 | 对话 UI | 单行文本、说话者、表情和 line type |
| `dialogue_sequences` | 轻叙事对话 | 轻叙事对话 | 7 天线性内容表 |
| `dialogue_context_tags` | 每日场景 | 轻叙事对话 | 只作为轻量氛围提示，最多消费 4 个 |
| `equipped_items` | 衣橱 UI / 每日场景 context | 轻叙事对话 | MVP 只用于可选 flavor，不做评分或合法性判断 |

### Dependency Constraints

- 轻叙事对话不调用 `GameState.request_transition(State.GOODNIGHT)`。
- 轻叙事对话不调用 `ProgressManager.advance_day()`。
- 轻叙事对话不修改 SaveManager、WardrobeDatabase 或衣橱装备状态。
- 轻叙事对话不决定对话 UI 布局、输入、逐字速度或结束按钮样式。
- 如果轻叙事对话不可用，对话 UI 必须先使用自己的 fallback provider；每日场景只在对话 UI 不可用时提供最小结束控件，让玩家到达 GOODNIGHT。
- 若后续改变 `request_dialogue_sequence(day, context)` 签名，必须同步修订每日场景和对话 UI GDD。

## Tuning Knobs

| Knob | Default | Range | Notes |
|------|---------|-------|-------|
| `TOTAL_DAYS` | `7` | fixed MVP | 与进度管理、每日场景一致；MVP 不在本系统单独调大。 |
| `LINES_PER_DAY_MIN` | `3` | `1..5` | 每天最少文本行数。低于 3 可能陪伴感不足，但 fallback 可为 1。 |
| `LINES_PER_DAY_MAX` | `5` | `3..6` | 每天默认最大文本行数。超过 6 会拖慢每日节奏。 |
| `MAX_FLAVOR_LINES_PER_SEQUENCE` | `1` | `0..1` MVP | 每次最多插入 1 条非评分 flavor。 |
| `MAX_DIALOGUE_CONTEXT_TAGS` | `4` | `0..8` | 与每日场景一致；MVP 默认消费前 4 个。 |
| `MAX_LINE_CHAR_COUNT` | `48` | `24..72` | 单行本地化后建议字符上限，保护对话 UI 可读性。 |
| `FALLBACK_SEQUENCE_DAY` | `1` | valid day | 内容缺失时使用 day 1 安全 fallback。 |
| `EMERGENCY_FALLBACK_TEXT_KEY` | `dialogue.fallback.daily_quiet` | localized key | 内容表严重缺失时的安全文本 key。 |

### Non-System Tuning

| Behavior | Controlled By | Notes |
|----------|---------------|-------|
| 逐字显示速度 | 对话 UI | 本系统只返回文本，不控制显示速度。 |
| 对话面板大小 | 对话 UI / UX spec | 本系统通过文本长度上限配合布局，不直接控制 UI。 |
| 每日背景与角色锚点 | 每日场景 / UX / Asset spec | 本系统只使用 `scene_id` 和 tags 做内容选择。 |
| 解锁奖励展示 | 服装解锁 / 晚安 UI | 本系统不展示新解锁。 |
| 服装类目可见性 | 进度管理 / 衣橱 UI | 本系统不决定哪些类目可见。 |

## Visual/Audio Requirements

轻叙事对话本身不渲染画面、不播放音频，但它输出的 `portrait_expression`、`line_type`、`mood_key` 和文本基调会影响每日场景、对话 UI、角色表现和音频氛围，因此必须约束内容表达方式。

### Visual Expression Requirements

| Area | Requirement | Notes |
|------|-------------|-------|
| 表情 key | 每条 `DialogueLine` 必须提供 `portrait_expression` | 默认可为 `neutral_soft`，不得依赖 UI 猜测 |
| 表情范围 | MVP 表情数量保持小而稳定 | 建议 `neutral_soft`、`happy_soft`、`thinking_soft`、`sleepy_soft`、`surprised_soft` |
| 表情语气 | 表情必须温柔、生活化 | 不使用强烈愤怒、惊吓、哭泣、失败、嘲笑等压力表情 |
| Line type | 每条 line 必须标记 `dialogue`、`narration` 或 `flavor` | UI 可据此决定角色名显示、文本节奏或轻量样式 |
| Mood key | 每个 sequence 可选提供 `mood_key` | 如 `quiet_morning`、`soft_outing`、`warm_closure`；只用于氛围，不做分支逻辑 |
| 文本长度 | 每条文本必须适合底部对话面板 | 以 `MAX_LINE_CHAR_COUNT` 为建议上限，避免 UI 溢出 |

### Audio Expression Requirements

| Area | Requirement | Notes |
|------|-------------|-------|
| 音频触发 | 本系统不直接播放音频 | 只提供 `line_type` 或 `mood_key` 给对话 UI/每日场景参考 |
| 声音方向 | 文本语气不应要求强音效 | 不写“砰”“尖叫”“胜利音乐响起”等强刺激提示 |
| 日常氛围 | mood 应支持低密度背景氛围 | 清晨、散步、咖啡馆、睡前等温和方向 |
| 结束语气 | Day 7 也不使用胜利/通关音效语义 | 只表达温柔收束 |
| Fallback | fallback 文本不暴露错误原因 | 不出现“文本加载失败”“资源缺失”等玩家可见技术语气 |

### Content Style Constraints

- 台词应像日记页、生活片段或轻声聊天，不像任务说明或教程。
- 每天 3-5 行文本应有一个轻微情绪弧线：进入当天 -> 轻声回应 -> 温柔收束。
- 服装 flavor 只增加被看见的感觉，不改变故事结果。
- 不使用攻略式词汇，例如“达成”“完成目标”“奖励”“解锁条件”。
- 不使用比较式评价，例如“比昨天好”“这件不如那件”“更高级”。
- 不使用暗示失败的文本，例如“这样也可以吧”“虽然不太适合”。

### Asset Spec Flag

后续 `/asset-spec system:light-narrative-dialogue` 需要生成或确认：`portrait_expression` key 列表、`mood_key` 列表、7 天 `sequence_id` 命名、正式本地化 key 表、fallback 文本 key、可选 flavor line key，以及 line_type 到 UI/音频表现的映射建议。

## UI Requirements

轻叙事对话不拥有 UI 组件，但它必须输出对话 UI 能稳定消费的数据。

| Requirement | Notes |
|-------------|-------|
| 所有玩家可见文本必须提供 `text_key` | 原型可保留 `text`，正式内容必须走本地化 |
| 所有说话者名称必须提供 `speaker_name_key` | 旁白可使用 narrator key 或隐藏显示，由对话 UI 决定 |
| 每条 line 必须有稳定 `line_id` | 用于测试、日志、跳过坏行和定位本地化问题 |
| 每个 sequence 必须有稳定 `sequence_id` | 建议格式 `daily.day_{n}.{scene_id}` |
| line 顺序必须固定 | MVP 不随机、不重排，保证测试和本地化稳定 |
| 返回 sequence 不包含 UI 布局参数 | 面板高度、逐字速度、按钮样式由对话 UI 控制 |
| 返回 sequence 不包含状态转换指令 | 不包含 `go_to_goodnight`、`advance_day` 等命令 |
| 文本必须允许分页或拆行 | 若本地化后过长，对话 UI 可分页；内容表仍应控制长度 |
| flavor line 必须可识别 | `line_type == flavor`，方便 UI 或测试确认它不是主剧情分支 |
| fallback sequence 必须可播放 | 即使内容表缺失，也至少返回一条安全文本 key |
| `system_hint` 不由本系统输出 | 操作提示归对话 UI；轻叙事对话只输出叙事和 flavor 内容 |

## Acceptance Criteria

### 请求与返回

1. **GIVEN** `request_dialogue_sequence(day, context)` 收到 `day == 1..7`，**WHEN** 对应内容存在，**THEN** 返回该 day 的 `DialogueSequence`。
2. **GIVEN** 返回任意 `DialogueSequence`，**WHEN** 检查数据结构，**THEN** 它包含 `sequence_id`、`day`、`scene_id`、`lines`。
3. **GIVEN** 返回任意 `DialogueLine`，**WHEN** 检查字段，**THEN** 它包含 `line_id`、`speaker_id`、`speaker_name_key`、`text_key`、`portrait_expression`、`line_type`。
4. **GIVEN** MVP 正常内容表，**WHEN** 检查每天内容，**THEN** 每天主序列包含 3-5 条可播放 line，且不超过 `LINES_PER_DAY_MAX`。
5. **GIVEN** `scene_id` 缺失，**WHEN** 请求对话序列，**THEN** 系统按 day 返回默认序列。
6. **GIVEN** `scene_id` 未知，**WHEN** 请求对话序列，**THEN** 系统按 day 返回默认序列并记录 warning。

### Day 与 fallback

7. **GIVEN** `requested_day` 小于 1 或大于 7，**WHEN** 请求对话序列，**THEN** 本地 clamp 到 `1..7`，返回有效序列，且不写 ProgressManager 或 SaveManager。
8. **GIVEN** `requested_day` 缺失或类型非法，**WHEN** 请求对话序列，**THEN** 返回 day 1 fallback sequence 并记录 warning。
9. **GIVEN** 某 day 的 sequence 缺失，**WHEN** 请求该 day，**THEN** 返回 day 1 fallback sequence。
10. **GIVEN** day 1 fallback sequence 缺失或为空，**WHEN** 请求任意内容，**THEN** 返回 emergency fallback sequence，记录 error，并标记内容数据不应通过实现交付校验。
11. **GIVEN** 某 sequence 的所有 line 无效，**WHEN** 请求该 sequence，**THEN** 使用 fallback sequence。

### Tags 与 flavor

12. **GIVEN** `dialogue_context_tags` 超过 `MAX_DIALOGUE_CONTEXT_TAGS`，**WHEN** 请求对话序列，**THEN** 只消费前 `MAX_DIALOGUE_CONTEXT_TAGS` 个 tag。
13. **GIVEN** `dialogue_context_tags` 缺失、为空或包含未知 tag，**WHEN** 请求对话序列，**THEN** 返回基础序列，不阻塞对话。
14. **GIVEN** `equipped_items` 缺失或为空，**WHEN** 请求对话序列，**THEN** 不插入服装 flavor，但仍返回基础序列。
15. **GIVEN** 有多个 flavor 候选，**WHEN** 组装序列，**THEN** 最多插入 `MAX_FLAVOR_LINES_PER_SEQUENCE` 条，MVP 默认最多 1 条。
16. **GIVEN** flavor 被插入，**WHEN** 检查 line，**THEN** `line_type == flavor`，且文本不包含评分、优劣、失败、正确搭配或惩罚语义。
17. **GIVEN** flavor 候选包含评价式文案，**WHEN** 内容校验执行，**THEN** 该候选被拒绝，不进入运行时输出。

### 内容安全与本地化

18. **GIVEN** 正式内容数据，**WHEN** 检查玩家可见文本，**THEN** 所有 line 使用 `text_key`，不要求对话 UI 硬编码文本。
19. **GIVEN** 正式内容数据，**WHEN** 检查说话者名称，**THEN** 所有 line 使用 `speaker_name_key` 或旁白约定 key。
20. **GIVEN** 某 line 缺少 `line_id`，**WHEN** 内容校验执行，**THEN** 数据不通过实现交付校验。
21. **GIVEN** 某 line 缺少 `text_key`，**WHEN** 正式内容校验执行，**THEN** 数据不通过实现交付校验；原型-only `text` fallback 不计入正式通过。
22. **GIVEN** 任意 line 文本本地化后超过 `MAX_LINE_CHAR_COUNT`，**WHEN** 内容校验执行，**THEN** 记录文本长度风险，需拆行、分页或缩短。
23. **GIVEN** Day 7 内容，**WHEN** 检查文本语气，**THEN** 它表达温柔收束，不显示胜利、通关、评分、奖励或结算语气。

### 系统边界

24. **GIVEN** 任意对话请求，**WHEN** 检查调用记录，**THEN** 轻叙事对话没有调用 `GameState.request_transition(State.GOODNIGHT)`。
25. **GIVEN** 任意对话请求，**WHEN** 检查调用记录，**THEN** 轻叙事对话没有调用 `ProgressManager.advance_day()`。
26. **GIVEN** 任意对话请求，**WHEN** 检查数据写入，**THEN** 轻叙事对话没有修改 SaveManager、WardrobeDatabase 或衣橱装备状态。
27. **GIVEN** 对话 UI 消费返回序列，**WHEN** 播放结束，**THEN** 完成事件仍由对话 UI 发出，GOODNIGHT 请求仍由每日场景承接。
28. **GIVEN** 内容 provider 不可用，**WHEN** 对话 UI 请求内容，**THEN** 对话 UI fallback provider 返回安全内容或进入结束确认；若对话 UI 本身不可用，每日场景 fallback 结束控件仍允许玩家到达 GOODNIGHT。
29. **GIVEN** 每日场景和对话 UI 都存在，**WHEN** DAILY_SCENE 启动对话，**THEN** 只有对话 UI 调用 `request_dialogue_sequence(day, context)`。

### 表情与 mood

30. **GIVEN** 任意 `DialogueLine`，**WHEN** 检查视觉字段，**THEN** `portrait_expression` 属于允许的 MVP 表情 key 或明确 fallback 为 `neutral_soft`。
31. **GIVEN** 任意 `DialogueSequence`，**WHEN** 存在 `mood_key`，**THEN** 它只影响表现建议，不改变内容分支、状态或进度。
32. **GIVEN** sequence line 顺序，**WHEN** 同一 day/context 重复请求，**THEN** 返回顺序稳定，不随机、不重排。
33. **GIVEN** 正式 provider 返回 line，**WHEN** 检查 `line_type`，**THEN** 不会返回 `system_hint`；UI 操作提示由对话 UI fallback/提示逻辑拥有。

## Open Questions

| Question | Owner | Target Resolution | Notes |
|----------|-------|-------------------|-------|
| MVP 7 天的正式 `sequence_id`、`scene_id` 和每日文本 key 是什么？ | 叙事 / 内容设计 | `/asset-spec system:light-narrative-dialogue` 或内容表制作前 | 本 GDD 定义结构，不直接写完整台词表。 |
| MVP 是否需要真实服装 flavor，还是只使用 scene/tag flavor？ | 叙事 / 制作 | 实现排期前 | 当前允许最多 1 条非评分 flavor，但可在 MVP 中先关闭。 |
| `portrait_expression` key 是否映射角色立绘表情，还是对话 UI 头像表情？ | 美术 / 对话 UI / 每日场景 | 资产规格前 | 本 GDD 只定义 key，不决定具体渲染位置。 |
| `mood_key` 是否需要接入音频氛围，还是只作为内容元数据？ | 音频 / 每日场景 | 资产规格前 | 当前不作为强依赖。 |
| 正式本地化表格式 | 本地化 / 技术设计 | Resolved by ADR-0011 | ADR-0011 已锁定 Godot Translation CSV 导入；内容表只保存 key，并保证 `text_key` 可被 `tr()` 路径消费。 |
| 内容校验由哪个工具执行？ | QA / 工程 | story 创建前 | 建议实现轻量内容验证测试，检查字段、长度、禁用词和 fallback。 |
