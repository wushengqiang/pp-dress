# 每日场景 (Daily Scene)

> **Status**: Approved
> **Author**: user + Codex Game Studios
> **Last Updated**: 2026-06-09
> **Implements Pillar**: 每日陪伴, 随心搭配

> **Quick reference** - Layer: `Feature` · Priority: `MVP` · Key deps: `场景/状态管理`, `精灵分层渲染`, `对话 UI`, `进度管理`

## Overview

每日场景是「每日穿搭」中玩家确认穿搭后的当日呈现场景，负责把 `GameState` 中的当前天数与玩家穿搭上下文，组合成一段可观看、可阅读、可结束的每日小片段。它实例化角色精灵，应用衣橱确认后的 `equipped_items`，加载当天背景与氛围表现，并承载对话 UI 逐句播放当天轻叙事；当对话结束并由玩家确认后，每日场景请求 `DAILY_SCENE → GOODNIGHT`，把流程交给晚安画面收束。对玩家来说，它是“我刚搭好的衣服真的走进了今天的故事里”的那一刻：没有评分、没有失败、没有任务结算，只有角色穿着玩家选择的搭配，在一个温暖的日常场面中度过今天。系统边界上，每日场景不推进天数、不写入进度、不拥有正式剧情文本、不直接管理服装数据；它是每日循环的编排与呈现层，服务「每日陪伴」与「随心搭配」。

## Player Fantasy

每日场景的玩家幻想是：“我刚刚为她选好的衣服，不只是停在衣橱里，而是真的陪她走进了今天。”

玩家确认穿搭后，应该立刻感到自己的选择被这个小世界温柔接住：角色穿着刚搭好的衣服出现在当天场景中，背景、站姿、对话和轻柔反馈一起告诉玩家“这就是今天”。这里不应该像任务提交、穿搭评分或剧情结算，而应该像翻开一页新的穿搭日记：今天可能是出门散步、在房间休息、去咖啡馆坐一会儿，角色用几句短短的话回应这个日子，也回应玩家刚刚做出的搭配。玩家不需要证明自己搭得好，只需要看到“我的搭配成为了今天故事的一部分”。

这个系统服务「每日陪伴」：每天都有一个清晰、温暖的小场面，让玩家觉得自己和角色认真见了一面；也服务「随心搭配」：无论玩家选择哪套衣服，每日场景都以认可而非评判的方式呈现它。最理想的感受不是“我完成了一关”，而是“今天这一页被我轻轻写下来了”。

## Detailed Design

### Core Rules

**系统定位**：每日场景是 `DAILY_SCENE` 状态下的场景编排器，负责把当前天数、玩家确认的穿搭、角色显示、当日背景氛围和对话 UI 组合成一段完整的每日呈现。它不拥有进度、不拥有服装数据、不拥有正式剧情文本，也不评价玩家穿搭。

**进入规则**：
- 每日场景只在 `GameState.current_state == DAILY_SCENE` 时激活。
- 场景 `_ready()` 中必须主动读取 `GameState.current_state` 和 `GameState.context`，不能只等待 `state_changed`。
- 当前天数优先来自 `GameState.context["current_day"]`；若缺失，则使用 `GameState.get_current_day()`。
- 当日穿搭来自 `GameState.context["equipped_items"]`，类型为 `Array[String]`；缺失或 `null` 表示没有保存穿搭上下文，空数组 `[]` 表示玩家明确确认了空穿搭。

**GameState 就绪握手规则**：
- 每日场景完成最小安全初始化后，必须调用 `GameState._on_scene_ready()` 或项目约定的等价场景就绪回调一次，用于释放场景/状态管理的转场锁。
- 最小安全初始化指：已确认当前状态仍为 `DAILY_SCENE`，已解析 `scene_day`，已选择有效 `scene_config` 或 day 1 fallback 配置，并且场景根节点可安全显示。
- 就绪回调不等待正式对话结束，也不要求全部音频资源可用；视觉资源若进入安全 fallback，仍可完成就绪握手。
- 每个 Daily Scene 实例最多发送一次就绪回调；迟到的 outfit、dialogue、timer 或卸载回调不得再次发送。

**角色呈现规则**：
- 每日场景实例化 `Character` 场景，而不是直接创建或操作单个服装精灵。
- 若 `equipped_items` 存在且为数组，无论是否为空，每日场景都调用角色渲染器 `apply_outfit(equipped_items)`。
- 若 `equipped_items` 缺失或为 `null`，每日场景可调用 `equip_default_outfit(day)` 或展示安全默认穿搭；该兜底不得阻塞对话流程。
- 每日场景等待 `outfit_applied(item_ids)`，或在渲染器已就绪但无穿搭可应用时进入视觉就绪状态。
- 角色位置、缩放和在场景中的构图由每日场景决定；`Character` 子场景不硬编码 DAILY_SCENE 尺寸。

**场景内容规则**：
- 每日场景根据 `day` 选择当天背景、氛围标签和轻量场景配置。
- MVP 使用 7 天线性场景配置，每天一个场景入口；不做随机日程、不做分支地图、不做玩家选择路线。
- 场景配置可包含 `scene_id`、`day`、`background_key`、`music_event_key`、`ambience_key`、`character_anchor`、`dialogue_context_tags`。
- 每日场景可以把 `day`、`scene_id`、`equipped_items` 和轻量 tags 传给对话 UI 或未来轻叙事对话系统，但不解析服装评分或搭配优劣。

