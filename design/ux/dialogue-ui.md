# UX Spec: Dialogue UI

> **Status**: In Design
> **Author**: user + ux-designer
> **Last Updated**: 2026-06-25
> **Journey Phase(s)**: DAILY_SCENE
> **Template**: UX Spec
> **Platform Target**: Web

---

## Purpose & Player Need

对话 UI 的目的，是让玩家在确认穿搭后，安静地读完今天这一小段故事，并通过轻点推进的方式感到“今天被温柔接住了”。玩家来到这里，不是为了做选择、打分或管理系统，而是为了把刚搭好的衣服带进今天的日常里，听角色用几句短话回应这一天。它要解决的核心需要是：让玩家清楚、舒服、无压力地完成每日场景的阅读和收束，并顺势走向晚安流程。

---

## Player Context on Arrival

玩家到达时，通常已经完成衣橱确认，角色和当天场景已在画面中稳定呈现，准备开始阅读当天台词。她的情绪应被假设为平静、专注、轻微期待，不需要被教育怎么用界面，也不需要被要求做复杂决策。这个界面是每日循环中的中段承接点，玩家一般是被流程带到这里的，而不是主动找来；她只需要继续点一下，就能把今天读完。

---

## Navigation Position

对话 UI 位于每日循环的中段，属于 `DAILY_SCENE` 内部的阅读层，而不是顶层菜单或独立流程页。它在玩家完成衣橱确认、每日场景稳定呈现之后出现，负责承接当天台词、推进阅读，并把“今天读完了”这个意图交回给每日场景，最终进入晚安流程。换句话说，这个界面的位置是 `Main Menu → Wardrobe UI → Daily Scene → Dialogue UI → Goodnight UI` 中的阅读节点；它不负责导航分发，也不直接承担天数推进。

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Daily Scene | 角色与背景已稳定呈现，`DAILY_SCENE` 启用对话 UI | 当前天数、当天场景、确认穿搭后的 `equipped_items`、`dialogue_context_tags` |
| Dialogue Fallback | 正式内容序列不可用、为空，或本地化缺失导致无法播放 | 当前天数、基础兜底文案、仍可继续的阅读流程 |
| Visual Fallback | 角色或背景进入安全降级态，但场景仍可继续 | 当前天数、降级视觉、可完成当天阅读的最小可用状态 |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Daily Scene → Goodnight | 最后一行读完后，玩家确认结束 | 对话 UI 只发出 `dialogue_sequence_finished(day)`；每日场景负责请求 `GOODNIGHT` |
| Daily Scene 内部结束态 | 结束确认已出现，但玩家尚未再次确认 | 保持在完成等待状态，不推进天数，不切换场景 |
| Fallback End Control | 对话 UI 不可用时，Daily Scene 提供的最小结束控件被确认 | 只用于保证玩家能到达晚安流程，不替代正常对话体验 |
| Hidden / Disabled | 当前状态不是 `DAILY_SCENE` | UI 保持隐藏或禁用，不接收主流程输入 |

---

## Layout Specification

### Information Hierarchy

1. 当前角色发言 / 旁白正文
2. 说话者名称或叙事标识
3. 继续 / 晚安提示
4. 当天场景氛围的轻量辅助信息
5. 可选的角色表情提示或系统提示

### Layout Zones

- 上半区：角色与场景主视觉，保持完整可见
- 下半区：半透明对话浮层，承载文本与交互
- 角落辅助区：弱提示、可选关闭类安全控件

### Component Inventory

**对话面板**
- 底部浮层，主承载区
- 负责显示角色名、正文、继续提示和结束按钮

**角色名标签**
- 显示 speaker name
- 在旁白行可弱化或隐藏

**正文文本**
- 逐字显示 / 完整显示
- 支持自动换行与长文本阅读

**继续提示**
- 当前行完成后出现
- 仅作为下一步的低干扰提示

**结束按钮**
- 最后一行后的 `晚安 / 继续`
- 交由 Daily Scene 接收完成意图

**返回 / 关闭类弱入口**
- 仅在 fallback 或安全结束态出现
- 作为保底退出路径，不干扰正常阅读

**头像 / 表情位**
- 可选，作为内容补充
- 不遮挡正文，不抢主视觉

### ASCII Wireframe

