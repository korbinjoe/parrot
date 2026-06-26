# 翻译软件竞品深度调研

检索日期：2026-06-26
输出目的：为 Parrot / TeemAI 的翻译、语言润色、跨语言理解与表达能力提供产品决策输入。
范围说明：本报告基于公开网页检索，优先使用官方产品页、官方价格页、应用商店、云厂商文档、市场研究摘要与 WMT/ACL 等公开研究。价格、下载量、评分和套餐名称会变化，本文只作为检索时点快照。

## 1. 核心结论

翻译软件已经不是一个单一市场，而是被拆成了六个互相重叠的战场：

1. 免费通用翻译：Google Translate、Microsoft Translator、Apple Translate 负责“随手能翻”，靠免费、系统入口和语言覆盖建立默认选择。
2. 高质量文本与文档翻译：DeepL、Reverso、OpenL 等负责“翻得自然”，核心竞争点是语感、文档、术语和风格。
3. 沉浸式阅读翻译：沉浸式翻译、Mate Translate 等负责“在网页、PDF、字幕里读懂”，靠场景嵌入和双语对照建立粘性。
4. 中国区 AI 翻译生产力工具：百度翻译、有道翻译、腾讯翻译君等把翻译、学习、论文、办公、同传、文档和大模型能力打包。
5. 企业本地化 / TMS / CAT：Phrase、Lokalise、Smartling、Crowdin、Trados、memoQ 负责团队流程、翻译记忆、术语、审校、工程集成和合规。
6. API 与模型基础设施：Google Cloud Translation、Azure AI Translator、Amazon Translate、DeepL API、腾讯云、百度、有道、火山、阿里云、Lingvanex 等负责开发者和企业集成。

Parrot 不适合正面做“更便宜的翻译器”或“另一个 DeepL”。更有胜率的定位是：

> 跨语言理解与表达工作台：在任意 App、网页、截图、文档和输入场景中，把“翻译”升级成“读懂、判断、改写、回复、沉淀术语”的完整任务闭环。

现有 Parrot 资产和这个方向匹配度高：macOS / iOS、全局划词、截图 OCR、输入翻译、多引擎聚合、术语表、插件系统、历史收藏、TTS，已经具备“系统级入口 + 多引擎 + 个人上下文”的底座。下一步不应只堆更多引擎，而应围绕 first-pass rate 和 task success rate 做任务闭环。

## 2. 市场与技术趋势

### 2.1 市场不是小赛道，但增长点在生产流

Mordor Intelligence 估算机器翻译市场 2026 年约 12.6 亿美元，并预计 2031 年达到约 21.9 亿美元，2026-2031 年 CAGR 约 11.7%。Grand View Research、Business Research Insights 等也都将机器翻译和翻译管理系统描述为 AI、全球内容、本地化和跨境业务驱动的增长市场。

这类数字对 Parrot 的意义不是“市场够大所以可做”，而是说明翻译能力正在从工具层进入工作流层：

- 内容消费：网页、论文、视频、社交媒体、知识库。
- 内容生产：邮件、社媒回复、产品文案、论文、PRD、客服。
- 全球发布：软件本地化、文档、营销页面、App Store 元数据。
- 实时沟通：会议、通话、字幕、旅行。
- 基础设施：多语言 API、企业私有化、模型定制、术语约束。

### 2.2 LLM 改变竞争维度，但没有消灭专用翻译产品

WMT 2024 的通用机器翻译任务已经把 LLM 翻译质量纳入主流评测语境；多个研究和产业产品也显示，LLM 在长上下文、风格改写、解释、术语约束、低资源语言辅助上有优势。但专用 NMT / 翻译平台仍然有明显价值：

- 批量成本和延迟更可控。
- 文档翻译、格式保留、术语库、翻译记忆更成熟。
- 企业审计、权限、数据隔离和工作流更完整。
- 对用户来说，“能翻译”和“能完成我的任务”仍是两件事。

因此 Parrot 的策略不应是押注某一个模型，而应做多引擎路由、结果解释、术语约束、上下文保留和任务模式。

### 2.3 OS 与浏览器入口正在重塑默认行为

Google Translate 用 Android / Web / Chrome 入口覆盖大众场景；Apple Translate 和 Apple Intelligence 的 Live Translation 会把翻译推入系统通信场景；沉浸式翻译把网页、PDF、字幕变成双语阅读流。入口越靠近用户任务，越能抢占心智。

Parrot 的差异化空间在系统级“选择即处理”：不只在浏览器里翻译网页，也能在任意 macOS / iOS App 中处理选中文本、截图、输入框和社交回复。

## 3. 竞品全景

