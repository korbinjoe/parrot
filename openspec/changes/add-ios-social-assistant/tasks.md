# Tasks: Parrot iOS Social Assistant

落地顺序：共享架构 → iOS 主 App → Share Extension → Understand/Express 服务 → OCR → 历史/设置 → 自动化验收。Parrot Keyboard、Safari Extension、云同步后置。

## 阶段 0 — 方案与设计基线

- [x] [设计] 生成产品/交互方案 `docs/ios-social-assistant-ux.md`
- [x] [设计] 生成高保真可交互 HTML 原型 `docs/mockups/ios-social-assistant/index.html`
- [x] [设计] 用 Playwright 验证原型首屏和关键交互路径
- [x] [方案] 创建 OpenSpec change `add-ios-social-assistant`

## 阶段 1 — 共享工程与平台拆分

- [x] [架构] 采用单仓库多 target 结构；不要拆成 macOS/iOS 两个仓库
- [x] [架构] 在 `design.md` 中维护目标目录树和允许/禁止依赖图，作为后续重构边界
- [x] [实现] 更新 `Package.swift` platforms，加入 `.iOS(.v17)`，确保 `ParrotCore` 可在 iOS 编译
- [x] [实现] 审计 `ParrotCore` / `ParrotEngines` 中的 AppKit/macOS-only import，移动到 macOS 专属 target 或协议适配层
- [x] [实现] 新增 `ParrotPlatform` target：`SecretStoreProtocol`、`SocialSessionStore`、`SharedHandoffStore`
- [x] [实现] 新增或规划 `ParrotPlatformMac`：保留 macOS HotKey/AX/NSPanel/文件 SecretStore 适配，避免 iOS 改造污染 `ParrotApp`
- [x] [实现] 新增 `ParrotPlatformiOS`：iOS Keychain、App Group、clipboard foreground、OCR/image handoff 适配
- [x] [实现] 拆分或条件编译当前 `ParrotEngines` 中 AppKit OCR image encoding；iOS MVP 不直接依赖含 AppKit import 的 engine target
- [x] [实现] 新增 `ParrotSocial` target：session/result models、tone/platform presets、prompt builders、result parsers
- [x] [测试] 为 `ParrotSocial` 添加 JSON parsing、state transition、prompt builder 单测
- [x] [验收] `swift test` 通过，且 iOS-compatible targets 不依赖 AppKit/Carbon/ApplicationServices
- [x] [验收] 现有 macOS `swift build` / `swift test` 保持通过；新增 iOS target 不要求 macOS app 改名或迁移

## 阶段 2 — iOS 主 App 骨架

- [x] [实现] 新增 `ParrotiOS` target / Xcode app target（SwiftUI App lifecycle）
- [x] [实现] 创建 `IOSAppState`，接入 `ParrotSocial` 和平台存储协议
- [x] [实现] 实现 `TodayView`：剪贴板前台建议、最近记录、继续草稿
- [x] [实现] 实现 `UnderstandWorkspaceView`：source preview、meaning card、tone tags、phrase cards、full translation 折叠区
- [x] [实现] 实现 `ExpressWorkspaceView`：context card、intent composer、tone presets、candidate reply cards、refinement row
- [x] [实现] 建立 iOS design tokens：颜色、字体、间距、圆角、按钮/卡片组件
- [x] [验收] 主 App 可在 iPhone 模拟器打开并切换 Understand/Express；草稿不丢失

## 阶段 3 — Share Extension MVP

- [x] [实现] 新增 `ParrotShareExtension` target 和 App Group entitlement
- [x] [实现] 定义 `ShareHandoff`：text/url/image file ref/source app/platform hint/timestamp
- [x] [实现] Extension 解析 plain text、URL、image attachments，并写入 App Group handoff store
- [x] [实现] 主 App 启动/前台时 consume handoff，创建 `SocialTextSession`
- [x] [实现] 对无法解析 payload 的分享显示可恢复提示，允许打开主 App 手动输入
- [x] [测试] 用 fixture 覆盖 text/url/image handoff encode-decode
- [x] [验收] 从系统分享面板传入文本后，Quick Peek 显示可编辑源文和 Meaning 占位/结果（代码路径、handoff fixture、主 App consume/deep-link 已验证；真机系统分享矩阵见阶段 7）

