# 输入管理 (Input Management)

> **Status**: Designed
> **Author**: user + Claude Code Game Studios
> **Last Updated**: 2026-06-11
> **Implements Pillar**: 即时有感

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

输入管理是「每日穿搭」Foundation 层的输入归一化系统，作为 Godot Autoload 单例（`InputManager`）运行。Web 平台上存在两类主要输入源：桌面端鼠标事件（`InputEventMouseButton` / `InputEventMouseMotion`）和移动端触摸事件（`InputEventScreenTouch` / `InputEventScreenDrag`）。InputManager 将这些事件归一化为玩家可理解的交互语义：**点击**（click/tap）、**拖拽**（drag）和桌面端 **悬停**（hover）。

本系统不再全局接管所有 GUI 输入。标准 Button、ScrollContainer、对话选项等普通控件继续使用 Godot 原生 `Control.gui_input()` / `pressed` / `ScrollContainer` 路径。InputManager 只在上层 UI 显式声明某个输入起点属于“游戏手势区域”后进入手势跟踪；例如衣橱 UI 对已解锁服装卡片注册拖拽热区，InputManager 才会把该按下/触摸流识别为服装拖拽候选。这样避免同一次点击同时触发 Godot Button 与 InputManager `clicked`，也避免列表滚动和拖拽互相抢同一条触摸流。

Web 端浏览器默认行为（页面滚动、文本选择、上下文菜单、手势缩放）由两层共同处理：InputManager 在 Godot 内部对已接管的 active drag 调用 `get_viewport().set_input_as_handled()`，Web shell / HTML / CSS / 导出模板负责验证并配置 canvas 内的 DOM 默认行为抑制。`set_input_as_handled()` 只被视为 Godot 事件传播控制，不单独承诺能阻止浏览器 DOM 默认行为。

## Player Fantasy

输入管理没有独立的玩家幻想——玩家不会夸“输入抽象层写得真好”。但它直接支撑「即时有感」：

- **“拖拽跟手”**：玩家拿起一件衣服后，服装预览在下一帧内跟随手指或光标移动。阈值前的短暂移动是“判断玩家意图”的阶段；一旦拖拽成立，视觉反馈必须稳定、连续、不跳位。
- **“手机和电脑是一样的游戏”**：鼠标与触摸使用同一套上层信号和数据结构，但可以有不同阈值与仲裁规则，以适配手指抖动、列表滚动和桌面 hover。
- **“不会拖到一半页面跟着滚”**：在 canvas 内拿起衣服后，游戏应锁定该输入流；页面滚动、文本选择、手势缩放不得劫持这次拖拽。该承诺必须通过 Web 导出集成测试验证。
- **“慢一点也不会被惩罚”**：MVP 不使用长按业务动作，慢速点击不应被隐藏语义吞掉。玩家犹豫半秒再松手，仍应得到清楚的点击或无操作反馈，而不是“点了没反应”。

简言之：本系统的目标不是制造情绪，而是移除交互摩擦。玩家应感觉衣服真的被自己拿起、移动、放下；浏览器、GUI 控件和输入设备差异都不该进入玩家意识。

## Detailed Design

### Core Rules

**架构**：`InputManager` 是 Godot Autoload 单例（`input_manager.gd`，注册名 `InputManager`），负责跟踪由上层 UI 显式交给它的输入流，并发射归一化信号。它不持有服装数据、不判断 `item_id`、不操作角色节点、不执行装备逻辑。

**输入所有权**：

Godot 输入传播顺序中 `_input()` 早于 GUI `_gui_input()`。因此 InputManager 不应在 `_input()` 中对所有 press/click 做全局语义解释。MVP 采用“注册热区 + 接管令牌”模型：

1. 衣橱 UI、其他需要游戏手势的 UI 在布局完成后向 InputManager 注册手势热区。
2. 按下/触摸开始时，InputManager 只检查已注册热区；若命中可接管热区，进入 `POTENTIAL_DRAG` 或 `POTENTIAL_CLICK`。
3. 若未命中任何热区，InputManager 不发 `clicked` / `drag_*` 信号，事件完全留给 Godot GUI。
4. 标准 Button、ScrollContainer、对话选项不注册 InputManager 点击语义，避免与原生 `pressed` 双触发。
5. 若某个 Control 在自身 `gui_input()` 中 `accept_event()` 并声明本次输入已被 UI 消费，InputManager 不应再为该输入流发全局 click。

**Autoload 注册顺序**：

InputManager 不依赖其他 Autoload，但 Godot Project Settings 中的注册顺序必须遵循全项目唯一 Autoload 链：`WardrobeDatabase -> GameState -> SaveManager -> TextureCache -> InputManager -> ProgressManager`。该顺序不同于 GameState 编排的 BOOT 业务初始化顺序；BOOT 仍按 `WardrobeDatabase -> SaveManager -> ProgressManager -> TextureCache -> InputManager` 做就绪检查，以便场景/状态管理确认 `InputManager.is_ready` 后再进入可交互衣橱。

**手势分类规则**：

```
INPUT START
    |
    +-- 命中可拖拽热区 -> POTENTIAL_DRAG
    |       |
    |       +-- 主要方向为列表滚动方向 -> RELEASE_TO_SCROLL
    |       +-- 移动距离 > source_threshold 且方向通过拖拽仲裁 -> DRAGGING
    |       +-- 抬起且距离 <= source_threshold -> CLICK
    |
    +-- 命中点击热区但非拖拽热区 -> POTENTIAL_CLICK
    |       |
    |       +-- 抬起且距离 <= source_threshold -> CLICK
    |       +-- 移动超过阈值 -> CANCEL_CLICK
    |
    +-- 未命中 InputManager 热区 -> IGNORE，交给 Godot GUI
```

