# Tasks: 翻译术语表与专业名词保留

## 阶段 0 — 方案与规格

- [x] 0.1 [设计] 创建 OpenSpec proposal/design/tasks
- [x] 0.2 [设计] 增量更新 `translation-engine` / `app-ui` / `plugin-system` specs

## 阶段 1 — Core 术语模型与匹配

- [x] 1.1 [实现] 新增 `TerminologyEntry`、`TerminologySnapshot`、`TerminologyMatch`、`TerminologyApplication` 模型
- [x] 1.2 [实现] 新增 `TerminologyStore`，本地 JSON 持久化，支持 macOS Application Support 与 iOS App Group 路径
- [x] 1.3 [实现] 新增 `TerminologyMatcher`：语言对过滤、大小写敏感、最长优先、重叠消解
- [x] 1.4 [测试] 覆盖 `AI Agent -> AI Agent`、大小写敏感、重复/嵌套术语、无命中、语言对不匹配

## 阶段 2 — 翻译管线接入

- [x] 2.1 [实现] 扩展 `TranslateRequest`，增加可选 `terminology` 快照
- [x] 2.2 [实现] 扩展 `TranslateResult` 或 `AggregatedOutcome`，携带术语应用策略、命中数和失败状态
- [x] 2.3 [实现] 在 `TranslationCoordinator` 发起聚合前生成一次术语快照，并复用到所有 Provider
- [x] 2.4 [实现] 新增 placeholder 保护/恢复工具，供传统引擎和插件复用
- [x] 2.5 [实现] 为 `OpenAICompatEngine` 和 `GeminiEngine` 注入术语 prompt；严格模式支持 prompt + placeholder
- [x] 2.6 [测试] 验证多引擎同一请求使用同一术语快照，异步返回不丢失术语元数据
- [x] 2.7 [测试] 验证 LLM JSON payload 中包含术语约束，传统引擎请求体使用占位符

## 阶段 3 — 设置页术语管理

- [x] 3.1 [实现] 设置侧栏新增「术语」分区
- [x] 3.2 [实现] 术语列表：搜索、启用 toggle、编辑、删除、新增
- [x] 3.3 [实现] 术语编辑表单：源词、译法、源语言、目标语言、大小写敏感、备注、启用
- [x] 3.4 [实现] 冲突校验：空值、重复源词 + 语言对、源词包含关系提示
- [x] 3.5 [实现] CSV 导入/导出，导入前展示新增/覆盖/冲突数量
- [x] 3.6 [测试] 设置状态保存后重新打开仍保留；禁用术语表后翻译请求不携带快照

## 阶段 4 — 结果反馈与工作流入口

- [x] 4.1 [实现] 结果卡增加术语状态标签：已应用、约束、未命中、不支持、恢复失败
- [x] 4.2 [实现] 点击术语标签展开本次命中明细
- [x] 4.3 [实现] 历史记录保存术语应用摘要，避免重看结果时丢失上下文
- [x] 4.4 [评审] 验证状态标签不会挤压复制/朗读按钮，明暗模式可读

## 阶段 5 — 插件与文档

- [x] 5.1 [实现] 插件 `query` 透传 `terminology` 数组
- [x] 5.2 [实现] manifest 支持可选 `supportsTerminology`
- [x] 5.3 [实现] 更新 `examples/openai.parrotplugin`，演示如何把术语拼进 system prompt
- [x] 5.4 [文档] 更新 `docs/plugin-development.md`，说明 `query.terminology` 和兼容策略
- [x] 5.5 [文档] 新增术语表使用说明和 CSV 模板
- [x] 5.6 [测试] 旧插件不读取 `query.terminology` 时仍正常翻译；新插件能读取术语数组

## 验收门禁

- [x] 用户添加 `AI Agent -> AI Agent` 后，英译中结果不再输出 `AI 代理`
- [x] 同一次多引擎聚合的所有结果基于同一术语快照
- [x] LLM 引擎能收到术语 prompt；传统引擎能通过占位符恢复目标译法
- [x] 结果卡能展示术语命中和应用策略
- [x] 术语表支持本地持久化、搜索、编辑、启停、CSV 导入导出
- [x] 插件接口向后兼容
