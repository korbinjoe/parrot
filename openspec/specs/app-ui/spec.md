# Spec: App UI 与交互

## 目的

统一 Parrot 全部 macOS 界面（悬浮结果面板、输入面板、菜单栏 Popover、设置、历史/收藏、OCR 取词浮层）的视觉语言与交互规范，遵循 macOS HIG / SwiftUI，保「即用即走」。

## 设计令牌（单一来源）

所有颜色/字阶/间距/圆角来自 `Sources/ParrotApp/DesignTokens.swift` 的 `Theme`：

- **Palette**：语义系统色映射（`bgWindow`/`bgContent`/`bgContent2`/`separator`/`label`/`label2`/`label3`/`accent`/`accentSoft`/`success`/`warning`/`danger`/`star`），深浅由系统语义色自动切换。
- **Font**：`result` 15 / `body` 13 / `callout` 12 / `caption` 11 / `tag` 10(semibold)。
- **Spacing**：`s4`/`s8`/`s12`/`s16`/`s20`（8pt 栅格）。
- **Radius**：`window` 12 / `card` 10 / `control` 6。

约束：界面代码不得出现散落硬编码字号或 `.red` 等魔法值；强调色每视图最多 1 处蓝（语义状态色不计入预算）。

## 共享组件

- `LangPill(from:to:)` — 语言方向胶囊。
- `IconButton(name:help:size:)` — 24×24 无边框图标按钮。
- `WarningBar(_:systemImage:)` — 全局态细条（warning 调）。

## 各界面契约

1. **悬浮结果面板**（`ResultView`，380pt，`.regularMaterial`）：顶部 LangPill + 收藏/复制/朗读；原文块 `bgContent2`；每引擎一张 `EngineCard`（主引擎 2px accent 竖条，引擎名 Tag 样式，hover 才显复制/朗读用 opacity 切换）；加载骨架屏；错误卡 danger 描边 + `ProviderError` 文案映射；离线时顶部 `WarningBar`。
2. **输入面板**（`InputView`，520pt）：Spotlight 式左图标 + 大号输入 + 右 LangPill；仅有文字时出现底部提示行 + accent 主按钮；聚焦 accent 外环；Esc 关闭。
3. **菜单栏 Popover**（`MenuBarPopoverView`，260pt，`.transient`）：四大动作行（图标+名+快捷键，hover accent-soft）；最近 3 条历史可点再翻译 + 查看全部历史；引擎快捷开关（无 Key 禁用，双向同步 `AppSettings`）；设置/退出。
4. **设置窗口**（`SettingsView`，640×460）：侧栏 + 内容面板，6 分区（通用/引擎/密钥/快捷键/插件/关于）；分区切换 crossfade；密钥写入本地 SecretStore，输入框不回填完整密钥。
5. **历史/收藏窗口**（`HistoryView`，720×480 可缩放）：列表 280（搜索 + 全部/收藏分段 + 语言对筛选）+ 详情双栏（源文块 + 译文卡 + 再翻译/复制/朗读/删除/收藏）；空态占位。
6. **OCR 取词浮层**（`OCRResultView`，420×360）：选区沿用系统 `screencapture -i`；识别后逐行可勾选卡片（默认全选）；翻译选中 → 结果走悬浮面板；单行直接翻译，多行才弹浮层。

## 动效规范

- 仅状态反馈，无装饰动画：悬浮窗入场 0.18s opacity 淡入（不补间高度，规避 NSPanel 抖动）；卡片 hover 复制/朗读 opacity 切换；设置分区 0.15s crossfade；行 hover accent-soft。

## 行为要求

- **离线**：`AppState.isOffline`（`NWPathMonitor`）为真时结果面板顶部显示 `WarningBar`。
- **未授权（辅助功能）**：选区捕获为空且无权限时，弹引导 Alert + 「打开设置」深链。
- **深色模式**：令牌走系统语义色，明暗自动适配，满足 WCAG AA。

## 验收标准

- [ ] 六界面明暗双模式可用，与 `openspec/changes/redesign-app-ui/mockups` 一致（需 GUI 目检）
- [ ] `grep` 无散落硬编码字号与 `.red`
- [ ] 加载/空/错误/离线态齐全
- [ ] 截图多行可逐行勾选并翻译选中