**移动端滚动 vs 拖拽仲裁**：

- 衣橱列表中，卡片主体可点击；拖拽只能从卡片缩略图或显式拖拽热区开始。
- 触摸输入使用较大的默认拖拽阈值（`touch_drag_threshold = 12.0` 设计分辨率 px），鼠标使用 `mouse_drag_threshold = 5.0`。
- 在 ScrollContainer 内，触摸起点若位于可滚动列表区域，且前两次有效移动的主方向为列表滚动方向，则本输入流释放给 ScrollContainer，InputManager 不进入 DRAGGING。
- 若起点位于服装拖拽热区，且移动方向离开列表滚动轴或超过拖拽阈值后仍命中拖拽意图，则 InputManager 接管该输入流，后续移动/抬起标记为 Godot handled。
- 被释放给 ScrollContainer 的输入流不得在中途重新变成服装拖拽；玩家需要重新按下才能开始拖拽。

**API 接口**：

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `is_dragging()` | — | bool | 当前是否有 active drag |
| `is_hovering()` | — | bool | 鼠标当前是否位于游戏 viewport 内；触摸输入不改变该状态 |
| `get_current_drag()` | — | Dictionary 或 null | 返回当前拖拽数据的顶层副本，无拖拽时返回 null |
| `set_mouse_drag_threshold(px)` | float | void | 修改鼠标拖拽阈值；输入 clamp 到安全范围 |
| `set_touch_drag_threshold(px)` | float | void | 修改触摸拖拽阈值；输入 clamp 到安全范围 |
| `set_click_timeout(seconds)` | float | void | 修改点击判定超时，单位为秒；输入 clamp 到安全范围 |
| `register_gesture_region(id, rect, options)` | StringName, Rect2, Dictionary | void | 注册可由 InputManager 接管的 UI 热区 |
| `unregister_gesture_region(id)` | StringName | void | 移除热区 |
| `clear_gesture_regions(owner_id)` | StringName | void | 场景/列表重建时清理某个 UI owner 的热区 |
| `cancel_active_gesture(reason)` | String | void | 场景切换、窗口失焦、布局重排时强制取消当前手势 |

**RegionOptions Schema**：

`register_gesture_region(id, rect, options)` 的 `options` 必须只使用下列字段。未知字段在 debug 构建中记录警告并忽略；缺失字段使用默认值；类型错误按默认值处理并记录警告。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `owner_id` | StringName | required | 注册该热区的 UI owner；用于 `clear_gesture_regions(owner_id)` 和事件回传 |
| `gesture_kind` | String | `"drag_click"` | 允许值：`"drag_click"`、`"click_only"`、`"hover_only"`、`"exclude"`、`"scroll_priority"` |
| `enabled` | bool | `true` | 为 `false` 时热区保留但不参与命中 |
| `z_index` | int | `0` | 多个热区重叠时选择最高 `z_index`；相同 `z_index` 时选择最后注册者 |
| `drag_axis` | String | `"any"` | 允许值：`"any"`、`"horizontal"`、`"vertical"`；限制拖拽方向仲裁 |
| `scroll_axis` | String | `"none"` | 允许值：`"none"`、`"horizontal"`、`"vertical"`；仅 `scroll_priority` 或含滚动仲裁的热区使用 |
| `allow_click` | bool | `true` | 是否允许在阈值内 release 时发射 `clicked` |
| `allow_drag` | bool | `true` | 是否允许超过阈值并通过方向仲裁后进入 `DRAGGING` |
| `allow_hover` | bool | `false` | 是否允许鼠标悬停触发 `hovered` / `unhovered` |

派生规则：
- `gesture_kind == "click_only"` 等价于 `allow_click=true, allow_drag=false`。
- `gesture_kind == "hover_only"` 等价于 `allow_hover=true, allow_click=false, allow_drag=false`。
- `gesture_kind == "exclude"` 表示该区域交给 Godot GUI；InputManager 不发信号、不调用 `mark_input_handled()`。
- `gesture_kind == "scroll_priority"` 表示早期移动先按 `scroll_axis` 和 `scroll_axis_lock_ratio` 仲裁；判定为滚动后释放给 ScrollContainer，同一输入流不得重新升级为拖拽。
- 服装卡片默认使用 `gesture_kind="drag_click"`，并由衣橱 UI 维护 `region_id -> item_id` 映射；InputManager 不在 options 或事件中携带 `item_id`。

**属性**：

| 属性 | 类型 | 说明 |
|------|------|------|
| `is_ready` | bool | `_ready()` 完成后设为 true |
| `mouse_drag_threshold` | float | 鼠标拖拽阈值，默认 5.0 设计分辨率 px |
| `touch_drag_threshold` | float | 触摸拖拽阈值，默认 12.0 设计分辨率 px |
| `click_timeout` | float | 点击判定超时，默认 0.5 秒 |
| `current_drag` | Dictionary | 当前拖拽状态，内部私有 |
| `active_source_key` | String | 当前输入源唯一键，如 `"mouse:0"`、`"touch:2"` |

**信号**：

