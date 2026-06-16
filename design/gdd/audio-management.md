# 音频管理 (Audio Management)

> **Status**: Approved
> **Author**: user + Codex Game Studios
> **Last Updated**: 2026-06-09
> **Implements Pillar**: 每日陪伴, 即时有感

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `None`

## Overview

音频管理是「每日穿搭」的全局声音协调系统，负责把各个系统发出的玩家操作、场景切换和情绪节点转化为柔和、低压力、可控的音乐与音效反馈。它统一管理背景音乐、UI 音效、换装反馈音、对话推进音、晚安收束音和未来解锁提示音，通过清晰的音频事件接口、音量分组、淡入淡出、SFX 播放池与 Web 音频解锁策略，避免每个 UI 或玩法系统各自创建播放器、重复叠音或播放不符合氛围的声音。对玩家来说，它不是一个可见系统，而是一层始终在场的温度：点击像轻轻翻页，拖拽像触碰布料，晚安像把一天安静合上；它服务「每日陪伴」与「即时有感」，让每次操作都有回响，但不催促、不评判、不打断玩家的穿搭日记节奏。

## Player Fantasy

音频管理的玩家幻想是：“我每一次触碰这个小世界，它都会用很轻的声音回应我，像有人在旁边温柔地陪我翻日记。”

玩家不需要意识到“音效系统”存在，也不应该被音乐或反馈音提醒自己正在操作一套界面。理想状态下，声音像晨光、纸页和布料一样自然地嵌在体验里：打开主菜单时有被迎接的安静感，切换类目时像轻轻拉开抽屉，拖起衣服时像指尖碰到柔软布料，放下成功时有小小满足但不是胜利欢呼，读完一天进入晚安时像把今天轻轻合上。音频管理服务的是「每日陪伴」和「即时有感」的交界：它让玩家的选择被听见，让操作有回响，但始终保持克制，不催促、不打断、不评价，也不把换装变成任务结算。最好的声音不是“很好听所以抢注意力”，而是玩家离开时会觉得：这个游戏很温柔。

## Detailed Design

### Core Rules

**系统定位**：音频管理是全局 Core 层服务，负责接收游戏中各系统发出的音频事件，并把这些事件解析为具体的音乐、UI 音效、换装反馈音、对话反馈音、场景氛围音或未来解锁提示音。其他系统不直接创建 `AudioStreamPlayer`，不直接设置音频 bus，不直接决定同类音效是否可叠放；它们只发出事件意图，例如 `ui.menu.start_pressed`、`wardrobe.item_drag_started`、`dialogue.line_advanced`、`ui.goodnight.continue_pressed`。

**事件驱动规则**：
- 音频管理对外提供统一入口：`play_event(event_key, context = {})`。
- `event_key` 是稳定字符串 key，按域命名：`ui.*`、`wardrobe.*`、`dialogue.*`、`scene.*`、`progress.*`、`system.*`。
- `context` 可携带轻量参数，例如 `day`、`category`、`item_category`、`intensity`、`is_locked`，但音频管理不得读取或修改进度、服装、对话或状态数据。
- 音频管理通过事件映射表决定资源、bus、默认音量、随机变体、冷却时间、是否允许叠放、是否需要淡入淡出。
- 未注册事件不播放声音，只记录 warning；不得崩溃，也不得播放默认失败音。

**Audio Bus 规则**：
- MVP 至少包含 4 个 bus：`Master`、`Music`、`SFX`、`UI`。
- 可预留 `Ambience` 与 `Voice` bus；若 MVP 不使用真实语音，`Voice` 只保留为未来扩展。
- 音量控制以 bus 为单位执行，避免逐节点散落调节。
- UI 点击、锁定提示、按钮确认走 `UI` bus；布料、换装、放下成功、纸页翻动等反馈走 `SFX` bus；背景音乐走 `Music` bus；环境底噪未来走 `Ambience` bus。
- 所有音量默认保持低侵入；任何单次 UI/SFX 不得压过音乐或对话阅读体验。

**播放器与并发规则**：
- 音频管理维护 SFX/UI 播放池，不在运行时为每个音效临时创建播放器。
- 同一事件可设置 `max_instances`，防止快速点击或拖拽产生刺耳叠音。
- 高频事件必须有冷却时间，例如 hover、拖拽更新、连续点击。
- 音乐播放器单独管理，支持淡入、淡出、交叉淡入淡出。
- 一次性短音效播放完成后播放器回到池中可复用。

