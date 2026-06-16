# 拖拽换装 (Drag Dress-Up)

> **Status**: Approved
> **Author**: user + Codex Game Studios
> **Last Updated**: 2026-06-09
> **Implements Pillar**: 随心搭配, 即时有感

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `输入管理`, `精灵分层渲染`, `衣橱 UI`, `音频管理`

## Overview

拖拽换装是「每日穿搭」Feature 层的核心交互系统，负责把玩家从衣橱 UI 发出的服装选择意图，转化为角色身上的即时换装结果。它连接输入管理、衣橱 UI、精灵分层渲染与音频管理：输入管理提供鼠标/触摸统一后的拖拽与点击信号，衣橱 UI 提供 `item_id`、拖拽落点或点击替代意图，拖拽换装负责判断该意图是否能应用到角色区域，并在成功时调用精灵分层渲染的 `equip_item(item_id)` 完成实际穿搭更新；装备结果确认后，它再把 `outfit_apply_result(item_id, accepted, equipped_items, reason)` 回写给衣橱 UI，并触发 `wardrobe.outfit_applied` 等音频/反馈事件。对玩家来说，这个系统不是一套可见规则，而是“拿起一件衣服，轻轻放到她身上，它立刻被温柔接住”的瞬间：没有评分、没有失败惩罚，只有清楚、跟手、可撤回的试衣反馈，服务「随心搭配」与「即时有感」。

## Player Fantasy

拖拽换装的玩家幻想是：“我真的把衣服拿起来，放到她身上，然后她立刻穿上了我的选择。”

这个系统要让换装像触碰一本纸质换装贴纸书一样直觉：玩家按住一件上衣时，它从衣橱里被轻轻拿起；移动时，它稳定跟随手指或光标；放到角色身上时，角色立刻换上对应服装，并用一小段柔和的视觉与音频反馈告诉玩家“这件衣服已经被接住了”。整个过程不应该像库存管理、装备评分或任务提交，而应该像在安静试衣间里反复尝试：拿起、看看、放上去、不满意就再换一件。玩家永远不应因为落点不够精确、重复装备同一件衣服或使用点击替代路径而感到被惩罚；系统的语气始终是“可以，再试试这一件”，而不是“操作失败”。拖拽换装服务「随心搭配」的自由感，也服务「即时有感」的满足感：每一次成功换装都应该轻、准、快，让玩家自然想再拖下一件。

## Detailed Design

### Core Rules

**系统定位**：拖拽换装是 WARDROBE 场景中的交互仲裁系统，负责接收衣橱 UI 输出的装备意图，判断该意图是否应应用到角色，并把结果同步回衣橱 UI。它不直接解析原始输入事件、不渲染衣橱卡片、不加载纹理文件、不直接修改服装数据库或进度数据；它只处理“这个 `item_id` 是否应该装备到角色身上”这一层规则。

**输入来源规则**：
- 拖拽路径沿用衣橱 UI 正式接口：`item_drag_dropped(item_id, position)`。
- 点击替代路径沿用衣橱 UI 正式接口：`item_selected_for_equip(item_id)`。
- `item_id` 必须来自已解锁、可交互的衣橱卡片；锁定物品和禁用类目应在衣橱 UI 层被拦截。
- 拖拽换装可以对 `item_id` 做二次安全校验，但不得把校验失败表现成惩罚或评分。

**落点判定规则**：
- MVP 使用宽容角色热区：只要 `position` 落在角色可换装热区内，即视为可应用。
- 不要求玩家把上衣放到躯干、鞋子放到脚部、发型放到头部；类别归属由服装数据库中的 `item.category` 决定。
- 角色热区应覆盖角色主体和少量安全边距，避免移动端手指遮挡造成误判。
- 若落点不在角色热区内，本次拖拽视为取消或未应用，不改变装备状态。
- 点击替代路径不做落点判定，直接尝试应用 selected item。

**装备应用规则**：
- 成功判定后，拖拽换装调用精灵分层渲染的 `equip_item(item_id)`。
- 系统等待精灵分层渲染发出 `equip_item_completed(item_id, category, status, equipped_items)`，再确认装备结果；`outfit_changed(category, old_item_id, new_item_id)` 只作为成功视觉/音频反馈的辅助信号。
- 装备成功后，拖拽换装从精灵分层渲染读取 `get_equipped_items()`，并回写衣橱 UI：`outfit_apply_result(item_id, true, equipped_items, "equipped")`。
- 若玩家尝试装备已穿上的同一物品，视为 `same_item` no-op：不重复加载、不播放成功音、不显示失败，只回写 `outfit_apply_result(item_id, false, equipped_items, "same_item")` 或等价轻量结果。`same_item` 的 `accepted=false` 表示“没有发生新装备变更”，不是失败。
- 若 `equip_item(item_id)` 返回 `status != "equipped"`，拖拽换装按 status 映射为 `accepted=false` 与明确 `reason`；超时只作为安全网，不再作为主要失败判定。

**反馈规则**：
- 拖拽开始音由衣橱 UI 触发 `wardrobe.item_drag_started`。
- 装备成功音由拖拽换装在确认成功后触发 `wardrobe.outfit_applied`。
- 无效落点、同物品 no-op、渲染器未就绪等情况只触发轻量不可用或轻提示反馈，不播放失败、警报、拒绝或评分音。
- 视觉反馈应表现为“衣服被接住”：轻微微光、柔和落点反馈或角色局部短暂强调；不使用胜利结算、爆闪或奖励式反馈。
- 拖拽换装不逐帧播放音效；拖拽移动期间只更新预览位置，声音事件保持离散。