```text
┌──────────────────────────────────────┐
│             场景主视觉               │
│         角色 / 背景 / 动作           │
│                                      │
│                                      │
├──────────────────────────────────────┤
│  [说话者名]                           │
│  正文正文正文正文正文正文正文正文      │
│  正文正文正文正文正文正文               │
│                            [继续 ›]   │
└──────────────────────────────────────┘
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|-----------------|---------|--------------|
| Default | `DAILY_SCENE` 启用且对话序列可用 | 显示角色名、正文、继续提示、结束流程 |
| Loading | 正在请求 `request_dialogue_sequence(day, context)` | 显示轻量等待，不抢主视觉，不显示错误术语 |
| Empty Sequence | 序列为空或全无效 | 进入安全兜底文本，仍可继续到晚安 |
| Error Fallback | 正式 provider 不可用、文本缺失、或资源异常 | 使用安全 fallback line / fallback control，避免卡死 |
| Complete Waiting | 最后一行已完整显示，玩家尚未再次确认 | 显示 `晚安 / 继续`，等待明确确认 |
| Hidden | 不在 `DAILY_SCENE` | UI 隐藏或禁用，不接受主流程输入 |
| Reduced Motion | 玩家开启减少动态效果 | 去掉逐字外的装饰动效，改为静态显示 / 轻淡入 |

---

## Interaction Map

| Component | Action | Input | Feedback | Outcome |
|---|---|---|---|---|
| 正文区域 | 继续阅读 / 补全当前行 | 点击 / 触摸 | 当前行立即完整显示，继续提示出现 | 若未显示完全则补全文本；否则推进到下一行 |
| 正文区域 | 无输入 | 无 | 维持当前逐字状态 | 不改变状态 |
| 结束按钮 | 完成当天阅读 | 点击 / 触摸 | 按钮轻微高亮，进入短暂锁定 | 发出 `dialogue_sequence_finished(day)`，交给 Daily Scene |
| 角色名标签 | 识别当前说话者 | 无 | 无 | 仅显示信息，不可交互 |
| 头像 / 表情位 | 查看情绪提示 | 无 / 点击可无效 | 若存在则轻量展示表情，不作为交互入口 | 不改变状态 |
| 关闭 / 返回弱入口（fallback only） | 退出到安全结束态 | 点击 / 触摸 | 弱高亮、淡出 | 仅在对话不可用或安全结束态下返回 Daily Scene 的最小结束控件 |

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| 点击正文推进 | `dialogue.line_advanced` | `{ "day": day, "line_id": line_id, "mode": "reveal_full_line" \| "advance_to_next_line" }` |
| 点击最后一行后的结束按钮 | `dialogue.finished_confirmed` | `{ "day": day, "sequence_id": sequence_id }` |
| 正文推进完成后播放轻反馈 | `dialogue.line_completed` | `{ "day": day, "line_id": line_id }` |
| 触发 fallback 结束控件 | `dialogue.fallback_finished_requested` | `{ "day": day, "reason": "content_unavailable" \| "ui_unavailable" }` |
| 无可用内容时进入兜底 | `dialogue.fallback_used` | `{ "day": day, "fallback_key": "dialogue.fallback.daily_quiet" }` |

---

## Transitions & Animations

- 进入：每日场景就绪后，对话面板从底部轻柔淡入，正文先出现，角色名和继续提示稍后稳定下来。
- 阅读中：逐字显示是主要动效，速率保持平滑，不做夸张打字机抖动。
- 补全当前行：玩家确认后，当前行瞬间完整显示，继续提示在短延迟后出现。
- 推进下一行：上一行收束后，下一行轻淡入或直接替换，保持阅读连续感。
- 完成等待：最后一行完成后，`晚安 / 继续` 以静态或极轻微强调出现，不能闪烁。
- 退出到晚安：`dialogue_sequence_finished(day)` 发出后，对话层先轻收束再让 Daily Scene 接管状态切换。
- Reduced motion：去掉淡入错峰和微动，只保留稳定显示和轻淡入。

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| 当前天数 | `ProgressManager` 通过 `GameState.get_current_day()` 暴露 | Read | 对话标题、内容选择、完成确认都要用 |
| 当前场景 ID | `Daily Scene` | Read | 用于选取对应 `DialogueSequence` |
| 当前对话序列 | `LightNarrativeDialogue` | Read | `request_dialogue_sequence(day, context)` 的返回值 |
| 说话者名称 | `LightNarrativeDialogue` / 本地化表 | Read | 用 `speaker_name_key` + `tr()` 显示 |
| 正文文本 | `LightNarrativeDialogue` / 本地化表 | Read | 用 `text_key` + `tr()` 显示，必要时 fallback 到 `text` |
| 角色表情 key | `LightNarrativeDialogue` / 角色表现资源 | Read | 可选，不影响推进 |
| `equipped_items` | `GameState.context`，写入源为衣橱确认流程 | Read | 仅用于内容上下文，不由对话 UI 写入 |
| `dialogue_context_tags` | `Daily Scene` | Read | 由每日场景提供给内容 provider |
| `line_id` / `sequence_id` | `LightNarrativeDialogue` | Read | 事件追踪与 QA 定位 |
| `scene_in_progress` | `SaveManager` / `GameState` | Read | 只在流程恢复和状态边界时有意义，对话 UI 不写 |
| `dialogue_sequence_finished(day)` | 对话 UI 发出，Daily Scene 接收 | Write | 只发意图，不直接切状态 |

---

## Accessibility

项目级无障碍 tier 尚未在独立 `design/accessibility-requirements.md` 中定义，因此本屏幕按 Standard 基线设计：鼠标和触摸均可完成全部主流程，正文与背景保持清晰对比，所有状态都不能只靠颜色表达，且提供 `Reduced-motion Alternative`。

- 所有主流程按钮与结束控件都必须可通过鼠标点击和触摸点击完成。
- 不依赖 hover 传达必要信息；hover 只能作为额外反馈。
- 所有交互热区不得小于 44×44px。
- 角色名、正文、继续提示、结束按钮都要有清晰的可见状态，不得重叠。
- 正文与背景对比度至少保持 4.5:1；若背景变化导致对比不足，必须使用更实的底板或降噪层。
- 角色名、正文、结束提示和任何状态标记不得只靠颜色区分，需配合位置、图标、字体重量或底板差异。
- `Reduced-motion Alternative` 必须覆盖进入、逐字显示的装饰动效、继续提示出现和完成收束。
- 对话不应自动消失，避免玩家错过当前句子或结束确认。
- 当前没有定义屏幕阅读器专用项目级 tier；若后续建立全局 accessibility spec，需要回填该项并检查该屏幕是否需要额外语义标注。

---

## Localization Considerations

| Text Element | Suggested Max Length | Notes |
|---|---|---|
| 角色名 | 中文 6 字 / 英文 18 chars | 过长时优先换行或缩短显示，不挤压正文 |
| 正文单行片段 | 中文 24 字 / 英文 48 chars | `LightNarrativeDialogue` 已建议单行上限 48 chars，UI 需支持自动换行 |
| 继续提示 | 中文 2-4 字 / 英文 8 chars | 低干扰，尽量保持简短 |
| 结束按钮 | 中文 2-4 字 / 英文 8 chars | 与 `finish` / `continue` 含义一致即可 |
| 安全兜底文案 | 中文 12-18 字 / 英文 40 chars | 兜底文案要温和，不提技术错误 |

- 所有文本必须通过本地化 key 加载，不在 UI 节点中硬编码。
- 对话正文应预留至少 40% 文本扩展空间，避免长译文挤压按钮。
- 若 speaker name 或正文超出可用空间，优先换行，其次缩短辅助信息，最后才考虑缩小辅助文本。
- 结束按钮文案必须与 `END_CONFIRM_LABEL` 保持一致或同义，不得在不同状态使用完全不同的语气。
- 数字天数、序列编号和状态提示都应走本地化格式化，不直接拼接固定字符串。

---

## Acceptance Criteria

- [ ] 对话 UI 在 `DAILY_SCENE` 中打开时，正文层在 500ms 内可见，且不遮挡角色主体超过 30%。
- [ ] 当 `request_dialogue_sequence(day, context)` 成功返回有效序列时，玩家可以通过鼠标或触摸逐次完成整段对话。
- [ ] 当当前行未完整显示时，点击正文会立即补全当前行，不会跳到下一行。
- [ ] 当当前行已完整显示且不是最后一行时，点击正文会推进到下一行，并继续逐字显示。
- [ ] 当最后一行已完整显示时，界面会显示 `晚安` / `继续`，再次确认后只发出一次 `dialogue_sequence_finished(day)`。
- [ ] 当对话序列为空、缺失或不可播放时，玩家仍可通过兜底路径到达晚安流程，不会卡死。
- [ ] 当输入方法为鼠标或触摸时，所有可交互控件都能完成推进、结束确认和兜底关闭。
- [ ] 当视口变化到常见桌面或移动尺寸时，对话面板不会越过中线，且文本不会与按钮重叠。
- [ ] 当启用 reduced-motion 时，进入、提示和收束仅使用轻淡入或静态显示，不出现错峰或额外装饰动效。
- [ ] 所有可见文本都通过本地化 key 渲染，且长文本不会超出面板可读区域。
- [ ] 对话 UI 不直接调用 `ProgressManager.advance_day()`，也不直接调用 `GameState.request_transition(State.GOODNIGHT)`。

---

## Open Questions

- 目前没有独立的 `design/accessibility-requirements.md`，是否要先建立项目级 tier 定义，再回填本屏幕的正式无障碍承诺？
- MVP 是否需要在对话 UI 中显示默认头像 / 表情占位，还是全部情绪表达都由每日场景承担？
- `dialogue.fallback_finished_requested` 是否应保留为正式事件，还是只在实现层作为内部兜底路径？
- 结束按钮文案是否统一为 `晚安`，还是在不同上下文中允许 `继续` 的本地化变体？
- 如果后续新增键盘或手柄支持，这一屏是否需要升级为更明确的 focus 顺序规范？