**音乐与氛围规则**：
- 主菜单音乐方向为清晨、轻柔、低密度，进入衣橱后可保持同一音乐或切换到更明亮但不兴奋的版本。
- 每日场景可按未来每日场景系统请求 `scene.music.day_{n}` 或等价事件；若未定义当天音乐，回退到通用轻柔背景。
- 晚安页面使用更低密度、更暖、更安静的音乐或氛围层，不播放结算式、胜利式或任务完成式音乐。
- 音乐切换必须淡入淡出，不能硬切；除非遇到错误或退出终端状态。
- Web 平台首次播放若受浏览器自动播放限制，音频管理等待第一次玩家输入后解锁音频，再播放允许的音乐或 UI 声音。

**风格约束**：
- 允许的声音质感：纸页、布料、轻木扣、柔铃、台灯开关、轻呼吸感环境声、温暖房间氛围。
- 禁止的声音质感：刺耳错误音、竞技胜利音、任务完成 fanfare、强警报、强低频冲击、老虎机式奖励音。
- 锁定/禁用反馈只能是轻微不可用提示，不能让玩家感到失败。
- 放下成功可以有满足感，但必须是“小小被接住”的感觉，不是评分通过。

### States and Transitions

```text
UNINITIALIZED
  → WAITING_FOR_USER_GESTURE
  → READY
  → MUTED
  → SUSPENDED
```

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|----------|----------|
| `UNINITIALIZED` | 音频管理尚未建立 bus、播放器池和事件映射 | 游戏启动 | 初始化完成 |
| `WAITING_FOR_USER_GESTURE` | Web 自动播放限制下，等待首次玩家输入解锁音频 | 初始化完成但浏览器未允许播放 | 玩家点击、触摸或按键 |
| `READY` | 可正常播放事件、音乐和 UI/SFX | 初始化完成且音频已解锁 | 玩家静音、页面失焦、系统暂停 |
| `MUTED` | bus 保持存在，但主输出静音 | 玩家选择静音或系统设置静音 | 玩家取消静音 |
| `SUSPENDED` | 页面失焦、标签页后台或游戏暂停时降低/暂停部分声音 | 平台焦点丢失或系统暂停 | 焦点恢复或游戏恢复 |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|----------|
| 主菜单/晚安 UI | 下游调用 | 发出 `ui.menu_entered`、`ui.menu.start_pressed`、`ui.menu.exit_pressed`、`ui.goodnight_entered`、`ui.goodnight.continue_pressed` 等事件 |
| 衣橱 UI | 下游调用 | 发出类目点击、服装卡片点击、锁定提示、拖起服装等 UI/布料事件；成功放下音由拖拽换装或渲染确认后触发 |
| 对话 UI | 下游调用 | 发出文本推进、补全文本、结束确认、兜底提示等轻量 UI 事件 |
| 拖拽换装 | 未来下游 | 在装备成功、无效落点、同物品 no-op 等结果确认后发出换装反馈事件 |
| 每日场景 | 未来下游 | 请求场景音乐、环境氛围、每日场景进入/退出音频事件 |
| 服装解锁 | 未来下游 | 请求新解锁提示音，但音频管理限制其能量层级，避免变成强奖励音 |
| 场景/状态管理 | 弱相关 | 可在状态切换时发出场景级音乐/淡出事件；音频管理不决定状态转换 |
| 保存/加载 | 可选相关 | 若未来有设置保存，保存音量、静音状态等用户偏好；音频管理不直接写游戏进度 |

**临时事件目录（MVP）**：