| 类别 | 代表产品 | 用户任务 | 竞争优势 | 典型短板 | 对 Parrot 的启示 |
|---|---|---|---|---|---|
| 免费通用翻译 | Google Translate、Microsoft Translator、Apple Translate | 临时翻译、旅行、图片、会话、离线 | 免费、覆盖广、入口强、语言多 | 缺少个人术语、上下文记忆、任务输出 | 不要做基础免费能力的正面对抗，要做任务增强层 |
| 高质量 AI 翻译 | DeepL、Reverso、OpenL | 高质量文本、文档、写作润色 | 译文自然、文档、风格、术语、企业安全 | 工作流仍偏翻译器，跨 App 操作弱 | DeepL 是质量标杆，Parrot 应做“质量 + 上下文 + 入口” |
| 沉浸式阅读 | 沉浸式翻译、Mate Translate | 网页、PDF、EPUB、字幕双语阅读 | 场景内翻译、双语对照、多引擎 | 写作/回复/术语长期记忆不足，浏览器外弱 | Parrot 可从 OS 级入口切入，并补齐表达闭环 |
| 中国 AI 翻译办公 | 百度翻译、有道翻译、腾讯翻译君 | 学习、论文、文档、会议、图片、社交 | 中文用户熟悉、本地服务、功能打包 | 产品复杂，跨平台和个人工作流割裂 | 中文场景必须支持论文、办公、社交表达 |
| 企业 TMS / CAT | Phrase、Lokalise、Smartling、Crowdin、Trados、memoQ | 软件本地化、团队翻译、审校、术语、记忆 | 工作流、权限、翻译记忆、集成、合规 | 对个人太重、采购复杂、价格高 | 早期不做完整 TMS，可借鉴术语/记忆/审校机制 |
| API 基础设施 | Google Cloud、Azure、AWS、DeepL API、国内云厂商、Lingvanex | 开发者集成、批量翻译、私有化 | 稳定、可计费、可扩展、合规 | 无终端体验，用户需自建工作流 | Parrot 应做 BYO Key、多引擎路由、成本可见 |
| AI 助手 | ChatGPT、Gemini、Claude、Kimi、豆包等 | 翻译、解释、润色、回复、总结 | 上下文、推理、改写、多模态 | 入口不总在用户当前 App，格式和术语不稳定 | Parrot 可以把 AI 助手能力产品化为固定模式 |

### 3.1 关键产品快照

| 产品 | 公开分发 / 入口 | 核心功能面 | 价格锚点 | 护城河 | Parrot 可攻击点 |
|---|---|---|---|---|---|
| Google Translate | Web、Android、iOS、Chrome、Google 生态；Android 10 亿+下载量级 | 文本、相机、图片、离线、会话、手写、短语本、网页/文档 | 消费端免费；Cloud Translation 按字符计费 | 免费默认选择、语言覆盖、Google 分发 | 不做基础替代，做专业上下文、术语、表达和多引擎 |
| Apple Translate | iOS / iPadOS / macOS 系统能力，Apple Intelligence 通信场景 | 文本、语音、会话、离线、系统通信 Live Translation | 系统内置 | 系统权限、隐私、设备端 | 做 Apple 没有的多引擎、术语、AI 解释、写作任务 |
| Microsoft Translator | App、Web、Office / Azure 生态 | 文本、语音、图片、多人对话、离线、API | 消费端免费；Azure 有免费层和标准字符计费 | 企业云、Office/Azure 渠道 | 作为企业/BYO Key 引擎；终端体验可更轻 |
| DeepL | Web、桌面、移动、浏览器扩展、API | 高质量文本、文档、Write、Voice、术语、风格、安全 | 美国价格页检索时显示个人/团队/企业订阅；API 为免费额度 + Pro 字符费 | 高质量心智、企业语言 AI | 系统级入口、中文/本土引擎、多任务输出、个人工作流 |
| 沉浸式翻译 | Chrome/Edge/Firefox/Safari 扩展、移动端浏览器、网页入口 | 双语网页、PDF、EPUB、字幕、图片、漫画、会议、多引擎 | 订阅制；Chrome Web Store 显示 300 万用户量级 | 场景内阅读、双语对照、多引擎生态 | 浏览器外、截图/OCR、写作/回复、个人术语闭环 |
| 百度翻译 | Web、App、桌面、开放平台 | 大模型翻译、203 种语言、文档、图片、论文精翻、译后编辑、同传 | 消费端免费/会员；API 按量 | 中文用户、论文学习、国内生态 | 产品较重；Parrot 可做轻量原生工作流和 BYO Key |
| 有道翻译 | Web、App、桌面、智云 API | 文本、文档、截屏、划词、AIBox、图片/视频/音频、同传、论文写作 | 消费端免费/会员；API 按量 | 学习场景、词典心智、中文教育 | 和 Parrot 在划词/截图重叠，Parrot 要强化多引擎和表达闭环 |
| Phrase / Lokalise / Smartling | Web SaaS、Git/Figma/CMS 集成 | TMS、Strings、翻译记忆、术语、审校、权限、AI、本地化流程 | 团队/企业订阅，价格从百美元/月到企业报价 | 工作流、协作、集成、采购 | 早期不打企业 TMS，借鉴轻量术语/记忆/QA |
| Trados / memoQ | 桌面 + 云，职业译员工作流 | CAT、翻译记忆、术语库、项目、QA、审校 | 专业软件订阅/授权 | 职业翻译资产管理 | 只吸收专业机制，不进入重型译员工具 |
| ChatGPT / Gemini / Claude 等 | Web、移动、API、系统集成 | 翻译、解释、润色、总结、回复、多模态 | 个人订阅 + API token 计费 | 通用推理和表达能力 | Parrot 把 prompt 产品化，并提供系统级入口和术语约束 |

