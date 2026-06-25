# Review

## Code Review

- [x] HTML 原型为独立静态文件，不影响生产 SwiftUI 代码。
- [x] 内联脚本通过 `new Function` 语法校验。
- [x] 核心交互覆盖：筛选、搜索、打开 picker、搜索 provider、选择 provider、展开表单、保存、验证、清除、关闭 sheet、明暗模式切换。

## Architecture Review

- [x] Provider catalog 与状态卡片在原型中分离，符合未来 SwiftUI 落地时拆分 `credentialSections` 的方向。
- [x] 保留现有 credential / account 映射边界，不引入底层配置模型变化。
- [x] Provider picker 只作为目录入口，不替代缺 Key / 已配置 / 环境变量状态展示。

## UI Review

- [x] Chrome headless 桌面视口 `1280x900` 渲染通过，无横向 overflow。
- [x] Chrome headless 移动视口 `390x844` 渲染通过，无横向 overflow。
- [x] Picker 搜索 `DeepSeek` 后只剩 1 条结果，选择后展开 DeepSeek 表单。
- [x] 保存交互显示 `DeepSeek 已保存到 iOS Keychain` toast。

## macOS UI Review

- [x] `mockups/macos.html` 静态 HTML / JS 语法校验通过。
- [x] Chrome headless 桌面视口 `1280x900` 渲染通过，无横向 overflow。
- [x] Chrome headless 窄屏视口 `900x760` 渲染通过，无横向 overflow，右侧错误恢复面板按预期隐藏。
- [x] Provider picker 打开后显示 13 个 provider；搜索 `DeepSeek` 后只剩 1 条结果。
- [x] 选择 DeepSeek 后展开表单，保存后显示 `DeepSeek 已保存到本机` toast。
- [x] 桌面视口点击错误面板 `配置密钥` 可切回 Keys 并展开 OpenAI 表单。

## Implementation Review

- [x] macOS Settings 窗口尺寸调整为 `820x650`，最小尺寸 `720x520`，贴近 `mockups/macos.html`。
- [x] Keys 页默认使用状态优先结构：摘要卡、搜索、chip 筛选、Provider 状态卡、单 Provider 表单。
- [x] Provider picker 以 macOS popover 实现，按 `常用 / LLM / OCR & TTS / 云厂商` 分组。
- [x] 复用现有 `CredentialCatalog`、`AppSettings`、`EngineValidator`、错误态聚焦和重试逻辑。
- [x] `swift build` 通过。
- [x] `swift test` 通过，100 个测试全绿。