| 信号 | 参数 | 说明 |
|------|------|------|
| `drag_started` | Dictionary | 拖拽判定成立时发射 |
| `drag_updated` | Dictionary | 拖拽进行中，每次被接管的移动事件时发射 |
| `drag_ended` | Dictionary | 拖拽正常结束或中断结束 |
| `clicked` | Dictionary | 已注册点击/拖拽热区上的点击成立时发射 |
| `hovered` | Dictionary | 鼠标悬停在注册 hover 热区或 viewport 内时发射 |
| `unhovered` | Dictionary | 鼠标离开 hover 热区、viewport、窗口失焦时发射 |

MVP 不发射 `long_pressed`。长按作为未来扩展保留在设计备注中，但不属于 MVP 输入语义，避免慢速点击被未使用的业务信号吞掉。若未来启用长按，必须使用独立 `long_press_timeout`，且在 timeout 到达时发射带反馈的 `long_press_started`，不能复用 `click_timeout`。

**DragData / ClickData Schema**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `position` | Vector2 | 当前输入位置，使用 root viewport 坐标 |
| `start_position` | Vector2 | 按下/触摸开始位置，使用 root viewport 坐标 |
| `offset` | Vector2 | `position - start_position` |
| `total_distance` | float | 从输入开始到结束的弦长累加，包含阈值前路径 |
| `duration` | float | 手势持续时间，单位秒 |
| `source_type` | String | `"mouse"` 或 `"touch"` |
| `source_index` | int | 触摸使用 Godot `index`；鼠标固定 0 |
| `source_key` | String | 输入源唯一键，格式为 `"source_type:source_index"` |
| `region_id` | StringName | 命中的注册热区 ID |
| `owner_id` | StringName | 注册该热区的 UI owner |
| `interrupted` | bool | 仅 `drag_ended` 含此字段；正常结束为 `false` |
| `cancel_reason` | String | 仅中断时填写，如 `"mouse_exit_timeout"`、`"touch_canceled"`、`"window_blur"`、`"layout_changed"` |

InputManager 不在信号数据中携带 `item_id`、Control、Node、Resource 或服装卡片引用。衣橱 UI 收到 `region_id` 后，用自己的映射表解析服装身份；如果布局已重建且 region 不再有效，衣橱 UI 必须取消该输入，不得猜测物品。

### Input Event Processing

系统处理以下事件路径：

**1. 鼠标按下 / 触摸开始**

- 生成 `source_key = "%s:%d" % [source_type, source_index]`。
- 若已有 active source，新的按下只记录为 ignored source，不改变当前手势。
- 将事件位置转换为 root viewport 坐标。
- 查询注册热区，若无命中则保持 IDLE，不发 InputManager 信号。
- 若命中标准 GUI 排除区或 ScrollContainer 滚动优先区，则保持 IDLE 或进入 `RELEASE_TO_SCROLL`，不发 InputManager 信号。
- 若命中可接管热区，记录 `start_position`、`last_position`、`start_time_seconds`、`source_key`、`region_id`、`owner_id`，进入 POTENTIAL。

**2. 鼠标移动 / 触摸移动**

- 只有 active source 的移动事件会被处理；ignored source 的移动被忽略。
- POTENTIAL 状态下先执行滚动/拖拽仲裁。
- 若仲裁释放给 ScrollContainer，InputManager 清除该 source 的候选状态，不发 `clicked` / `drag_*`。
- 若移动距离严格大于对应输入源阈值且仲裁通过，进入 DRAGGING。
- `drag_started.position` 等于首次超过阈值的当前事件位置；`start_position` 保持按下位置。二者不相等是正常且必须的。
- 进入 DRAGGING 的当前事件发射 `drag_started`，随后同一事件或下一次移动发射 `drag_updated`。实现可在同一事件中先发 `drag_started` 再发一次 `drag_updated`，但顺序必须固定。
- DRAGGING 状态下，首次进入 DRAGGING 的事件、后续移动事件以及最终 release 事件都调用 `mark_input_handled()` 包装方法，该方法内部调用 `get_viewport().set_input_as_handled()`，便于测试 spy。
- 鼠标无按键移动只更新 hover，不参与触摸逻辑。

**3. 鼠标抬起 / 触摸结束**

- 只有 active source 的 release 会结束当前手势；ignored source 的 release 不改变当前状态。
- DRAGGING 状态发射一次 `drag_ended(interrupted=false)`，随后清空 active source。
- POTENTIAL 状态若距离小于等于对应阈值且耗时小于等于 `click_timeout`，发射一次 `clicked`。
- POTENTIAL 状态若距离小于等于阈值但耗时超过 `click_timeout`，MVP 不发长按信号；清除状态并可由 UI 根据需要显示“未操作”反馈。
- POTENTIAL 状态若移动超过阈值但已释放给滚动或被取消，不发 `clicked`。

**4. touch canceled / 窗口失焦 / 页面隐藏 / 场景切换**

- `InputEventScreenTouch.canceled == true`、窗口 blur、页面隐藏、场景离开、衣橱布局重建时，若存在 active gesture，调用 `cancel_active_gesture(reason)`。
- 若已进入 DRAGGING，发射 `drag_ended(interrupted=true, cancel_reason=reason)`。
- 若仍在 POTENTIAL，直接清除状态，不发 click 或 drag。
- 取消后所有 ignored source 记录一并清空。

**5. 鼠标离开 viewport / canvas 边界**

