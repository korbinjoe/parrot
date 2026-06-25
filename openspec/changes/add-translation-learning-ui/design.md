# Design: 翻译学习闭环 UI

## Design Principle

学习层必须服务翻译主任务：用户不需要先选择“学习模式”，也不需要手动整理单词。系统在翻译结果中自动筛选最值得掌握的词/短语，用原句语境完成解释、沉淀和复习。

## Information Architecture

```
ResultPanel
  ├─ SourceBlock 原文
  ├─ TranslationResult 译文
  │   └─ LearnHighlight 高价值词/短语高亮
  ├─ LearningStrip 建议掌握 N 个表达
  ├─ ContextWordPopover 当前语境词义弹层
  └─ MicroPractice 翻译后 10 秒挖空练习

LearningReviewWindow
  ├─ ReviewQueue 今日复习队列
  ├─ ReviewCard 原句/迁移句练习
  └─ MasteryControls 掌握反馈

VocabularyWindow
  ├─ SearchAndFilter 搜索与筛选
  ├─ WordList 个人词库
  ├─ WordDetail 语境、搭配、历史句子
  └─ AbilitySnapshot 词汇画像

SettingsWindow
  └─ LearningPane 学习设置
```

## Components

### LearnHighlight

- 只标记系统推荐的高价值表达，默认每句最多 3 个。
- 高亮样式使用 `accent-soft` 底和 0.5px accent 描边；避免整句被蓝色污染。
- 高亮词后可显示低噪声历史频次徽标，例如 `4次`；频次来自用户历史翻译语料，用于提示高频重点。
- 支持三种状态：未处理、已加入词库、已掌握。

### ContextWordPopover

弹层内容顺序固定：

1. 词/短语、音标、词性或表达类型。
2. 当前句中含义。
3. 原句词块，例如 `insufficient evidence = 证据不足`。
4. 常见搭配，不超过 3 个。
5. 掌握阶段与操作：认识 / 加入词库 / 已掌握。

### LearningStrip

- 位于译文卡底部，不抢占主结果阅读。
- 展示建议表达数量、预计复习时间、词块 chip 和历史出现次数。
- 用户点击 chip 时打开对应 `ContextWordPopover`。

### MicroPractice

- 默认折叠为一行“10 秒练习”入口。
- 展开后使用原句挖空，不使用抽象词典例句。
- 答对后进入“原句认出”阶段，答错则保持“待复习”并进入间隔队列。

### LearningReviewWindow

- 独立窗口，面向每日 3-5 分钟复习。
- 左侧为复习队列，右侧为当前卡片。
- 练习类型包括原句挖空、中文回忆英文、相似句迁移。

### VocabularyWindow

- 列表展示词/短语、场景、掌握阶段、历史出现次数和下次复习时间。
- 详情页展示最初来源句、最近复现句、搭配和错误次数。
- 顶部展示能力画像：已掌握词块、待复习、反复遗忘、预计少查词比例。

## States

| 状态 | 视觉与行为 |
|------|------------|
| 识别中 | LearningStrip 显示骨架，不阻塞翻译结果 |
| 无推荐 | 不显示 LearningStrip，保持纯翻译体验 |
| 已加入词库 | chip 左侧显示 check，操作按钮变为“已加入” |
| 已掌握 | chip 降低强调，掌握阶段到“主动可用” |
| 练习答对 | 绿色状态条，卡片自动进入下一词 |
| 练习答错 | 橙色状态条，展示正确答案并标记稍后复习 |

## Decisions

1. **学习层不做独立入口首屏**：用户主任务仍是翻译，学习能力作为结果面板的渐进披露层出现。
2. **复习内容绑定历史翻译句子**：个人词库可以检索，但记忆卡片优先复现用户自己翻译过的句子。
3. **短语与搭配优先级高于孤立单词**：UI 文案使用“表达”而不是“单词”，避免用户只积累碎片释义。
4. **每句默认最多 3 个推荐表达**：用推荐质量换取翻译界面的干净度。
5. **历史频次作为优先级信号**：翻译结果、学习条和词库列表展示出现次数，但用小徽标承载，避免把译文变成统计面板。
6. **个人词库使用本地实体记录**：`LearningVocabularyEntry` 持久化加入词库、收藏、掌握阶段、错误次数和下次复习时间；历史推荐继续作为未加入词库的发现层。

## SwiftUI Mapping Notes

- `ResultView` 后续新增 `LearningStripView` 和 `ContextWordPopoverView`。
- `HistoryWindow` 可复用历史句子作为复习来源。
- 学习设置应进入现有 `SettingsWindow` 侧栏，不新增偏离系统风格的全屏页面。
- 掌握状态建议抽象为 enum：`seen` / `recognizedInContext` / `recognizedTransferred` / `activeRecall` / `usable`。