| Event Key | 触发方 | 目标声音 |
|-----------|--------|----------|
| `ui.menu_entered` | 主菜单/晚安 UI | 极轻晨间/纸页进入音 |
| `ui.menu.start_pressed` | 主菜单/晚安 UI | 柔和确认、翻页感 |
| `ui.menu.exit_pressed` | 主菜单/晚安 UI | 轻柔告别/收束音 |
| `ui.goodnight_entered` | 主菜单/晚安 UI | 纸页合上、台灯暖光感 |
| `ui.goodnight.continue_pressed` | 主菜单/晚安 UI | 短促温暖继续音 |
| `wardrobe.category_pressed` | 衣橱 UI | 小木扣/抽屉切换音 |
| `wardrobe.item_pressed` | 衣橱 UI | 轻布料触碰音 |
| `wardrobe.item_locked_pressed` | 衣橱 UI | 轻微不可用提示 |
| `wardrobe.item_drag_started` | 衣橱 UI | 极轻布料摩擦起音 |
| `wardrobe.outfit_applied` | 拖拽换装 | 柔和放下成功音 |
| `dialogue.line_advanced` | 对话 UI | 轻翻页/文本推进音 |
| `dialogue.line_completed` | 对话 UI | 极轻提示音，可选 |
| `dialogue.finished_confirmed` | 对话 UI | 温和结束确认音 |
| `scene.daily.entered` | 每日场景 | 轻柔翻页/房间空气感进入音 |
| `scene.music.daily_generic` | 每日场景 | 通用每日场景低密度循环音乐 |
| `scene.music.day_{n}` | 每日场景 | 可选的第 n 天音乐覆写；缺失时回退到通用每日场景音乐 |
| `scene.transition_page` | 场景/状态管理或场景系统 | 0.8 秒翻页转场音 |
| `progress.items_unlocked` | 服装解锁 | 小惊喜但低能量的柔光音 |

## Formulas

音频管理不包含经济或成长公式，但需要定义音量、事件冷却、并发限制和淡入淡出规则，确保声音反馈柔和、稳定、不会因快速操作而堆叠刺耳。

### Bus 音量换算

```text
effective_volume_db = base_volume_db + bus_volume_db + user_volume_db
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `base_volume_db` | float | `-24..0 dB` | 单个音频事件在映射表中的基础音量 |
| `bus_volume_db` | float | `-40..0 dB` | 当前 bus 的设计默认音量或系统设置音量 |
| `user_volume_db` | float | `-40..0 dB` | 玩家设置中的额外音量偏移 |
| `effective_volume_db` | float | `-80..0 dB` | 实际播放音量，最终 clamp 到安全范围 |

**输出**：单次播放的最终音量。

**规则**：`effective_volume_db` 最终 clamp 到 `-80..0 dB`。UI/SFX 默认不得超过 `-6 dB`，防止短音效盖过音乐或对话。

### 事件冷却判定

```text
can_play_event = current_time_ms - last_played_time_ms[event_key] >= cooldown_ms[event_key]
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `current_time_ms` | int | `>=0` | 当前时间戳 |
| `last_played_time_ms[event_key]` | int | `>=0` | 该事件上次成功播放时间 |
| `cooldown_ms[event_key]` | int | `0..1000` | 事件最小播放间隔 |
| `can_play_event` | bool | true/false | 当前是否允许播放该事件 |

**输出**：是否播放该事件。

**规则**：若 `can_play_event == false`，本次事件静默丢弃，不排队。高频事件如 hover、locked pressed、drag started 默认应配置冷却。

### 并发实例限制

```text
active_instances(event_key) < max_instances(event_key)
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `active_instances(event_key)` | int | `0..SFX_POOL_SIZE` | 当前同一事件正在播放的实例数 |
| `max_instances(event_key)` | int | `1..4` | 该事件允许同时播放的最大数量 |
| `SFX_POOL_SIZE` | int | `4..16` | SFX/UI 播放池大小 |

**输出**：是否允许创建本次播放。

**规则**：若超过 `max_instances`，低优先级事件静默丢弃；高优先级事件可抢占同一事件中最早开始的实例，但不得抢占不同 bus 的音乐。

### 音乐淡入淡出

```text
fade_progress = clamp(elapsed_fade_time / fade_duration, 0.0, 1.0)
current_music_volume_db = lerp(from_volume_db, target_volume_db, ease_out(fade_progress))
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `elapsed_fade_time` | float | `>=0s` | 淡入/淡出已经过时间 |
| `fade_duration` | float | `0.3..2.0s` | 淡入淡出总时长 |
| `from_volume_db` | float | `-80..0 dB` | 起始音量 |
| `target_volume_db` | float | `-80..0 dB` | 目标音量 |
| `current_music_volume_db` | float | `-80..0 dB` | 当前帧音乐音量 |

**输出**：当前音乐播放器音量。

**规则**：常规场景音乐切换使用 `0.8..1.5s` 淡入淡出；短 UI 页面变化可使用 `0.3..0.8s`。不得硬切，除非进入错误、退出或音频资源缺失。

### Web 音频解锁队列