- 鼠标离开 viewport 或 Web shell 上报 canvas leave 时，发射 `unhovered` 并清除 hover。
- 若 DRAGGING 中收到明确 mouse exit，进入 `DRAG_EXIT_PENDING` 并记录 `_drag_exit_time_seconds`。
- 在 `DRAG_EXIT_GRACE_SECONDS` 内回到 viewport，则恢复 DRAGGING，不发 `drag_ended`。
- 在 grace 内收到左键 release，则正常 `drag_ended(interrupted=false)`。
- 超过 grace 仍未回到 viewport 或收到 release，则 `drag_ended(interrupted=true, cancel_reason="mouse_exit_timeout")`。
- 如果没有可靠 leave 信号，仅凭没有 mouse motion 不得启动中断。

### Interaction with Godot's GUI System

InputManager 与 Godot GUI 是分工关系，不是替代关系：

- **标准 GUI 优先**：Button、ScrollContainer、OptionButton、对话按钮、主菜单按钮使用 Godot 原生信号，不注册 InputManager click。
- **游戏手势显式注册**：只有服装卡片拖拽热区、角色放置区、未来滑动式组件等需要跨节点手势的区域注册到 InputManager。
- **避免双触发**：同一 UI 元素不得同时用 Godot Button `pressed` 和 InputManager `clicked` 执行同一业务动作。
- **消费包装**：InputManager 使用 `mark_input_handled()` 包装 Godot handled 调用，便于单元测试统计调用。该包装只表示 Godot 内部事件传播处理，不表示 DOM 默认行为已阻止。
- **Control.accept_event() 边界**：Control 在 `_gui_input()` 中消费的事件不应再触发全局 InputManager click。实现上由注册热区所有权和 UI 消费标记约束，而不是靠 InputManager 猜测所有 Control 状态。
- **ScrollContainer 边界**：滚动列表区域必须显式声明滚动轴和拖拽热区。纵向滚动优先时，InputManager 释放输入流给 ScrollContainer；拖拽热区优先时，InputManager 接管输入流。

### Browser Scroll Prevention

Web 导出环境的默认行为控制分三层：

1. **Godot 层**：InputManager 对 active drag 的移动/抬起调用 `mark_input_handled()`，阻止 Godot 内部后续未处理输入路径误响应。
2. **Web shell 层**：项目 Web 模板必须为 game canvas 设置可验证的默认行为策略，例如合适的 `touch-action`、禁止 canvas 内文本选择、按需处理 context menu。具体实现由 Web 导出模板或包装页面负责。
3. **验收层**：Web 集成测试必须在目标浏览器中验证 canvas 内拖拽服装不会触发页面滚动、文本选择、浏览器 pinch zoom 或右键菜单。若某浏览器无法满足，应记录为平台限制并在发布范围中排除或降级。

页面级滚动在 canvas 外不受 InputManager 影响。canvas 内列表滚动由 Godot ScrollContainer 负责，不依赖浏览器原生页面滚动。

### Internal State Machine（不对外暴露）

```
IDLE
  |-- registered region press/touch --> POTENTIAL
  |       |-- scroll-axis intent --> RELEASE_TO_SCROLL --> IDLE
  |       |-- move > source_threshold and drag intent --> DRAGGING
  |       |-- release within threshold and duration <= click_timeout --> IDLE (emit clicked)
  |       |-- release after click_timeout --> IDLE (no MVP long_press signal)
  |       |-- cancel/blur/layout change --> IDLE (no signal)
  |
  |-- unregistered GUI input --> IDLE (ignore)
  |-- mouse hover movement --> IDLE (emit hovered)

DRAGGING
  |-- move by active source --> DRAGGING (emit drag_updated)
  |-- normal release --> IDLE (emit drag_ended, interrupted:false)
  |-- touch canceled / blur / layout change --> IDLE (emit drag_ended, interrupted:true)
  |-- mouse exit --> DRAG_EXIT_PENDING

DRAG_EXIT_PENDING
  |-- return within grace --> DRAGGING
  |-- release within grace --> IDLE (emit drag_ended, interrupted:false)
  |-- grace timeout --> IDLE (emit drag_ended, interrupted:true)
```

## Formulas

输入管理系统包含判定算法、坐标规则和性能预算。

### 手势判定算法

**距离计算**：

```
distance = sqrt(
    (current_position.x - start_position.x)^2 +
    (current_position.y - start_position.y)^2
)
```

**拖拽判定**：

```
threshold = mouse_drag_threshold if source_type == "mouse" else touch_drag_threshold
is_drag = (distance > threshold) AND drag_intent_passed
```

- 鼠标默认阈值：5.0 设计分辨率 px；安全范围：2.0 - 20.0。
- 触摸默认阈值：12.0 设计分辨率 px；安全范围：8.0 - 28.0。
- 阈值单位是 Godot root viewport 坐标中的设计分辨率像素，不是物理设备像素。
- 恰好等于阈值时不判定为拖拽，继续保持 POTENTIAL。

**点击判定**：

```
elapsed_seconds = current_time_seconds - press_time_seconds
is_click = (distance <= threshold) AND (elapsed_seconds <= click_timeout)
```

- `click_timeout` 默认值：0.5 秒。
- 安全范围：0.15 - 0.75 秒。
- `set_click_timeout(seconds)` 的参数单位是秒；传入值 clamp 到安全范围。

**长按**：

MVP 不实现 `long_pressed` 信号。未来如需长按，应新增独立参数 `long_press_timeout`，默认不得低于 0.6 秒，并在 timeout 到达时提供视觉/音频反馈；不得复用 `click_timeout`。

### 拖拽路径总长度

