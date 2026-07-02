# 沉浸式翻译竞品分析与 Parrot 迭代机会

日期：2026-07-02  
范围：市面沉浸式翻译、系统级翻译、学习型翻译、macOS 快捷翻译工具。  
影响范围：docs-only 研究文档，无产品代码变更。

## 1. 结论

Parrot 不应把「沉浸式翻译」理解成单一的网页双语翻译功能。市面上真正跑出来的模式，是把翻译做成一层贴近用户原始任务的上下文处理层：

- 在阅读中保留原文和页面结构，减少理解断裂。
- 在输入中直接改写或翻译草稿，减少复制粘贴。
- 在视频、PDF、图片、会议等内容类型中保持上下文连续。
- 在查词和阅读后自动沉淀句子、词汇、例句和复习材料。
- 在多引擎、术语、隐私、质量判断上替用户做默认决策。

对 Parrot 最值得引入的不是「完整复制沉浸式翻译的浏览器插件」，而是这五个产品原则：

1. **原文不消失**：翻译是旁注、对照和解释，不是替换原上下文。
2. **原地完成任务**：选中、截图、输入、分享之后尽量不跳出原工作流。
3. **段落是最小理解单元**：词和句可快速查，长内容应按段落保持语义上下文。
4. **结果要能继续行动**：翻译后直接进入改写、回复、复制、保存、术语沉淀。
5. **多引擎变成质量供应链**：用户选任务意图，Parrot 选择引擎、隐私策略和结果推荐。

基于 Parrot 现状，优先级最高的机会是：**Quick Peek + 段落双语阅读 + 输入框改写/替换 + 学习记忆 + per-source 自动规则**。这组能力能直接服务 first-pass rate 和 task success rate，也避开了和 Immersive Translate 在完整网页/PDF 排版上的正面消耗战。

## 2. 竞品分层

| 分层 | 代表产品 | 核心任务 | 设计心智 | Parrot 借鉴点 |
| --- | --- | --- | --- | --- |
| 浏览器沉浸阅读 | Immersive Translate、Trancy | 网页、PDF、EPUB、字幕、图片双语阅读 | 翻译嵌在原内容里，减少中断 | 段落对照、hover/selection peek、页面/来源规则 |
| 系统级快捷翻译 | Mate、Bob、Easydict、PopClip | 任意 App 划词、截图、输入翻译 | 菜单栏/快捷键触发，来去很快 | 原生浮窗稳定性、静默 OCR、输入翻译、插件/服务扩展 |
| 高质量语言 AI | DeepL | 高质量翻译、写作、文档、术语 | 翻译质量和写作可信度 | 术语、正式度/语气、改写备选、show changes |
| 平台默认翻译 | Chrome、Edge、Safari、Apple Live Translation | 页面/选中文本/通信实时翻译 | 默认、自动、可撤销 | always/never 规则、自动提示、原文恢复、设备端隐私 |
| 学习型翻译 | Readlang、Reverso、Trancy | 边读边学、词汇收藏、例句复习 | 每次查词都变成学习资产 | 保存句子上下文、词汇复习、SRS、真实例句 |

## 3. 重点竞品观察

### 3.1 Immersive Translate

Immersive Translate 已经把沉浸式翻译做成「多内容类型阅读层」。官方页面和 Chrome Web Store 展示的能力包括双语网页、PDF/EPUB/文档、视频字幕、会议、图片/漫画、选中文本、hover 翻译、输入框翻译、AI 术语、多引擎、隐私承诺。Chrome Web Store 当前显示 300 万用户，官方页面宣称 2000 万用户级别。

关键设计理念：

- **不破坏原页面节奏**：翻译贴在原段落附近，而不是把用户送到另一个翻译器。
- **段落作为理解单元**：hover 段落后显示翻译，强化上下文而不是只查词。
- **内容类型覆盖**：网页、PDF、EPUB、字幕、图片都按「保留原布局」设计。
- **输入框翻译**：用户在网页输入框里输入母语，通过快捷触发生成目标语言。
- **AI 专家和术语库**：把专业领域翻译包装成用户可理解的配置。
- **隐私信任叙事**：强调不保留翻译内容、不用于训练、传输加密。

对 Parrot 的启示：

