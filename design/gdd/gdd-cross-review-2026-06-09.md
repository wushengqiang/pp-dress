# GDD 横向审阅报告

> **Date**: 2026-06-09
> **Scope**: `design/gdd/*.md`
> **Depth**: Lean holistic pass
> **Reviewer**: Codex Game Studios

## Verdict

**CONCERNS**

15 个 MVP 系统的核心方向基本一致：日循环保持为 `MAIN_MENU -> WARDROBE -> DAILY_SCENE -> GOODNIGHT -> MAIN_MENU`；穿搭不评分、不失败、不惩罚；天数推进集中在 `GOODNIGHT -> MAIN_MENU`；服装解锁由 `ProgressManager.advance_day()` 产生，服装解锁系统只展示结果。当前没有发现会推翻核心设计的阻塞性矛盾。

但进入架构、故事拆分或 Pre-Production gate 前，仍需要先修正若干追踪状态、过期文本和跨系统接口登记问题，否则后续实现团队可能按旧状态或旧契约执行。

## Blocking Issues

无明确 Blocking 级设计冲突。

## Warnings

### W1. 文档状态与系统索引不一致

`systems-index.md` 已将多个系统标为 `Approved`，但对应 GDD 文件头仍显示 `Designed` 或 `In Design`。

已观察到的状态不一致包括：

| GDD | 文件内状态 | systems-index 状态 | 风险 |
|---|---|---|---|
| `design/gdd/wardrobe-database.md` | `In Design` | `Approved` | Foundation 数据系统状态不一致，可能阻塞实现 handoff 判断 |
| `design/gdd/progress-management.md` | `Designed` | `Approved` | 进度系统已通过 review log，但文件头未同步 |
| `design/gdd/daily-scene.md` | `Designed` | `Approved` | Feature 系统已被索引视为批准，但文件头未同步 |
| `design/gdd/light-narrative-dialogue.md` | `Designed` | `Approved` | 叙事 provider 状态未同步 |
| `design/gdd/save-load.md` | `Designed` | `Designed` | 仍未进入 Approved，后续 gate 需明确是否已审完 |
| `design/gdd/input-management.md` | `Designed` | `Designed` | 仍未进入 Approved |
| `design/gdd/sprite-layered-rendering.md` | `In Design` | `Designed` | 文件头与索引均未到 Approved |

**Recommendation**: 先统一文件头、review log 和 `systems-index.md` 的状态。若这些文档已经通过单项审阅，应把 GDD 文件头同步为 `Approved`；若尚未审阅，应在系统索引中保持 `Designed` 并列入下一步审阅队列。

### W2. `scene-state-management.md` 的跳过开关文本已过期

`scene-state-management.md` 的 Tuning Knobs 中仍写：

- `skip_resource_loader = true`
- `skip_input_manager = true`

但 `resource-loader.md` 已是 `Approved`，`input-management.md` 也已完成设计。资源加载器 GDD 还明确写到 `skip_resource_loader` 在系统设计后应设为 `false`。

**Risk**: 实现时若照旧使用跳过开关，会造成 GameState BOOT 不等待资源加载器或输入管理，WARDROBE 交互和纹理加载流程可能进入未就绪状态。

**Recommendation**: 将正式实现默认值同步为：

- `skip_resource_loader = false`
- `skip_input_manager = false`

并保留“仅原型阶段可临时跳过”的说明。

### W3. `scene_in_progress` 清除与保存顺序需要明确

`save-load.md` 说明 `GOODNIGHT -> MAIN_MENU` 时由 GameState 清除 `scene_in_progress = false`，而 `progress-management.md` 说明 `advance_day()` 内部调用 `SaveManager.save()`。

当前跨文档语义是合理的，但缺少明确顺序：

1. GameState 清除 `scene_in_progress = false`
2. GameState 调用 `ProgressManager.advance_day()`
3. `advance_day()` 更新 day / completed / unlock_progress 并保存

如果实现顺序反过来，可能出现 `advance_day()` 已保存新天数，但 `scene_in_progress` 仍为 `true` 的存档快照。刷新后 GameState 可能错误恢复到 DAILY_SCENE。

**Recommendation**: 在 `scene-state-management.md`、`save-load.md` 或 `progress-management.md` 中补一条顺序约束：`GOODNIGHT -> MAIN_MENU` 转换中，GameState 必须先清除会话恢复标记，再调用 `ProgressManager.advance_day()`；最终保存必须包含清除后的 `scene_in_progress=false`。