`drag_ended.total_distance` 使用弦长累加，从按下/触摸开始的第一段位移开始累计，包含阈值前路径：

```
total_distance = Σ sqrt(
    (p[i].x - p[i-1].x)^2 +
    (p[i].y - p[i-1].y)^2
)
```

若按下 `(0,0)` 后首次移动到 `(6,0)` 即触发拖拽，并立即抬起，则 `total_distance` 至少为 6.0，而不是 0。

中断拖拽只统计最后一次已收到事件的位置。玩家离开 canvas 后发生但 Godot 未收到的不可见位移不计入 `total_distance`；因此该字段表示“InputManager 已观测路径长度”，不是物理真实路径长度。

### 坐标系统

InputManager 所有输出坐标使用 **root viewport 坐标**。实现规则：

- 鼠标事件优先使用 `InputEventMouse.global_position`；若不可用，则将当前 viewport `position` 转换到 root viewport。
- 触摸事件使用 `InputEventScreenTouch.position` / `InputEventScreenDrag.position`，并按事件所在 viewport 转换到 root viewport。
- Autoload 作为普通 `Node` 不假设可直接调用 `get_global_mouse_position()`。
- 调用方负责把 root viewport 坐标转换到自己的 Control、CanvasLayer 或 SubViewport 局部坐标。
- 若 UI 使用 SubViewport、SubViewportContainer 或多 CanvasLayer，注册热区时必须提交已转换到 root viewport 的 Rect2。
- `ProjectSettings.display/window/stretch/mode = canvas_items` 下的坐标映射必须通过 Godot Web 原型验证，不能只靠文档假设。

### 事件处理性能预算

| 操作 | 预算 | 依据 |
|------|------|------|
| InputManager 单次事件处理 p95 | < 0.5ms | Godot 4.6 release export，固定测试场景，预热后采样 1000 次 |
| InputManager 每帧聚合处理 p95 | < 1.5ms | 高频输入可能一帧多事件，输入层自身不得吞掉帧预算 |
| `drag_started` 到衣橱拖拽预览首帧显示 | <= 16.6ms | 支撑「即时有感」 |
| `mark_input_handled()` 包装调用 | 可 spy | 单元测试断言调用次数，集成测试断言 GUI 不误触发 |

InputManager 自身不得执行节点树搜索、资源加载、文件 I/O 或服装数据查询。高频 `drag_updated` 可以一帧多次发射；衣橱 UI 若有渲染成本，应在自身系统内节流或只在 `_process()` 读取最新 `current_drag`。

## Edge Cases

### EC-1: 同时存在鼠标和触摸输入

**场景**：Surface、触屏笔记本等设备同时支持触摸与鼠标。

**行为**：

- 输入源唯一身份使用 `(source_type, source_index)`，序列化为 `source_key`。
- 鼠标 `source_key = "mouse:0"`；触摸使用 Godot touch index，如 `"touch:2"`。
- 同一时间只有一个 active source。已有 active source 时，新 source 的 press/touch start 被标记为 ignored source。
- ignored source 的 move/release 不发信号、不结束当前手势。
- active source 正常结束或取消后，新的输入必须重新按下才能开始；MVP 不做自动 promotion。

### EC-2: 拖拽时离开游戏画布

**场景**：玩家拖拽衣服到 canvas 边缘，鼠标继续向外移动。

**行为**：

- 鼠标离开 viewport/canvas 的检测来源必须在实现前确定：Godot Window/Viewport 信号、边界位置检测、或 Web shell 上报 canvas leave。
- 收到明确 leave 后才启动 grace 计时；没有明确 leave 时不得仅凭无 motion 取消拖拽。
- 在 `DRAG_EXIT_GRACE_SECONDS` 内回到 canvas，拖拽继续。
- 在 grace 内收到左键 release，正常结束拖拽，`interrupted=false`。
- 超过 grace 未回到 canvas 且未收到 release，强制结束，`interrupted=true`，`cancel_reason="mouse_exit_timeout"`。
- 衣橱 UI 收到 interrupted drag 后应清理拖拽预览并播放取消/回弹反馈，不输出装备事件。

### EC-3: 浏览器滚动/缩放与拖拽冲突

**场景**：Web 移动端玩家在衣橱列表上滑动，可能是在滚动列表，也可能想拿起衣服。

**行为**：

- 列表滚动和服装拖拽必须通过注册热区、滚动轴和方向锁仲裁。
- 起点在列表空白或非拖拽热区时，InputManager 不接管，滚动交给 ScrollContainer。
- 起点在服装拖拽热区时，若早期移动明显沿列表滚动轴，InputManager 释放给 ScrollContainer。
- 一旦 InputManager 进入 DRAGGING，同一输入流被游戏接管，Godot 层调用 `mark_input_handled()`，Web shell 层必须保证 canvas 内不会触发页面滚动、文本选择或 pinch zoom。
- canvas 外页面滚动不受影响。

### EC-4: 多点触摸

**场景**：移动端玩家两根手指同时触摸屏幕。

**行为**：

- MVP 只支持单 active touch。
- 第一根触摸点成为 active source；第二根触摸点标记为 ignored source。
- ignored source 不会 promotion。第一根触摸结束后，如果第二根仍按住，InputManager 保持 IDLE，直到玩家重新抬起并按下。
- 第二根触摸的 move/release 不发信号、不改变 active source。
- `InputEventScreenTouch.canceled == true` 若发生在 active source 上，取消当前手势；若发生在 ignored source 上，仅清理 ignored 记录。