- Parrot 不需要先做完整网页重排，但应该在全局划词和 OCR 后提供 **段落双语阅读块**。
- Parrot 的 `TranslationContextProfile` 可以继续向「AI 专家/场景 profile」演化，例如 GitHub、论文、Email、Social、Reply。
- 输入框翻译是高价值方向。Parrot 可做系统级「当前输入框草稿 -> 翻译/润色 -> 替换或复制」，比浏览器扩展覆盖面更广。
- 隐私状态应该显性化。比如结果卡显示「已遮罩 3 个敏感项」「本地模式」「云端 DeepL」。

### 3.2 Trancy

Trancy 更像「沉浸式翻译 + 语言学习」。它围绕 YouTube/Netflix 等视频字幕、网页选中翻译、全文沉浸翻译、AI 查词、语法分析、生词高亮、学习 decks、听说练习展开。

关键设计理念：

- **理解和学习合一**：翻译不是一次性动作，查过的词和句子会进入复习材料。
- **字幕阅读模式**：视频缩到一侧，字幕作为可阅读文本，降低听力和阅读之间的切换成本。
- **句法辅助**：AI 语法分析、词性标注、智能断句帮助用户理解复杂句。
- **未知词被动高亮**：用户阅读时能看到自己的薄弱点。

对 Parrot 的启示：

- Parrot 的查词、历史、收藏、TTS 已经有学习底座，但还缺「从一次翻译自动生成可复习资产」。
- 对 AI builder 和研究者，学习不一定是背单词，也可以是「术语、表达、常见错误、项目词表」的长期记忆。
- `Understand` profile 可以加入「结构化解释」：关键词、隐含语气、句法/指代、适用回复。

### 3.3 Mate Translate

Mate 的强项不是复杂能力，而是原生体验：iOS、macOS、浏览器都有入口，强调菜单栏、快捷键、即时浮窗、历史同步、短语本、发音、词典、暗色模式和「不打断当前工作流」。

关键设计理念：

- **工具应该出现得快、消失得快**：菜单栏和快捷键让翻译像系统动作。
- **跨设备历史和短语同步**：用户常用表达变成个人资产。
- **查词体验完整**：发音、音标、同义词、词性等比单纯翻译更可信。

对 Parrot 的启示：

- Parrot 已经有菜单栏和快捷键，但第一屏应更强调「任意 App 的跨语言工作台」而不是功能清单。
- 历史和收藏应升级为「短语本/表达库/术语记忆」，支持跨 macOS/iOS 复用。
- Quick Peek 需要足够快，短文本不应每次都打开重工作区。

### 3.4 DeepL

DeepL 代表高质量和商务可信度。官方功能页强调文本、文档、图片翻译、术语表、正式度、词典、DeepL Write、写作风格、语气、show changes、历史、保存翻译、安全和团队管理。

关键设计理念：

- **翻译和写作融合**：翻译结果之后，用户还要调整语气、风格和受众。
- **质量控制产品化**：术语、正式度、词典、改写备选都让用户觉得可控。
- **编辑差异可见**：show changes 让润色结果可验证。

对 Parrot 的启示：

- Native Polish 不应只给一段改写，还要给「改动说明/差异视图/语气选项」。
- Strict Terminology 应显示命中、未命中和被保护词，而不是只暗中处理。
- 多引擎结果要有推荐和质量标记，减少用户在结果列表里猜。

### 3.5 Chrome、Edge、Safari 与 Apple Live Translation

平台默认翻译的优势是自动、可信、低摩擦。Chrome 支持整页翻译和选中文本翻译，并有偏好语言、自动翻译、永不翻译等设置。Edge 在地址栏提供翻译入口、自动提示、always/never 规则和显示原文。Safari 支持网页翻译、选中文本翻译和问题反馈。Apple Live Translation 把翻译放进 Messages、Phone、FaceTime 和 AirPods，并强调在这些通信场景中设备端运行。

关键设计理念：

- **自动提示但可撤销**：用户不需要找入口，同时可以设定 always/never。
- **按语言/来源记忆偏好**：系统记住某语言或页面类型是否需要翻译。
- **通信场景优先隐私**：实时对话翻译必须解释本地/云端边界。

对 Parrot 的启示：

- Parrot 应增加 per-source 自动规则：这个 App/网站/语言是否默认 Quick Peek、完整工作区、忽略、自动复制。
- 对选中文本翻译，提供「显示原文/恢复」「本来源下次自动使用此 profile」。
- iOS 社交方向应优先贴近 Messages/Share Extension/截图，而不是做一个孤立翻译 App。