```text
if audio_unlocked == false:
    if event.allow_queue_before_unlock:
        queue_event(event_key, context)
    else:
        drop_event(event_key)
else:
    play_event(event_key, context)
```

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `audio_unlocked` | bool | true/false | Web 平台音频是否已被首次玩家输入解锁 |
| `allow_queue_before_unlock` | bool | true/false | 事件是否允许在解锁前排队 |
| `queued_events` | Array | `0..MAX_UNLOCK_QUEUE_SIZE` | 解锁前暂存事件 |
| `MAX_UNLOCK_QUEUE_SIZE` | int | `0..8` | 解锁队列最大长度 |

**输出**：播放、排队或丢弃。

**规则**：音乐进入、主菜单进入等可排队；快速点击、hover、拖拽类事件不排队。解锁后只播放队列中最后一个音乐事件和必要的首个 UI 反馈，避免“解锁后一串旧音效爆发”。

## Edge Cases

- **如果 Web 平台尚未获得首次用户手势**：音频管理进入 `WAITING_FOR_USER_GESTURE`。允许排队的音乐/进入事件只保留必要的最新项；点击、hover、拖拽等短音效直接丢弃，不在解锁后一口气播放。
- **如果收到未注册的 `event_key`**：不播放任何声音，记录 warning，继续游戏流程。不得回退到通用错误音或刺耳提示音。
- **如果事件映射存在但音频资源缺失或加载失败**：跳过该事件并记录 warning；若是音乐事件，保持当前音乐或静音，不硬切到空状态；若是 UI/SFX，静默失败。
- **如果 SFX/UI 播放池已满**：低优先级事件直接丢弃；高优先级事件可抢占同一事件中最早开始的实例。不得动态创建额外播放器。
- **如果同一事件被快速重复触发**：按 `cooldown_ms[event_key]` 丢弃冷却期内事件，避免按钮连点、锁定提示或拖拽反馈堆叠刺耳。
- **如果玩家静音**：音频管理进入 `MUTED`，所有 bus 保持状态但不输出声音；事件可以正常被接收和记录冷却，但不播放。取消静音后不补播静音期间错过的短音效。
- **如果页面失焦或浏览器标签进入后台**：进入 `SUSPENDED`，音乐和氛围音降低或暂停，短 UI/SFX 不排队；恢复焦点后音乐按淡入恢复，不补播后台期间的点击/hover 音。
- **如果音乐切换请求在淡入淡出中再次到来**：取消上一段未完成的淡入淡出，使用当前实际音量作为新 `from_volume_db`，平滑过渡到最新目标音乐。
- **如果请求播放与当前音乐相同的 music key**：不重启音乐；可根据 context 更新目标音量或保持当前播放状态。
- **如果 `base_volume_db + bus_volume_db + user_volume_db` 超出安全范围**：最终 clamp 到 `-80..0 dB`；UI/SFX 若超过 `-6 dB`，按 `-6 dB` 上限播放并记录调参 warning。
- **如果玩家在拖拽中持续移动**：音频管理不响应每帧拖拽更新；只播放拖起、有效悬停可选反馈、放下结果等离散事件。
- **如果禁用类目或锁定物品被点击**：播放轻微不可用反馈，受冷却限制；不得播放失败、拒绝、警报或负面音色。
- **如果退出或 Web 端告别状态触发**：播放短收束音后允许音乐淡出；若平台无法保证收束音完整播放，不阻塞退出流程。
- **如果设置保存系统尚未接入**：音频管理使用默认音量和未静音状态；不得因无法读取设置而阻塞主菜单或 UI 声音。
- **如果音频事件 context 缺失或字段非法**：忽略非法字段，使用事件映射表默认值；不得反向查询其他系统来补齐 context。

## Dependencies