**状态同步规则**：
- 衣橱 UI 不得在输出装备意图后立即假定成功；拖拽换装是装备结果的确认者。
- 拖拽换装不得直接改写 ProgressManager、SaveManager 或 GameState。
- 当前穿搭持久化仍由衣橱 UI 确认穿搭流程或场景/状态管理处理；拖拽换装只负责当前 WARDROBE 会话内的即时装备。
- 若拖拽中断或场景离开，拖拽换装清理等待中的装备意图，不回写成功结果。

### States and Transitions

```text
IDLE
  → DRAG_PENDING(item_id)
  → APPLYING(item_id)
  → RESULT_SYNC
  → IDLE

IDLE
  → CLICK_APPLYING(item_id)
  → RESULT_SYNC
  → IDLE
```

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|----------|----------|
| `IDLE` | 无装备意图等待处理 | WARDROBE 场景就绪 | 收到拖拽落点或点击替代意图 |
| `DRAG_PENDING` | 收到拖拽落点，正在判定角色热区 | `item_drag_dropped(item_id, position)` | 落点无效返回 `IDLE`；落点有效进入 `APPLYING` |
| `APPLYING` | 已调用 `equip_item(item_id)`，等待渲染器完成结果 | 落点有效或点击替代意图有效 | 收到 `equip_item_completed`、超时、无效 ID 或渲染器错误 |
| `CLICK_APPLYING` | 点击替代路径正在应用物品 | `item_selected_for_equip(item_id)` | 同 `APPLYING` |
| `RESULT_SYNC` | 正在把结果回写给衣橱 UI，并触发成功/轻提示反馈 | 装备结果已确定 | 回写完成后返回 `IDLE` |

### Interactions with Other Systems

| 系统 | 方向 | 交互性质 |
|------|------|----------|
| 输入管理 | 间接依赖 | 输入管理提供 `drag_started` / `drag_updated` / `drag_ended`，但拖拽换装主要消费衣橱 UI 已整理后的装备意图，不重复解析原始输入 |
| 衣橱 UI | 本系统依赖 / 回写对象 | 接收 `item_drag_dropped(item_id, position)` 与 `item_selected_for_equip(item_id)`；返回 `outfit_apply_result(item_id, accepted, equipped_items, reason)` |
| 精灵分层渲染 | 强依赖 | 调用 `equip_item(item_id)` 执行实际穿搭；监听 `equip_item_completed` 作为结果确认；监听 `outfit_changed` 播放成功反馈；读取 `get_equipped_items()` |
| 音频管理 | 本系统调用 | 装备成功后触发 `play_event("wardrobe.outfit_applied", context)`；无效结果可触发轻量不可用事件，受音频管理冷却限制 |
| 服装数据库 | 间接依赖 | 通过精灵分层渲染和衣橱 UI 消费物品数据；拖拽换装可用 `item.category` 做二次校验，但不拥有数据库逻辑 |
| 进度管理 | 间接依赖 | 解锁/可见性由衣橱 UI 负责拦截；拖拽换装不读取或修改进度 |
| 场景/状态管理 | 弱相关 | WARDROBE 离开时取消 pending/applying 状态；不决定场景切换 |

## Formulas

拖拽换装不包含评分、搭配优劣或成长数值。这里的公式只用于判定交互是否成功、如何保护即时反馈，以及如何避免重复装备或异步确认造成状态混乱。

### 角色热区扩展

```text
expanded_hotzone = character_bounds.grow(HOTZONE_PADDING_PX)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `character_bounds` | `B` | Rect2 | valid Rect2 | 角色主体在 WARDROBE 场景中的可换装区域，来自角色展示节点或配置 |
| `HOTZONE_PADDING_PX` | `P` | float | `0..80 px` | 角色热区额外边距，用于补偿移动端手指遮挡和轻微落点偏移 |
| `expanded_hotzone` | `H` | Rect2 | valid Rect2 | 实际用于落点判定的宽容热区 |

**Output Range:** `expanded_hotzone` 为一个有效 `Rect2`。
**Example:** 角色主体区域为 `(x=220, y=80, w=300, h=520)`，`P=32`，则实际热区扩大到 `(188, 48, 364, 584)`。

### 拖拽落点命中判定

```text
drop_accepted = expanded_hotzone.has_point(drop_position)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `drop_position` | `D` | Vector2 | viewport/global coordinate | 衣橱 UI 传入的拖拽结束位置 |
| `expanded_hotzone` | `H` | Rect2 | valid Rect2 | 角色宽容热区 |
| `drop_accepted` | `A` | bool | true/false | 本次拖拽落点是否可应用 |

**Output Range:** boolean。
**Example:** `D=(300, 360)` 且位于 `H` 内 → `drop_accepted=true`；`D=(40, 640)` 在衣橱网格底部 → `drop_accepted=false`。

### 点击替代应用判定

```text
click_apply_accepted = selected_item_id != null
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `selected_item_id` | `S` | String\|null | valid item id or null | 衣橱 UI 当前点击选中的物品 |
| `click_apply_accepted` | `C` | bool | true/false | 点击替代路径是否有可应用物品 |

**Output Range:** boolean。
**Rule:** 点击替代路径不做落点判定，只要衣橱 UI 传入有效 `item_id`，拖拽换装即尝试应用。
**Example:** `selected_item_id="top_white_tee"` → `true`；`selected_item_id=null` → `false`。

### 同物品 No-Op 判定

```text
same_item = current_equipped_item_for_category == item_id
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `item_id` | `I` | String | valid item id | 玩家尝试应用的物品 |
| `item_category` | `K` | String | valid category key | 该物品所属类目 |
| `current_equipped_item_for_category` | `E` | String\|null | item id or null | 精灵分层渲染当前该类目已装备物品 |
| `same_item` | `N` | bool | true/false | 是否重复装备同一物品 |

