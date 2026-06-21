# Tasks: iOS Quick Lens

## 阶段 0 — 范围与入口基线

- [x] [方案] 确认 Quick Lens 作为 `add-ios-social-assistant` 之上的独立入口优化，不替代 Share Extension 和 OCR Cleanup
- [x] [方案] 更新 `docs/ios-social-assistant-ux.md`，加入 Quick Lens 主路径：截图 -> 唤起 Parrot -> 自动块级翻译
- [x] [方案] 确认 MVP 默认最近截图窗口为 60 秒，且只在用户显式触发后读取

## 阶段 1 — 数据模型与状态

- [x] [实现] 在 `Sources/ParrotSocial/SocialModels.swift` 增加 `SourceOrigin.latestScreenshot`
- [x] [实现] 新增 `QuickLensState`、`QuickLensCandidate`、`QuickLensRoleHint` 及 Codable geometry helpers
- [x] [实现] 将 Quick Lens metadata 接入 `SocialTextSession`，或先以 session ID sidecar 存储并保持 `sourceDraft` 为唯一翻译源
- [x] [测试] 覆盖 Quick Lens state encode/decode、candidate selection、sourceDraft 更新规则

## 阶段 2 — 最近截图读取

- [x] [实现] 在 `Sources/ParrotPlatformiOS` 新增 `LatestScreenshotProvider`
- [x] [实现] 使用 PhotoKit 查询 screenshot smart album 或 screenshot asset，并按创建时间过滤最近 60 秒
- [x] [实现] 增加 Photos 权限状态模型：notDetermined、authorized、limited、denied、restricted
- [x] [实现] 在 `Apps/iOS/ParrotiOS/Info.plist` 增加 `NSPhotoLibraryUsageDescription`
- [x] [实现] 将选中的截图复制到 App Group `HandoffImages/`，复用现有图片路径加载逻辑
- [x] [实现] 增加未授权、无最近截图、图片读取失败的 inline recovery
- [x] [测试] 用 fake provider 覆盖最新截图选择、超时窗口、权限拒绝、无截图状态

## 阶段 3 — Shortcut / Deep Link 入口

- [x] [实现] 新增 App Intent：`TranslateLatestScreenshotIntent`
- [x] [实现] 支持 `parrot://quick-lens` URL route，并在 `IOSAppState.handle(url:)` 中进入 Quick Lens
- [x] [实现] 在 Today 或 Understand 顶部加入 Lens 入口，作为调试和无 Shortcuts 配置时的可见入口
- [x] [验收] 通过 URL route 可从冷启动进入 Quick Lens（模拟器验证到 iOS 打开确认弹窗；实际进入需用户点“打开”）
- [x] [真机] 验证 Shortcuts、Action Button、Back Tap 可触发 `Translate Latest Screenshot`

## 阶段 4 — OCR 块聚类与排序

- [x] [实现] 扩展 `IOSOCRService` 或适配层，保留 image pixel size 与 line bounding boxes
- [x] [实现] 新增 `OCRTextBlockClusterer`：将 OCR lines 聚合为候选文本块
- [x] [实现] 新增噪音过滤：状态栏、底部导航、孤立按钮、时间戳、孤立用户名、零散互动数字
- [x] [实现] 新增 candidate ranking：中心区域、自然语言 token、行数、面积、置信度、平台 hint
- [x] [实现] 输出候选块 score/debug reason，开发期用于调参，正式 UI 不展示调参细节
- [x] [测试] 增加 X、Reddit、引用推文、密集评论截图的 OCR block fixture
- [x] [测试] 验证默认候选块优先于用户名、时间戳、按钮和 tab bar 文本

## 阶段 5 — Quick Lens UI

- [x] [实现] 新增 `Apps/iOS/ParrotiOS/QuickLensView.swift`
- [x] [实现] 新增 screenshot overlay 组件，按候选块 bounding box 绘制可点击区域
- [x] [实现] 展示状态：loading screenshot、requesting permission、recognizing、translating、ready、needs permission、no recent screenshot、OCR failed
- [x] [实现] 自动选择最高分候选块并立即触发 Understand
- [x] [实现] 点击其他候选块后更新 `sourceDraft`，在同一 surface 内重新翻译
- [x] [实现] 增加 `Edit source`，进入现有 editable source composer，不丢截图上下文
- [x] [实现] 增加 `Crop` fallback，允许用户手动框选区域后局部 OCR
- [x] [验收] 默认路径不要求用户先裁剪、清理 OCR 或点击翻译

## 阶段 6 — AppState 与服务串联

- [x] [实现] 在 `IOSAppState` 新增 `openQuickLensFromLatestScreenshot()`
- [x] [实现] 新增 `selectQuickLensCandidate(_:)`，候选块切换后复用 `understandActiveSession()`
- [x] [实现] 新增 `retryQuickLensOCR()` 和 `openQuickLensManualCrop()`
- [x] [实现] Quick Lens 产生的 session 保存到现有 history，reopen 后仍可编辑和重新翻译
- [x] [实现] 保证 provider 请求只发送选中/编辑后的文本，不上传整张截图
- [x] [实现] 增加 App Group 图片清理：删除未被 session 引用且超过 24 小时的 Quick Lens 图片

## 阶段 7 — 自动化测试与验收

- [x] [测试] 单测：LatestScreenshotProvider fake、OCRTextBlockClusterer、QuickLensState、session persistence
- [x] [测试] UI test：fixture 截图打开 Quick Lens 后自动翻译最高分文本块
- [x] [测试] UI test：点击第二个文本块后原文和结果在原 surface 更新
- [x] [测试] UI test：编辑 source 后重新翻译，截图 overlay 不消失
- [x] [测试] UI test：无最近截图与权限拒绝 recovery
- [x] [验证] iPhone SE / standard / Pro Max，浅色/深色模式，动态字号不遮挡
- [x] [验证] 真机 Shortcuts / Action Button / Back Tap 调用路径
- [x] [验收] `swift test` 通过，iOS UI test 对 Quick Lens fixture 通过

## 验收门禁

- Quick Lens 默认路径最多两步：截图 + 唤起 Parrot。
- 默认路径必须自动选择候选文本块并开始翻译。
- 用户必须能一键切换到另一个文本块并在原 surface 重新翻译。
- OCR 文本必须可编辑；编辑后可重新翻译。
- 没有最近截图、无权限、OCR 失败都必须有 inline recovery。
- 不得后台扫描相册；不得上传整张截图给翻译/LLM provider。
- Quick Lens history reopen 后仍是 editable `SocialTextSession`。
