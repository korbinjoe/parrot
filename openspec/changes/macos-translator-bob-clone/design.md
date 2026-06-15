# Design: OpenBob — macOS 翻译与 OCR 工具

## 1. 技术栈选型

### 候选与取舍

| 方案 | 优势 | 劣势 | 结论 |
|------|------|------|------|
| **Swift + SwiftUI + AppKit（原生）** | 系统能力直达：Accessibility、CGEvent 全局快捷键、ScreenCaptureKit 截图、Vision OCR、AVSpeechSynthesizer TTS、NSPanel 悬浮窗、菜单栏；包体小、性能/能耗最佳；公证/分发成熟 | 仅 macOS；Swift 生态相对小 | **采用** |
| Electron | 跨平台、Web 技术栈 | 包体大、能耗高；全局快捷键/截图/AX 需大量原生插件桥接，反而更复杂；与"轻量即用即走"定位冲突 | 否 |
| Tauri (Rust) | 包体较小、跨平台 | macOS 深度系统 API 仍需走 objc/swift FFI；Vision/AX 集成成本高 | 否 |
| Flutter | 跨平台 UI | 桌面系统集成弱，全局监听/截图需大量 platform channel | 否 |

### 决策

**采用 Swift 5.9+ / SwiftUI（主 UI）+ AppKit（系统交互与悬浮窗）**。
理由：本产品 80% 的差异化能力来自 macOS 系统级深度集成（全局选词、截图、OCR、悬浮窗、菜单栏），跨平台方案在这些点上不仅没有红利，反而引入桥接复杂度与体验损耗。最低支持 **macOS 13 Ventura**（Vision 文档级 OCR、ScreenCaptureKit、SwiftUI 成熟度的平衡点）。

- 依赖管理：Swift Package Manager
- 持久化：Core Data（或 GRDB/SQLite，见 §6 决策）
- 凭据：Keychain Services
- 插件 JS 运行时：JavaScriptCore（系统自带，零依赖）

## 2. 整体架构

```
┌──────────────────────────────────────────────────────────┐
│                      Interaction Layer                      │
│  GlobalHotkey · SelectionCapture(AX) · ScreenCapture ·      │
│  InputPanel · MenuBarController · PopClip Bridge            │
└───────────────────────────┬──────────────────────────────┘
                            │ TranslateRequest
┌───────────────────────────▼──────────────────────────────┐
│                   Application / Orchestration               │
│  TranslationCoordinator (语言检测·引擎编排·并发对比)         │
│  OCRCoordinator · HistoryService · FavoriteService · TTS    │
└───────────────────────────┬──────────────────────────────┘
                            │ TranslationProvider 协议
┌───────────────────────────▼──────────────────────────────┐
│                     Engine Abstraction                      │
│  内置: Apple·Google·DeepL·Tencent·Baidu·Youdao·Caiyun·     │
│        Microsoft·OpenAI ...                                  │
│  PluginProvider → JS Plugin Runtime (sandbox)               │
└───────────────────────────┬──────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────┐
│  Platform Services: Vision(OCR) · ScreenCaptureKit ·        │
│  AVSpeechSynthesizer(TTS) · Keychain · CoreData · Network   │
└──────────────────────────────────────────────────────────┘
```

### 模块边界与依赖方向

- 依赖**单向向下**：Interaction → Application → Engine → Platform。下层不反向依赖上层。
- 引擎与插件统一实现 `TranslationProvider` 协议，Application 层只面向协议编程，**新增引擎/插件零侵入**。
- UI（SwiftUI View）只依赖 ViewModel；ViewModel 调用 Application 服务。

## 3. 翻译引擎抽象层（核心）

```swift
struct TranslateRequest {
    let text: String
    let from: Language       // .auto 表示自动检测
    let to: Language
    let mode: TranslateMode  // .translate / .lookup(查词) / .polish
}

struct TranslateResult {
    let providerId: String
    let translated: String
    let detectedFrom: Language?
    let phonetics: [Phonetic]?     // 查词：音标
    let definitions: [Definition]? // 查词：释义/词性/例句
    let raw: [String: Any]?
}

protocol TranslationProvider {
    var id: String { get }                 // 唯一标识，如 "openai"、"plugin.xxx"
    var displayName: String { get }
    var supportedLanguages: [Language] { get }
    var capabilities: ProviderCapabilities { get } // 是否支持查词/流式/语音
    func configure(_ config: ProviderConfig) throws
    func translate(_ req: TranslateRequest) async throws -> TranslateResult
    func stream(_ req: TranslateRequest) -> AsyncThrowingStream<String, Error> // LLM 流式可选
}
```

