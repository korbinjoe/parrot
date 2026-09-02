# Tasks: 语境含义翻译

## 1. OpenSpec

- [x] 1.1 创建 proposal、design、translation-engine 与 app-ui 增量规格

## 2. Core

- [x] 2.1 新增通用 `InterpretationResult`、文化说明和歧义模型
- [x] 2.2 扩展 `TranslateResult` 与 `TranslationContext`，保持旧调用兼容
- [x] 2.3 新增健壮的结构化理解响应解析器
- [x] 2.4 扩展 Provider 能力和理解场景质量推荐

## 3. Engines and routing

- [x] 3.1 为 OpenAI-compatible 与 Gemini 接入结构化理解 prompt/解析
- [x] 3.2 将来源元数据、有限前后文和术语约束安全注入 prompt
- [x] 3.3 让 `preferLLM` 和 `preferredProviderIDs` 真正影响 Provider 顺序

## 4. App UI and context

- [x] 4.1 OCR 选择文本块时组装有限前后文
- [x] 4.2 桌面结果卡展示真正含义、自然译法、语气、文化说明、歧义与置信度
- [x] 4.3 保持复制、朗读、历史和传统快译行为兼容

## 5. Verification

- [x] 5.1 增加解析器、prompt、上下文、路由和推荐测试
- [x] 5.2 增加文化语境回归样例
- [x] 5.3 运行 `swift test` 与 `openspec validate`
