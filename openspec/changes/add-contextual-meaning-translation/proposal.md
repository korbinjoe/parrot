# Proposal: 语境含义翻译

- **Change name**: `add-contextual-meaning-translation`
- **Status**: Proposed
- **Date**: 2026-09-02
- **Related**: `translation-engine`, `app-ui`, `ios-social-assistant`

## Why

Parrot 当前虽然可以调用 LLM，但桌面翻译主链路仍以单一译文字符串为中心。大多数划词和手动输入默认进入快译，LLM 收到的指令接近传统机器翻译；已有来源 App、窗口标题和 URL 等上下文也没有进入 prompt。结果质量评估只检查空输出、语言和长度等结构问题，无法识别直译、语气丢失、反讽误判或文化含义遗漏。

用户真正需要的不是更多引擎结果，而是知道一句话在当前场景中“真正想表达什么”，并获得适合目标文化的自然说法。Parrot 已在社媒助手中验证了 `meaningSummary`、语气标签、短语解释、自然译文和歧义提示的结构化结果，应将这套能力下沉为通用翻译能力。

## What Changes

- 在 `ParrotCore` 新增通用 `InterpretationResult`，描述真实含义、本地化译文、可选字面译文、语气、文化说明、歧义和置信度。
- 扩展 `TranslateResult`，在保持 `translated` 兼容的同时携带可选结构化理解结果。
- 扩展 `TranslationContext`，允许携带用户主动触发范围内的前后文，并将来源 App、窗口标题、URL 和来源入口真正注入 LLM prompt。
- Understand 与 Social profile 使用 JSON 结果契约；解析失败时安全降级为普通译文。
- LLM Provider 声明结构化理解能力；Understand/Social 路由优先支持该能力的 Provider，同时保留已配置引擎的对比结果。
- 质量推荐在理解场景优先选择含结构化理解的结果，而不是优先选择最快返回的格式正确译文。
- 桌面结果卡先展示“真正含义”，再展示自然译法、语气、文化说明和歧义提示。
- OCR 选择单一文本块时，把本次 OCR 的其余候选文本作为有限前后文传入理解请求。

## Non-Goals

- 本变更不自动抓取整个页面、聊天记录或后台窗口内容。
- 本变更不默认联网检索文化事件或实时网络梗。
- 本变更不增加额外的 LLM Judge 调用；首版使用结构化结果完整度与现有质量信号推荐。
- 本变更不移除传统机器翻译和快译路径。

## Impact

| 区域 | 影响 |
| --- | --- |
| `Sources/ParrotCore/` | 新增理解模型、解析器、上下文字段和理解场景质量信号 |
| `Sources/ParrotEngines/` | LLM 结构化 prompt、上下文注入和响应解析 |
| `Sources/ParrotApp/AppState.swift` | OCR 前后文组装、推荐结果与历史兼容 |
| `Sources/ParrotApp/ResultView.swift` | 结构化含义、自然译法、语气、文化说明和歧义展示 |
| `Tests/` | 解析、prompt、上下文、路由、推荐和 UI 状态测试 |