**Output Range:** boolean。
**Rule:** `same_item=true` 时不调用新的装备反馈，不播放成功音，不显示失败；只回写轻量 no-op 结果。
**Example:** 当前 `top` 已装备 `top_white_tee`，再次应用 `top_white_tee` → `same_item=true`。

### 装备确认超时

```text
apply_timed_out = elapsed_apply_time_ms > APPLY_CONFIRM_TIMEOUT_MS
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `elapsed_apply_time_ms` | `T` | int | `>=0 ms` | 从调用 `equip_item(item_id)` 到收到确认信号之间的时间 |
| `APPLY_CONFIRM_TIMEOUT_MS` | `L` | int | `100..1000 ms` | 等待 `equip_item_completed` 的最大时长 |
| `apply_timed_out` | `O` | bool | true/false | 本次装备是否超时 |

**Output Range:** boolean。
**Default:** `APPLY_CONFIRM_TIMEOUT_MS = 500 ms`。
**Rule:** 超时后回写 `outfit_apply_result(item_id, false, equipped_items, "apply_timeout")`，不播放成功音。若迟到的 `equip_item_completed` 或 `outfit_changed` 到达，必须用 pending token 检查并丢弃过期结果。
**Example:** 热缓存装备通常同帧确认；若 500ms 内没有 `equip_item_completed`，视为装备未确认。

### Pending Token 匹配

```text
result_is_current = equip_item_completed.item_id == pending_item_id
                    AND pending_token == active_apply_token
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `equip_item_completed.item_id` | `R` | String | item id | 渲染器完成结果对应的物品 ID |
| `pending_item_id` | `I` | String | item id | 当前等待确认的物品 ID |
| `pending_token` | `Q` | int | `>=0` | 本次装备请求的序号 |
| `active_apply_token` | `Q_active` | int | `>=0` | 系统当前仍承认有效的请求序号 |
| `result_is_current` | `M` | bool | true/false | 该确认信号是否属于当前请求 |

**Output Range:** boolean。
**Rule:** 快速连续装备时，只有最后一次请求的确认可回写 UI 和播放成功反馈；旧请求迟到时静默丢弃。
**Example:** 先应用 `top_a`，立刻应用 `top_b`；`top_a` 的纹理晚到时 `pending_token` 已过期，不能覆盖 `top_b` 的 UI 状态。

### 反馈强度