- **聚合对比**：`TranslationCoordinator` 用 `async let` / TaskGroup 并发调用所有启用的 Provider，结果按到达/固定顺序填入对比卡片，单引擎失败不影响其它（独立错误态）。
- **语言检测**：优先 `NLLanguageRecognizer`（系统、离线）；不确定时回退引擎自带检测。
- **错误统一**：`ProviderError`（鉴权/限流/网络/不支持语言），UI 统一渲染重试/降级。

## 4. OCR 方案

- **首选**：Apple **Vision** `VNRecognizeTextRequest`（离线、免费、系统级，支持中英日韩等，`.accurate` 模式 + 语言提示）。
- 流程：`ScreenCaptureKit` 选区截图 → `CGImage` → Vision 识别 → 文本块按版面排序还原 → 送入翻译编排。
- **可扩展**：`OCRProvider` 协议，插件可接入第三方 OCR（如需更强 PDF/手写）。
- 兜底：Vision 不可用或低于阈值置信度时提示重截。

## 5. 插件系统

- **运行时**：JavaScriptCore（系统自带）。
- **插件包结构**：`info.json`（manifest：id、name、version、author、需要的配置项 schema、权限声明、支持的能力）+ `main.js`（实现约定的 `translate(query, completion)` 接口，对齐 Bob 插件签名以降低社区迁移成本）。
- **配置注入**：宿主将用户填写的 API Key / Model / Prompt 等通过 `$option` 注入；Key 存 Keychain，不落明文。
- **安全沙箱**（详见 specs/plugin-system）：
  - JS 上下文无文件系统访问；
  - 网络仅通过宿主提供的 `$http` 桥接，受 manifest 声明的域名白名单限制；
  - 执行超时与内存限制；
  - 安装时展示权限清单需用户确认。
- **热加载**：插件目录监听，安装/启用/禁用无需重启。

## 6. 数据模型与持久化

```
TranslationRecord(id, sourceText, sourceLang, targetLang, results:[ProviderResult],
                  mode, createdAt, isFavorite, tags)
ProviderResult(providerId, translated, createdAt, latencyMs, errorCode?)
EngineConfig(providerId, enabled, order, configRef→Keychain)
PluginRecord(pluginId, version, enabled, manifestPath, grantedScopes)
AppSettings(hotkeys, theme, defaultTargetLang, autoDetect, panelBehavior)
```

- **存储**：历史/收藏用 SQLite（经 GRDB）——比 Core Data 更可控的全文检索与迁移。
- **凭据**：所有 API Key / Token 存 **Keychain**，DB 仅存引用，绝不明文。
- **导入/导出**：历史与配置支持 JSON 导出（不含密钥）。

## 7. 全局快捷键与权限

- **全局快捷键**：基于 `CGEvent` tap / Carbon `RegisterEventHotKey`，全部可在设置中自定义；默认对齐 Bob（划词 ⌥D、截图 ⌥S、输入 ⌥A）。
- **选中文本捕获**（划词）：
  1. 首选 Accessibility API（`AXUIElement` 读 focused element 的 selected text）；
  2. 回退：合成 ⌘C 复制 → 读 `NSPasteboard` → 还原剪贴板。
- **权限引导**：首启检测「辅助功能」「屏幕录制」「Keychain」授权状态，未授权时给出图文引导与系统设置深链。
- **菜单栏常驻** + 悬浮窗（`NSPanel`，`.nonactivatingPanel`，失焦自动隐藏，可置顶 pin）。

## 8. 分发与开源治理

- **分发**：GitHub Release 提供 notarized `.dmg`（Developer ID 签名 + 公证），规避 App Store 对全局监听的限制；App Store 作为可选后续。
- **License**：建议 **AGPL-3.0**（防闭源二次商用）或 **MIT**（最大化采用）——列为待定决策项 D-3。
- 配套：`CONTRIBUTING.md`、插件开发文档、`SECURITY.md`。

## Decisions

- **D-1（已定）**：技术栈采用 Swift + SwiftUI + AppKit 原生方案，放弃跨平台。依据：系统级集成是核心价值。
- **D-2（已定）**：OCR 首选 Apple Vision（离线免费），插件可扩展第三方。
- **D-3（已定）**：开源 License = **AGPL-3.0**（强 Copyleft，防闭源二次商用）。
- **D-4（已定）**：插件运行时用 JavaScriptCore 并对齐 Bob 插件接口签名，以复用社区生态；不承诺 100% 兼容。
- **D-5（已定）**：持久化用 SQLite/GRDB 而非 Core Data，换取更好的全文检索与可控迁移。
- **D-6（已定）**：最低系统版本 = **macOS 13 Ventura**。