### 3.2 价格与成本锚点

价格不是 Parrot 的主要差异化，但决定了引擎路由和商业模型。检索时点的公开价格呈现出三个规律：

| 层级 | 价格形态 | 代表 | 产品含义 |
|---|---|---|---|
| 消费免费 | 免费使用，部分能力内置系统或 App | Google Translate、Microsoft Translator、Apple Translate | 基础翻译没有收费空间，必须卖任务成功率 |
| 消费订阅 | 月付/年付，解锁高质量、无限制、文档、AI 或离线能力 | DeepL、沉浸式翻译、iTranslate、Reverso | 用户愿意为“更好结果 + 更少限制 + 场景效率”付费 |
| API 按量 | 字符、文档页、音频时长或 token 计费 | Google Cloud、Azure、AWS、DeepL API、国内云厂商、OpenAI | Parrot 需要成本可见和 BYO Key，否则托管成本难控 |
| 企业订阅 | 团队席位、项目、字符串、工作流、审校和安全能力 | Phrase、Lokalise、Smartling、Crowdin | 这是后期市场，不适合作为 Parrot 当前主战场 |

对产品定价的推导：

- 免费层应覆盖基本划词/截图翻译，否则用户会回到系统或 Google。
- Pro 层应围绕“任务效率”收费：高级模式、术语记忆、历史工作区、自动路由、同步、批量处理。
- 高成本模型不要默认无感消耗，应明确标注“高质量 / 高成本 / 云端”。
- BYO Key 会降低商业化天花板的一部分，但能显著提升专业用户信任和长期使用。

## 4. 重点竞品拆解

### 4.1 Google Translate

定位：默认的大众翻译基础设施。

公开信息显示，Google Translate Android 应用已达到 10 亿+下载，支持文本、离线、相机、照片、会话、手写和短语本等能力；Google Translate Web / App 也是大量用户的默认入口。Google Cloud Translation 则提供 Basic / Advanced / 自定义 / LLM / 批处理等开发者能力，并按字符计费。

强项：

- 分发极强：Web、Android、Chrome、Google 生态。
- 覆盖极广：多语言、离线、相机、对话、手写。
- 免费心智牢固：大众用户不会为“临时翻一下”付费。
- API 基础设施成熟：开发者和企业可直接接入。

弱项：

- 对专业文本、语气、收件人关系、个人术语的持续记忆弱。
- 翻译结果通常是终点，而不是后续行动入口。
- 多数场景不帮助用户判断“这句话该不该这么说”。

Parrot 应对：

- 把 Google 当作低成本基线引擎，而不是正面竞品。
- 在结果卡中提供“解释 / 自然表达 / 回复 / 术语检查 / 多引擎对照”。
- 对短文本提供快速结果，对高风险文本自动提示更稳的引擎或 LLM 模式。

### 4.2 DeepL

定位：高质量翻译和企业语言 AI。

DeepL 已经从翻译器扩展到 DeepL Write、DeepL Voice、API、企业套餐、术语表、风格规则、文档翻译和安全合规。公开价格页在美国区展示 Individual、Team、Business 等套餐；API 页面展示 Free / Pro 路线，Free 有月度字符额度，Pro 采用基础费 + 字符费模式。

强项：

- 高质量译文心智强，尤其在欧美语言和商务文本中。
- 文档翻译、术语表、风格规则、正式/非正式语气等生产力能力完整。
- 企业安全、SSO、管理、数据保护叙事成熟。
- API 可作为第三方产品质量兜底。

弱项：