### EC-5: 快速连续点击（含双击）

**场景**：玩家快速点击同一位置多次。

**行为**：

- 每次完整的按下/抬起周期在注册点击热区内成立时，发射一次 `clicked`。
- InputManager 不合并、不延迟、不发 double-click 语义。
- Godot `InputEventScreenTouch.double_tap` 字段在 MVP 中显式忽略。
- 若某个 UI 需要防抖或双击，属于该 UI 自己的业务逻辑。

### EC-6: 右键和中键

**场景**：桌面玩家按下鼠标右键或中键。

**行为**：

- InputManager 只响应左键 press/move/release。
- 右键/中键 press、move、release 均不发手势信号、不改变 active drag、不调用 `mark_input_handled()`。
- 右键菜单的 DOM 阻止由 Web shell 或导出模板负责，并需 Web 集成测试覆盖。

### EC-7: 拖拽阈值恰好等于位移

**场景**：位移恰好等于当前 source threshold。

**行为**：

- 拖拽使用严格大于：`distance > threshold`。
- 等于阈值时仍保持 POTENTIAL。
- 若此时抬起且耗时在 click timeout 内，判定为点击。
- 该规则有意偏向点击，避免把轻点误判成拖拽。

### EC-8: 游戏中浏览器视口尺寸变化

**场景**：拖拽中旋转手机或调整窗口。

**行为**：

- 视口 resize 或衣橱布局重建会使已注册热区和 drop 目标失效。
- 若 resize 发生在 POTENTIAL 状态，取消候选输入，不发 click/drag。
- 若 resize 发生在 DRAGGING 状态，InputManager 发 `drag_ended(interrupted=true, cancel_reason="layout_changed")`。
- 衣橱 UI 清理拖拽预览，等待玩家重新操作。
- 不承诺拖拽在布局重排中继续保持同一落点。

### EC-9: Web 导出环境中输入事件未到达

**场景**：浏览器策略、扩展、iframe 或系统手势阻止 Godot 接收输入。

**行为**：

- 无输入事件时 InputManager 保持 IDLE。
- `is_dragging()` 返回 false，`get_current_drag()` 返回 null。
- 若输入流中途丢失且无 cancel/leave/blur 信号，系统无法主动恢复；Web 集成测试必须覆盖目标嵌入方式。

### EC-10: 非常高频率的输入事件

**场景**：高 DPI 鼠标或高刷新触摸屏一帧产生多次移动事件。

**行为**：

- InputManager 单事件处理保持 O(1)。
- `drag_updated` 可以高频发射；接收方应避免重资源操作。
- 性能测试区分 InputManager 自身耗时与订阅者耗时。
- 若 Web 移动端实测信号风暴导致掉帧，衣橱 UI 应改为每帧读取最新拖拽状态，而不是响应每个 `drag_updated` 做完整渲染。

## Dependencies

### 本系统依赖（上游）

输入管理是 Foundation 层系统，不依赖其他游戏系统。

| 依赖 | 类型 | 说明 |
|------|------|------|
| Godot `InputEvent` 类层次 | 引擎内置 | `InputEventMouseButton`、`InputEventMouseMotion`、`InputEventScreenTouch`、`InputEventScreenDrag` |
| Godot `_input()` / `_unhandled_input()` / GUI 输入传播 | 引擎内置 | 实现必须尊重 `_input -> GUI _gui_input -> _shortcut_input -> _unhandled_key_input -> _unhandled_input` 的传播顺序 |
| `Viewport.set_input_as_handled()` | 引擎内置 | 仅用于 Godot 内部事件传播控制 |
| Web shell / HTML / CSS / export template | 平台包装 | 负责 canvas 内 DOM 默认行为控制与验证 |

### 依赖本系统的系统（下游）

| 系统 | 依赖性质 | 说明 |
|------|---------|------|
| 衣橱 UI | 强依赖 | 注册服装卡片拖拽热区，监听 `drag_*` / `clicked` / `hovered`，并用 `region_id` 映射 `item_id` |
| 拖拽换装 | 间接依赖 | 消费衣橱 UI 输出的 `item_drag_dropped(item_id, position)`；不重复解析原始输入 |
| 场景/状态管理 | 就绪依赖 | BOOT 阶段检查 `InputManager.is_ready`，以确认可交互 WARDROBE 已具备输入入口；不直接消费输入信号 |
| 对话 UI（未来） | 弱依赖 | MVP 使用 Godot 原生 GUI；若未来接入 InputManager，只注册明确点击热区 |
| 主菜单/晚安 UI（未来） | 弱依赖 | 标准按钮继续使用 Godot Button `pressed`；不连接 InputManager click |

### 与 Godot GUI 系统的关系

| 交互类型 | 使用方式 | 原因 |
|---------|---------|------|
| 标准按钮点击 | Godot Button `pressed` | 避免 InputManager click 双触发 |
| 列表滚动 | Godot ScrollContainer | 引擎原生滚动，InputManager 只做拖拽热区仲裁 |
| 服装拖拽 | InputManager `drag_*` | 需要跨节点拖拽、鼠标/触摸统一、Web 默认行为控制 |
| Hover 高亮 | InputManager `hovered` 或 Control mouse_entered | 具体由衣橱 UI 选择，但移动端必须有点击/选中等价反馈 |
| 对话点击推进 | Godot GUI | MVP 不依赖 InputManager |

### 双向依赖确认

**输入管理 -> 衣橱 UI**：