**Scene Config Contract**：
- `daily_scene_configs` 由 Daily Scene 系统拥有，MVP 必须提供 `1..7` 七个 day key；缺失任一天配置必须记录 warning，并回退到 day 1 safe fallback。
- day 1 配置是强制安全 fallback，必须始终存在且通过校验；若 day 1 配置缺失或无效，属于实现/数据构建错误，不应通过 smoke/QA。
- 每个 `scene_config` 必填字段为 `scene_id: String`、`day: int`、`background_key: String`、`character_anchor: String`、`dialogue_context_tags: Array[String]`。
- 可选字段为 `music_event_key: String`、`ambience_key: String`、`background_variant_key: String`、`character_scale: float`。
- `scene_id` 必须在 7 天内唯一；`day` 必须与字典 key 一致；`dialogue_context_tags` 进入对话 UI 前必须裁剪到 `MAX_DIALOGUE_CONTEXT_TAGS`。
- `background_key` 和 `character_anchor` 可以先使用资源 key / anchor key，不在本 GDD 定义具体坐标；具体资源与坐标由 `/asset-spec system:daily-scene` 和 `/ux-design daily-scene` 细化。

**对话启动规则**：
- 每日场景必须在角色视觉就绪后启用或启动对话 UI，避免文字先出现而角色仍为空或未换装完成。
- 对话 UI 使用 ADR-0011 确认的 `LightNarrativeDialogue.request_dialogue_sequence(day, context)` 正式契约；每日场景只提供上下文，不直接请求 provider，也不拥有正式台词库。
- 每日场景监听 `dialogue_sequence_finished(day)`。
- 收到对话完成事件后，每日场景请求 `GameState.request_transition(State.GOODNIGHT)` 或等价 `DAILY_SCENE -> GOODNIGHT` 入口。
- 每日场景不调用 `ProgressManager.advance_day()`；天数推进只发生在 `GOODNIGHT -> MAIN_MENU`。

**音频与反馈规则**：
- 每日场景可在进入时请求 `AudioManager.play_event("scene.daily.entered", {"day": day, "scene_id": scene_id})` 或请求当天音乐事件。
- 若当天音乐未定义，音频管理回退到通用每日场景音乐。
- `scene.daily.entered`、`scene.music.daily_generic`、`scene.music.day_{n}` 是每日场景新增音频事件需求；实现前必须由音频管理或资产规格登记映射，否则只能作为可降级 warning 处理。
- 场景进入、角色就绪、对话开始的反馈应轻柔、低干扰，不做胜利、评级或任务完成表现。
- 音频不可用时，每日场景流程照常继续。

**禁止职责**：
- 不评分、不排名、不判断穿搭正确性。
- 不修改 `ProgressManager`、`SaveManager` 或服装数据库。
- 不直接加载服装纹理；服装视觉交给精灵分层渲染和资源加载器。
- 不拥有正式剧情内容；未来由轻叙事对话系统提供内容。
- 不在对话结束时直接显示新解锁服装；服装解锁属于后续系统。

### States and Transitions

```text
UNINITIALIZED
  -> READING_CONTEXT
  -> BUILDING_SCENE
  -> APPLYING_OUTFIT
  -> READY_FOR_DIALOGUE
  -> DIALOGUE_RUNNING
  -> WAITING_GOODNIGHT_TRANSITION
  -> EXITING
```

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|----------|----------|
| `UNINITIALIZED` | 场景节点尚未读取上下文 | DAILY_SCENE 场景实例化 | `_ready()` 开始 |
| `READING_CONTEXT` | 读取 day 与 equipped_items | `_ready()` | 上下文读取完成或使用兜底 |
| `BUILDING_SCENE` | 创建背景、角色锚点、对话 UI 容器 | 上下文就绪 | 场景节点准备完成 |
| `APPLYING_OUTFIT` | 向 Character 应用玩家穿搭 | Character 就绪且有穿搭数据 | 收到 `outfit_applied` 或安全兜底完成 |
| `READY_FOR_DIALOGUE` | 角色与场景可见，可启动对话 | 视觉就绪 | 启动对话 UI |
| `DIALOGUE_RUNNING` | 对话 UI 正在播放当天片段 | 对话 UI 启动 | 收到 `dialogue_sequence_finished(day)` |
| `WAITING_GOODNIGHT_TRANSITION` | 已请求进入 GOODNIGHT，防重复触发 | 对话完成 | GameState 接管场景切换 |
| `EXITING` | 场景正在卸载 | 状态切换开始或场景离开树 | 节点销毁 |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|----------|
| 场景/状态管理 | 强依赖 | 读取 `GameState.current_state`、`GameState.context`、`GameState.get_current_day()`；对话完成后请求 `DAILY_SCENE -> GOODNIGHT` |
| 精灵分层渲染 | 强依赖 | 实例化 `Character`，调用 `apply_outfit(equipped_items)` 或兜底默认穿搭，等待 `outfit_applied(item_ids)` |
| 对话 UI | 强依赖 | 启动每日对话，传入 day/context，监听 `dialogue_sequence_finished(day)` |
| 进度管理 | 间接只读 | 通过 GameState Facade 获取当前 day；每日场景不直接调用 `advance_day()` |
| 轻叙事对话 | 强依赖 | 通过 ADR-0011 提供正式每日台词 key、场景文本 key、表情 key 和服装 flavor 响应 |
| 音频管理 | 弱依赖 | 请求每日场景进入、音乐、氛围或转场事件；音频失败不阻塞流程 |
| 主菜单/晚安 UI | 下游流程 | 每日场景进入 GOODNIGHT 后，由晚安 UI 承接当日收束 |

## Formulas

每日场景不包含评分、成长、经济或服装优劣公式。这里的规则只用于决定当天场景如何选择、何时可以启动对话、以及如何防止对话结束后重复请求晚安转换。

### Day 合法化

```text
scene_day = clamp(raw_day, 1, TOTAL_DAYS)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `raw_day` | `D_raw` | int | any int | 从 `GameState.context["current_day"]` 或 `GameState.get_current_day()` 读取的原始天数 |
| `TOTAL_DAYS` | `D_max` | int | `7` | MVP 总天数，来自进度管理 |
| `scene_day` | `D` | int | `1..7` | 每日场景实际使用的天数 |

**Output Range:** `1..7`。
**Rule:** clamp 只用于本场景显示和配置选择；每日场景不修正 ProgressManager 或 SaveManager 中的数据。
**Example:** `raw_day = 0` -> `scene_day = 1`；`raw_day = 9` -> `scene_day = 7`。

### 场景配置选择

```text
scene_config = daily_scene_configs.get(scene_day, daily_scene_configs[1])
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `daily_scene_configs` | `C` | Dictionary | keys `1..7` expected | 7 天每日场景配置表 |
| `scene_day` | `D` | int | `1..7` | 合法化后的天数 |
| `scene_config` | `C_D` | Dictionary | valid config | 当天要使用的背景、音乐、角色锚点和对话标签 |

