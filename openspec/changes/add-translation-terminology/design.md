# Design: 翻译术语表与专业名词保留

## Context

当前 Parrot 已有多引擎聚合、LLM 内置、插件系统和设置页密钥管理，但“翻译时必须这样处理某个词”还没有产品化。现状约束：

- `TranslateRequest` 只有 `text/from/to/mode`，无法携带术语约束。
- `OpenAICompatEngine.systemPrompt(for:)` 是固定 prompt，不能读取用户自定义术语。
- LLM 设置只支持 `apiKey/model/endpoint`，没有 prompt 或术语配置。
- DeepL、Google、腾讯、百度、有道、彩云、Microsoft 等传统引擎当前只发送基础翻译字段。
- 插件系统已经支持自定义 options，但没有宿主级统一术语对象。

## Goals / Non-Goals

**Goals:**

1. 用户可以定义 `AI Agent -> AI Agent` 这类专业名词保留规则，并默认应用到所有翻译入口。
2. 多引擎同屏结果使用同一份术语快照，保证比较结果时规则一致。
3. 无 native glossary 的引擎也能通过占位符保护获得基本术语稳定性。
4. LLM 引擎能收到明确术语约束，减少风格和上下文被占位符破坏的问题。
5. UI 让用户清楚看到术语是否命中、是否被严格应用、哪些引擎只是尽力。
6. 插件可逐步适配术语，旧插件不破坏。

**Non-Goals:**

- 首版不做账号同步、团队协作、云端术语库。
- 首版不做翻译记忆库。
- 首版不做复杂正则规则；先支持短语级精确匹配和大小写敏感配置。
- 首版不要求每个官方 API 的 native glossary 都接完；先把宿主模型和通用策略落地。

## User Experience

### 默认体验

普通翻译不增加任何步骤。用户在设置中维护术语后，所有入口自动应用：

- 划词翻译
- 输入翻译
- 截图 OCR 后翻译
- 历史再翻译
- iOS 社交理解/表达中走 `TranslationProvider` 的请求

### 设置页：术语

设置窗口新增「术语」分区，信息结构：

| 字段 | 说明 |
|------|------|
| 源词 | 用户原文中会出现的词或短语，例如 `AI Agent` |
| 译法 | 目标输出中必须使用的词，例如 `AI Agent` |
| 语言对 | 默认 `任意 -> 中文`，可选具体源语言 |
| 匹配 | 默认短语精确匹配；可选大小写敏感 |
| 备注 | 可选，用于说明领域或上下文 |
| 启用 | 单条术语可禁用 |

关键交互：

- 顶部开关：`启用术语表`。
- 搜索框：按源词、译法、备注过滤。
- 新增按钮：打开紧凑表单，默认目标语言跟随 App 默认目标语言。
- 冲突提示：相同语言对下源词重复时阻止保存；源词包含关系时提示按最长匹配优先。
- 导入/导出：CSV，字段为 `source,target,from,to,caseSensitive,note,enabled`。

### 结果卡反馈

每个引擎结果卡显示一个小标签：

- `术语已应用 · 2`：命中并通过占位符或 native glossary 恢复。
- `术语约束 · 2`：LLM prompt 注入，未使用强制占位符。
- `术语未命中`：术语表开启但本次文本没有匹配。
- `不支持术语`：引擎或插件声明不支持，且宿主无法安全前后处理。

点击标签可展开命中明细：`AI Agent -> AI Agent`。首版只做只读说明，不做就地修改。

## Data Model

```swift
public struct TerminologyEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var source: String
    public var target: String
    public var from: Language
    public var to: Language
    public var note: String?
    public var caseSensitive: Bool
    public var enabled: Bool
}

public struct TerminologySnapshot: Codable, Equatable, Sendable {
    public let entries: [TerminologyEntry]
    public let strictMode: Bool
    public let createdAt: Date
}

public enum TerminologyApplicationStrategy: String, Codable, Sendable {
    case nativeGlossary
    case placeholder
    case prompt
    case promptAndPlaceholder
    case unsupported
}

public struct TerminologyApplication: Codable, Equatable, Sendable {
    public let strategy: TerminologyApplicationStrategy
    public let matches: [TerminologyMatch]
}
```

`TranslateRequest` 增加：

```swift
public let terminology: TerminologySnapshot?
```

`TranslateResult` 或 `AggregatedOutcome` 增加：

```swift
public let terminologyApplication: TerminologyApplication?
```

## Matching Rules

1. 只匹配启用的术语。
2. 语言对匹配规则：
   - `from == .auto` 的术语可匹配任意源语言。
   - `to` 必须匹配请求目标语言；`.auto` 不用于目标语言。
3. 源词和目标译法都必须 trim 后非空。
4. 同一请求中按源词长度降序匹配，避免 `Agent` 抢先匹配 `AI Agent`。
5. 默认大小写不敏感；勾选大小写敏感时使用精确大小写。
6. MVP 不做词形还原，不把 `agents` 自动视为 `agent`。
7. 匹配完成后生成不可变 `TerminologySnapshot`，并随请求传入所有 Provider。