- 入口仍偏翻译器和文档工具，跨 App 的上下文捕获不是核心。
- 面向个人“理解 -> 判断 -> 回复 -> 沉淀”的完整任务链不足。
- 对中国用户的生态入口、中文互联网场景和本土模型选择不如本地产品。

Parrot 应对：

- 默认把 DeepL 作为质量锚点：在高质量模式、文档片段、商务表达中优先推荐。
- 不复制 DeepL 的“纯翻译器”产品形态，而是做系统级工作流。
- 用术语表 + 个人语气 + 多版本输出解决 DeepL 结果仍需手工调的场景。

### 4.3 沉浸式翻译

定位：网页、PDF、EPUB、视频字幕的双语阅读层。

沉浸式翻译官网和 Chrome Web Store 展示其核心能力包括双语网页、PDF、EPUB、字幕、图片/漫画、会议、术语和多引擎；Chrome Web Store 显示 300 万用户量级，官网宣称 2000 万+用户。它已经证明“场景内翻译 + 双语对照 + 多引擎”是强需求。

强项：

- 把翻译放进真实阅读场景，而不是让用户复制粘贴。
- 双语对照降低信任成本，适合长文和学习。
- 多引擎和 AI 服务选择丰富。
- 浏览器扩展分发成本低，增长快。

弱项：

- 主要优势集中在浏览器和内容阅读。
- 写作、回复、发布、社交表达不是第一任务。
- 系统级文本选择、截图 OCR、原生 App 场景覆盖不足。
- 多引擎多配置对非技术用户可能复杂。

Parrot 应对：

- 避免复制“浏览器内双语网页”作为唯一卖点。
- 用 macOS / iOS 系统级入口覆盖浏览器外任务。
- 对阅读后的动作做闭环：总结、问答、提取术语、改写、回复、收藏。

### 4.4 Microsoft Translator / Azure AI Translator

定位：消费者翻译 + 企业云翻译基础设施。

Microsoft Translator 应用支持文本、语音、图片、对话和离线语言包；Azure AI Translator 则面向开发者和企业，公开价格页显示免费额度、标准文本翻译、文档翻译、自定义翻译等分层计费。

强项：

- Microsoft 生态和 Azure 企业渠道。
- 对会议、语音、多人对话、企业集成有基础。
- API 成本和 SLA 更适合企业采购。

弱项：

- 个人用户心智不如 Google Translate / DeepL。
- 终端体验更像工具集合，缺少强个人工作台叙事。

Parrot 应对：

- Azure 适合作为企业或 BYO Key 引擎。
- 对企业用户可强调用户直连 API Key、密钥自管、无代理转发。

### 4.5 Apple Translate / Apple Intelligence Live Translation

定位：系统内置、隐私优先、设备端体验。

Apple Translate 支持文本、语音、会话和离线语言；Apple Intelligence 的 Live Translation 继续把翻译推向 Messages、Phone、FaceTime、AirPods 等系统通信入口。

强项：

- 系统级入口和默认权限强。
- 隐私、设备端、本地体验心智强。
- 对通话和消息的实时场景有天然优势。

弱项：

- 语言覆盖、专业翻译和自定义能力不如专门平台。
- 不面向跨语言知识工作者的深度工作流。
- 对多引擎、术语表、文档理解和写作润色不够开放。

Parrot 应对：

- Apple 系统翻译可作为离线 / 隐私模式引擎之一。
- Parrot 的价值要在 Apple 原生能力之上：术语、AI 解释、多版本表达、历史、收藏、插件。

### 4.6 百度翻译 / 有道翻译 / 腾讯翻译君

定位：中国用户的学习、办公、论文、文档和同传翻译工具。

百度翻译官网强调 AI 大模型翻译、203 种语言、文本、文档、图片、AI 论文精翻、译后编辑、AI 同传等能力。有道翻译桌面端强调文本、文档、截屏、划词、AIBox、图片、视频、音频、同声传译、论文和写作。腾讯翻译君 / 腾讯云 TMT 覆盖文本、图片、语音、文件、音视频、同传和行业定制。

强项：

- 中文用户熟悉，中文语境和教育办公场景强。
- 功能打包完整：查词、学习、论文、文档、同传、OCR。
- 国内 API、合规和支付路径更顺。

弱项：

- 产品形态常较重，容易成为功能堆叠。
- 对专业用户的“个人上下文 / 术语 / 多引擎评估 / 工作流自动化”不够精细。
- 国际化、开发者可扩展性和透明成本管理弱于开源 / BYO Key 工具。

Parrot 应对：

- 中文场景不能只做英中互译，要覆盖论文、产品文档、社媒、邮件、PRD、跨境内容。
- 国内引擎应作为可选供应链，而不是把 Parrot 绑定为某一家云服务的前端。

### 4.7 Phrase / Lokalise / Smartling / Crowdin

