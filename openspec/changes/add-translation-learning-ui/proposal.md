# Proposal: 翻译学习闭环 UI 原型

- **Change name**: `add-translation-learning-ui`
- **Status**: Proposed
- **Date**: 2026-06-24
- **Owner**: fullstack-engineer
- **Related**: `app-ui`, `translation-engine`, `translation-terminology`

## Summary

在现有 Parrot macOS 高保真视觉体系上新增“翻译即学习”的交互层：翻译结果中自动识别高价值陌生词/短语，提供当前语境解释、一键沉淀到个人词库、翻译后 10 秒微练习、每日复习队列和词汇画像。本次交付是可直接在浏览器打开的高保真可交互 HTML 视觉稿，作为后续 SwiftUI 实现依据。

## Motivation

Parrot 当前解决的是“快速得到翻译结果”。但用户长期痛点是：翻译句子里出现陌生词时，当下看懂了，过后仍然不会。单独做一个背单词入口会破坏 Parrot “即用即走”的工具属性，也会增加用户管理负担。因此学习能力必须附着在翻译结果里，以语境为核心自动沉淀，而不是让用户离开翻译工作流。

## Goals

1. 在结果面板中轻量高亮高价值陌生词与词块，不干扰主译文阅读。
2. 点击词/短语后展示当前语境解释、音标、搭配、熟词僻义、掌握阶段和加入词库操作。
3. 翻译完成后提供 10 秒微练习，优先用原句挖空而非词典例句。
4. 新增每日复习窗口，复习内容来自用户历史翻译句子。
5. 新增词库画像窗口，展示已掌握、待复习、反复遗忘和场景分布。
6. 新增学习设置页，控制自动识别、每句推荐数量、复习强度和目标水平。
7. 沿用现有 `redesign-app-ui` 的 macOS 原生视觉语言、设计 token、浅深色模式和窗口结构。

## Non-goals

- 不在本次实现 SwiftUI 运行代码、数据库、复习算法或模型调用。
- 不替代现有术语表能力；术语表解决“译法稳定”，学习词库解决“用户掌握”。
- 不做独立背单词 App，不新增营销页或复杂课程体系。
- 不要求首版覆盖所有语言学习场景，MVP 聚焦英文词汇/词块。

## Approach

- HTML 原型放在 `mockups/index.html`，复用现有视觉 token 和 macOS 桌面舞台结构。
- 学习层作为 ResultPanel 的渐进披露内容：默认只显示高亮与“建议掌握”条，点击后才展开详情。
- 每个学习对象优先以 `sourceText + translatedText + contextMeaning` 为核心，避免孤立词典释义。
- 复习卡片按掌握阶段呈现：见过、原句认出、迁移认出、主动写出、自然使用。
- 词库画像聚合到独立窗口，服务周期性复盘，不挤占翻译主流程。

## Impact

| 区域 | 影响 |
|------|------|
| `openspec/changes/add-translation-learning-ui/mockups/index.html` | 新增高保真可交互 HTML 原型 |
| `openspec/changes/add-translation-learning-ui/design.md` | 定义学习 UI 的信息架构、组件、状态与交互 |
| `openspec/changes/add-translation-learning-ui/specs/app-ui/spec.md` | App UI 增量规格 |
| SwiftUI 实现 | 后续需新增学习高亮、词义弹层、复习窗口、词库画像和设置项 |

## Risks

| 风险 | 缓解 |
|------|------|
| 学习功能干扰翻译效率 | 默认只高亮和提示数量，详情与练习均为渐进披露 |
| 变成传统背单词 App | 所有复习卡片绑定用户翻译过的原句，词库窗口只做沉淀与复盘 |
| 高亮过多导致视觉噪声 | 每句默认最多推荐 3 个高价值表达，可在设置中调整 |
| 词典解释脱离语境 | 详情第一屏必须展示“当前句中含义”和“原句词块” |
| 后续实现数据复杂 | 本次只定义 UI 契约，算法与存储在后续 OpenSpec 细化 |
