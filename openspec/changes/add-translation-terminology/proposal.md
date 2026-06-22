# Proposal: 翻译术语表与专业名词保留

- **Change name**: `add-translation-terminology`
- **Status**: Proposed
- **Date**: 2026-06-22
- **Owner**: product-design
- **Related**: `translation-engine`, `app-ui`, `plugin-system`

## Why

Parrot 的核心价值不是“把一段文字机械换成另一种语言”，而是让用户在真实工作流里快速得到可信、可复用的表达。专业用户最常遇到的失败不是整体语义错，而是关键术语被翻错：例如 `AI Agent` 被翻成 `AI 代理`、`prompt` 被翻成 `提示`、产品名或团队内部名词被意外本地化。一个错误术语会直接破坏可信度，用户必须反复手改，长期会放弃使用多引擎结果。

当前项目没有全局术语模型：`TranslateRequest` 只携带文本、语言和模式；LLM prompt 固定；设置页只暴露 key/model/endpoint；传统机翻也没有统一术语策略。因此需要把“术语表”定义为 Parrot 的一等产品能力，而不是散落在某个 LLM prompt 或单个插件里的临时配置。

## What Changes

- 新增全局 **术语表 Terminology** 能力：用户可以维护源词、目标译法、语言对、备注、大小写敏感和启用状态。
- 翻译请求携带一次性的 `TerminologySnapshot`，保证一次多引擎聚合使用同一组术语规则。
- 引入统一术语应用管线：
  - 对机器翻译和不支持术语的引擎，使用占位符保护 + 译后恢复，尽量保证关键术语稳定。
  - 对 LLM 引擎，在 system prompt 中注入术语约束；严格模式下也可叠加占位符保护。
  - 对未来支持官方 glossary 的服务，保留 native glossary adapter。
- 设置页新增 **术语** 分区，支持增删改、启停、语言对过滤、冲突提示、CSV 导入/导出。
- 结果卡展示术语应用状态：`术语已应用`、`术语尽力保留`、`该引擎不支持术语`，避免用户误以为所有引擎都有同等保证。
- 插件查询对象扩展 `terminology` 字段，插件可读取术语表；未适配插件继续按现有接口运行。

## Product Principles

1. **术语是用户的语言契约**：同一个词在同一个团队/领域里必须稳定，不应由引擎每次自由发挥。
2. **默认少配置、关键处可控**：普通用户无需理解术语表；专业用户能用最少字段锁定关键表达。
3. **透明优于假保证**：不同引擎支持程度不同，UI 必须展示实际应用策略和局限。
4. **一次请求一致**：多引擎聚合结果必须基于同一份术语快照，不能因设置变化导致同屏结果规则不一致。

## Capabilities

### New Capabilities

- `translation-terminology`: 全局术语表模型、匹配、应用策略、导入导出和验收标准。

### Modified Capabilities

- `translation-engine`: `TranslateRequest` 增加术语快照；Provider 能力描述增加术语支持级别；LLM prompt 和普通引擎请求走统一术语管线。
- `app-ui`: 设置页增加术语管理分区；结果卡展示术语应用状态；输入/结果工作流提供轻量术语入口。
- `plugin-system`: 插件 `query` 对象透传术语数组，manifest 可声明术语支持。

## Non-Goals

- 不在首版实现云端账号同步或团队共享术语库。
- 不承诺所有第三方机器翻译都能 100% 遵守术语；无 native glossary 的引擎先走占位符保护和译后恢复。
- 不做复杂 CAT 工具能力，例如术语审核流、翻译记忆库、批量语料对齐。
- 不改变现有多引擎聚合排序模型。

## Impact

| 区域 | 影响 |
|------|------|
| `Sources/ParrotCore/` | 新增术语模型、匹配器、快照、请求/结果元数据 |
| `Sources/ParrotEngines/` | LLM prompt 注入；传统引擎前后处理；未来 native glossary adapter |
| `Sources/ParrotApp/AppSettings.swift` | 本地术语持久化、启用状态、导入导出 |
| `Sources/ParrotApp/SettingsWindow.swift` | 新增术语分区和编辑表单 |
| `Sources/ParrotApp/ResultView.swift` | 每个结果卡展示术语应用状态和命中数 |
| `Sources/ParrotPlugins/` | `query.terminology` 透传；manifest 支持声明 |
| `Tests/` | 术语匹配、占位符保护、LLM payload、UI 状态映射、插件兼容测试 |
| `docs/` | 术语表使用说明与 CSV 格式 |