定位：企业本地化平台和翻译管理系统。

这些产品面向团队和企业，核心能力包括翻译记忆、术语库、审校流程、权限、供应商管理、GitHub / GitLab / Figma / CMS 集成、机器翻译和 AI 辅助。公开价格页显示，Lokalise 和 Crowdin 有面向团队的阶梯套餐，Phrase 和 Smartling 更偏企业采购或高价团队套餐。

强项：

- 工作流成熟：任务分配、审校、版本、权限、质量检查。
- 对软件本地化、字符串、设计稿、文档和营销内容集成深入。
- 术语和翻译记忆是刚需，不是附属功能。

弱项：

- 对个人用户和小团队太重。
- 采购门槛高、学习成本高、配置复杂。
- 主要解决“发布多语言内容”，不是“日常跨语言理解与表达”。

Parrot 应对：

- 不要早期进入完整 TMS。
- 借鉴术语库、翻译记忆、质量检查、审校标注，但保持个人工具轻量。
- 未来可做“个人术语 / 记忆导出到 TMS”的接口，而不是替代 TMS。

### 4.8 Trados / memoQ

定位：专业译员和语言服务商的 CAT 工具。

Trados、memoQ 这类工具强调翻译记忆、术语库、项目管理、审校、桌面端或云端工作流，是职业翻译和语言服务公司的基础工具。

强项：

- 翻译记忆、术语、分段、质量检查、项目交付成熟。
- 专业译员工作流稳定。
- 对大型文档和客户资产管理能力强。

弱项：

- 对非译员太重，不适合普通知识工作者。
- 用户任务是“翻译生产”，不是“理解信息并做下一步行动”。

Parrot 应对：

- 只吸收“术语一致性、记忆复用、质量检查”的轻量版本。
- 不把 Parrot 变成 CAT 工具，否则会偏离 AI super-individual 的日常效率场景。

### 4.9 ChatGPT / Gemini / Claude / Kimi / 豆包等 AI 助手

定位：通用 AI 助手，间接吞噬翻译、解释、润色和写作场景。

AI 助手的竞争威胁不在“翻译按钮”，而在它们能理解上下文、解释语气、生成多版本表达、辅助回复和总结长文。很多用户已经把 ChatGPT 当翻译 + 润色 + 外语写作工具。

强项：

- 能处理上下文、意图、受众、语气和格式。
- 能解释为什么这么翻，也能给替代表达。
- 可直接完成“翻译后动作”：总结、回复、改写、提纲、邮件。

弱项：

- 入口通常不在用户正在看的 App 中。
- 结果稳定性、术语一致性和格式保留需要产品化约束。
- 高质量模型成本高，用户难以判断何时值得调用。
- 隐私和企业合规取决于服务和配置。

Parrot 应对：

- 把 AI 助手能力拆成稳定的产品模式：翻译、解释、润色、回复、总结、术语检查。
- 让用户不需要写 prompt，也能获得可复用的跨语言输出。
- 引入成本/隐私/质量路由，而不是每次都让用户手动选择模型。

## 5. 用户任务拆解

| JTBD | 用户原话 | 当前强竞品 | 未满足需求 | Parrot 产品机会 |
|---|---|---|---|---|
| 临时看懂一句话 | “这句话什么意思？” | Google、Apple、Microsoft | 上下文、双关、行业术语解释 | 选中文本后给译文 + 语境解释 + 关键词 |
| 看懂网页 / PDF | “我想快速读懂这篇外文资料” | 沉浸式翻译、Google、DeepL | 阅读后的总结、问答、收藏、术语沉淀 | 阅读模式：双语、摘要、问答、术语抽取 |
| 写出自然表达 | “我知道中文意思，但英文怎么说才自然？” | DeepL Write、ChatGPT、Grammarly | 语气、受众、平台格式、个人风格 | 翻译 + 润色 + 多版本表达 + 语气选择 |
| 回复跨语言消息 | “帮我得体地回这条消息” | ChatGPT、iOS 社交助手类能力 | 上下文搬运麻烦、关系语气不稳定 | 社交 / 邮件回复模式，保留原文上下文 |
| 翻译专业文本 | “术语不能错，产品名不能乱翻” | DeepL、TMS、CAT | 个人术语和记忆轻量化 | 术语表、严格术语模式、命中提示、违规检查 |
| 批量 / 文档翻译 | “帮我翻完整文档且格式别乱” | DeepL、Google Cloud、百度、有道 | 格式、质量检查、成本 | 先做片段/章节级高质量，不急做完整排版引擎 |
| 会议 / 音视频 | “边听边看字幕” | Microsoft、Apple、腾讯、百度、有道 | 实时性、准确性、隐私 | 不是当前首要战场，可作为 P2 |
| 软件本地化 | “多语言 strings 怎么管理？” | Phrase、Lokalise、Crowdin、Trados | 对个人产品 builder 太重 | 后续做轻量术语/字符串辅助，不做完整 TMS |

