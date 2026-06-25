# Proposal: 修复英译中学习高亮文本选择

- **Change name**: `fix-learning-highlight-en-zh`
- **Status**: Implemented
- **Date**: 2026-06-24
- **Owner**: fullstack-engineer
- **Type**: Bug fix

## Summary

修复学习识别在英译中场景下错误高亮中文译文内英文专名的问题。英译中时，如果中文译文保留了 `iCloud`、`GPT` 等 Latin 专名，学习层应仍然在英文源句中识别和高亮英文学习表达。

## Root Cause

结果卡当前以“译文是否包含任意 Latin 字母”决定学习识别文本。英译中译文经常保留英文产品名、模型名和技术名词，导致学习推荐从中文译文中抽取这些专名，而不是从英文源句中抽取真正可学习的英文表达。

## Impact

| Area | Impact |
|------|--------|
| `Sources/ParrotApp/LearningSupport.swift` | 新增共享的学习文本选择规则，并让词库历史聚合复用 |
| `Sources/ParrotApp/ResultView.swift` | 结果卡传入语言方向，使用共享规则选择高亮文本 |
| `Tests/ParrotAppTests/EngineValidatorTests.swift` | 覆盖英译中译文含 Latin 专名时仍使用英文源句 |

## Risks

- 学习引擎当前聚焦英文表达，规则应避免影响中译英：目标语言为英文时继续高亮英文译文。
- 自动检测语言可能为 `.auto`，结果卡需传入 AppState 已解析/检测后的源语言。

## Verification

- `swift test --filter EngineValidatorTests` passed with 7 tests.
- `swift test` passed with 87 tests.
- `git diff --check` passed.