| Dependency | Type | Contract |
|------------|------|----------|
| Godot Audio System | Strong engine dependency | 使用 Godot 4.6 `AudioStreamPlayer`、`AudioServer`、audio buses 和播放池实现音乐、UI/SFX 与未来 Ambience 播放。音频管理不得在运行时为每个短音效临时创建播放器。 |
| 主菜单/晚安 UI | Downstream caller | 发出主菜单进入、开始今天、退出、晚安进入、继续等 `ui.*` 音频事件。该 UI 不直接管理音频资源或播放器。 |
| 衣橱 UI | Downstream caller | 发出类目点击、物品点击、锁定提示、拖起服装等 `wardrobe.*` 音频事件。放下成功音需等待拖拽换装/装备结果确认后触发。 |
| 对话 UI | Downstream caller | 发出文本推进、结束确认、兜底提示等 `dialogue.*` 音频事件。对话 UI 不直接控制音乐或 bus。 |
| 拖拽换装 | Future downstream caller | 在装备成功、无效落点、同物品 no-op 等结果确认后发出换装结果音频事件。音频管理不做装备判定。 |
| 每日场景 | Future downstream caller | 请求每日场景音乐、场景进入/退出音和未来环境氛围事件。若未定义当天音乐，音频管理回退到通用背景。 |
| 服装解锁 | Future downstream caller | 请求新解锁提示音。音频管理限制该事件能量层级，避免强奖励音或结算音。 |
| 保存/加载 | Optional future | 未来保存玩家音量、静音和 bus 设置。未接入时音频管理使用默认音量和未静音状态。 |
| 资源加载器 | Optional future | 未来可接入音频资源预加载或异步加载策略。MVP 中音频管理可使用自身事件映射表直接引用音频资源。 |

**Dependency Constraints**
- 音频管理没有强业务上游依赖；它可以在游戏启动时以默认配置初始化。
- 其他系统只发送事件意图，不传入裸资源路径、不创建播放器、不直接设置 bus 音量。
- 音频管理只消费 `event_key` 与轻量 `context`，不得查询或修改进度、服装、对话、场景状态。
- 下游系统需要新增音频事件时，必须把事件 key 加入音频事件映射表或音频资产规格，避免“随手播放资源”。
- 保存/加载和资源加载器接入前，音频系统必须仍能以默认音量和已打包资源运行。
- 若未来加入 `Voice` 或复杂环境音层，应回传修订本 GDD，避免 MVP 音频管理膨胀成完整音频中间件。

## Tuning Knobs

| Knob | Default | Range | Notes |
|------|---------|-------|-------|
| `MASTER_VOLUME_DB` | `0 dB` | `-40..0 dB` | 主输出默认音量。玩家设置未来可覆盖；静音不改该值，只 mute bus。 |
| `MUSIC_VOLUME_DB` | `-10 dB` | `-30..0 dB` | 背景音乐默认音量，必须低于 UI/SFX 峰值存在感，不抢对话阅读。 |
| `UI_VOLUME_DB` | `-8 dB` | `-24..-4 dB` | UI 点击、确认、锁定提示默认音量。上限保持克制。 |
| `SFX_VOLUME_DB` | `-8 dB` | `-24..-4 dB` | 布料、纸页、换装反馈默认音量。 |
| `AMBIENCE_VOLUME_DB` | `-18 dB` | `-36..-8 dB` | 未来环境氛围音默认音量；MVP 可预留但不使用。 |
| `SFX_POOL_SIZE` | `8` | `4..16` | UI/SFX 播放池大小。过小会丢音，过大浪费节点与混音资源。 |
| `DEFAULT_EVENT_COOLDOWN_MS` | `120` | `0..500` | 未单独配置事件的默认冷却。 |
| `LOCKED_FEEDBACK_COOLDOWN_MS` | `300` | `150..700` | 锁定物品/禁用类目提示音冷却，防止玩家连点时变刺耳。 |
| `DRAG_AUDIO_COOLDOWN_MS` | `250` | `100..600` | 拖拽相关反馈冷却。拖拽更新不逐帧播放声音。 |
| `DEFAULT_MAX_INSTANCES` | `2` | `1..4` | 单一事件默认最大并发实例数。 |
| `MUSIC_FADE_SECONDS` | `1.0` | `0.3..2.0` | 常规音乐切换淡入淡出时长。 |
| `UI_FADE_SECONDS` | `0.3` | `0.1..0.8` | 短 UI 页面或告别收束音淡出时长。 |
| `SUSPENDED_MUSIC_VOLUME_DB` | `-30 dB` | `-80..-18 dB` | 页面失焦或后台时音乐降低到的音量；若设为 `-80 dB` 等价暂停/静音。 |
| `MAX_UNLOCK_QUEUE_SIZE` | `4` | `0..8` | Web 音频解锁前可排队事件数量。解锁后只播放必要事件，避免旧声音爆发。 |
| `MAX_UI_SFX_VOLUME_DB` | `-6 dB` | `-12..-3 dB` | UI/SFX 最终播放音量上限。 |