### W4. 每日场景新增音频事件未完全登记到音频管理

`daily-scene.md` 新增事件需求：

- `scene.daily.entered`
- `scene.music.daily_generic`
- `scene.music.day_{n}`

`audio-management.md` 当前事件目录只明确包含 `scene.transition_page`，并未登记上述每日场景进入与音乐事件。

`daily-scene.md` 已写明未登记时应作为 warning 降级，但实现交付前这些 key 必须映射。

**Recommendation**: 在 `audio-management.md` 的 MVP event key 表补齐每日场景事件，或明确这些 key 由 `/asset-spec system:audio-management` 在实现前登记，且实现故事不得在映射缺失时把 warning 视为通过。

### W5. `game-concept.md` 仍保留早期压力感措辞

`game-concept.md` 仍是 `Draft`，并包含若干与后续 GDD 语气不完全一致的早期表达：

- “完成每日剧情获得新衣服”
- “遇到一次关键日场景需要认真搭配”
- “完成 5-7 天的剧情”

后续 GDD 已将这些概念修正为：晚安后自然推进、解锁是轻量提示、无任务结算、无正确搭配、无评分压力。

**Recommendation**: 更新 game concept，使其成为当前 GDD 体系的上位来源，而不是旧脑暴文本。特别建议删除“关键日需要认真搭配”或改为“Day 7 温柔收束，不评价穿搭”。

### W6. 实体注册表为空

`design/registry/entities.yaml` 当前为空：

- `entities: []`
- `items: []`
- `formulas: []`
- `constants: []`

本轮横向审阅只能依赖全文阅读与 grep 结果，无法通过 registry 校验 item id、公式名、事件 key、常量等跨文档一致性。

**Recommendation**: 在进入架构前至少登记以下内容：

- 系统级核心事件 key：`progress.items_unlocked`、`wardrobe.outfit_applied`、`scene.transition_page` 等
- 核心常量：`TOTAL_DAYS = 7`
- MVP 类目：`top`, `bottom`, `shoes`, `accessory`, `hair`, `makeup`
- 核心公式：`new_items(day)`、`visible_categories(day)`、`is_day_available(day)`

## Cross-System Scenario Walkthrough

### Scenario A: 新玩家第 1 天开始

**Flow**: BOOT -> MAIN_MENU -> WARDROBE

Expected:

- SaveManager 默认 `current_day = 1`
- ProgressManager 初始化 `unlock_day == 1` 物品缓存
- Wardrobe UI 显示 6 个类目标签，其中 `top/bottom/shoes` enabled，`accessory/hair/makeup` 灰色禁用
- 未可见类目仍出现，点击只触发轻量不可用反馈

**Result**: 一致。衣橱 UI、进度管理、服装解锁对灰色未可见类目的要求已对齐。

### Scenario B: 衣橱换装并确认

**Flow**: WARDROBE -> DAILY_SCENE

Expected:

- 衣橱 UI 只输出 `item_drag_dropped` 或 `item_selected_for_equip`
- 拖拽换装等待 SpriteLayeredRenderer `outfit_changed`
- 成功后回写 `outfit_apply_result`
- 衣橱 UI 使用确认后的 `equipped_items`
- GameState context 携带 `equipped_items` 到 Daily Scene

**Result**: 一致。UI 不提前假定装备成功，拖拽换装不直接写存档或进度，精灵分层渲染只负责纹理与层级。

### Scenario C: 每日场景完成

**Flow**: DAILY_SCENE -> GOODNIGHT

Expected:

- Daily Scene 等角色视觉就绪后启动 Dialogue UI
- Dialogue UI 发出 `dialogue_sequence_finished(day)`
- Daily Scene 请求 `DAILY_SCENE -> GOODNIGHT`
- Dialogue UI、Light Narrative、Daily Scene 都不调用 `advance_day()`

**Result**: 一致。

### Scenario D: 晚安后推进与解锁

**Flow**: GOODNIGHT -> MAIN_MENU

Expected:

- GameState 是 `ProgressManager.advance_day()` 的唯一常规调用方
- ProgressManager 计算 `new_items`
- 发射 `items_unlocked(new_items)`
- Clothing Unlock 只展示有效新物品，不计算解锁、不写进度
- AudioManager 播放 `progress.items_unlocked` 对应的柔和提示音