### 3.6 Bob 与 Easydict

Bob 和 Easydict 证明 macOS 原生翻译工具的核心用户期待：划词、截图、输入、OCR、多服务、插件、快捷键、PopClip、静默识别、连续识别、自动复制、智能分段。Bob 还覆盖驼峰拆分、蛇形拆分、AppleScript 调用等开发者友好细节。

关键设计理念：

- **工具型功能要可组合**：划词、OCR、输入、复制、插件、脚本入口构成效率网络。
- **OCR 有多种强度**：有窗口翻译、静默识别、连续识别、选图识别。
- **开发者文本需要特别处理**：camelCase、snake_case、代码片段、Markdown 不应被普通翻译破坏。

对 Parrot 的启示：

- `github` / developer profile 要更强：保护代码块、拆分变量名、解释技术术语、保留 Markdown。
- OCR 可以分成「截图翻译」和「静默 OCR 到剪贴板/工作区」两种路径。
- 插件系统是优势，但需要更清晰的安全和默认模板。

### 3.7 Readlang 与 Reverso

Readlang 把「点击翻译」和「flashcards」连接起来，强调读什么就学什么；Reverso Context 强调用真实语境、表达/俚语/技术术语、收藏、例句、flashcards、SRS、语音、图片和文档。

关键设计理念：

- **保存的是上下文，不只是单词**：词必须连同原句、译文、来源一起保存。
- **查词结果要服务表达**：同义词、例句、语域、连接词、俚语帮助用户写得对。
- **复习是自然副产物**：用户不需要额外整理学习材料。

对 Parrot 的启示：

- 收藏结果时应保存 source app、URL/title、原句、译文、profile、术语命中、用户最终采纳文本。
- 词库不应只做 vocabulary list，应支持「从历史里提炼常错词/常用表达」。
- Social/Reply/Email 场景可沉淀用户个人表达偏好。

## 4. Parrot 当前位置

Parrot 已经具备几项强底座：

- macOS 全局入口：划词、截图 OCR、输入、查词、菜单栏、URL Scheme、PopClip。
- 统一工作区方向：源文可编辑、可重试、结果可对照。
- 多引擎：Google、DeepL、OpenAI-compatible、国内引擎、插件。
- 专业能力：术语表、历史、收藏、TTS、隐私遮罩、质量评分设计。
- iOS 方向：Understand、Express、Polish、Quick Lens、Share Extension。

主要差距不是「能不能翻」，而是：

| 差距 | 现象 | 影响 |
| --- | --- | --- |
| 短文本响应不够像系统动作 | 所有任务都容易进入同一个重工作区 | 降低高频划词 first-pass rate |
| 长内容缺少真正双语阅读层 | 多引擎卡片更适合比较，不适合阅读 | 用户仍需要自己拼上下文 |
| 输入场景还未闭环 | 输入翻译有工作区，但缺少原输入框替换/插入 | 写作任务 success rate 受限 |
| 学习/记忆弱 | 历史收藏存在，但未变成复习和表达资产 | 留存理由不足 |
| per-source 规则缺失 | 每次都要手动选择语言/profile/行为 | 重复任务效率低 |
| 隐私/成本状态不够前台化 | 用户不知道文本发给谁、是否遮罩、成本高低 | 专业用户信任感不足 |

## 5. 可引入的设计理念

### 5.1 翻译是旁注，不是替换

沉浸式翻译最核心的体验不是「翻得准」，而是「原文、译文、上下文同时可见」。Parrot 应把这条原则扩展到任意 App：

- 短文本：Quick Peek 显示原文、主译文、发音/词典、copy/use。
- 中长文本：workspace 中先显示 paragraph bilingual block，再显示 provider cards。
- OCR：候选文本块和译文同处一个工作区，用户能换块、编辑、重试。
- 历史：打开历史项时回到可编辑 workspace，而不是只读记录。

### 5.2 自动但不失控

Chrome/Edge/Safari 的强处是自动提示；专业工具的强处是可配置。Parrot 可以结合二者：

- Always translate this language/source app.
- Never translate this app/domain/language.
- For this app, default to profile: GitHub / Email / Social / Document.
- For this source, use Quick Peek / Workspace / Copy silently.
- Show original / keep bilingual / translation only.

### 5.3 段落是最小语义单元

词典适合 lookup，但理解文章、论文、文档、社交长帖时，段落比词句更重要。Parrot 应将 `ParagraphSegmenter` 变成核心阅读能力：