**非本系统控制的调参**
- 具体每个音频资源的制作音量、长度、材质与尾音由后续 `/asset-spec system:audio-management` 或音频资产清单定义。
- 每日场景使用哪首音乐由未来 `每日场景` GDD 或场景内容表决定。
- 服装解锁提示何时触发由 `服装解锁` 系统决定；音频管理只控制声音播放和能量层级。
- 玩家设置 UI 如何呈现由后续 UX/UI 或设置系统决定。

## Visual/Audio Requirements

音频管理本身不渲染画面，但它定义全项目声音风格、音频事件资产方向和播放约束。声音必须像 Art Bible 中的“晨光”和“纸页”一样柔和存在：能回应玩家操作，但不抢走角色、穿搭和文本的注意力。

### Audio Style Requirements

| 类别 | 声音方向 | 要求 |
|------|----------|------|
| 背景音乐 `Music` | 清晨、卧室、轻日记、低密度旋律 | 旋律简单、循环不疲劳，不使用强节拍或明显高潮；适合 10-20 分钟休闲会话。 |
| 主菜单音效 `UI/SFX` | 纸页、晨间铃、轻柔确认 | 进入和按钮确认像翻开日记，不像系统菜单。 |
| 衣橱 UI 音效 `UI/SFX` | 轻木扣、抽屉、布料触碰 | 类目切换像打开抽屉；物品点击像触碰衣料；锁定反馈短而圆润。 |
| 拖拽/换装音效 `SFX` | 布料摩擦、轻放、柔光涟漪 | 拖起只播放短起音，不循环；成功放下有满足感但不“胜利化”。 |
| 对话 UI 音效 `UI` | 轻翻页、微提示、低干扰确认 | 文本推进音极短极轻，不模拟尖锐打字机声。 |
| 晚安音效 `SFX/Music` | 纸页合上、台灯、柔暗收束 | 晚安进入和继续都应降低能量，不播放结算或奖励音。 |
| 解锁提示 `SFX` | 小小惊喜、柔光浮现 | 可以比普通 UI 稍亮，但能量层级保持 `measured`，不得像抽卡或大奖。 |
| 未来环境音 `Ambience` | 房间空气感、窗外轻风、咖啡馆低噪 | 仅作为低音量背景层，不能影响文本阅读。 |

### Asset Requirements

MVP 至少需要以下音频资产或可替代变体：

| Asset Key | 用途 | 变体建议 |
|-----------|------|----------|
| `music.menu_morning_loop` | 主菜单/首页循环音乐 | 1 首 |
| `music.wardrobe_light_loop` | 衣橱界面循环音乐，可与菜单共用 | 1 首，可选 |
| `music.daily_generic_loop` | 每日场景通用循环音乐 | 1 首 |
| `music.daily_day_variant` | 每日场景按天覆写音乐 | 0-7 首，可选；未提供时使用通用每日场景音乐 |
| `music.goodnight_soft_loop` | 晚安页面低密度音乐或氛围 | 1 首 |
| `ui.page_in` | 主菜单进入/页面进入 | 2-3 个轻变体 |
| `ui.confirm_soft` | 通用确认/开始今天/继续 | 2-3 个轻变体 |
| `ui.exit_soft` | 退出/告别 | 1-2 个变体 |
| `ui.locked_soft` | 禁用类目/锁定物品 | 2 个变体 |
| `wardrobe.category_tick` | 类目切换 | 2-3 个变体 |
| `wardrobe.fabric_touch` | 物品点击 | 3 个变体 |
| `wardrobe.fabric_lift` | 拖起服装 | 2 个变体 |
| `wardrobe.outfit_apply` | 换装成功/放下成功 | 2-3 个变体 |
| `dialogue.advance_soft` | 对话推进 | 2 个变体 |
| `dialogue.finish_soft` | 对话结束确认 | 1-2 个变体 |
| `goodnight.page_close` | 晚安页进入/今日收束 | 1-2 个变体 |
| `scene.daily_enter_soft` | 每日场景进入 | 1-2 个变体 |
| `progress.unlock_soft` | 新解锁提示 | 2 个变体，未来接入 |

### Mixing Requirements