**Result**: 基本一致。需补强 `scene_in_progress` 保存顺序，避免恢复标记残留。

### Scenario E: 第 7 天完成

**Flow**: GOODNIGHT(day 7) -> MAIN_MENU completed mode

Expected:

- `current_day` 保持 7
- `highest_day_completed = 7`
- 不创建第 8 天
- 不发射 `items_unlocked`
- Clothing Unlock 不显示第 8 天提示
- Main Menu 进入 completed mode

**Result**: 一致。

## Game Design Holism

### Pillar Fit

| Pillar | Result | Notes |
|---|---|---|
| 每日陪伴 | Pass | 主菜单、每日场景、对话、晚安和解锁语气整体温柔克制 |
| 随心搭配 | Pass | 多系统明确禁止评分、正确搭配、失败惩罚 |
| 即时有感 | Pass with tech risk | 拖拽、精灵渲染、资源加载、音频反馈都有明确预算和反馈边界；Godot Web 线程/内存风险仍需 prototype 验证 |

### Scope Fit

当前 MVP 范围仍然集中于 1 角色、6 类目、约 30 件服装、7 天线性循环。未发现新增经济、货币、评分、社交或复杂分支叙事导致的范围膨胀。

## GDDs Flagged For Revision

| GDD | Revision Type | Priority |
|---|---|---|
| `design/gdd/systems-index.md` | 同步状态、移除 stale next step | High |
| `design/gdd/scene-state-management.md` | 更新 skip flags；明确 `scene_in_progress` 清除顺序 | High |
| `design/gdd/save-load.md` | 明确 GOODNIGHT 保存顺序 | High |
| `design/gdd/progress-management.md` | 同步文件头状态；可补保存顺序注释 | Medium |
| `design/gdd/audio-management.md` | 补齐每日场景音频事件 key | Medium |
| `design/gdd/game-concept.md` | 更新早期压力感措辞与 Draft 状态 | Medium |
| `design/registry/entities.yaml` | 登记核心事件、常量、类目、公式 | Medium |
| `design/gdd/wardrobe-database.md` | 同步文件头状态 | Medium |
| `design/gdd/daily-scene.md` | 同步文件头状态 | Medium |
| `design/gdd/light-narrative-dialogue.md` | 同步文件头状态 | Medium |

## Recommended Next Steps

1. 同步 GDD 文件头与 `systems-index.md` 状态。
2. 修订 `scene-state-management.md` 的正式 skip flags 与 `GOODNIGHT -> MAIN_MENU` 保存顺序。
3. 在 `audio-management.md` 登记每日场景音频事件。
4. 更新 `game-concept.md` 中早期任务/关键日措辞。
5. 填充 `design/registry/entities.yaml` 的最小跨文档注册项。
6. 对仍未 Approved 的 Foundation 文档运行单项 `design-review`，再执行 `gate-check pre-production`。

## Resolution Update

> **Date**: 2026-06-09
> **Status**: Main recommendations applied

已执行本报告中的主要修订建议：

- 同步 `wardrobe-database.md`、`progress-management.md`、`daily-scene.md`、`light-narrative-dialogue.md` 文件头状态为 `Approved`。
- 更新 `systems-index.md` 的 stale next steps，并修正精灵分层渲染为 6 层。
- 更新 `scene-state-management.md`：正式实现中 `skip_resource_loader=false`、`skip_input_manager=false`，并明确 `GOODNIGHT -> MAIN_MENU` 中先清除 `scene_in_progress` 再调用 `ProgressManager.advance_day()`。
- 更新 `save-load.md` 与 `progress-management.md`，补充 `scene_in_progress=false` 的保存顺序约束。
- 更新 `audio-management.md`，登记 `scene.daily.entered`、`scene.music.daily_generic`、`scene.music.day_{n}` 及对应资产需求。
- 更新 `game-concept.md`，移除早期“完成每日剧情获得新衣服”“关键日需要认真搭配”“穿搭任务”等压力感措辞。
- 填充 `design/registry/entities.yaml` 的最小跨文档注册项，包括 `TOTAL_DAYS`、MVP 类目、关键公式与核心音频事件 key。

剩余待办：`sprite-layered-rendering.md`、`save-load.md`、`input-management.md` 仍未 Approved，应继续运行单项 `design-review`。