## 6. 关键痛点与机会区

### 6.1 用户真正要的不是翻译，而是可用输出

普通翻译器给出“目标语言文本”就结束了，但用户真实任务经常是：

- 看懂原文立场和隐含语气。
- 判断译文是否可信。
- 把译文改成适合邮件、Slack、社媒、论文、产品文档的格式。
- 避免误翻产品名、术语、缩写和人名。
- 根据上下文回复，而不是孤立翻译一句话。

机会：把结果卡从“原文/译文”升级为“理解/表达工作台”。

### 6.2 多引擎时代，用户不想做调度员

Parrot 已经有大量引擎。引擎多不是用户价值本身，用户价值是：

- 快速：默认低延迟引擎先给结果。
- 稳定：高风险内容自动触发高质量引擎。
- 可解释：告诉用户不同结果差异在哪里。
- 可控：展示成本、隐私和是否使用云服务。
- 可复用：术语、语气、历史偏好会影响下一次输出。

机会：做“引擎路由 + 结果仲裁”，而不是只做“引擎列表”。

### 6.3 双语对照降低信任成本，但还不够

沉浸式翻译证明了双语对照的价值：用户需要保留原文来核对。但下一层需求是：

- 哪个词是关键术语？
- 这一句是不是机器翻译腔？
- 有没有文化语境或礼貌风险？
- 可以更短、更正式、更像母语者吗？

机会：在双语视图上叠加“术语、语气、风险、替代表达”。

### 6.4 个人术语和语气是小团队的护城河

企业 TMS 证明术语库和翻译记忆有价值，但个人工具通常没有把它做轻：

- 用户不想维护复杂项目库。
- 但用户确实希望产品名、项目名、团队黑话、固定译法不再出错。
- 用户希望“我改过一次，下次别再错”。

机会：把术语表从设置页能力升级为结果卡内的反馈闭环。

## 7. Parrot 推荐定位

### 7.1 一句话定位

Parrot 是给 AI super-individual 的跨语言理解与表达工作台：在任意地方选中、截图或输入内容，立即读懂、改写、回复，并让个人术语和语气持续生效。

### 7.2 目标用户

优先用户：

- AI product builder：阅读英文文档、论文、GitHub issue、产品资料，并需要写英文回复、PRD、发布文案。
- 跨境知识工作者：邮件、客服、社媒、商务沟通、跨语言资料整理。
- 研究/学习型用户：论文、博客、视频字幕、技术资料。
- 小团队创始人/独立开发者：需要轻量本地化、产品文档和应用内文案翻译。

不优先：

- 旅行游客：Google / Apple / Microsoft 已覆盖。
- 职业翻译团队：CAT / TMS 已覆盖。
- 大企业本地化采购：Phrase / Lokalise / Smartling 已覆盖。
- 纯 API 调用方：云厂商已覆盖。

### 7.3 价值主张

| 价值 | 具体表达 |
|---|---|
| 少搬运 | 任意 App 划词、截图、输入框触发，不要求复制到网页 |
| 更可信 | 原文、译文、解释、术语命中、替代表达同时显示 |
| 更可用 | 一键得到自然版、正式版、简短版、回复版、社媒版 |
| 更个性化 | 术语、固定译法、个人语气、历史偏好持续生效 |
| 更可控 | BYO Key、多引擎、成本可见、隐私模式、离线/本地引擎 |

## 8. 产品路线建议

### P0：把“翻译结果”升级为“可用结果”

1. 结果卡增加任务模式：
   - 直译：忠实、快速、低成本。
   - 自然表达：更像母语者。
   - 商务/正式：适合邮件和合作沟通。
   - 社交回复：保留上下文并输出可直接发送的回复。
   - 技术解释：术语、缩写、上下文解释。

2. 多版本输出：
   - 默认给一个推荐版本。
   - 可展开 2-3 个备选，不要把所有引擎原始结果平铺给用户。
   - 每个版本给短标签：`忠实`、`自然`、`更短`、`正式`。

3. 术语闭环：
   - 结果中高亮术语命中。
   - 用户改动译文时，提示是否加入术语。
   - 下次同类文本自动应用。
   - 统计术语违规率，作为 first-pass rate 的反向指标。

4. 引擎路由：
   - 短文本默认快引擎。
   - 专业/长文本/用户开启高质量时调用 DeepL 或 LLM。
   - 涉及隐私时优先本地或系统翻译。
   - 展示“本次使用云服务/本地/用户自有 Key”。