- 自动识别段落、列表、引用、代码块。
- 每段可复制、重试、展开解释。
- 翻译失败时只重试失败段落。
- 对 OCR 噪声提供「合并行/删除页眉页脚/重分段」。

### 5.4 翻译后要继续行动

用户真正目标通常不是获得译文，而是：

- 读懂后判断是否重要。
- 把英文资料总结成中文笔记。
- 写出自然回复。
- 把中文想法改成英文评论、邮件、issue。
- 沉淀术语和表达，下一次更快。

因此结果卡的动作应从 copy 扩展为：

- Explain nuance
- Make native
- Draft reply
- Save as phrase
- Add terminology
- Compare tone
- Replace in source app

### 5.5 多引擎是供应链，不是展示墙

多引擎并排是 Parrot 的资产，但也会给用户增加判断负担。应转成：

- 任务 profile 决定候选引擎。
- 质量评分决定推荐结果。
- Provider card 保留透明度，但默认突出一个 best answer。
- 失败时自动 fallback，并解释原因。
- 用户可以学习 Parrot 的推荐逻辑，逐步形成个人偏好。

### 5.6 每次查词都是个人语料

Readlang/Reverso/Trancy 的共同点是把「查」变成「学」。Parrot 面向 AI super-individual，可以把学习定义得更宽：

- 单词学习：发音、词性、例句、SRS。
- 表达学习：常用回复、礼貌程度、语气差异。
- 专业学习：术语固定译法、项目词表。
- 个人风格：用户采纳过的改写和回复。

## 6. 功能机会清单

### P0：直接提升 first-pass rate / task success rate

| 功能 | 说明 | 建议落点 | 影响 |
| --- | --- | --- | --- |
| Quick Peek | 短文本/单词走轻量浮层，长文本再进入 workspace | macOS FloatingPanel / ResultView surface model | 缩短高频划词路径 |
| 段落双语阅读块 | 长文本优先显示原段落+译段落，provider cards 作为对照 | ParagraphSegmenter + ResultView | 提升长文理解连续性 |
| 任务 profile 默认推荐 | 根据入口和来源自动选 Quick/Understand/Reply/GitHub/Document | TranslationContextProfile | 减少用户配置负担 |
| 质量推荐结果 | 标记 best answer、低质量原因和 fallback | ResultQuality + result cards | 降低多引擎判断成本 |
| per-source 规则 | Always/Never/Default profile by app/domain/language | AppSettings + context origin | 降低重复操作 |
| 输入框改写/替换 MVP | 读取当前选中/剪贴板草稿，Polish/Translate 后复制或可选替换 | macOS selection/input flow | 把表达任务闭环 |

### P1：建立差异化和留存

| 功能 | 说明 | 建议落点 | 影响 |
| --- | --- | --- | --- |
| 学习记忆 | 收藏时保存原句、译文、来源、profile、最终采纳文本 | HistoryStore / terminology / vocabulary UI | 提升长期留存 |
| 表达库 | 保存用户常用回复、邮件句式、社交语气模板 | LearningWindows / iOS Express | 复用个人表达 |
| OCR 候选切换增强 | 显示候选块、置信度、快速删除噪声、重分段 | OCRCoordinator + workspace | 提高截图任务成功率 |
| 静默 OCR / 静默翻译 | 截图后直接复制识别文本或首选译文，可在通知中恢复工作区 | Screenshot flow | 面向工具型用户提速 |
| GitHub/Developer profile | 保护代码块、拆分 camelCase/snake_case、保留 Markdown | TranslationContext + prompts | 强化 AI builder 定位 |
| 隐私/成本状态条 | 显示本地/云端、遮罩数量、模型成本档位 | Result card metadata | 提升专业信任 |

### P2：暂缓但值得保留方向

| 功能 | 暂缓原因 | 何时做 |
| --- | --- | --- |
| 完整网页双语重排 | 浏览器插件工程量大，正面撞 Immersive Translate | Quick Peek/段落阅读跑通后 |
| PDF 原布局翻译 | OCR、排版、导出复杂，成本高 | 文档用户明确增长后 |
| 视频字幕/会议同传 | 音频、字幕、实时延迟和权限复杂 | iOS/macOS 核心任务成功率稳定后 |
| 图片 inpainting 翻译 | 视觉质量要求高，不是 Parrot 当前主战场 | OCR 翻译成熟后 |
| 团队术语/TMS | 太重，偏企业流程 | 个人术语和项目记忆已有强留存后 |