- 衣橱 UI 注册卡片拖拽热区，并保存 `region_id -> item_id` 映射。
- 衣橱 UI 监听 InputManager 信号并创建拖拽预览。
- InputManager 不持有衣橱 UI 节点或服装引用。

**输入管理 -> 拖拽换装**：

- 拖拽换装不直接监听 InputManager 作为主路径。
- 衣橱 UI 将输入语义转换为装备意图后，拖拽换装再判断是否可装备。
- 中断拖拽不会输出装备意图。

### 引擎/平台约束

| 约束 | 影响 |
|------|------|
| Godot Web 导出使用 `engine.js` 桥接浏览器事件 | InputManager 不能假设 DOM 默认行为一定已被阻止 |
| `Viewport.set_input_as_handled()` 只影响 Godot 事件传播 | Web 防滚动必须在导出模板/HTML/CSS 层验证 |
| `InputEventScreenTouch.canceled` 存在 | 必须处理 touch cancel |
| 鼠标没有 touch index | 唯一键必须使用 `(source_type, source_index)` |
| 触摸 `position` 是 viewport 坐标 | 信号输出统一转换为 root viewport 坐标 |
| GUI 事件传播顺序早于 `_unhandled_input()` | 标准 GUI 不走 InputManager；游戏热区显式接管 |

## Tuning Knobs

| 参数 | 默认值 | 安全范围 | 影响 |
|------|--------|---------|------|
| `mouse_drag_threshold` | 5.0 px | 2.0 - 20.0 | 鼠标拖拽灵敏度 |
| `touch_drag_threshold` | 12.0 px | 8.0 - 28.0 | 触摸拖拽灵敏度；更大以容忍手指抖动 |
| `click_timeout` | 0.5 秒 | 0.15 - 0.75 | 点击最大按住时间 |
| `DRAG_EXIT_GRACE_SECONDS` | 0.15 秒 | 0.10 - 0.25 | 鼠标离开 canvas 后等待回到画布或 release 的时间 |
| `scroll_axis_lock_ratio` | 1.4 | 1.2 - 2.0 | 早期移动主方向超过副方向多少时判定为滚动意图 |

所有 setter 对输入值进行 clamp，并在 debug 日志中记录被 clamp 的值。测试之间应使用新实例或恢复默认值。

### 刻意不做成可调的

| 项目 | 固定值 | 原因 |
|------|--------|------|
| 同时 active 手势数 | 1 | MVP 一次只操作一件服装 |
| 多点手势 | 不支持 | pinch/rotate 不属于 MVP |
| 双击检测 | 不实现 | 双击属于具体 UI 业务 |
| 长按业务信号 | MVP 不实现 | 避免慢点击被未使用语义吞掉 |
| DOM 默认行为策略 | Web shell 负责 | InputManager 不能直接访问 DOM |

## Acceptance Criteria

### 热区与输入所有权

- [ ] **AC-1**: 未注册热区上的鼠标左键点击不发射 `clicked`、`drag_started`、`drag_updated` 或 `drag_ended`，标准 Godot Button / Control 仍可处理该事件。
- [ ] **AC-2**: 已注册点击热区上，鼠标左键按下 `(10,10)`、0.1 秒内在 `(10,10)` 抬起，只发射一次 `clicked`，不发射任何 `drag_*`。
- [ ] **AC-3**: 同一 UI 业务不得同时绑定 Godot Button `pressed` 与 InputManager `clicked`；衣橱 UI 文档中的卡片点击路径必须指定唯一所有者。
- [ ] **AC-4**: ScrollContainer 空白区域触摸纵向滑动时，InputManager 不发射 `drag_started`，输入流释放给 ScrollContainer。

### 手势判定

- [ ] **AC-5**: 鼠标左键在已注册拖拽热区 `(0,0)` 按下，移动到 `(6,0)` 后抬起，按顺序发射 `drag_started`、至少一次 `drag_updated`、一次 `drag_ended`；不发射 `clicked`。
- [ ] **AC-6**: 触摸在已注册拖拽热区按下后移动 6px 再抬起，在默认 `touch_drag_threshold = 12.0` 下只发射 `clicked`，不发射 `drag_started`。
- [ ] **AC-7**: 触摸在已注册拖拽热区按下后移动 13px 且通过拖拽方向仲裁，发射 `drag_started` 和后续拖拽信号。
- [ ] **AC-8**: POTENTIAL 状态按住 0.8 秒不移动后抬起，MVP 不发射 `clicked` 或 `long_pressed`，并清除候选状态。
- [ ] **AC-9**: 移动距离恰好等于当前 source threshold 时不发射 `drag_started`；继续移动到大于阈值后才发射。

### 拖拽数据完整性

- [ ] **AC-10**: `drag_started` Dictionary 包含 `position`、`start_position`、`source_type`、`source_index`、`source_key`、`region_id`、`owner_id`；其中 `position` 等于首次超过阈值的事件位置，`start_position` 等于按下位置，且 `position.distance_to(start_position) > threshold`。
- [ ] **AC-11**: 起点 `(10,10)`，拖拽更新事件位置 `(18,14)` 时，`drag_updated.position == Vector2(18,14)`，`offset == Vector2(8,4)`，`start_position == Vector2(10,10)`。
- [ ] **AC-12**: 起点 `(0,0)`，移动到 `(3,4)` 再到 `(6,8)` 后结束，`drag_ended.total_distance == 10.0 ± epsilon`，`offset == Vector2(6,8)`，`interrupted == false`。
- [ ] **AC-13**: 所有手势 Dictionary 均不包含 `item_id`、Control、Node、Resource 或服装引用。
- [ ] **AC-14**: `get_current_drag()` 返回顶层 Dictionary 副本；调用方修改返回副本的顶层字段后，下一次 `get_current_drag()` 与内部 `current_drag` 不变。