```text
feedback_intensity = clamp(drop_distance_to_center / HOTZONE_FEEDBACK_RADIUS_PX, 0.0, 1.0)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `drop_distance_to_center` | `R` | float | `>=0 px` | 落点到角色热区中心的距离 |
| `HOTZONE_FEEDBACK_RADIUS_PX` | `F` | float | `120..480 px` | 反馈强度归一化半径 |
| `feedback_intensity` | `V` | float | `0.0..1.0` | 传给视觉/音频 context 的轻量强度值 |

**Output Range:** `0.0..1.0`。
**Rule:** 该值只用于微光/柔影等反馈强弱，不代表搭配评价。不得把靠近中心解释为“更好搭配”。
**Example:** 中心附近落点 `V≈0.0`，热区边缘落点 `V≈1.0`；两者都同样成功，只是反馈位置/强度略有差异。

## Edge Cases

- **If drop position is outside the expanded character hotzone**: treat the drag as cancelled. Do not call `equip_item()`, do not change equipped state, and return `outfit_apply_result(item_id, false, equipped_items, "drop_outside_hotzone")`. Feedback should be light and non-punitive.
- **If `drag_ended(interrupted=true)` occurs before衣橱 UI emits a drop intent**: clear any local pending drag state and do not emit an outfit result. This is a cancellation, not a failed outfit attempt.
- **If the player drops an item on the clothing grid, category labels, buttons, or any non-character UI**: treat as outside hotzone even if the item visually overlaps the character due to layout. UI controls have priority over accidental outfit application.
- **If the player applies the same item that is already equipped in its category**: return `outfit_apply_result(item_id, false, equipped_items, "same_item")`; do not call `equip_item()` again, do not play `wardrobe.outfit_applied`, and briefly emphasize the already-equipped card or item.
- **If two equip requests arrive in quick succession**: increment `active_apply_token` for the latest request. Only the latest matching token may write back to衣橱 UI or trigger success feedback; older confirmations are discarded.
- **If `equip_item_completed` arrives for an item that is not the current pending item**: ignore it for this request. Do not overwrite UI state or play success audio.
- **If `equip_item(item_id)` does not produce `equip_item_completed` before `APPLY_CONFIRM_TIMEOUT_MS`**: return `outfit_apply_result(item_id, false, equipped_items, "apply_timeout")`; do not play success feedback. Late confirmations must pass token matching before they can affect state.
- **If SpriteLayeredRenderer is not ready**: do not call `equip_item()`. Return `outfit_apply_result(item_id, false, equipped_items, "renderer_not_ready")` and show only a soft unavailable cue.
- **If `item_id` is invalid or cannot be resolved**: return `outfit_apply_result(item_id, false, equipped_items, "invalid_item")`, log a warning, and leave outfit state unchanged.
- **If the item belongs to a category that is not part of the MVP category set**: return `outfit_apply_result(item_id, false, equipped_items, "invalid_category")`. This protects against bad data or future content entering the MVP flow early.
- **If the item is locked or from a disabled category despite衣橱 UI normally preventing this**: reject it with `outfit_apply_result(item_id, false, equipped_items, "not_unlocked")`. The visual tone remains gentle; this is a safety net, not player-facing punishment.
- **If texture loading fails inside精灵分层渲染**: renderer emits `equip_item_completed(item_id, category, "texture_failed", equipped_items)` and no `outfit_changed`. Drag dress-up maps this to `outfit_apply_result(item_id, false, equipped_items, "texture_failed")`, leaves current outfit unchanged, and avoids success audio.
- **If WARDROBE scene exits while an equip request is pending**: invalidate the active token, disconnect temporary listeners if needed, and do not write back success after leaving the scene.
- **If the character hotzone cannot be found or has zero size**: disable drag application for that frame/session, log a warning, and return `outfit_apply_result(item_id, false, equipped_items, "hotzone_unavailable")` for incoming attempts.
- **If viewport size or orientation changes during a drag**: use the latest recalculated character hotzone for the final drop判定. If recalculation is unavailable, cancel safely rather than applying to a stale region.
- **If click alternative is triggered with no selected item**: ignore the request or return `outfit_apply_result("", false, equipped_items, "no_selected_item")`; do not produce failure-styled feedback.
- **If click alternative applies a selected item while a drag apply is already pending**: latest request wins via token matching. The earlier request cannot write back after it becomes stale.
- **If the player repeatedly drops outside the hotzone**: do not escalate feedback. Use the same light unavailable cue, subject to audio cooldowns.
- **If audio management is unavailable or the audio event is missing**: outfit application still succeeds visually and logically. Audio failure must never block `outfit_apply_result`.
- **If visual feedback assets are missing**: complete the outfit application and UI state sync; skip the visual flourish and log a warning.
- **If `get_equipped_items()` returns an empty array after a claimed successful equip**: treat the result as suspicious and return `accepted=false` with `reason="equipped_state_unconfirmed"` unless the applied item category is intentionally empty, which MVP does not use.
- **If a request is cancelled before applying**: no outfit state changes, no success audio, no persistence change, and no GameState write.
- **If the player confirms穿搭 immediately after an equip request starts**:衣橱 UI should wait for `outfit_apply_result` before submitting final `equipped_items`; if the result times out, confirm using the last known equipped state rather than speculative state.

## Dependencies

### 本系统依赖（上游）

| 依赖 | 类型 | 接口/数据 | 说明 |
|------|------|----------|------|
| 衣橱 UI | 强依赖 | `item_drag_dropped(item_id, position)`、`item_selected_for_equip(item_id)` | 提供已经过 UI 层过滤的玩家装备意图。拖拽换装不负责生成卡片、预览或 selected 状态 |
| 精灵分层渲染 | 强依赖 | `equip_item(item_id)`、`get_equipped_items()`、`get_equipped_item_for_category(category)`、`equip_item_completed(item_id, category, status, equipped_items)`、`outfit_changed(category, old_item_id, new_item_id)` | 执行实际换装并确认渲染结果。拖拽换装不得直接改 Sprite2D |
| 音频管理 | 反馈依赖 / 软依赖 | `play_event("wardrobe.outfit_applied", context)`；可选轻提示事件 | 成功反馈音只在装备确认后播放；音频失败不阻塞装备 |
| 输入管理 | 间接依赖 | `drag_started`、`drag_updated`、`drag_ended`、`clicked` | 衣橱 UI 已消费这些信号并输出装备意图；拖拽换装不重复解析原始输入 |
| 服装数据库 | 间接/安全校验 | `get_item_by_id(item_id)` 或来自渲染器/UI 的 item metadata | 主要由衣橱 UI 和精灵分层渲染消费；拖拽换装仅可用于二次校验 item/category |
| 进度管理 | 间接/安全校验 | `is_item_unlocked(item_id)` 可选 | 解锁和可见性由衣橱 UI 负责；拖拽换装只做防御性拒绝，不拥有进度逻辑 |
| 场景/状态管理 | 弱依赖 | WARDROBE enter/exit 生命周期 | 离开 WARDROBE 时取消 pending apply，不决定场景跳转 |

### 本系统输出（下游/回写）

| 输出 | 接收方 | 数据 | 说明 |
|------|--------|------|------|
| `outfit_apply_result(item_id, accepted, equipped_items, reason)` | 衣橱 UI | `item_id: String`, `accepted: bool`, `equipped_items: Array[String]`, `reason: String` | 拖拽换装对装备意图的唯一结果回写。衣橱 UI 根据它更新 equipped/selected 状态 |
| `wardrobe.outfit_applied` 音频事件 | 音频管理 | `item_id`, `category`, `feedback_intensity` | 仅在装备成功确认后触发 |
| 轻量不可用/提示反馈 | 衣橱 UI / 音频管理 | `reason` | 用于无效落点、同物品、未就绪等情况；不得表现为失败或评分 |
| 当前装备状态 | 衣橱 UI | `equipped_items` | 来自精灵分层渲染的 `get_equipped_items()`，不是拖拽换装自行维护的真相源 |

### 正式接口契约

衣橱 UI 早前预留的以下接口，在本 GDD 中正式确认：

| 接口 | 方向 | 语义 |
|------|------|------|
| `item_drag_dropped(item_id, position)` | 衣橱 UI → 拖拽换装 | 玩家拖拽已解锁物品并释放，要求拖拽换装判定是否应用 |
| `item_selected_for_equip(item_id)` | 衣橱 UI → 拖拽换装 | 玩家通过点击替代路径选择物品并请求应用 |
| `outfit_apply_result(item_id, accepted, equipped_items, reason)` | 拖拽换装 → 衣橱 UI | 装备意图处理完成，返回是否成功、当前穿搭和原因 |

`reason` 使用固定枚举字符串集合：`"equipped"`、`"same_item"`、`"drop_outside_hotzone"`、`"renderer_not_ready"`、`"invalid_item"`、`"invalid_category"`、`"not_unlocked"`、`"texture_failed"`、`"cancelled_stale"`、`"apply_timeout"`、`"hotzone_unavailable"`、`"no_selected_item"`、`"equipped_state_unconfirmed"`。新增 reason 必须回传修订本 GDD，避免实现阶段随手扩展导致 UI 分支不一致。

### 双向依赖确认

**拖拽换装 ↔ 衣橱 UI**：
- 衣橱 UI 输出装备意图，但不立即改 equipped state。
- 拖拽换装回写结果，衣橱 UI 才更新 equipped/selected 状态。
- 若未来接口名改动，必须同步修订 `design/gdd/wardrobe-ui.md`。

**拖拽换装 ↔ 精灵分层渲染**：
- 拖拽换装只调用公开 API，不直接操作精灵节点或纹理。
- 精灵分层渲染通过 `equip_item_completed` 确认真实装备结果，`outfit_changed` 只表示成功视觉变更。
- `get_equipped_items()` 是当前穿搭的读取来源。

**拖拽换装 ↔ 音频管理**：
- 拖拽换装只发送音频事件 key 和轻量 context。
- 音频管理决定资源、bus、冷却、并发和实际播放。
- 成功音必须等待装备确认，不能在拖拽放下瞬间提前播放。

### 不依赖/不负责

- 不读写 SaveManager 或 LocalStorage。
- 不推进每日进度、不解锁服装。
- 不决定穿搭评分、推荐或搭配优劣。
- 不直接加载 `texture_path` 或 `thumbnail_path`。
- 不管理衣橱卡片布局、类目显示或锁定说明。
- 不决定 WARDROBE → DAILY_SCENE 的场景切换；确认穿搭流程仍归衣橱 UI / 场景状态管理。

## Tuning Knobs

拖拽换装的调参目标是“更跟手、更宽容、更有反馈”，而不是提高难度或制造精准操作要求。所有参数都应服务轻松试衣感。

| 参数 | 默认值 | 安全范围 | 影响 |
|------|--------|----------|------|
| `HOTZONE_PADDING_PX` | `32 px` | `0..80 px` | 角色可换装热区的额外边距。增大可降低移动端误判，过大可能让靠近 UI 的落点误触换装；减小更精确，但手指遮挡时容易取消 |
| `APPLY_CONFIRM_TIMEOUT_MS` | `500 ms` | `100..1000 ms` | 等待精灵分层渲染 `equip_item_completed` 的最大时长。过短可能误判冷缓存加载，过长会让 UI 等待迟钝 |
| `HOTZONE_FEEDBACK_RADIUS_PX` | `240 px` | `120..480 px` | 反馈强度归一化半径。影响微光/柔影强弱，不影响装备成功率，不代表搭配评价 |
| `SUCCESS_FEEDBACK_DURATION_MS` | `260 ms` | `160..500 ms` | 成功换装微光、轻强调或柔和落点反馈时长。过短不易感知，过长会拖慢连续试衣 |
| `UNAVAILABLE_FEEDBACK_DURATION_MS` | `180 ms` | `100..350 ms` | 无效落点、同物品、未就绪等轻提示时长。必须轻，不得像错误动画 |
| `INVALID_DROP_COOLDOWN_MS` | `250 ms` | `100..700 ms` | 连续无效落点提示冷却，避免玩家快速拖放时反馈堆叠 |
| `VISUAL_GLOW_STRENGTH` | `0.35` | `0.0..0.7` | 成功反馈微光强度。过高会像奖励爆闪；MVP 应保持柔和 |
| `CARD_EQUIPPED_PULSE_SCALE` | `1.03` | `1.0..1.08` | 回写 UI 后已装备卡片的轻微强调缩放。过高会显得跳脱 |
| `MAX_PENDING_APPLY` | `1` | fixed | 同时只允许一个有效装备请求。新请求覆盖旧请求，避免竞态 |
| `BODY_ZONE_MATCHING_ENABLED` | `false` | fixed for MVP | MVP 不启用精确身体部位匹配。若未来启用，必须回传修订本 GDD 和衣橱 UI/UX spec |

### 非本系统控制的调参点

| 行为 | 控制方 | 说明 |
|------|--------|------|
| 拖拽触发阈值 | 输入管理 | `drag_threshold` 属于 InputManager |
| 拖拽预览缩放 | 衣橱 UI | `DRAG_PREVIEW_SCALE` 属于衣橱 UI |
| 卡片尺寸、类目布局 | 衣橱 UI | 拖拽换装只消费装备意图 |
| 角色精灵层级 | 精灵分层渲染 / 服装数据库 | `z_index` 和 `z_index_override` 不归本系统调整 |
| 音频冷却、并发、音量 | 音频管理 | `wardrobe.outfit_applied` 实际播放由音频管理控制 |
| 当前穿搭保存 | 衣橱 UI / 场景状态管理 / 保存加载 | 拖拽换装不持久化 |

### 刻意不做成可调的

| 项目 | 固定值 | 原因 |
|------|--------|------|
| 是否存在评分 | 不存在 | 与「随心搭配」冲突 |
| 是否要求精确身体部位落点 | 不要求 | MVP 优先宽容、移动端友好和无压力 |
| 是否允许锁定物品强行装备 | 不允许 | 解锁规则由进度管理和衣橱 UI 保证 |
| 成功音触发时机 | 装备确认后 | 防止拖拽放下但实际未穿上时提前播放成功音 |
| 同时 pending 请求数量 | 1 | 简化竞态处理，保证 UI 状态可预测 |

## Visual/Audio Requirements

拖拽换装的视觉和音频必须让玩家感到“衣服被温柔接住”，而不是“系统判定通过”。反馈应轻、短、明确，支撑连续试衣，不打断玩家继续搭配。

### Visual Requirements

| 事件/状态 | 视觉要求 | 说明 |
|-----------|----------|------|
| 拖拽进行中 | 拖拽预览由衣橱 UI 负责；拖拽换装不重复创建预览 | 避免双重预览或状态冲突 |
| 进入角色热区 | 可选轻微角色热区暗示，如角色主体附近极淡暖光或落点吸附感 | 不显示硬边框、不画命中框，不让玩家感觉在做精准投掷 |
| 成功装备 | 角色对应服装层即时更新；叠加 `SUCCESS_FEEDBACK_DURATION_MS` 的柔和微光、轻亮或落点涟漪 | 表达“被接住”，不是奖励爆炸 |
| 已装备卡片同步 | 衣橱 UI 根据 `outfit_apply_result` 显示 equipped 状态；可短暂使用 `CARD_EQUIPPED_PULSE_SCALE` 轻强调 | 表示状态已同步，不代表评分 |
| 同物品 no-op | 当前已装备卡片或角色对应区域轻微强调一次 | 告诉玩家“已经是这一件”，不播放失败反馈 |
| 无效落点 | 拖拽预览自然回落/淡出，角色不变化；可显示极轻不可用提示 | 不用红色、不震动、不弹错误 |
| 渲染器未就绪/热区不可用 | 显示轻量不可用提示或静默忽略，避免技术状态暴露给玩家 | 技术异常不应破坏温柔语气 |
| 快速连续换装 | 只显示最新成功结果的反馈；旧请求迟到时不闪烁、不回跳 | 防止视觉竞态 |

### Audio Requirements

| 事件 | 音频事件 | 要求 |
|------|----------|------|
| 拖起服装 | `wardrobe.item_drag_started` | 由衣橱 UI 触发，拖拽换装不重复播放 |
| 成功装备 | `wardrobe.outfit_applied` | 仅在 `equip_item_completed.status == "equipped"` 且对应 `outfit_changed` 已确认后触发；短、柔、布料/轻放质感 |
| 同物品 no-op | 可选轻量 UI 提示事件，或不播放 | 不使用失败音，不播放成功音 |
| 无效落点 | 可选轻量不可用事件，受音频管理冷却限制 | 不得刺耳，不得连续堆叠 |
| 装备超时/渲染器未就绪 | 通常不播放，或使用极轻提示 | 技术异常不应被戏剧化 |
| 音频系统不可用 | 无声音，流程照常完成 | 音频不可阻塞换装 |

### Style Constraints

- 成功反馈应像布料轻轻落好、纸贴被贴上、微光被点亮；不得像胜利、抽卡、任务完成。
- 不使用红色错误态、强震动、爆闪、强粒子或大幅弹跳。
- 反馈总时长应支持连续试衣：成功反馈默认约 `260 ms`，无效反馈默认约 `180 ms`。
- 角色穿搭结果永远比特效更重要；特效不得遮挡服装细节。
- 所有视觉/音频反馈都必须尊重“无评分”原则，不暗示某件衣服更正确或更高级。

### Asset Spec Flag

后续需要 `/asset-spec system:drag-dress-up` 生成成功微光、落点涟漪、不可用轻提示、已装备卡片强调等视觉反馈规格，并与 `audio-management` 的 `wardrobe.outfit_applied` 声音资产保持一致。

## UI Requirements

拖拽换装本身不渲染完整界面，但它定义衣橱 UI 中“应用服装到角色”的交互要求。所有 UI 表现必须与衣橱 UI GDD 对齐，并保证玩家不依赖精确拖拽也能完成换装。

### 拖拽路径

1. 玩家从已解锁服装卡片拖起物品。
2. 衣橱 UI 显示拖拽预览和源卡 ghost。
3. 玩家把物品释放在角色宽容热区内。
4. 衣橱 UI 发出 `item_drag_dropped(item_id, position)`。
5. 拖拽换装判定热区并尝试装备。
6. 拖拽换装回写 `outfit_apply_result(...)`。
7. 衣橱 UI 根据结果更新 equipped/selected 状态。

### 点击替代路径

1. 玩家点击已解锁服装卡片。
2. 卡片进入 selected 状态。
3. 玩家点击角色区域、确认应用区域，或使用键盘/手柄确认动作。
4. 衣橱 UI 发出 `item_selected_for_equip(item_id)`。
5. 拖拽换装直接尝试装备，不做落点判定。
6. 装备结果通过 `outfit_apply_result(...)` 回写。

### 角色热区要求

- 角色热区应覆盖角色主体，并使用 `HOTZONE_PADDING_PX` 扩大判定。
- 热区默认不显示硬边框；可在拖拽接近或进入时显示极淡暖光提示。
- 热区不得遮挡角色服装细节，不得显示类似“命中框”的竞技反馈。
- 桌面端、移动端、窄屏布局都必须重新计算热区，避免使用过期坐标。
- 若 UI 控件与角色热区视觉重叠，UI 控件优先，不触发换装。

### 移动端要求

- 不要求精确身体部位落点；玩家只需把物品放到角色附近。
- 手指遮挡下仍应容易成功，默认通过 `HOTZONE_PADDING_PX = 32 px` 补偿。
- 无效落点不弹错误；拖拽预览自然淡出或回落。
- 点击替代路径必须完整可用，避免拖拽困难玩家无法换装。

### Godot 4.6 Focus Requirements

- 鼠标 hover、触摸 selected、键盘/手柄 focus 必须被区分。
- 键盘/手柄 focus 不等于鼠标 hover；两者可同时存在于不同控件。
- 若玩家使用键盘/手柄，应能通过衣橱 UI 焦点选中服装卡片，再执行确认应用到角色。
- 拖拽换装不直接管理 focus，但必须接受点击替代路径产生的 `item_selected_for_equip(item_id)`。

### Accessibility

- 换装不得只依赖拖拽；点击替代路径是 MVP 必需。
- 任何“可应用/已应用/不可用”反馈不得只靠颜色区分，应由衣橱 UI 同步图标、状态或轻提示。
- 无效落点、同物品和未就绪不使用红色错误态或惩罚语言。
- 触控目标尺寸、卡片状态、锁定说明等遵循衣橱 UI GDD。
- 若未来进入 UX spec，应把拖拽 + 点击替代作为同一交互模式的两条等价路径，而不是把点击替代视为降级。

### UX Flag

拖拽换装影响衣橱 UI 的核心交互模式。进入 Pre-Production 前，应在 `/ux-design wardrobe-ui` 中细化拖拽路径、点击替代路径、角色热区提示、键盘/手柄确认动作和移动端布局验证；后续故事应同时引用 `design/gdd/drag-dress-up.md` 与 `design/ux/wardrobe-ui.md`。

## Acceptance Criteria

### 初始化与依赖

1. **GIVEN** WARDROBE 场景进入且衣橱 UI、精灵分层渲染、音频管理可用，**WHEN** 拖拽换装初始化，**THEN** 系统进入 `IDLE`，能接收 `item_drag_dropped` 与 `item_selected_for_equip`。
2. **GIVEN** 精灵分层渲染未就绪，**WHEN** 收到任意装备意图，**THEN** 不调用 `equip_item()`，回写 `outfit_apply_result(item_id, false, equipped_items, "renderer_not_ready")`。
3. **GIVEN** 角色热区不存在或大小为 0，**WHEN** 收到拖拽落点，**THEN** 不应用装备，回写 `reason="hotzone_unavailable"` 并记录 warning。

### 拖拽成功路径

4. **GIVEN** 玩家拖拽已解锁物品到 `expanded_hotzone` 内，**WHEN** 衣橱 UI 发出 `item_drag_dropped(item_id, position)`，**THEN** 拖拽换装调用 `equip_item(item_id)`。
5. **GIVEN** `equip_item(item_id)` 已调用，**WHEN** 精灵分层渲染发出匹配当前 pending token 的 `equip_item_completed(item_id, category, "equipped", equipped_items)`，**THEN** 回写 `outfit_apply_result(item_id, true, equipped_items, "equipped")`。
6. **GIVEN** 装备成功确认，**WHEN** 结果回写完成，**THEN** 播放一次 `wardrobe.outfit_applied` 音频事件，且 context 包含 `item_id`、`category`、`feedback_intensity`。
7. **GIVEN** 装备成功确认，**WHEN** 视觉反馈播放，**THEN** 角色服装已更新，并显示不超过 `SUCCESS_FEEDBACK_DURATION_MS` 的柔和成功反馈。

### 无效落点与取消

8. **GIVEN** 玩家拖拽物品释放在 `expanded_hotzone` 外，**WHEN** 衣橱 UI 发出 `item_drag_dropped(item_id, position)`，**THEN** 不调用 `equip_item()`，回写 `reason="drop_outside_hotzone"`。
9. **GIVEN** 玩家释放在衣橱网格、类目标签或按钮上，**WHEN** 该区域与角色热区视觉重叠，**THEN** UI 控件优先，拖拽换装不得应用装备。
10. **GIVEN** `drag_ended(interrupted=true)` 且衣橱 UI 未发出 drop intent，**WHEN** 拖拽换装收到取消状态，**THEN** 不回写成功、不播放成功音、不改变装备状态。
11. **GIVEN** 玩家连续多次拖到无效区域，**WHEN** 触发不可用反馈，**THEN** 反馈受 `INVALID_DROP_COOLDOWN_MS` 或音频管理冷却限制，不出现连续堆叠。

### 点击替代路径

12. **GIVEN** 玩家通过衣橱 UI 选中已解锁物品，**WHEN** 衣橱 UI 发出 `item_selected_for_equip(item_id)`，**THEN** 拖拽换装不做落点判定，直接尝试 `equip_item(item_id)`。
13. **GIVEN** 点击替代路径装备成功，**WHEN** 收到匹配的 `equip_item_completed(..., "equipped", ...)`，**THEN** 回写 `accepted=true`，衣橱 UI 可清除 selected 状态并更新 equipped 状态。
14. **GIVEN** 点击替代路径没有 selected item，**WHEN** 发生应用请求，**THEN** 不应用装备，回写或忽略 `reason="no_selected_item"`，不显示失败样式。
15. **GIVEN** 玩家只使用键盘/手柄焦点路径，**WHEN** 选中服装卡片并确认应用到角色，**THEN** 能完成一次成功换装，不依赖鼠标 hover。

### Same Item 与安全校验

16. **GIVEN** 当前类目已装备 `item_id`，**WHEN** 玩家再次应用同一 `item_id`，**THEN** 不调用 `equip_item()`，回写 `outfit_apply_result(item_id, false, equipped_items, "same_item")`。
17. **GIVEN** 同物品 no-op，**WHEN** 反馈播放，**THEN** 不播放 `wardrobe.outfit_applied`，只做轻量强调或静默。
18. **GIVEN** `item_id` 无效，**WHEN** 收到装备意图，**THEN** 回写 `reason="invalid_item"`，装备状态不变。
19. **GIVEN** 物品类目不在 MVP 类目集合内，**WHEN** 收到装备意图，**THEN** 回写 `reason="invalid_category"`，装备状态不变。
20. **GIVEN** 锁定物品或禁用类目绕过衣橱 UI 进入拖拽换装，**WHEN** 二次校验失败，**THEN** 回写 `reason="not_unlocked"`，不装备、不播放成功音。

### 异步确认与竞态

21. **GIVEN** `equip_item(item_id)` 已调用，**WHEN** `APPLY_CONFIRM_TIMEOUT_MS` 内没有收到匹配的 `equip_item_completed`，**THEN** 回写 `reason="apply_timeout"`，不播放成功音。
22. **GIVEN** 超时后迟到的 `equip_item_completed` 或 `outfit_changed` 到达，**WHEN** pending token 已失效，**THEN** 不回写 UI、不播放成功音。
23. **GIVEN** 玩家快速应用 `top_a` 后立刻应用 `top_b`，**WHEN** 两个渲染确认先后到达，**THEN** 只有最新 active token 对应的 `top_b` 可更新衣橱 UI 和播放成功反馈。
24. **GIVEN** `equip_item_completed.item_id` 与 pending item 不一致，**WHEN** 信号到达，**THEN** 拖拽换装忽略该信号，不改变本次请求结果。
24a. **GIVEN** `equip_item_completed.status` 为 `"same_item"`、`"invalid_item"`、`"invalid_category"`、`"texture_failed"`、`"renderer_not_ready"` 或 `"cancelled_stale"`，**WHEN** 信号匹配当前 pending token，**THEN** 拖拽换装回写 `accepted=false` 与同名 `reason`，不播放成功音。
25. **GIVEN** `get_equipped_items()` 在成功确认后返回空数组，**WHEN** MVP 不允许空穿搭作为成功结果，**THEN** 回写 `reason="equipped_state_unconfirmed"` 或阻止 accepted=true。

### 场景与生命周期

26. **GIVEN** WARDROBE 场景退出时仍有装备请求 pending，**WHEN** 场景离开，**THEN** active token 失效，之后迟到结果不得回写 UI。
27. **GIVEN** 玩家点击确认穿搭时装备请求仍 pending，**WHEN** 衣橱 UI 准备提交最终穿搭，**THEN** 必须等待 `outfit_apply_result` 或超时后使用最后已确认 equipped state。
28. **GIVEN** 视口尺寸或方向在拖拽中变化，**WHEN** 玩家释放物品，**THEN** 使用最新角色热区判定；若热区无法更新则安全取消。

### 视觉、音频与无障碍

29. **GIVEN** 成功装备反馈播放，**WHEN** 检查视觉表现，**THEN** 不使用评分、胜利、爆闪或红色错误态。
30. **GIVEN** 无效落点、同物品或未就绪，**WHEN** 反馈播放，**THEN** 不使用惩罚语言、刺耳失败音或强警告样式。
31. **GIVEN** 音频管理不可用或 `wardrobe.outfit_applied` 资源缺失，**WHEN** 装备成功，**THEN** 视觉与逻辑仍成功，音频失败只记录 warning。
32. **GIVEN** 视觉反馈资产缺失，**WHEN** 装备成功，**THEN** 角色穿搭和 UI 状态仍正确同步。
33. **GIVEN** 移动端触摸操作，**WHEN** 玩家把服装释放在角色附近但不精确对应身体部位，**THEN** 只要在 expanded hotzone 内即可成功装备。
34. **GIVEN** 玩家无法或不愿拖拽，**WHEN** 使用点击替代路径，**THEN** 可完成与拖拽路径等价的换装结果。

### 性能

35. **GIVEN** 热缓存命中且渲染器就绪，**WHEN** 应用一件服装，**THEN** 从收到装备意图到 `outfit_apply_result(..., true, ...)` 目标在同一帧或 `<16ms` 内完成。
36. **GIVEN** 连续应用 10 件服装，**WHEN** 每次等待前一次结果或使用 latest-token 覆盖，**THEN** UI 不闪烁、不回跳、不出现过期装备状态。
37. **GIVEN** 60fps 目标环境，**WHEN** 拖拽换装处理单次装备意图，**THEN** 本系统判定逻辑不超过 `0.5ms`，不包含纹理加载时间。

## Open Questions

| 问题 | 负责人 | 截止 | 决议 |
|------|--------|------|------|
| Web 端鼠标/触摸拖拽手感是否达到“跟手、宽容、不误触”的目标？ | 技术设计 / 原型验证 | `/prototype 拖拽换装` | 未决。systems-index 已标记该系统为技术风险，进入实现前应先做 Web 拖拽原型验证 |
| 角色热区的具体矩形来源是角色节点 bounds、手工配置 Rect2，还是 UX spec 中定义的可交互区域？ | UI/UX 设计师 / gameplay programmer | `/ux-design wardrobe-ui` 或实现故事前 | 未决。本 GDD 只定义判定规则和默认 padding |
| 成功微光、落点涟漪、不可用轻提示的具体视觉资产如何制作？ | 美术总监 / 技术美术 | `/asset-spec system:drag-dress-up` | 未决。当前只定义风格、时长和强度 |
| `outfit_apply_result` 等接口在代码中使用 signal、callable 回调还是事件总线？ | 架构设计 / gameplay programmer | ADR 或实现故事前 | 未决。GDD 固定语义，不固定实现机制 |
| 是否需要在衣橱 UI GDD 中把预留接口措辞更新为已确认正式契约？ | GDD 作者 | 已完成 | 已同步。衣橱 UI 已将 `item_drag_dropped`、`item_selected_for_equip`、`outfit_apply_result` 标为正式接口 |
