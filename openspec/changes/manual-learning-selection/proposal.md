# Proposal: 手动选词触发学习功能

- **Change name**: `manual-learning-selection`
- **Status**: Implemented
- **Date**: 2026-06-24
- **Owner**: fullstack-engineer
- **Type**: Behavior change

## Summary

取消结果卡中的自动陌生词识别和自动推荐高亮。学习功能改为用户先在原文或译文中手动选中单词/短语，随后显示语境卡、加入词库、标记掌握和微练习。

## Motivation

自动匹配会推荐过于简单的词，目标水平调整对结果影响不明显，反而干扰翻译主流程。用户手动选词能把学习对象的控制权交还给用户，减少噪声。

## Goals

- 结果卡不再自动高亮推荐词，也不自动展示 LearningStrip。
- 用户选中原文或译文片段后，才生成对应学习表达并展示学习功能。
- 个人词库和复习队列只来自用户加入或练习过的表达，不再从历史翻译自动抽词。
- 保留历史出现次数，用于显示用户选中表达在历史语料中的频次。

## Non-goals

- 不在本次接入 LLM 词义解释。
- 不删除既有词库持久化数据。
- 不改变术语表能力。

## Impact

| Area | Impact |
|------|--------|
| `Sources/ParrotApp/ResultView.swift` | 结果卡改为选区触发学习卡 |
| `Sources/ParrotApp/LearningSupport.swift` | 新增手动选区表达生成，词库聚合停止默认历史抽词 |
| `Sources/ParrotApp/AppState.swift` | 个人词库只聚合持久化词条 |
| `Sources/ParrotApp/SettingsWindow.swift` | 学习设置文案改为手动选词 |
| `Tests/ParrotAppTests/EngineValidatorTests.swift` | 覆盖手动选词和词库不自动抽词 |

## Risks

- AppKit 选区通知需要避免影响现有源文编辑器的输入体验。
- 译文使用只读 `NSTextView` 后，需要保持复制和选择可用。

## Verification

- `swift test --filter EngineValidatorTests` passed with 9 tests.
- `swift test` passed with 91 tests.
- `git diff --check` passed.
- `.codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh` passed.