- UI/SFX 默认短、干净、低尾音；不得互相拖尾覆盖。
- 背景音乐循环点必须平滑，不出现明显断点。
- 所有 UI/SFX 资产导入后应以 bus 默认音量播放时保持克制，不依赖极端负增益修正。
- 高频事件必须提供短音效，单个 UI/SFX 建议控制在 `0.05..0.6s`。
- 音乐 loop 建议控制在 `45..120s`，避免太短导致重复感。
- 解锁提示和换装成功可以稍有亮度，但不得使用强上升音阶、奖杯音或 fanfare。
- 不使用红色错误态对应的声音语言；不可用反馈应是“轻轻提醒”，不是“拒绝”。

### Visual Requirements

- 音频管理无独立可见 UI。
- 若未来设置界面提供音量滑杆或静音按钮，应遵循 UI GDD 的无障碍要求：触控热区 ≥44×44px，状态不只靠颜色区分。
- 调试用音频事件面板若存在，只能作为开发工具，不进入玩家 MVP 体验。

### Asset Spec Flag

后续需要 `/asset-spec system:audio-management` 生成音频资产清单、事件 key、文件命名、目标时长、响度、变体数量和导入建议。音频资产规格应与本 GDD 的事件目录保持一致。

## UI Requirements

音频管理没有独立玩家界面。MVP 中玩家通过其他系统间接听到音频反馈，不进入单独的音频菜单或调试面板。

- 音频管理不得在主流程中显示独立 UI、弹窗或说明页。
- 主菜单、衣橱、对话、晚安等系统只发送音频事件，不展示音频系统状态。
- 若 Web 平台等待首次用户手势解锁音频，不显示技术提示；首次点击/触摸自然完成解锁。
- 静音/音量控制若在 MVP 中出现，应放在未来设置 UI 或主菜单弱化入口中，不由本 GDD 定义具体布局。
- 未来音量设置至少应支持：总音量、音乐音量、音效音量、静音开关。
- 所有未来音频设置控件必须满足触控热区 ≥44×44px，并支持键盘/手柄焦点。
- 静音状态必须有颜色以外的图标或文本提示，不得只靠颜色区分。
- 调试音频事件面板仅供开发测试，不进入玩家可见 MVP。

### UX Flag

若后续实现音量设置界面，需要在 `/ux-design settings-ui` 或主菜单 UX spec 中补充音频设置控件；本系统当前不单独要求 `/ux-design audio-management`。

## Acceptance Criteria