**Output Range:** 一个有效场景配置。
**Rule:** 若某天配置缺失，回退到第 1 天安全配置并记录 warning，不阻塞对话流程。
**Example:** `scene_day = 4` 且配置存在 -> 使用第 4 天；第 4 天配置缺失 -> 使用第 1 天 fallback。

### 视觉就绪判定

```text
visual_ready = background_ready AND character_ready AND outfit_ready
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `background_ready` | `B` | bool | true/false | 背景或安全 fallback 背景是否可显示 |
| `character_ready` | `K` | bool | true/false | `Character` 实例是否存在且渲染器可用 |
| `outfit_ready` | `O` | bool | true/false | 玩家穿搭已应用，或已进入安全默认穿搭兜底 |
| `visual_ready` | `V` | bool | true/false | 是否可以启动对话 UI |

**Output Range:** boolean。
**Rule:** 对话 UI 必须在 `visual_ready == true` 后启动。若某个视觉资源缺失，应进入安全 fallback，而不是让流程卡死。
**Example:** 背景缺失但 fallback 背景可显示、角色默认穿搭就绪 -> `visual_ready = true`。

### 对话启动判定

```text
dialogue_can_start = visual_ready AND current_state == DAILY_SCENE AND dialogue_started == false
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `visual_ready` | `V` | bool | true/false | 视觉就绪判定结果 |
| `current_state` | `S` | enum | `GameState.State` | 当前游戏状态 |
| `dialogue_started` | `Q` | bool | true/false | 当前每日场景是否已经启动过对话 |
| `dialogue_can_start` | `A` | bool | true/false | 本帧是否允许启动对话 UI |

**Output Range:** boolean。
**Rule:** 每次进入每日场景只启动一次对话；场景恢复或信号重复到达不得重复请求对话序列。
**Example:** `visual_ready=true`、状态为 `DAILY_SCENE`、`dialogue_started=false` -> 启动对话并把 `dialogue_started` 设为 true。

### 晚安转换防重复