## 阶段 4 — Understand / Express 服务

- [x] [实现] `SocialUnderstandingService`：调用 LLM provider，生成 `UnderstandResult`
- [x] [实现] `SocialExpressionService`：基于 context + user intent + tone preset 生成 `ReplyCandidate`
- [x] [实现] JSON schema prompt + 容错 parser；失败时保留 raw text 并给 inline recovery
- [x] [实现] 平台预设：General / X / Reddit；LinkedIn / Email 可先作为隐藏枚举
- [x] [实现] refinement actions：Shorter、More casual、More polite、Keep my attitude、Add context
- [x] [实现] provider timeout/error card：保留 sourceDraft/userIntentDraft，允许 retry/configure
- [x] [测试] malformed JSON、provider timeout、partial result parser 单测
- [x] [验收] 中文/混合语言 intent 可生成至少 3 个 native English reply candidates

## 阶段 5 — Screenshot OCR Cleanup

- [x] [实现] iOS OCR adapter：图片输入 -> text blocks -> recognized draft
- [x] [实现] `OCRCleanupView`：screenshot thumbnail、editable OCR text、cleanup chips
- [x] [实现] cleanup actions：Remove usernames、Remove timestamps、Join broken lines、Delete empty lines
- [x] [实现] OCR result can continue to Understand or Express using the cleaned draft
- [x] [测试] OCR fixture 文本清理规则单测
- [x] [验收] 分享/导入截图后，文字进入可编辑 editor，用户清理后再分析

## 阶段 6 — 历史、收藏、设置与隐私

- [x] [实现] `AppGroupSocialSessionStore`：recent/search/delete/favorite
- [x] [实现] iOS `HistoryView`：解释记录、回复记录、收藏、搜索
- [x] [实现] `IOSKeychainSecretStore` 并接入 provider 配置
- [x] [实现] `EngineSettingsView`：启用 provider、配置 Key、validate、错误回流到当前 session
- [x] [实现] `PrivacySettingsView`：说明剪贴板、分享文本、键盘、provider 发送边界
- [x] [测试] history persistence、favorite、delete、Keychain adapter 单测
- [x] [验收] 历史记录可 reopen 为 editable session；缺 Key 不丢失当前任务

## 阶段 7 — 自动化验收与真机检查

- [x] [测试] iOS UI test：Quick Peek、Reply Composer、tone switching、copy feedback
- [x] [测试] iOS UI test：OCR cleanup mutates text and preserves cleaned draft
- [x] [测试] iOS UI test：history item reopens editable session
- [x] [验证] iPhone SE / standard / large screen 截图检查文字不溢出
- [x] [验证] 深色模式和动态字号检查
- [ ] [验证] Extension flow on physical device with at least Safari, Photos, and one social app share payload（需要签名真机和外部 App 分享源，当前环境仅完成 simulator build、handoff fixtures、app consume 路径）
- [ ] [验收] MVP ready for TestFlight/internal install（需要开发者团队签名、App Group provisioning profile、真机分享矩阵通过后关闭）

## 阶段 8 — P1 / P2 后续入口

- [ ] [P1] App Shortcuts：Explain Clipboard、Rewrite Clipboard、Translate Screenshot、Open Reply Composer
- [ ] [P1] Rich URL metadata extraction for shared links
- [ ] [P1] 更多平台 style presets
- [ ] [P2] `ParrotKeyboardExtension`：command row、result strip、explicit insert、privacy disclosure
- [ ] [P2] Safari Extension
- [ ] [P2] user writing style memory and optional cross-device sync

## 验收门禁

- MVP 不依赖 Parrot Keyboard。
- Share Extension、主 App、OCR、History 都必须走同一 `SocialTextSession` 语义模型。
- 所有 captured/shared/OCR/history source 都必须可编辑。
- Copy/insert/generate 不能清空用户 draft。
- iOS secrets 只能存 Keychain；App Group 不得存 provider secrets。
- 不做后台剪贴板监控。