## 7. 推荐路线

### 0-30 天：把「原地快速理解」做好

- 实现或完成 Quick Peek 的交互闭环：短文本默认轻量浮层，支持复制、朗读、收藏、展开 workspace。
- 长文本在 workspace 中默认显示段落双语阅读块，provider cards 下沉为比较区。
- 对结果卡加入推荐状态和质量问题标签。
- 增加「本次来源下次默认使用此 profile」入口。
- 文案上明确 Parrot 是「任意 App 的跨语言理解与表达工作台」。

验收指标：

- 短文本从触发到可复制首选结果的时间下降。
- 用户不编辑/不重试直接复制的 first-pass rate 上升。
- 长文本任务中 provider card 切换次数下降，段落 copy/use 上升。

### 30-60 天：把「表达闭环」做好

- 做输入框改写/翻译 MVP：选中输入框内草稿或读取剪贴板，输出可复制或可替换。
- Native Polish 加差异视图和语气选项。
- Social/Reply/Email profile 输出多候选，支持直接保存为表达库。
- iOS Share Extension/Quick Lens 与 macOS 历史/收藏字段对齐。

验收指标：

- Polish/Reply 结果复制或回到来源 App 的 task success rate 上升。
- 用户二次编辑后重试率下降，说明 first answer 更接近可用。
- 常用表达被重复调用。

### 60-90 天：把「个人记忆」做好

- 历史升级为学习记忆：按来源、profile、术语、收藏、采纳文本检索。
- 从历史中一键添加术语、短语、回复模板。
- 生词/术语/表达复习入口，不追求完整教育产品，先做轻量回顾。
- 增加 app/domain/language 规则管理页。

验收指标：

- 第二周用户的历史复用率、术语命中率、表达库复用率上升。
- 有术语命中时用户修改结果的比例下降。
- per-source 规则命中的任务完成时间下降。

## 8. 建议的下一步 OpenSpec

如果要进入实现，建议拆成两个非重叠 OpenSpec change：

1. `add-quick-peek-and-bilingual-reading`
   - Quick Peek surface
   - Paragraph bilingual result block
   - Result recommendation labels
   - Acceptance: short selection, long selection, OCR, history reopen 都保持 source editable。

2. `add-source-rules-and-expression-memory`
   - per-source app/domain/language rules
   - saved phrase / expression memory fields
   - Native Polish diff/tone controls
   - Acceptance: rules affect future sessions, history can restore final adopted text and source context。

不建议立即做完整网页翻译/PDF 原布局导出。那是沉浸式翻译的主战场，Parrot 现阶段更应该利用 OS 级入口优势，把「任意 App 的理解和表达闭环」打穿。

## 9. 参考来源

- Immersive Translate: https://immersivetranslate.com/en/
- Immersive Translate Pricing/Privacy: https://immersivetranslate.com/en/pricing/
- Immersive Translate Chrome Web Store: https://chromewebstore.google.com/detail/immersive-translate-ai-we/bpoadfkcbjbfhfodiogcnhhhpibjhbnh
- Trancy: https://www.trancy.org/
- Mate Translate: https://matetranslate.com/en
- DeepL features: https://www.deepl.com/en/features
- DeepL Write: https://www.deepl.com/en/write
- Chrome Translate Help: https://support.google.com/chrome/answer/173424
- Microsoft Edge Translator Help: https://support.microsoft.com/en-us/topic/use-microsoft-translator-in-microsoft-edge-browser-4ad1c6cb-01a4-4227-be9d-a81e127fcb0b
- Safari Translate Help: https://support.apple.com/guide/safari/translate-a-webpage-ibrw646b2ca2/mac
- Apple Live Translation: https://support.apple.com/en-us/123720
- Readlang: https://readlang.com/
- Reverso Context: https://context.reverso.net/translation/
- Bob: https://github.com/ripperhe/Bob
- Easydict: https://github.com/tisfeng/Easydict
- Parrot 本地上下文：`README.md`
- Parrot 本地上下文：`docs/contextual-translation-workflows.md`
- Parrot 本地上下文：`docs/current-product-competitiveness-analysis.md`
- Parrot 本地上下文：`openspec/changes/optimize-contextual-translation-workflows/design.md`
