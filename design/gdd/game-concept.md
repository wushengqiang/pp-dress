# Game Concept: 每日穿搭 (Dress Up Daily)

*Created: 2026-06-04*
*Status: Updated*

---

## Elevator Pitch

> 一款网页端的少女换装游戏，你每天为角色搭配穿搭，在温暖的轻叙事中感受陪伴与放松。

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 换装 / 轻叙事 |
| **Platform** | Web（浏览器） |
| **Target Audience** | 休闲玩家，喜欢表达和收集 |
| **Player Count** | 单人 |
| **Session Length** | 10-20 分钟 |
| **Monetization** | 免费游玩 |
| **Estimated Scope** | 小（2-3 周 MVP，单人） |
| **Comparable Titles** | 暖暖系列、Shining Nikki、Love Nikki |

---

## Core Fantasy

拥有一个专属的电子衣橱，每天打开它，为角色挑选今天的穿搭，然后看着她穿着你搭配的衣服走进故事里。

这不是一个需要你"打赢"的游戏——它不会评判你、不会催促你。它像一个每天见面的朋友，温暖地陪伴你几分钟。你的品味就是唯一的标准。

---

## Unique Hook

像写日记一样玩换装——每一天有新的场景和剧情，你的穿搭是今天故事的主角。这不是"换装模拟器"，而是一本**穿搭日记**。

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 2 | 精美的服装立绘、流畅的拖拽动画、柔和的音效反馈 |
| **Fantasy** (make-believe, role-playing) | 5 | 陪伴一位少女的日常生活，代入她的世界 |
| **Narrative** (drama, story arc) | 4 | 每日场景推进一段轻叙事，服装触发不同的角色心情对话 |
| **Challenge** (obstacle course, mastery) | N/A | 不做挑战——这是核心反支柱 |
| **Fellowship** (social connection) | 6 | 与角色的日常陪伴形成情感连接 |
| **Discovery** (exploration, secrets) | 7 | 解锁新衣服、发现新的搭配组合 |
| **Expression** (self-expression, creativity) | 1 | 每一次穿搭都是玩家个人品味的表达，100% 自由 |
| **Submission** (relaxation, comfort zone) | 3 | 零压力循环，随时打开随时放下 |

### Key Dynamics (Emergent player behaviors)

- 玩家会自然形成"每日登录"的习惯——打开游戏看看今天穿什么
- 玩家会对特定服装产生感情——"这件上衣是第一天就有的，我一直很喜欢"
- 玩家会尝试不同的风格组合，探索自己的审美偏好

### Core Mechanics (Systems we build)

1. **拖拽换装** —— 点击服装部件拖到角色身上，即时换装，即时反馈
2. **每日场景系统** —— 每天一个场景，角色穿着玩家选择的搭配走进今天的生活片段
3. **服装解锁系统** —— 晚安后衣橱自然多出几件新单品，逐步扩充搭配选择
4. **轻叙事对话** —— 角色的对话随服装风格略微变化，营造陪伴感

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | 每件穿搭完全由玩家决定，没有"正确"答案 | Core |
| **Competence** (mastery, skill growth) | 通过解锁新衣服、看到搭配在故事中"活"起来 | Supporting |
| **Relatedness** (connection, belonging) | 与角色的日常陪伴建立情感连接 | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: 服装解锁收集、完成一周轻叙事循环
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: 探索不同风格组合、发现隐藏搭配
- [ ] **Socializers** (relationships, cooperation, community) — How: MVP 不做社交
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — How: 不做竞技

### Flow State Design

- **Onboarding curve**: 前 3 天只开放基础部件（上衣、下装、鞋子），第 4 天起逐步解锁配饰、发型等，降低初始认知负担
- **Difficulty scaling**: 无难度曲线——游戏的核心是表达而非挑战
- **Feedback clarity**: 换装即时视觉反馈 + 角色对话中反映穿搭风格
- **Recovery from failure**: 无失败状态——任何搭配都可以继续

---

## Core Loop

### Moment-to-Moment (30 seconds)
拖拽服装部件到角色身上——手指拖一件上衣、松手即穿上、不满意再拖一件。每次换装都有柔和微光、布料感反馈和轻柔音效。

### Short-Term (5-15 minutes)
每天一个场景（约会 / 逛街 / 宅家），从衣橱选择搭配，确认穿搭后阅读当天的轻叙事对话。

### Session-Level (30-60 minutes)
完成 7 天轻叙事循环，每天晚安后自然解锁 3-4 件新衣服。第 7 天是温柔收束，不是挑战或搭配考试。自然停止点：每天的"晚安"画面——角色安静回顾今天。

### Long-Term Progression
7 天剧情为一个完整周。通关后可以重玩任意一天，用新解锁的服装重新搭配。目标：收集全部 ~30 件服装。

### Retention Hooks
- **Curiosity**: 明天会是什么场景？会解锁什么新衣服？
- **Investment**: 角色的故事在推进，衣橱在成长
- **Mastery**: 回顾自己的搭配历史，看到审美进化

---

## Game Pillars

### Pillar 1: 每日陪伴
打开游戏就像见到一位老朋友——轻松、温暖、没有压力。

*Design test*: "这段对话会不会让玩家感到放松？"如果不放松，就砍掉。

### Pillar 2: 随心搭配
每一套穿搭都是对的——玩家的品味永远被认可，不被评判。

*Design test*: "这里有没有暗示'你搭配得不好'？"如果有，删除。

### Pillar 3: 即时有感
拖拽一件衣服上身的瞬间，必须让人感到满足——清脆的音效、微妙的动画、即时的视觉变化。