5. 质量反馈：
   - `复制`、`替换`、`收藏`、`重新生成`、`手动编辑`都应计入质量信号。
   - 将“用户第一次就复制/替换”定义为 first-pass success 的主要 proxy。

### P1：沉浸式阅读与资料工作流

1. 网页 / PDF 片段阅读：
   - 不急做完整浏览器扩展，可以先从截图 OCR、选中文本、剪贴板 URL、PDF 选区切入。
   - 支持原文/译文对照、段落摘要、关键词、问答。

2. 资料沉淀：
   - 翻译历史按来源、主题、术语、语言聚合。
   - 一键把术语加入个人词库。
   - 对长文生成“中文摘要 + 原文引用点 + 术语表”。

3. 跨语言写作：
   - 输入中文意图，生成英文邮件/回复/issue/comment。
   - 对选中的英文草稿做 polish，不强制走翻译路径。
   - 支持“保留我原来的意思，但更自然”。

### P2：轻量协作与发布

1. 小团队术语共享：
   - 导入/导出 CSV。
   - 项目级术语和个人级术语分层。

2. 字符串/文案辅助：
   - 支持选中文案批量改写/翻译。
   - 不做完整 TMS，但可为开发者输出 JSON / strings / Markdown 片段。

3. 会议/字幕：
   - 若后续进入音视频，需要先明确实时延迟、隐私和模型成本。
   - 当前不建议作为第一增长点。

## 9. 指标体系

### 9.1 First-pass rate

定义：用户在第一次生成后，不需要重试或大幅修改，就完成目标动作。

可观测指标：

- 首次结果复制率。
- 首次结果替换到输入框的比例。
- 首次结果后 30 秒内是否触发重试。
- 用户手动编辑距离。
- 术语违规次数。
- 多版本中推荐版本被选择的比例。

### 9.2 Task success rate

按任务分层统计，而不是只看“翻译调用成功”：

| 任务 | 成功事件 |
|---|---|
| 快速理解 | 用户关闭卡片前停留足够时间，未重试，未切换引擎 |
| 写作润色 | 用户复制/替换 polished 结果 |
| 社交回复 | 用户选择 reply 模式并复制结果 |
| 专业术语 | 术语全部命中且未被用户修正 |
| 阅读资料 | 用户收藏、摘要、问答或添加术语 |

### 9.3 质量评测方法

建议建立内部 benchmark：

- 语料类型：技术文档、产品文案、论文摘要、社交消息、商务邮件、用户评论、代码注释。
- 语言方向：英中、中英优先；再扩展日中、韩中、英日等。
- 对照引擎：Google、DeepL、Microsoft、百度、有道、OpenAI-compatible LLM、Apple 系统翻译。
- 评价维度：准确性、自然度、术语一致性、语气适配、格式保持、可直接使用程度。
- 关键指标：Parrot 推荐版本相对单引擎的 first-pass rate 提升。

## 10. 商业与定价启示

竞品价格锚点：

- 免费层：Google Translate、Microsoft Translator、Apple Translate 将基础翻译价格压到 0。
- 个人高级层：DeepL、沉浸式翻译、iTranslate、Reverso 等多在月付/年付订阅区间内竞争。
- API 层：Google、AWS、Azure、DeepL、国内云厂商大多按字符计费；高质量 LLM 输出还会叠加 token 成本。
- 企业层：Phrase、Lokalise、Smartling 等从团队套餐到企业报价，价格明显高于个人工具。

对 Parrot 的建议：

1. 不要按“翻译字符”直接卖给个人用户。个人用户会和免费工具比较，感知价值低。
2. 适合卖“工作流效率”：系统级入口、多模式输出、术语/记忆、历史、隐私、BYO Key、高级路由。
3. BYO Key 是差异化：让重度用户自己控制成本和数据流向。
4. 如果未来做托管模型额度，需要把“快速/高质量/隐私”模式清楚区分，避免成本不可控。
5. 开源产品可考虑 Pro 功能集中在原生体验、同步、术语记忆、工作区和高级自动化，而不是基础翻译调用。

## 11. 风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| Google / Apple 系统级能力继续增强 | 基础翻译入口被平台吃掉 | 聚焦专业任务、术语、AI 表达和多引擎 |
| DeepL 推出更强跨 App 工具 | 高质量心智被进一步强化 | 用 OS 入口 + BYO Key + 本土引擎 + 个性化做差异 |
| 沉浸式翻译扩展到桌面端 | 阅读场景竞争加剧 | 避免浏览器单点竞争，强化截图/任意 App/回复 |
| LLM 成本波动 | 托管功能毛利不稳定 | 默认 BYO Key，路由分级，缓存和轻量模型优先 |
| 功能过多导致复杂 | 用户不知道该点什么 | 默认推荐一个结果，高级能力渐进展开 |
| 术语维护成本高 | 用户不愿配置 | 从用户修改行为自动建议术语，不强迫手填 |