1. **GIVEN** 游戏启动，**WHEN** 音频管理初始化完成，**THEN** 创建并可访问 `Master`、`Music`、`SFX`、`UI` buses，且 SFX/UI 播放池已建立。
2. **GIVEN** 音频管理处于 `READY`，**WHEN** 调用 `play_event("ui.menu.start_pressed")`，**THEN** 系统从事件映射表找到对应资源并通过 `UI` 或 `SFX` bus 播放一次。
3. **GIVEN** 收到未注册的 `event_key`，**WHEN** 调用 `play_event(event_key)`，**THEN** 不播放声音、不崩溃，并记录 warning。
4. **GIVEN** 事件映射存在但资源缺失，**WHEN** 调用该事件，**THEN** UI/SFX 事件静默失败并记录 warning。
5. **GIVEN** 音乐事件资源缺失，**WHEN** 请求切换音乐，**THEN** 当前音乐保持播放或保持静音状态，不硬切到破损状态。
6. **GIVEN** 同一事件设置 `cooldown_ms = 300`，**WHEN** 300ms 内连续触发该事件多次，**THEN** 只播放第一次，后续冷却期内事件被丢弃。
7. **GIVEN** 同一事件 `max_instances = 2`，**WHEN** 第 3 个同事件实例在前两个仍播放时触发，**THEN** 低优先级事件被丢弃或按规则抢占同事件最早实例，不创建额外播放器。
8. **GIVEN** `SFX_POOL_SIZE = 8`，**WHEN** 快速触发 20 个短音效事件，**THEN** 活跃 `AudioStreamPlayer` 数量不超过 8。
9. **GIVEN** `base_volume_db + bus_volume_db + user_volume_db` 超过 `0 dB`，**WHEN** 播放事件，**THEN** 最终音量被 clamp 到 `0 dB` 以下，UI/SFX 事件不超过 `MAX_UI_SFX_VOLUME_DB`。
10. **GIVEN** 请求从主菜单音乐切换到晚安音乐，**WHEN** 音乐切换执行，**THEN** 使用淡入淡出过渡，常规情况下不硬切。
11. **GIVEN** 音乐淡入淡出尚未完成，**WHEN** 新的音乐切换请求到来，**THEN** 取消旧 tween/过渡，并以当前实际音量作为新淡入淡出起点。
12. **GIVEN** 请求播放与当前相同的 music key，**WHEN** 音乐事件触发，**THEN** 不重启当前音乐。
13. **GIVEN** Web 平台音频尚未解锁，**WHEN** 主菜单进入音乐事件触发，**THEN** 允许排队，且队列不超过 `MAX_UNLOCK_QUEUE_SIZE`。
14. **GIVEN** Web 平台音频尚未解锁，**WHEN** hover、拖拽或快速点击短音效触发，**THEN** 不排队，直接丢弃。
15. **GIVEN** 音频解锁队列已有多个音乐事件，**WHEN** 玩家首次点击解锁音频，**THEN** 只播放最后一个有效音乐事件和必要的首个 UI 反馈，不连续播放旧事件。
16. **GIVEN** 玩家启用静音，**WHEN** 任意音频事件触发，**THEN** 音频管理接收事件但不输出声音，且取消静音后不补播静音期间短音效。
17. **GIVEN** 浏览器页面失焦或标签进入后台，**WHEN** 音频管理进入 `SUSPENDED`，**THEN** 音乐和氛围音降低或暂停，短 UI/SFX 不排队。
18. **GIVEN** 页面恢复焦点，**WHEN** 音频管理从 `SUSPENDED` 返回 `READY`，**THEN** 音乐按淡入恢复，不补播后台期间短音效。
19. **GIVEN** 衣橱 UI 触发 `wardrobe.item_locked_pressed`，**WHEN** 音频管理播放该事件，**THEN** 使用轻微不可用反馈音，且受 `LOCKED_FEEDBACK_COOLDOWN_MS` 限制。
20. **GIVEN** 拖拽换装确认装备成功，**WHEN** 触发 `wardrobe.outfit_applied`，**THEN** 播放柔和成功反馈音；衣橱 UI 单独拖拽开始不得提前播放成功音。
21. **GIVEN** 对话 UI 推进文本，**WHEN** 触发 `dialogue.line_advanced`，**THEN** 播放低干扰短音效，不循环、不长尾。
22. **GIVEN** 主菜单/晚安 UI 进入晚安页，**WHEN** 触发 `ui.goodnight_entered`，**THEN** 播放低能量收束音，不播放胜利、结算或奖励音。
23. **GIVEN** 玩家点击禁用类目或锁定物品 10 次，**WHEN** 检查播放记录，**THEN** 实际播放次数受冷却限制，不出现 10 次连续叠音。
24. **GIVEN** 音频管理 MVP 主流程运行，**WHEN** 玩家完成 `主菜单 → 衣橱 → 对话 → 晚安 → 主菜单`，**THEN** 所有音频由音频管理事件接口触发，没有下游 UI 系统直接创建播放器或播放裸资源。
25. **GIVEN** 主流程中任一音频事件播放失败，**WHEN** 游戏继续运行，**THEN** 不阻塞状态转换、穿搭确认、对话推进或晚安继续。

## Open Questions

| Question | Owner | Target Resolution |
|----------|-------|-------------------|
| MVP 是否需要独立的衣橱音乐 `music.wardrobe_light_loop`，还是主菜单音乐可贯穿主菜单与衣橱？ | 音频设计 / 制作 | `/asset-spec system:audio-management` 前 |
| MVP 是否提供玩家可见的音量/静音设置，还是先使用默认音量并延后设置 UI？ | UX 设计 / 制作 | 主菜单 UX spec 或设置系统设计前 |
| 音频资源是否在 MVP 直接由音频管理事件表引用，还是接入资源加载器统一预加载？ | 技术设计 / 资源加载器 | 架构设计或实现前 |
| 每日场景是否每一天都有独立音乐，还是使用 1 首通用每日场景音乐加少量氛围变化？ | 每日场景 / 音频设计 | 每日场景 GDD 设计时 |
| 新解锁提示音是否在服装解锁弹出时播放，还是返回衣橱/主菜单时播放？ | 服装解锁 / 音频设计 | 服装解锁 GDD 设计时 |
| 是否需要 `Ambience` bus 在 MVP 中实际启用，还是只预留到未来扩展？ | 音频设计 / 技术设计 | 实现前 |
| 是否需要语音或角色呼吸/轻声反应？ | 叙事 / 音频设计 | 轻叙事对话 GDD 或后续内容扩展前 |