*Design test*: "这个交互反馈够不够让人想再做一次？"如果不够，加强。

### Anti-Pillars (What This Game Is NOT)

- **NOT 评分系统**: 不对穿搭打分或排名——这会破坏"随心搭配"的核心支柱
- **NOT 深度分支叙事**: 不做多路线、多结局复杂剧情——故事是氛围，不是系统
- **NOT 海量收集**: 不做"集齐全部 500 件"——每件单品精心设计，少而精

---

## Visual Identity Anchor

### Visual Direction: 温暖手绘风

基于"每日陪伴"的核心体验，视觉方向应该像一本温暖的手绘日记——柔和的色彩、圆润的线条、手绘般的质感。

- **一切皆有回响**: 每个交互都有即时视觉反馈——拖拽有跟随动画、放下有微光、换装完成有柔和的闪烁
- **颜色哲学**: 主色调为暖粉色系，辅助色为奶油白和浅灰，整体饱和度偏低，营造舒适放松的氛围
- **线条与形状**: 角色和服装部件使用柔和的圆角线条，避免锐利的边角

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| 暖暖系列 | 换装核心交互、部件分类体系 | 不加评分和竞技系统，聚焦轻叙事 | 验证了换装品类核心循环的可行性 |
| Animal Crossing | 每日登录的动力、轻松陪伴感 | 更轻量——只聚焦换装这一个动作 | 证明"轻松日常"可以形成长期留存 |

**Non-game inspirations**: 手绘日记、穿搭博主 vlog、纸质换装贴纸书——那种"翻开这一页，看看今天穿什么"的感觉。

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 14-28 |
| **Gaming experience** | 休闲 / 轻度游戏玩家 |
| **Time availability** | 每天 10-20 分钟碎片时间 |
| **Platform preference** | 手机/网页，偏好零安装门槛 |
| **Current games they play** | 暖暖系列、休闲手游、模拟经营类 |
| **What they're looking for** | 无压力的日常陪伴，表达审美品味，收集美好事物 |
| **What would turn them away** | 付费墙、强制社交、评分带来的焦虑感、复杂的操作门槛 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 — 免费开源，Web 导出干净，GDScript 易上手 |
| **Key Technical Challenges** | Web 端的拖拽交互（需同时处理触摸和鼠标事件）、大量图片资源加载优化 |
| **Art Style** | 2D 立绘 + 部件叠加 |
| **Art Pipeline Complexity** | 中等（需逐一绘制每个服装部件，但 2D 叠加方案成熟） |
| **Audio Needs** | 轻度——背景音乐 + 换装/UI 音效 |
| **Networking** | 无 |
| **Content Volume** | MVP: 1 角色、6 部件类别、约 30 件服装、7 天剧情 |
| **Procedural Systems** | 无 |

---

## Risks and Open Questions

### Design Risks
- **换装新鲜感维持**: 7 天剧情后玩家是否还有动力重玩？缓解：解锁新衣服可以给旧场景带来新体验

### Technical Risks
- **Web 拖拽体验**: 浏览器中拖拽可能与页面滚动冲突，需仔细处理触摸/鼠标事件
- **图片加载性能**: 约 30 件服装部件的图片需要在场景切换时流畅加载

### Scope Risks
- **美术产能是最大瓶颈**: 30 件单品需要逐一设计绘制，这是项目最关键的时间约束
- **如果美术进度落后**: 可将部件类别从 6 类缩减到 4 类（发型、上衣、下装、鞋子）

### Open Questions
- 服装部件的视觉风格方向需进一步明确——在 `/art-bible` 中解决
- 拖拽交互的技术可行性需原型验证——在 `/prototype` 中测试

---

## MVP Definition

**Core hypothesis**: 玩家会享受在轻叙事背景下自由搭配服装的体验，拖拽换装的即时反馈足以支撑每天 10-20 分钟的游玩。

**Required for MVP**:
1. 1 个女主角，6 类可换部件（发型、上衣、下装、鞋子、配饰、妆容），每类 4-5 件
2. 7 天剧情，每天一个场景 + 轻叙事对话
3. 拖拽换装核心交互（支持鼠标和触摸）
4. 服装解锁系统（每天完成剧情解锁 3-4 件新衣服）

**Explicitly NOT in MVP** (defer to later):
- 第二个角色（闺蜜）
- 服装图鉴系统
- 穿搭回顾相册
- 多周目内容
- 额外的 4 个部件类别（眼睛、耳饰、项链、手套、袜子）

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 角色、6 部件类型、~30 件服装、7 天剧情 | 拖拽换装 + 轻叙事 + 服装解锁 | 2-3 周 |
| **扩展 1** | 部件扩展至 10 类，每类 6-8 件 | 新增 4 个部件类别 | +1-2 周 |
| **扩展 2** | 21 天剧情，第二个角色 | 服装图鉴 + 穿搭回顾相册 | +2-3 周 |
| **Full Vision** | 2 角色、10 部件类型、~100 件服装、21 天剧情 | 所有核心系统完成 | 2-3 个月 |

---

## Next Steps

- [ ] Run `/setup-engine` to configure Godot 4.6 and populate version-aware reference docs
- [ ] Run `/art-bible` to create the visual identity specification
- [ ] Discuss vision with `creative-director` for pillar refinement
- [ ] Run `/map-systems` to decompose the concept into individual systems
- [ ] Run `/design-system [system-name]` to author per-system GDDs
- [ ] Run `/create-architecture` to produce master architecture blueprint
- [ ] Run `/architecture-review` to validate architecture coverage
- [ ] Run `/gate-check` to validate readiness before production