## 12. 近期产品决策清单

建议立刻做：

- 把结果卡的主要 CTA 从“复制译文”升级为“复制推荐表达 / 替换原文 / 继续改写”。
- 增加固定任务模式：翻译、解释、润色、回复。
- 让术语表进入结果卡反馈闭环，而不只在设置页。
- 增加推荐引擎策略：快、准、隐私、便宜四种清晰模式。
- 建立 first-pass rate 的事件埋点定义。

建议延后：

- 完整 PDF 排版翻译。
- 实时会议同传。
- 企业 TMS。
- 旅行相机翻译。
- 自建翻译模型。

需要继续调研：

- Parrot 当前用户实际触发场景占比：划词、OCR、输入、PopClip、iOS 社交。
- 用户最常用语言方向和内容类型。
- 高质量模式下 DeepL 与 LLM 的实际 first-pass rate。
- 用户是否愿意为 BYO Key + 本地原生工作流付费。

## 13. 来源索引

市场与研究：

- Mordor Intelligence, Machine Translation Market: https://www.mordorintelligence.com/industry-reports/machine-translation-market
- Grand View Research, Machine Translation Market: https://www.grandviewresearch.com/industry-analysis/machine-translation-market-report
- WMT 2024 Findings of the General Machine Translation Task: https://www2.statmt.org/wmt24/pdf/2024.wmt-1.2.pdf

通用翻译与 OS 入口：

- Google Translate on Google Play: https://play.google.com/store/apps/details?id=com.google.android.apps.translate
- Google Translate Help: https://support.google.com/translate/
- Microsoft Translator: https://translator.microsoft.com/
- Microsoft Translator on Google Play: https://play.google.com/store/apps/details?id=com.microsoft.translator
- Apple Translate User Guide: https://support.apple.com/guide/iphone/translate-text-voice-conversations-iph206d53f92/ios
- Apple Intelligence Live Translation announcement: https://www.apple.com/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/

高质量翻译与 AI 写作：

- DeepL Pro: https://www.deepl.com/en/pro
- DeepL API: https://www.deepl.com/en/pro-api
- DeepL Write: https://www.deepl.com/write
- DeepL Voice: https://www.deepl.com/en/products/voice
- Reverso Translation: https://www.reverso.net/text-translation
- iTranslate: https://itranslate.com/
- Naver Papago: https://papago.naver.com/

沉浸式阅读：

- Immersive Translate: https://immersivetranslate.com/
- Immersive Translate Chrome Web Store: https://chromewebstore.google.com/detail/immersive-translate-ai-we/bpoadfkcbjbfhfodiogcnhhhpibjhbnh
- Mate Translate: https://gikken.co/mate-translate/

中国区产品与云服务：

- 百度翻译: https://fanyi.baidu.com/
- 百度翻译开放平台: https://fanyi-api.baidu.com/
- 有道翻译: https://fanyi.youdao.com/
- 有道智云: https://ai.youdao.com/
- 腾讯云机器翻译 TMT: https://cloud.tencent.com/product/tmt
- 腾讯云机器翻译文档: https://cloud.tencent.com/document/product/551
- 火山引擎机器翻译: https://www.volcengine.com/product/translate
- 阿里云机器翻译: https://www.aliyun.com/product/ai/almt

企业 TMS / CAT：

- Phrase Pricing: https://phrase.com/pricing/
- Lokalise Pricing: https://lokalise.com/pricing/
- Smartling Plans: https://www.smartling.com/plans
- Crowdin Pricing: https://crowdin.com/pricing
- Trados Pricing: https://www.trados.com/pricing/
- memoQ Pricing: https://www.memoq.com/pricing

API 与基础设施：

- Google Cloud Translation Pricing: https://cloud.google.com/translate/pricing
- Google Cloud Translation Documentation: https://cloud.google.com/translate/docs
- Azure AI Translator Pricing: https://azure.microsoft.com/pricing/details/cognitive-services/translator/
- Azure AI Translator Documentation: https://learn.microsoft.com/azure/ai-services/translator/
- Amazon Translate Pricing: https://aws.amazon.com/translate/pricing/
- Amazon Translate Features: https://aws.amazon.com/translate/features/
- Lingvanex Translation API: https://lingvanex.com/translationapi/
- OpenAI API Pricing: https://openai.com/api/pricing/
- ChatGPT Pricing: https://openai.com/chatgpt/pricing/