### 输入源隔离与多点触摸

- [ ] **AC-15**: 触摸拖拽已进入 DRAGGING 后，注入鼠标移动和鼠标左键按下事件，不发射新的 `drag_started` / `clicked`，`current_drag.source_type == "touch"`，原触摸拖拽可继续更新并结束。
- [ ] **AC-16**: 鼠标拖拽已进入 DRAGGING 后，注入 `InputEventScreenTouch.pressed=true` 和 `InputEventScreenDrag`，不发射新的手势信号，`current_drag.source_type == "mouse"`。
- [ ] **AC-17**: 两根触摸同时存在时，第二触点 move/release 不发手势信号、不改变 active source；第一触点结束后第二触点不会自动 promotion，必须重新按下才可开始新手势。
- [ ] **AC-18**: active touch 收到 `canceled == true` 时，若已 DRAGGING 则发射一次 `drag_ended(interrupted=true, cancel_reason="touch_canceled")`；若仍 POTENTIAL 则不发信号并清除状态。

### Hover

- [ ] **AC-19**: 鼠标无按键在 viewport 内移动时发射 `hovered`，并使 `is_hovering() == true`。
- [ ] **AC-20**: 鼠标离开 viewport、窗口失焦或收到 mouse exit 通知时发射一次 `unhovered`，并使 `is_hovering() == false`。
- [ ] **AC-21**: 触摸事件不发射 `hovered` / `unhovered`，也不改变 `is_hovering()`。

### 状态查询 API

- [ ] **AC-22**: 初始化且未注入输入事件时，`is_dragging() == false`，`get_current_drag() == null`，`is_ready == true`。
- [ ] **AC-23**: 按下后未超过阈值时 `is_dragging() == false`；首次超过阈值并发射 `drag_started` 后为 `true`；正常或中断 `drag_ended` 后为 `false`。

### 输入消费行为

- [ ] **AC-24**: 未命中注册热区的输入流不调用 `mark_input_handled()`。
- [ ] **AC-25**: POTENTIAL 状态下尚未接管拖拽前不调用 `mark_input_handled()`。
- [ ] **AC-26**: 首次进入 DRAGGING 的事件调用一次 `mark_input_handled()`；后续 active drag move/release 继续调用。
- [ ] **AC-27**: 单元测试通过 spy `mark_input_handled()` 调用次数；集成测试通过 Button/Control 验证拖拽成立后后续事件不触发 GUI 点击路径。
- [ ] **AC-28**: Web 导出集成测试中，在目标浏览器 canvas 内拖拽服装不触发页面滚动、文本选择、右键菜单或浏览器 pinch zoom；canvas 外页面滚动仍可用。

### 边界条件

- [ ] **AC-29**: `set_mouse_drag_threshold(10.0)` 后，鼠标移动 8px 抬起发射 `clicked`，不发射 `drag_started`；测试结束恢复默认值或使用新实例。
- [ ] **AC-30**: `set_click_timeout(0.5)` 后，按住 0.4 秒抬起发射 `clicked`；传入单位为秒。
- [ ] **AC-31**: `set_click_timeout(-1.0)` 被 clamp 到安全范围，不会使点击永远不可达。
- [ ] **AC-32**: 右键/中键 press、move、release 均不发射手势信号、不改变 active drag、不调用 `mark_input_handled()`。
- [ ] **AC-33**: 拖拽中鼠标离开 canvas 后，在 `DRAG_EXIT_GRACE_SECONDS` 内回到 canvas 并继续移动，不发射 `drag_ended`，`is_dragging() == true`。
- [ ] **AC-34**: 拖拽中鼠标离开 canvas 后，在 grace 内收到左键 release，发射一次 `drag_ended(interrupted=false)`，随后 `is_dragging() == false`。
- [ ] **AC-35**: 拖拽中鼠标离开 canvas 且超过 grace 未收到 release 或返回事件，发射一次 `drag_ended(interrupted=true, cancel_reason="mouse_exit_timeout")`。
- [ ] **AC-36**: 拖拽中玩家在 canvas 内按住不动超过 grace，不发射 `drag_ended`，拖拽状态保持。
- [ ] **AC-37**: 拖拽中发生 viewport resize 或衣橱布局重建，发射 `drag_ended(interrupted=true, cancel_reason="layout_changed")`，衣橱 UI 不输出装备事件。

### 性能

- [ ] **AC-38**: Godot 4.6 Web release export 固定测试场景中，预热后采样 1000 次 InputManager 单事件处理，p95 < 0.5ms。
- [ ] **AC-39**: 连续处理 100 次 drag move 输入时，InputManager 自身 p95 < 0.5ms，且每帧聚合处理 p95 < 1.5ms；报告中排除订阅者渲染逻辑。
- [ ] **AC-40**: 从 `drag_started` 发射到衣橱 UI 拖拽预览首帧显示，目标浏览器中不超过 16.6ms。

### 不测试的内容

- 双击业务语义：InputManager 不实现，由具体 UI 自行测试。
- 长按业务语义：MVP 不实现 `long_pressed`。
- 非目标浏览器的 DOM 行为：只测试发布目标浏览器；未通过的浏览器记录为平台限制。