## Engine Strategy

### D1 — 通用占位符保护

对传统机翻和未声明 native glossary 的引擎，宿主在发送前做保护：

1. 从原文中找出术语命中。
2. 将命中片段替换为稳定占位符，例如 `PARROTTERM0001`。
3. 调用引擎翻译。
4. 在译文中把占位符恢复为术语目标译法。

示例：

```text
源文：AI Agent should preserve user intent.
术语：AI Agent -> AI Agent
发送：PARROTTERM0001 should preserve user intent.
恢复：AI Agent 应保留用户意图。
```

权衡：占位符可能轻微影响句法自然度，但能最大化跨引擎稳定性。对短语和产品名这是合理默认。

### D2 — LLM prompt 注入

LLM 引擎在 system prompt 中追加术语约束：

```text
Terminology constraints:
- AI Agent => AI Agent
- prompt engineering => 提示词工程

Use the exact target term whenever the source term appears.
Do not translate or paraphrase protected product names.
```

默认 LLM 使用 `prompt` 策略；当用户打开「严格术语模式」时使用 `promptAndPlaceholder`。

### D3 — Native glossary adapter

未来某个 Provider 支持官方 glossary 时，接入 `nativeGlossary`：

- Provider 声明 `terminologyStrategy == .nativeGlossary`。
- 宿主将活跃术语转换为该服务要求的 glossary id 或请求参数。
- native 失败时降级到 placeholder，并在结果状态中标记降级。

首版只预留接口，不强制所有引擎接 native glossary。

### D4 — 插件兼容

插件 `query` 增加：

```js
query.terminology = [
  { source: "AI Agent", target: "AI Agent", from: "en", to: "zh", note: "" }
]
```

旧插件忽略该字段即可。新插件可在 manifest 声明：

```json
{ "capabilities": ["translate"], "supportsTerminology": true }
```

宿主仍可在调用插件前后执行 placeholder 策略，除非插件声明自己处理术语。

## Persistence

术语表不是 secret，使用本地 JSON 存储即可：

- macOS：`Application Support/Parrot/terminology.json`
- iOS：App Group store 中的 `terminology.json`

写入策略：

- 保存时做 schema version。
- 每次翻译前从 `AppSettings` / store 读取内存态并生成 snapshot。
- 导入 CSV 时先预览新增、覆盖、冲突数量，再确认写入。

## UI Design Details

设置窗口「术语」分区应保持工具属性，不做营销式解释：

- 左侧仍用现有设置侧栏。
- 主区顶部为搜索 + 新增 + 导入/导出图标按钮。
- 术语列表使用紧凑表格或行列表，不使用大卡片。
- 每行主文本：`source -> target`。
- 次文本：语言对、大小写、备注。
- 行尾：启用 toggle、编辑、删除图标按钮。
- 空态只显示短文案和新增按钮。

## Edge Cases

| 场景 | 处理 |
|------|------|
| 源词为空或目标为空 | 禁止保存 |
| 重复源词 + 语言对 | 阻止保存，提示编辑已有条目 |
| 多条术语重叠 | 长词优先 |
| 占位符被引擎改写 | 尝试大小写不敏感恢复；失败时标记 `术语恢复失败` |
| 译文中已含目标译法 | 不重复替换 |
| 查词模式 | 默认不应用术语表，除非后续增加词典覆盖能力 |
| 润色模式 | 只对同语种或目标语言匹配的术语应用 prompt 约束，不做源文占位符 |

## Migration

无数据迁移要求。首次启动术语表为空。可以在 README 或 docs 中提供示例：

```csv
source,target,from,to,caseSensitive,note,enabled
AI Agent,AI Agent,en,zh,true,产品/AI 领域,true
LLM,LLM,en,zh,true,模型简称,true
prompt engineering,提示词工程,en,zh,false,AI 术语,true
```

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 占位符影响翻译流畅度 | LLM 默认 prompt 策略；严格模式才叠加占位符 |
| 机器翻译改写占位符导致恢复失败 | 使用简单 ASCII token；增加恢复失败状态和单测 |
| 用户误以为所有引擎 100% 支持 | 结果卡展示策略标签；设置说明 native/prompt/placeholder 差异 |
| 术语表 UI 变复杂 | MVP 只做源词、译法、语言对、大小写、备注、启用 |
| 插件破坏兼容 | `query.terminology` 为新增可选字段，旧插件无感 |

## Rollout

1. 先落地 Core 术语模型、匹配器、placeholder pipeline 和单测。
2. 接入 LLM prompt 注入和聚合结果元数据。
3. 接入设置页术语管理。
4. 再接插件透传、CSV 导入导出和 docs。
5. 最后评估 native glossary adapter 的实际投入优先级。