```text
goodnight_transition_allowed =
    dialogue_finished == true
    AND goodnight_transition_requested == false
    AND current_state == DAILY_SCENE
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `dialogue_finished` | `F` | bool | true/false | 是否已收到 `dialogue_sequence_finished(day)` |
| `goodnight_transition_requested` | `G` | bool | true/false | 是否已经请求过进入 GOODNIGHT |
| `current_state` | `S` | enum | `GameState.State` | 当前游戏状态 |
| `goodnight_transition_allowed` | `T` | bool | true/false | 是否允许请求 `DAILY_SCENE -> GOODNIGHT` |

**Output Range:** boolean。
**Rule:** 每个每日场景实例最多请求一次 GOODNIGHT 转换；重复的对话完成信号、快速点击或场景卸载期间的迟到信号都不得再次触发转换。
**Example:** 第一次收到完成事件 -> 请求 GOODNIGHT 并设 `goodnight_transition_requested=true`；第二次完成事件 -> 忽略。

## Edge Cases

- **If `GameState.current_state` is not `DAILY_SCENE` when the scene initializes**: keep daily scene content disabled, do not start dialogue, and log a warning. This prevents stale DAILY_SCENE nodes from driving state changes after an invalid load.
- **If `current_day` is missing from context**: use `GameState.get_current_day()` as the fallback source. Do not write the value back to ProgressManager or SaveManager.
- **If the resolved day is outside `1..7`**: clamp it locally for scene configuration and display, record a warning, and continue with the clamped day.
- **If the scene config for the resolved day is missing**: use day 1 safe fallback config, record a warning, and continue. The player should still see a complete scene and be able to reach GOODNIGHT.
- **If day 1 safe fallback config is missing or invalid**: treat this as a build/data error, record an error, and do not consider the build implementation-ready. Runtime may still show the safest available neutral fallback to avoid trapping the player.
- **If the background asset for the selected scene is missing or fails to load**: display a neutral fallback background and continue. Do not block dialogue or state transition.
- **If `equipped_items` is missing from context or is null**: use `equip_default_outfit(scene_day)` or a safe default outfit. Do not treat this as player failure.
- **If `equipped_items` is present but empty (`[]`)**: treat it as an explicit empty outfit, call `apply_outfit([])`, wait for `outfit_applied([])`, and continue to dialogue without replacing it with default clothing.
- **If `equipped_items` contains invalid item IDs**: pass valid IDs to the Character renderer where possible; invalid IDs are ignored or warned by the renderer. If no valid outfit remains because every ID is invalid, call `apply_outfit([])` only when the original context key existed; use the default outfit fallback only when the context key was missing/null.
- **If `Character` fails to instantiate**: show the scene background and dialogue UI using a non-character fallback presentation, record an error, and allow the player to finish the day. This is an emergency degraded path: it must not trap the player at runtime, but a normal smoke/QA pass must treat it as a failure to fix before release.
- **If the Character renderer exists but is not ready**: wait briefly for readiness; if it remains unavailable, enter fallback visual-ready state and start dialogue without blocking progression.
- **If `apply_outfit(equipped_items)` never emits `outfit_applied`**: after a timeout, use the current renderer state or default outfit as fallback, record a warning, and start dialogue.
- **If `outfit_applied` arrives after the scene has moved to `EXITING`**: ignore the late signal and do not start dialogue or modify UI.
- **If dialogue UI cannot be found or instantiated**: show a fallback end-of-day confirmation control owned by Daily Scene, allowing the player to request GOODNIGHT. Record an error for implementation follow-up.
- **If `request_dialogue_sequence(day, context)` fails through the dialogue UI fallback path**: rely on Dialogue UI's fallback line or completion path; Daily Scene should still receive completion or provide a fallback finish control.
- **If `dialogue_sequence_finished(day)` is emitted more than once**: only the first valid event may request `DAILY_SCENE -> GOODNIGHT`; later events are ignored.
- **If `dialogue_sequence_finished(day)` carries a day different from the active `scene_day`**: record a warning but allow the first completion event to finish the current scene unless the scene is already exiting.
- **If the player triggers the ending control repeatedly**: keep `goodnight_transition_requested == true` after the first request and ignore repeats until GameState completes or rejects the transition.
- **If `GameState.request_transition(State.GOODNIGHT)` is rejected**: keep the scene in a safe waiting state, re-enable the ending control after transition lock timeout, and show only a gentle retry affordance.
- **If the scene is unloaded while dialogue is running**: disconnect signals, stop pending timers, and prevent late callbacks from emitting GOODNIGHT requests.
- **If AudioManager is unavailable or the daily scene audio event is unregistered**: continue silently and record a warning. Audio failure never blocks visual presentation or dialogue.
- **If day 7 completes**: request GOODNIGHT normally. Do not show day 8, do not advance progress, and do not display completion/replay UI inside Daily Scene.
- **If browser refresh occurs during DAILY_SCENE**: recovery is owned by Save/Load and GameState. Daily Scene may be re-entered from saved `scene_in_progress`; when restored, it restarts from the beginning of the daily scene with saved day/outfit context.
- **If viewport size changes during the scene**: recompute character anchor, background fit, and dialogue-safe regions. Do not rely on stale anchors from the initial layout.
- **If visual fallback and dialogue fallback both trigger**: still preserve the emotional tone: no broken-resource text, no technical error copy, no failure language, and no scoring or punishment framing.

## Dependencies

### Strong Dependencies

| Dependency | Type | Contract |
|------------|------|----------|
| 场景/状态管理 | Strong | 提供 `GameState.current_state`、`GameState.context`、`GameState.get_current_day()`、`GameState.request_transition(State.GOODNIGHT)` 和 `GameState._on_scene_ready()` 或等价场景就绪回调。每日场景必须在 `_ready()` 主动读取当前状态和上下文，完成最小安全初始化后只发送一次就绪回调，不能只依赖 `state_changed`。 |
| 精灵分层渲染 | Strong | 提供可实例化的 `Character` 场景，以及 `apply_outfit(item_ids)`、`equip_default_outfit(day)`、`get_equipped_items()`、`outfit_applied(item_ids)`。每日场景不直接操作服装 Sprite2D 或纹理。 |
| 对话 UI | Strong | 提供 DAILY_SCENE 内的对话显示、输入推进和结束事件。每日场景启动或启用对话 UI，并监听 `dialogue_sequence_finished(day)`。对话 UI 不直接请求 GOODNIGHT，Daily Scene 是该事件的承接者。 |
| 进度管理 | Indirect read-only | 通过 GameState Facade 提供当前 day 和总天数语义。每日场景不直接调用 `ProgressManager.advance_day()`、不修改完成状态、不写解锁数据。 |

### Context Contract

| Context Key | Type | Written By | Read By Daily Scene | Required Behavior |
|-------------|------|------------|---------------------|-------------------|
| `current_day` | `int` | GameState / ProgressManager facade | Yes | 优先用于选择每日场景配置；缺失时回退到 `GameState.get_current_day()` |
| `equipped_items` | `Array[String]` | 衣橱 UI at WARDROBE confirmation | Yes | 用于恢复玩家确认穿搭；缺失或 `null` 时使用默认穿搭兜底；`[]` 是明确空穿搭，必须按空穿搭恢复 |
| `scene_in_progress` | `bool` | Save/Load future flow | Optional | GameState 在 BOOT 恢复时使用；每日场景不写该字段 |

### Optional / Weak Dependencies

| Dependency | Type | Contract |
|------------|------|----------|
| 音频管理 | Weak | 每日场景可请求 `scene.daily.entered`、`scene.transition_page`、`scene.music.day_{n}` 或通用每日音乐事件。音频管理缺失、静音或事件未注册时，场景流程照常继续。 |
| 资源加载器 | Indirect | 背景、角色和服装纹理由对应显示系统或资源加载流程处理。每日场景可以引用背景配置 key，但不直接加载服装纹理。 |
| 主菜单/晚安 UI | Downstream flow | 每日场景完成后只请求进入 GOODNIGHT；晚安 UI 负责显示当日收束、继续按钮和后续主菜单返回。 |

### Future Dependencies

| Dependency | Type | Contract |
|------------|------|----------|
| 轻叙事对话 | Strong | 通过 ADR-0011 接管每日文本 key、旁白 key、表情 key、场景台词 key 和服装 flavor 响应。每日场景只传入 `day`、`scene_id`、`equipped_items` 和 tags，不拥有正式剧情内容。 |
| 服装解锁 | Future downstream | 每日场景结束后不展示新解锁内容；服装解锁系统可在 GOODNIGHT 后或返回主菜单时接入。 |
| UX spec / Asset spec | Future production dependency | 每日场景的具体背景构图、角色锚点、对话安全区和音频/视觉资产需在后续 `/ux-design daily-scene` 与 `/asset-spec system:daily-scene` 中细化。 |

### Dependency Constraints

- 每日场景是编排者，不是进度 owner、剧情 owner、服装数据 owner 或音频资源 owner。
- `equipped_items` 的语义必须保持为 `Array[String]` 物品 ID 列表，与场景/状态管理、衣橱 UI、精灵分层渲染一致。
- `dialogue_sequence_finished(day)` 的长期接口若被轻叙事对话或对话 UI 修订，必须回传修订本 GDD。
- `GOODNIGHT -> MAIN_MENU` 才是进度推进点；每日场景不得提前完成或推进 day。
- 若未来加入服装影响台词，只能作为非评分式 flavor 响应，不得引入“正确搭配”判定。

## Tuning Knobs

| Knob | Default | Range | Notes |
|------|---------|-------|-------|
| `OUTFIT_APPLY_TIMEOUT_MS` | `800` | `300..2000` | 等待 `outfit_applied` 的最大时间。超时后使用当前角色状态或默认穿搭兜底，避免卡住对话。 |
| `SCENE_FADE_IN_MS` | `500` | `200..1000` | 每日场景进入时的柔和淡入时长。过短会生硬，过长会拖慢每日节奏。 |
| `DIALOGUE_START_DELAY_MS` | `200` | `0..600` | 视觉就绪后到启动对话 UI 的短暂停顿，让玩家先看到角色穿搭进入场景。 |
| `GOODNIGHT_TRANSITION_LOCK_MS` | `1000` | `500..2500` | 请求进入 GOODNIGHT 后的防重复锁定时长；若状态转换失败或超时，可恢复结束控件。 |
| `CHARACTER_DAILY_SCALE` | `1.0` | `0.5..1.5` | Daily Scene 中 Character 子场景缩放。具体值可按场景配置覆写。 |
| `CHARACTER_ANCHOR_KEY` | `center_soft` | config key | 每日场景默认角色锚点 key；具体坐标由场景配置或 UX spec 定义。 |
| `BACKGROUND_FIT_MODE` | `cover` | `cover` / `contain` / `stretch-safe` | 背景适配视口方式。MVP 推荐 `cover`，但必须保护角色和对话安全区。 |
| `FALLBACK_BACKGROUND_KEY` | `daily.fallback_room` | valid background key | 当天背景缺失时使用的安全背景。不得显示破损资源或技术占位。 |
| `DEFAULT_DAILY_MUSIC_EVENT` | `scene.music.daily_generic` | valid audio event key | 当天音乐事件缺失时的通用每日场景音乐。 |
| `SCENE_ENTER_AUDIO_EVENT` | `scene.daily.entered` | valid audio event key | 每日场景进入时可触发的轻量音频事件。音频缺失不阻塞流程。 |
| `MAX_DIALOGUE_CONTEXT_TAGS` | `4` | `0..8` | 每日场景传给对话内容系统的轻量 tags 数量上限，防止上下文膨胀。 |

### Non-System Tuning

| Behavior | Controlled By | Notes |
|----------|---------------|-------|
| 每天具体台词内容 | 轻叙事对话 | 每日场景只传 day/context/tags，不写正式剧情文本。 |
| 服装是否解锁 | 进度管理 / 服装数据库 / 服装解锁 | 每日场景只消费已确认穿搭，不计算或展示解锁结果。 |
| 服装纹理加载速度 | 资源加载器 / 精灵分层渲染 | 每日场景只等待结果和处理 fallback。 |
| 对话文字速度、面板高度、输入去抖 | 对话 UI | 每日场景不重复定义对话 UI 的控件参数。 |
| 晚安页展示内容和继续按钮 | 主菜单/晚安 UI | 每日场景只请求进入 GOODNIGHT。 |
| 新解锁提示出现时机 | 服装解锁 | 每日场景不在对话结束时展示新衣服。 |

### Fixed Design Choices

| Item | Fixed Value | Reason |
|------|-------------|--------|
| MVP 天数 | `7` | 来自 game concept 和进度管理。 |
| 每日场景流程 | 线性：进入 -> 应用穿搭 -> 启动对话 -> 请求晚安 | 保持每日陪伴节奏简单清晰。 |
| 穿搭评价 | 不存在 | 与「随心搭配」冲突。 |
| 进度推进时机 | `GOODNIGHT -> MAIN_MENU` | 由 GameState / ProgressManager 负责，避免每日场景提前推进 day。 |
| 剧情分支 | MVP 不做 | 故事是氛围，不是复杂分支系统。 |

## Visual/Audio Requirements

每日场景是玩家看到“穿搭进入今天”的主要呈现层，因此视觉与音频必须温暖、清晰、低压力。它不做关卡胜利、不做评分结算、不做强刺激转场；所有表现都服务“今天这一页被轻轻翻开”的感觉。

### Visual Requirements

| Area | Requirement | Notes |
|------|-------------|-------|
| 背景 | 每天至少有一个可识别的日常背景或背景变体 | MVP 可复用少量背景，但 day 配置必须能表达不同日子的轻微差异 |
| 角色呈现 | 角色穿搭必须在对话开始前可见 | 角色是玩家选择被确认的核心证据，不能让文字先于穿搭出现 |
| 构图 | 角色主体不得被对话面板遮挡超过 30% | 与对话 UI 的面板覆盖规则保持一致 |
| 角色锚点 | 每个场景配置应定义 `character_anchor` 或等价锚点 key | 具体坐标可由后续 UX spec / scene config 定义 |
| 入场 | 场景进入使用柔和淡入或翻页式过渡 | 时长由 `SCENE_FADE_IN_MS` 控制，不做硬切或强闪白 |
| 视觉就绪 | 角色穿搭应用完成后可有极轻微呼吸、站定或柔光反馈 | 表达“她已经在今天的场景里”，不是奖励反馈 |
| 背景适配 | 桌面、移动端和窄屏都必须保持角色主体、背景意图和对话面板可读 | 背景可裁切，但不能裁掉场景识别核心 |
| Fallback | 背景或角色异常时显示温和安全画面 | 不显示破损资源、调试占位、红色错误 UI 或技术提示 |
| 文本安全区 | 画面下半部必须预留对话 UI 安全区域 | 每日场景不得把角色关键细节放在对话面板必然覆盖的位置 |

### Daily Scene Mood Direction

MVP 的 7 天不要求 7 张完全独立大背景，但每一天都应通过背景、光线、角色位置、音乐或对话标签形成“今天不同”的感受。

| Day Range | Mood Direction | Visual Notes |
|-----------|----------------|--------------|
| Day 1 | 安静开始、房间、清晨 | 让玩家感到被欢迎，适合基础穿搭首次进入故事 |
| Day 2-3 | 轻松日常、散步或室内小事 | 场景变化轻，不增加认知负担 |
| Day 4-5 | 外出感增强、咖啡馆/街角/小约定 | 与配饰、发型逐步出现的节奏呼应 |
| Day 6 | 临近一周结束、稍微特别的一天 | 可增加更明确的场景记忆点，但不做挑战 |
| Day 7 | 温柔收束、完成一周 | 不做胜利结算；只表达“这一周被好好走完了” |

### Audio Requirements

| Event | Audio Direction | Notes |
|------|-----------------|-------|
| 场景进入 | 轻柔翻页、房间空气感、短促温暖进入音 | 可通过 `scene.daily.entered` 触发 |
| 每日音乐 | 低密度、可循环、不会抢对白 | 默认事件 `scene.music.daily_generic`；可按 day 覆写 |
| 背景氛围 | 可选，极低音量 | 如房间空气、窗外轻风、咖啡馆低噪；MVP 可不启用 |
| 角色穿搭就绪 | 极轻微柔光/布料落定感 | 不应像换装成功奖励音；换装成功音仍归拖拽换装 |
| 对话开始 | 可以不单独播放，或用极轻翻页音 | 避免重复打扰对话 UI 的文字推进音 |
| 进入晚安 | 可请求 `scene.transition_page` 或让晚安 UI 接管 | 每日场景只负责离场意图，不播放结算音乐 |

### Style Constraints

- 不使用胜利、评级、任务完成、抽卡、奖励或强成就感音效。
- 不使用红色错误态、强震动、爆闪、高饱和警告或失败文案。
- 角色穿搭清晰度优先于背景装饰；背景不能抢走服装细节。
- 场景氛围应像日记页、生活片段或轻柔插画，不像关卡舞台或任务地图。
- 所有视觉/音频 fallback 都必须保持温柔语气，不暴露技术异常给玩家。
- 若未来服装影响场景 flavor，只能以非评分、非优劣的方式影响台词或轻量氛围标签。

### Asset Spec Flag

后续需要 `/asset-spec system:daily-scene` 生成：每日背景或背景变体、fallback 背景、角色锚点示意、场景进入/离场轻量视觉反馈、每日音乐事件、可选 ambience 事件，以及与对话 UI 安全区配套的构图规范。

## UI Requirements

每日场景本身不是一个独立 UI 面板系统；它主要承载角色、背景和对话 UI。所有正式对话文本、逐字显示、继续按钮和结束确认优先由对话 UI 负责。每日场景只定义布局安全区、对话启动时机、fallback 结束控件和状态转换防重复要求。

### Layout Requirements

- 首屏必须直接显示每日场景内容：背景、角色和对话区域，不出现教学页、说明卡或结算页。
- 对话 UI 默认位于画面下半部；每日场景必须预留安全区域，避免角色主体和关键服装细节被遮挡超过 30%。
- 角色锚点和缩放必须随视口变化重新计算或使用响应式配置。
- 桌面端应保持角色与背景场景都可读；移动端优先保证角色主体、对话文本和主要背景意图。
- 背景适配可以裁切边缘，但不能裁掉当天场景的识别核心或角色主体。
- 每日场景不得把新解锁物品列表、评分、任务完成、穿搭评价或通关入口放入本屏。

### Dialogue UI Hosting

- 每日场景必须在 `visual_ready == true` 后才启动或启用对话 UI。
- 对话 UI 应接收包含 `day`、`scene_id`、`equipped_items` 和 `dialogue_context_tags` 的上下文。
- 每日场景监听 `dialogue_sequence_finished(day)`，并负责请求 GOODNIGHT 转换。
- 对话 UI 的文字速度、面板高度、输入去抖和继续提示样式由 `dialogue-ui.md` 控制，每日场景不重复定义。
- 若对话 UI 已在场景树中，离开场景时每日场景必须断开完成信号或使 pending 回调失效。

### Fallback End Control

- 若对话 UI 无法实例化或对话完成事件不可用，每日场景可以显示一个最小 fallback 结束控件。
- fallback 控件文案应温和，例如本地化 key `daily_scene.fallback_continue`，语义为“继续”或“晚安”。
- fallback 控件只负责请求 `DAILY_SCENE -> GOODNIGHT`，不显示错误原因。
- fallback 控件必须满足 44x44px 最小触控热区，并支持鼠标、触摸、键盘和手柄确认。
- fallback 控件出现时不得与正式对话 UI 同时可交互；避免两个结束入口竞争。

### Input and Focus

- 每日场景不直接处理对话文本推进输入；该输入归对话 UI。
- 每日场景只处理 fallback 结束控件和必要的状态转换锁定。
- Godot 4.6 中鼠标/触摸 hover 与键盘/手柄 focus 分离；fallback 控件若出现，必须分别显示 hover、pressed 和 keyboard_focus。
- 请求 GOODNIGHT 后，结束控件进入 disabled 或 locked 状态，直到 GameState 完成转换或明确失败。
- 隐藏或 disabled 控件不得保留在键盘/手柄 focus path 中。

### Accessibility and Localization

- 所有每日场景可见文字必须使用 `tr()` 和本地化 key。
- 不使用只靠颜色区分的状态；若 fallback 控件 disabled，需有形状、透明度、焦点状态或文字以外的辅助信号。
- 不显示技术错误、资源路径、debug 文案或“失败/错误穿搭”语气。
- 长本地化文本必须自动换行或改用更宽容布局，不溢出、不遮挡角色主体。
- 所有可交互控件热区不小于 44x44px。

### UX Flag

后续需要 `/ux-design daily-scene` 细化：桌面和移动端每日场景构图、角色锚点、对话 UI 安全区、fallback 结束控件、焦点顺序、视口变化处理，以及每日场景到 GOODNIGHT 的交互节奏。

## Acceptance Criteria

### 初始化与上下文

1. **GIVEN** `GameState.current_state == DAILY_SCENE`，**WHEN** 每日场景 `_ready()` 执行，**THEN** 它读取 `GameState.current_state`、`GameState.context` 和 `GameState.get_current_day()`。
2. **GIVEN** `GameState.current_state != DAILY_SCENE`，**WHEN** 每日场景初始化，**THEN** 场景内容保持 disabled，不启动对话 UI，也不请求 GOODNIGHT。
3. **GIVEN** `GameState.context["current_day"]` 存在且合法，**WHEN** 每日场景选择配置，**THEN** 使用该 day 对应的 `scene_config`。
4. **GIVEN** `GameState.context["current_day"]` 缺失，**WHEN** 每日场景选择配置，**THEN** 回退使用 `GameState.get_current_day()`。
5. **GIVEN** resolved day 小于 1 或大于 7，**WHEN** 每日场景选择配置，**THEN** 本地 clamp 到 `1..7`，记录 warning，且不修改 ProgressManager 或 SaveManager。
6. **GIVEN** 当前 day 的 `scene_config` 缺失，**WHEN** 每日场景构建，**THEN** 使用 day 1 fallback 配置并继续流程。

### 场景与角色呈现

7. **GIVEN** 有效 `scene_config`，**WHEN** 每日场景构建，**THEN** 背景、角色锚点和对话 UI 容器被创建或启用。
8. **GIVEN** 背景资源缺失，**WHEN** 每日场景构建，**THEN** 显示 `FALLBACK_BACKGROUND_KEY` 对应安全背景，并继续到视觉就绪判定。
9. **GIVEN** `equipped_items` 存在且为数组，**WHEN** Character 渲染器 ready，**THEN** 每日场景调用 `apply_outfit(equipped_items)`，包括 `equipped_items == []`。
10. **GIVEN** `equipped_items` 缺失或为 `null`，**WHEN** Character 渲染器 ready，**THEN** 每日场景调用 `equip_default_outfit(scene_day)` 或使用安全默认穿搭。
10a. **GIVEN** `equipped_items == []`，**WHEN** Character 渲染器 ready，**THEN** 每日场景调用 `apply_outfit([])` 并等待 `outfit_applied([])`；不得改为默认穿搭。
11. **GIVEN** `apply_outfit(equipped_items)` 发出 `outfit_applied(item_ids)`，**WHEN** 背景和角色也已就绪，**THEN** `visual_ready == true`。
12. **GIVEN** `apply_outfit(equipped_items)` 在 `OUTFIT_APPLY_TIMEOUT_MS` 内未发出 `outfit_applied`，**WHEN** 超时到达，**THEN** 每日场景使用当前角色状态或默认穿搭兜底，并允许对话启动。
13. **GIVEN** Character 无法实例化，**WHEN** 每日场景构建，**THEN** 使用无角色 fallback 呈现，记录 error，并允许玩家完成当天流程。
14. **GIVEN** `outfit_applied` 在每日场景进入 `EXITING` 后到达，**WHEN** 信号触发，**THEN** 每日场景忽略该迟到信号，不启动对话、不修改 UI。

### 对话启动与完成

15. **GIVEN** `visual_ready == false`，**WHEN** 每日场景初始化完成，**THEN** 对话 UI 不启动。
16. **GIVEN** `visual_ready == true` 且 `dialogue_started == false`，**WHEN** 当前状态仍为 `DAILY_SCENE`，**THEN** 每日场景启动或启用对话 UI。
17. **GIVEN** 对话 UI 启动，**WHEN** 每日场景传入上下文，**THEN** 上下文包含 `day`、`scene_id`、`equipped_items` 和 `dialogue_context_tags`。
18. **GIVEN** 对话已启动一次，**WHEN** 视觉就绪信号或状态信号重复到达，**THEN** 每日场景不重复请求对话序列。
19. **GIVEN** 对话 UI 发出 `dialogue_sequence_finished(day)`，**WHEN** 每日场景尚未请求 GOODNIGHT，**THEN** 每日场景请求一次 `DAILY_SCENE -> GOODNIGHT`。
20. **GIVEN** `dialogue_sequence_finished(day)` 被重复发出，**WHEN** `goodnight_transition_requested == true`，**THEN** 每日场景忽略后续完成事件。
21. **GIVEN** 完成事件的 day 与 active `scene_day` 不一致，**WHEN** 每日场景收到该事件，**THEN** 记录 warning；若场景仍有效且尚未请求 GOODNIGHT，可完成当前每日场景。
22. **GIVEN** 对话 UI 无法实例化，**WHEN** 每日场景进入 fallback 路径，**THEN** 显示最小 fallback 结束控件，玩家可通过该控件请求 GOODNIGHT。
23. **GIVEN** fallback 结束控件可见，**WHEN** 玩家用鼠标、触摸、键盘或手柄确认，**THEN** 每日场景请求 `DAILY_SCENE -> GOODNIGHT` 一次。
24. **GIVEN** 请求 GOODNIGHT 后，**WHEN** 玩家重复点击结束控件，**THEN** 不重复请求状态转换。

### 进度与状态边界

25. **GIVEN** 每日场景完成对话，**WHEN** 检查进度调用，**THEN** 每日场景没有调用 `ProgressManager.advance_day()`。
26. **GIVEN** 每日场景完成对话，**WHEN** 检查保存写入，**THEN** 每日场景没有直接修改 SaveManager、ProgressManager 或 WardrobeDatabase。
27. **GIVEN** 当前为 day 7，**WHEN** 对话完成，**THEN** 每日场景仍正常请求 GOODNIGHT，不显示 day 8、不显示通关/重玩 UI、不推进进度。
28. **GIVEN** `GameState.request_transition(State.GOODNIGHT)` 被拒绝，**WHEN** 转换锁定超时，**THEN** 每日场景恢复结束控件或显示温和 retry affordance。
29. **GIVEN** 每日场景正在卸载，**WHEN** 仍有 pending timer、对话完成信号或 outfit 回调，**THEN** 它们不会再触发 GOODNIGHT 请求。

### 视觉、音频与 UI

30. **GIVEN** 常见桌面和移动视口，**WHEN** 每日场景显示角色和对话 UI，**THEN** 角色主体被对话面板遮挡不超过 30%。
31. **GIVEN** 视口尺寸变化，**WHEN** 每日场景重新布局，**THEN** 角色锚点、背景适配和对话安全区被重新计算或使用响应式配置更新。
32. **GIVEN** 音频管理不可用或事件未注册，**WHEN** 每日场景请求进入音、音乐或转场音，**THEN** 流程继续，不阻塞角色显示、对话或 GOODNIGHT 转换。
33. **GIVEN** 每日场景显示 fallback 控件，**WHEN** 检查触控热区，**THEN** 控件热区不小于 44x44px。
34. **GIVEN** Godot 4.6 双焦点系统，**WHEN** 鼠标 hover 和键盘/手柄 focus 位于不同控件，**THEN** fallback 控件的 hover、pressed 和 keyboard_focus 状态可区分且不互相覆盖。
35. **GIVEN** fallback 控件隐藏或 disabled，**WHEN** 使用键盘/手柄导航，**THEN** 焦点不会落到该控件上。
36. **GIVEN** 任意每日场景可见文字，**WHEN** 检查实现，**THEN** 使用 `tr()` 和本地化 key，不硬编码玩家可见文本。
37. **GIVEN** 背景、角色或对话 fallback 同时触发，**WHEN** 玩家查看画面，**THEN** 不显示技术错误、资源路径、破损占位、失败语言、评分或惩罚式反馈。
38. **GIVEN** 每日场景运行主流程，**WHEN** 玩家从 WARDROBE 确认穿搭进入 DAILY_SCENE 并完成对话，**THEN** 玩家可以到达 GOODNIGHT，且全程不出现评分、排名、任务结算或“正确穿搭”暗示。

### 场景配置与就绪握手

39. **GIVEN** `daily_scene_configs` 被加载，**WHEN** 检查 MVP 数据，**THEN** 存在 `1..7` 七个 day key，且 day 1 safe fallback 配置存在并通过必填字段校验。
40. **GIVEN** 任一 `scene_config` 被校验，**WHEN** 检查字段，**THEN** 它包含 `scene_id`、`day`、`background_key`、`character_anchor`、`dialogue_context_tags`，且 `day` 与字典 key 一致。
41. **GIVEN** 每日场景完成最小安全初始化，**WHEN** 场景根节点可安全显示，**THEN** 每日场景调用一次 `GameState._on_scene_ready()` 或等价场景就绪回调。
42. **GIVEN** 每日场景已发送场景就绪回调，**WHEN** 迟到的 outfit、dialogue、timer 或卸载回调触发，**THEN** 不会再次发送场景就绪回调。
43. **GIVEN** `scene.daily.entered`、`scene.music.daily_generic` 或 `scene.music.day_{n}` 未在音频管理中登记，**WHEN** 每日场景请求该音频事件，**THEN** 记录 warning 并继续流程；实现交付前这些 key 必须被音频管理或资产规格映射。

## Open Questions

| Question | Owner | Target Resolution | Notes |
|----------|-------|-------------------|-------|
| MVP 7 天的具体每日场景表是什么？ | 轻叙事对话 / 场景设计 | `/design-system 轻叙事对话` 或 `/ux-design daily-scene` 前 | 本 GDD 只定义 day 配置结构和氛围范围，尚未锁定每一天的 `scene_id`、背景和 tags。 |
| 7 天是否需要 7 张独立背景，还是 2-3 张背景加光线/道具变体？ | 美术 / 制作 | `/asset-spec system:daily-scene` 前 | MVP 建议优先复用少量背景变体，避免美术范围膨胀。 |
| `character_anchor` 的具体坐标和桌面/移动端缩放如何定义？ | UX 设计 / 场景实现 | `/ux-design daily-scene` | 精灵分层渲染已规定 Character 不硬编码 DAILY_SCENE 缩放；每日场景需要自己的响应式锚点方案。 |
| `dialogue_sequence_finished(day)` 长期是否仍由每日场景接收？ | 对话 UI / 轻叙事对话 / GameState | 轻叙事对话 GDD 完成时 | 当前契约为每日场景接收并请求 GOODNIGHT；若后续改由 GameState 或内容系统承接，需回传修订本 GDD。 |
| 每日场景传给轻叙事对话的 `dialogue_context_tags` 应包含哪些 tags？ | 轻叙事对话 / 场景设计 | `/design-system 轻叙事对话` | 当前只规定最多 4 个 tags，不定义具体标签集。 |
| MVP 是否启用 `Ambience` 音频层？ | 音频设计 / 制作 | `/asset-spec system:audio-management` 或 `/asset-spec system:daily-scene` 前 | 音频管理已预留 Ambience；每日场景可选使用，但 MVP 可先不启用。 |
| 背景/角色/对话 fallback 同时触发时的具体画面是什么？ | UX 设计 / 技术美术 | `/ux-design daily-scene` 前 | 本 GDD 只要求温和、不暴露技术错误；具体视觉需要 UX 和资产规格定义。 |
| 是否需要每日场景入场时短暂展示角色站定动画？ | 美术 / 技术美术 / 原型验证 | `/prototype daily-scene` 或资产规格前 | MVP 可以只做淡入；若角色静止显得突兀，再考虑轻量呼吸或站定反馈。 |
| Day 7 的“温柔收束”是否由每日场景表现，还是完全交给晚安 UI / 轻叙事对话？ | 叙事 / 主菜单晚安 UI / 每日场景 | 轻叙事对话 GDD 完成时 | 当前设计要求每日场景不显示通关/重玩 UI，只正常进入 GOODNIGHT。 |
