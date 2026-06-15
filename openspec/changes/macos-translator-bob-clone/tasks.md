# Tasks: Parrot 实现任务拆解

按里程碑分阶段。每个里程碑有明确门禁（Definition of Done），通过后方进入下一阶段，控制范围蔓延。

## M0 — 工程脚手架与基础设施

- [x] 初始化 Swift Package 工程，确定目录结构（App / Core / Engines），`swift build` 通过
- [x] 搭建菜单栏常驻 App 骨架（`NSStatusItem` + `NSApplication` accessory 模式）
- [x] `.app` 打包脚本（scripts/build-app.sh + Info.plist，LSUIElement，ad-hoc 签名）—— 启动验证通过
- [x] 全局快捷键管理器（Carbon `RegisterEventHotKey`，⌥D/⌥S/⌥A）
- [x] 辅助功能权限检测与系统弹窗引导（`AXIsProcessTrustedWithOptions`）
- [ ] 配置 SPM 依赖（GRDB 等）、SwiftLint、CI（GitHub Actions：build + test）
- [ ] Keychain 授权态检测 + 屏幕录制权限引导文案完善
- **DoD**：App 常驻菜单栏 ✓，快捷键触发 handler ✓，权限引导 ✓

## M1 — MVP：划词 + 输入翻译 + 单引擎 + 悬浮窗

- [x] 定义 `TranslationProvider` 协议与 `TranslateRequest/Result` 模型（ParrotCore）
- [x] 实现参考引擎：`OpenAIEngine`（LLM）+ `MockEngine`（离线 demo）
- [x] `TranslationCoordinator`（`NLLanguageRecognizer` 语言检测 + 并发聚合 + 超时 + 错误隔离）
- [x] 单元测试覆盖协调器/引擎/检测/错误隔离（Swift Testing，6 passing）
- [x] 选中文本捕获（AX `kAXSelectedText` + ⌘C 复制回退双策略，含剪贴板还原）
- [x] 输入翻译面板（SwiftUI 输入框 → 回车翻译）
- [x] 悬浮窗 `NSPanel`（nonactivating、失焦自动隐藏、近光标定位、多引擎卡片）
- **DoD**：选中文本 ⌥D 出译文 ✓；⌥A 输入翻译 ✓（建议真机授权辅助功能后端到端验证）

## M2 — 截图翻译 / OCR

- [x] 选区截图（采用系统 `screencapture -i` 交互框选，比 ScreenCaptureKit 更简洁可靠）
- [x] Apple Vision OCR（`VNRecognizeTextRequest` accurate 模式 + 版面排序还原 top→bottom/left→right）
- [x] OCR 结果 → 翻译编排 → 悬浮窗展示
- [ ] 低置信度兜底提示重截（当前为静默忽略，待补提示 UI）
- [ ] 抽象 `OCRProvider` 协议以支持插件扩展 OCR
- **DoD**：⌥S 截取图片/PDF 区域文字并翻译 ✓（建议真机授权屏幕录制后端到端验证）

## M3 — 多翻译引擎聚合对比

- [x] `TranslationCoordinator` 并发聚合（TaskGroup），独立错误态（M1 已落地）
- [x] 悬浮窗多引擎并排对比卡片（M1 已落地）
- [x] Google 引擎（免费 web 端点，无需 Key，默认启用）— 真机联网验证 `Good morning→早上好`
- [x] DeepL 引擎（官方 API，Free/Pro 自动选 host，Key 注入）
- [x] OpenAI 引擎（M1 已落地，LLM）
- [x] 引擎解析逻辑单测（Google/DeepL parse，12 tests passing）
- [ ] 接入其余引擎：腾讯、百度、有道、彩云、Microsoft、Apple Translation
- [ ] 各引擎鉴权配置 UI + Keychain 存储（当前经环境变量注入，待做设置面板）
- [ ] 引擎开关/排序设置 UI
- **DoD**：聚合并排对比 ✓、单引擎失败隔离 ✓；引擎数量与配置 UI 持续补充

## M4 — 插件系统

- [x] 定义插件 manifest（`info.json`）Codable schema 与 `*.bobplugin` 目录规范
- [x] JavaScriptCore 运行时 + `translate(query, completion)` 桥接（对齐 Bob 签名）
- [x] `$http` 网络桥 + 域名白名单（host 后缀匹配）+ 每调用超时（沙箱：独立 JSContext/串行队列/无 fs）
- [x] `$option` / `$log` 注入；secret 经 `resolveOptions` 合并默认值
- [x] `PluginProvider` 适配为 `TranslationProvider`，参与聚合
- [x] `PluginLoader` 磁盘发现/加载（`loadAll` 容错跳过）+ 接入 AppState
- [x] 示例插件 echo + openai（含 $http 白名单）
- [x] 单测：manifest 解析/选项合并/JS 桥/白名单拦截/Provider 适配（7 项，共 19 passing）+ 磁盘加载端到端
- [ ] 插件安装/启用/禁用 UI + 安装时权限确认弹窗
- [ ] secret 配置写 Keychain（当前经 secrets 字典注入，待接 Keychain）
- [ ] 热加载（目录监听）
- [ ] 插件开发文档
- **DoD**：可加载第三方 JS 插件接入 GPT 等并参与聚合对比 ✓（UI/Keychain/热加载待补）

## M5 — 查单词 + TTS + 历史/收藏 + PopClip

- [x] 查词模式：返回音标/词性/释义/例句（`TranslateMode.lookup`，⌥E/菜单/URL，悬浮窗渲染）
- [x] TTS：`AVSpeechSynthesizer` 朗读原文/译文，多语言（`Speaker`，Language→BCP-47 映射）
- [x] 历史记录（`HistoryStore` actor + JSON 持久化 + 检索，自动记录首个成功译文）
- [x] 收藏夹（`setFavorite`/`favorites`，悬浮窗 ⭐️ 切换，trim 优先保留收藏）
- [x] PopClip 扩展集成（`examples/Parrot.popclipext` + `parrot://` URL scheme）
- [~] 历史/配置 JSON 导入导出（历史已 JSON 落盘；显式导入导出 UI 待补）
- **DoD**：查词、朗读、历史、收藏、PopClip 全部可用 ✓

## M6 — 打磨与开源发布

- [x] 设置面板（默认目标语言/引擎开关/API Key 录入/快捷键展示）`SettingsWindow`+`SettingsView`+`AppSettings`
- [x] Keychain 凭据存储（`KeychainStore`，AppSettings + 引擎接入，环境变量回退）
- [x] 公证脚本 + 文档（`scripts/notarize.sh`：hardened runtime 签名 + notarytool + stapler）
- [x] 单元测试（引擎抽象层、协调器、历史库、插件运行时）覆盖关键路径（24 passing）
- [x] 文档：README、CONTRIBUTING.md、SECURITY.md、插件开发指南（docs/plugin-development.md）
- [x] 确定 License（D-3 = AGPL-3.0）并加入 LICENSE 文件
- [x] CI（GitHub Actions：build + test + 打包 artifact，`.github/workflows/ci.yml`）
- [~] `.dmg` 打包 / GitHub Release 首版发布（脚本就绪，发布动作待人工触发）
- **DoD**：用户可从 GitHub 下载 notarized 版本开箱即用（构建/签名/公证链路就绪）

## 决策项（已拍板）

- [x] D-3 开源 License = **AGPL-3.0**
- [x] D-6 最低系统版本 = **macOS 13 Ventura**
