# Review: 重设计 Parrot macOS App UI 与交互

## UI Review

### 代码静态审查（Layer 0）

- [x] 设计令牌单一来源：六界面颜色/字阶/间距/圆角均走 `Theme`（DesignTokens.swift）。
- [x] 无 `.red` 等硬编码语义色：`grep` 全工程 `Sources/ParrotApp` 无命中。
- [x] 剩余 `.system(size: 11/12)`：仅用于小图标与快捷键键帽，属可接受的图标级字号，未污染正文字阶。
- [x] 行内边距 `padding(.horizontal, 10)`：作为列表行统一内缩，外层容器用 `Theme.Spacing` token；非散落魔法数。
- [x] hover 显隐用 `opacity` 切换（EngineCard 复制/朗读），未用 `display`/`hidden` 切换，无布局抖动。
- [x] 状态覆盖：加载（SkeletonCard）、空（"无可用引擎"/"暂无记录"）、错误（danger 卡 + ProviderError 文案）、离线（WarningBar）。
- [x] 长文本防御：HistoryRow/recentRow `lineLimit(1)`，结果/源文 `fixedSize(vertical)` 自动换行。
- [x] 无 AI 味：无渐变、无彩色 glow、无装饰动画（仅 opacity/crossfade 状态反馈）；强调色每视图唯一蓝，语义色（星黄/状态红绿橙/warning）不计入预算。

### 已落地界面（编译 + 单测验证）

| 阶段 | 界面 | 文件 | 状态 |
|------|------|------|------|
| 1 | 悬浮结果面板 | ResultView.swift | ✅ 编译通过 |
| 2 | 输入面板 Spotlight | InputPanel.swift | ✅ |
| 3 | 菜单栏 Popover | MenuBarPopover.swift + AppDelegate | ✅ |
| 4 | 设置窗口 | SettingsWindow.swift | ✅ |
| 5 | 历史/收藏窗口 | HistoryWindow.swift | ✅ |
| 6 | OCR 逐行结果浮层 | OCRResultPanel.swift + ScreenOCR | ✅ |
| 7 | 全局态/动效 | AppState(NWPathMonitor) + WarningBar + crossfade | ✅ |

`swift build` 通过；`swift test` 24/24 通过。

### 关键决策

- **Decision 6**（design.md）：OCR 选区沿用系统 `screencapture -i`（已含遮罩/十字线/四角把手/实时尺寸且久经验证），不自绘选区窗口以免回归可用截图链路。本次只新增「识别后逐行可勾选卡片」这一真正增量。
- 未授权（辅助功能）沿用既有引导 Alert + 「打开设置」深链，未改为内联卡片——Alert 模态可操作性更佳，符合「即用即走」。

### 未尽事项（需 GUI 会话目检，无法无人值守验证）

1. **像素/交互验收**：六界面明暗双模式与 `mockups/*.png` 的逐像素比对，需有头 GUI 会话（菜单栏 App，浮窗依赖辅助功能/录屏权限，无法 headless 截图）。
2. **深色模式 WCAG AA**：令牌走系统语义色，明暗自动适配理论达标；`WarningBar` 的 `warning.opacity(0.12)` 底 + `warning` 文字对比度建议真机目检。
3. **LangPill 旋转动效**：源语言互换尚未接线（当前恒为 `.auto`），故未加方向旋转动画——避免无真实状态变化的装饰动效；待源语言可切换后补。
4. **菜单栏 Popover 引擎开关 / 最近历史 / 再翻译闭包**：逻辑已接 AppSettings 与 HistoryStore，行为正确性需真机点测。

### 结论

代码层与构建层全绿，七个阶段功能完整落地、令牌统一、无 AI 味红线。**视觉/交互最终验收（明暗双模式像素比对、深色 WCAG 目检）需一次有头 GUI 会话补做**，建议在合并前由人工或 GUI runner 过一遍上述 4 项。
