# Review: Parrot (Bob 复刻)

变更：`macos-translator-bob-clone` — 验证日期 2026-06-15。

## 验证结论

构建、测试、打包链路全绿，Bob 核心功能已全部落地，可开箱即用（Google 引擎免 Key）。

```
swift build   → Build complete!
swift test    → 24 tests passed
build-app.sh  → build/Parrot.app（菜单栏常驻，parrot:// URL scheme 已注册）
```

## 功能完成度对照（vs Bob）

| Bob 功能 | 状态 | 实现 |
|----------|------|------|
| 划词翻译 | ✓ | ⌥D，AX + ⌘C 回退 |
| 查词（音标/词性/释义） | ✓ | ⌥E，`TranslateMode.lookup`，悬浮窗渲染 |
| 截图 OCR 翻译 | ✓ | ⌥S，`screencapture -i` + Vision |
| 输入翻译 | ✓ | ⌥A，SwiftUI 输入面板 |
| 多引擎聚合对比 | ✓ | TaskGroup 并发 + 失败隔离 + 超时，并排卡片 |
| 插件系统（接入 LLM） | ✓ | JavaScriptCore 沙箱 + `$http` 白名单 + `$option`/`$log` |
| 历史 / 收藏 / 检索 | ✓ | `HistoryStore` actor + JSON 持久化 |
| TTS 朗读 | ✓ | `AVSpeechSynthesizer`，原文/译文，多语言 |
| PopClip 集成 | ✓ | `examples/Parrot.popclipext` + URL scheme |
| 设置面板 | ✓ | 目标语言/引擎开关/API Key（钥匙串） |
| 悬浮窗即用即走 | ✓ | nonactivating NSPanel，失焦自动隐藏 |

引擎：Google（免 Key 默认开）、DeepL、OpenAI、Mock、JS 插件。

## Code Review

- **架构清晰**：`TranslationProvider` 协议 + `ProviderRegistry` + `TranslationCoordinator` 三层解耦，新引擎/插件零侵入接入编排层与 UI。
- **并发正确**：跨 actor 边界类型已正确标注 `@MainActor` / `Sendable` / `@unchecked Sendable`；协调器 actor 内 TaskGroup 聚合，单引擎失败/超时不影响其余。
- **错误隔离**：统一 `ProviderError` 模型，UI 逐引擎渲染错误态。
- **修复记录**：HistoryStore `trim()` 优先删除最旧非收藏项（曾误删收藏）；`load()` 补 `.iso8601` 解码策略（曾解码失败丢数据）。两者均有回归单测。

## Security Review

- **密钥不落盘**：API Key 仅存钥匙串（`KeychainStore`，`kSecAttrAccessibleAfterFirstUnlock`），绝不写 UserDefaults/历史库/日志；环境变量仅作开发回退。
- **插件沙箱**：独立 JSContext + 串行队列 + 无 fs；网络仅限 manifest `permissions.network` 白名单（后缀匹配）；调用带超时防挂起。
- **历史库**：仅含原文/译文/引擎 ID/语言/时间戳，无敏感信息。
- 详见 `SECURITY.md`。

## 遗留项（不阻塞首版，已在 tasks.md 标 `[~]`/未勾选）

- 更多引擎（腾讯/百度/有道/彩云/Microsoft/Apple Translation）— 抽象已就绪，按需补充。
- 插件安装/启用/禁用 UI + 热加载；OCR 低置信度重截提示。
- 历史/配置显式导入导出 UI。
- `.dmg` 打包与 GitHub Release 为人工触发动作（`notarize.sh` 链路已就绪）。

## 决策

- D-3 License = **AGPL-3.0**（`LICENSE` 已加入）。
- D-6 最低系统 = **macOS 13 Ventura**。
