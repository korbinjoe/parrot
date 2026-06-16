# Tasks: 重设计 Parrot macOS App UI 与交互

落地顺序：设计基线 → 悬浮面板（MVP 门禁）→ 输入面板 → 菜单栏 Popover → 设置 → 历史/收藏 → OCR 浮层 → 全局态与动效。
图例：`[设计]` ui-designer · `[实现]` fullstack-engineer · `[评审]` code-reviewer/architect。

## 阶段 0 — 设计基线（已交付视觉稿）

- [x] [设计] proposal.md / design.md
- [x] [设计] 高保真可交互 HTML 视觉稿 `mockups/index.html`（6 界面 + 明暗 + 加载/错误态）
- [x] [设计] 浏览器渲染验证 + 截图存档（`mockups/*.png`）
- [x] [实现] 新建 `Sources/ParrotApp/DesignTokens.swift`：语义色 `Color` 扩展、`Font` 扩展（`.result`/`.tag`/`.caption` 等）、`Spacing` 常量、圆角常量
- [x] [实现] 替换悬浮面板/输入面板内散落的硬编码字号、`.red`、padding 魔法数为 token（其余界面随各阶段跟进）

## 阶段 1 — 悬浮结果面板（核心 / MVP 门禁）

- [x] [实现] 抽出可复用结果卡和 pending 卡；共享 `LangPill`/`IconButton` 入 UIComponents（`SourceBlock` 内联于面板，历史窗口复用时再抽）
- [x] [实现] `ResultView` 重构：顶部 LangPill 栏 + 操作组、原文区用实色 `bgContent`、按设置顺序展示结果槽位
- [x] [实现] 译文字阶提升至 15pt（`.result`），引擎名改 Tag 样式（accent-soft 底）
- [x] [实现] 结果展示顺序跟随设置页「结果顺序」，异步返回不改变槽位位置
- [x] [实现] 每个成功结果保留复制/朗读 IconButton
- [x] [实现] 错误行：danger 文案映射 `ProviderError`；鉴权/未配置时提供「配置密钥」
- [x] [实现] 加载态骨架屏（`Skeleton` shimmer），翻译中原文区右上小 ProgressView
- [x] [实现] FloatingPanel 改 `bgPanel` 实色底；入场 0.18s 淡入（按 Decision 4 只做 opacity，不补间高度）
- [x] [实现] Pin 常驻按钮：默认失焦隐藏；Pin 后跳过失焦自动隐藏并保持当前位置
- [ ] [实现] 面板底部指向光标的箭头 Shape（可选；不影响验收）
- [ ] [评审] 对照 `mockups` 截图做像素/交互验收（明暗双模式，需 GUI 会话目检）

## 阶段 2 — 输入翻译面板

- [x] [实现] `InputView` 升级 Spotlight 式：左图标 + 大号输入 + 右 LangPill
- [x] [实现] 底部提示行（`↩ 翻译 / ⎋ 关闭`）+ accent 主按钮，仅有文字时出现
- [x] [实现] 聚焦 accent 外环；`Esc` 关闭（onExitCommand）（InputBar 的 LangPill 后续复用面板语言选择逻辑）
- [x] [实现] InputPanel 改 `bgPanel` + `radius-window` + `shadow-panel`

## 阶段 3 — 菜单栏 Popover

- [x] [实现] 用 `NSPopover` + SwiftUI 替换 AppDelegate 的裸 `NSMenu`
- [x] [实现] 四大动作行（图标 + 名 + 快捷键 caption，hover bgSelection）
- [x] [实现] 「最近」区：注入最多 3 条 HistoryStore 记录，点击再翻译 + 「查看全部历史」入口
- [x] [实现] 菜单栏不展示引擎配置；引擎开关、密钥和结果顺序统一放在设置页
- [x] [实现] 底部「设置… ⌘,」「退出 ⌘Q」

## 阶段 4 — 设置窗口

- [x] [实现] `SettingsView` 改「侧栏 + 内容面板」（6 分区：通用/引擎/密钥/快捷键/插件/关于）
- [x] [实现] 通用：默认来源语言、默认目标语言（开机启动/失焦自动隐藏/菜单栏图标待 AppSettings 接线）
- [x] [实现] 引擎：每引擎行（状态点 + Toggle，接 AppSettings）（拖拽优先级待 ProviderRegistry 排序能力）
- [x] [实现] 密钥：SecureField + 校验状态点 + 「保存到钥匙串」+ 安全提示 callout
- [x] [实现] 快捷键：键帽样式展示（只读；可录制 KeyRecorder 待全局热键改造）
- [x] [实现] 插件：「打开插件目录」+ 目录/文档链接 callout（已安装列表待插件清单 API）
- [x] [实现] 关于：图标 + 版本 + 开源链接

## 阶段 5 — 历史 / 收藏窗口（新增）

- [x] [实现] 新建 `HistoryWindow`（NSWindow + SwiftUI），列表 280 + 详情双栏
- [x] [实现] 列表：搜索框 + 全部/收藏分段 + 语言对筛选 + HistoryRow
- [x] [实现] 详情：源文块 + 译文卡（providerId Tag + 时间）+ 再翻译/复制/朗读/删除/收藏
- [x] [实现] 接 HistoryStore（检索/收藏/删除）；空态占位
- [ ] [实现] 菜单栏 Popover「查看全部历史」打开此窗口（待阶段 3 AppDelegate 改造，re-translate 闭包已预留）

## 阶段 6 — 截图 OCR 取词浮层（新增）

- [x] [实现] 选区反馈：沿用系统 `screencapture -i`（已自带遮罩/十字线/把手/实时尺寸，且可靠）—— 见 Decision 5，避免自绘选区回归可用路径
- [x] [实现] 识别完成后逐行可勾选卡片（`OCRResultPanel`，默认全选 + 全选/取消全选）
- [x] [实现] 「翻译选中」→ 结果走 ResultPanel（单行直接翻译，多行才弹选择浮层，保「即用即走」）
- [x] [实现] `ScreenOCR.recognizeLines` 暴露有序分行，复制选中

## 阶段 7 — 全局态与动效收口

- [x] [实现] 无网络顶部 warning 细条（`WarningBar` + `AppState.isOffline`/NWPathMonitor）；未授权沿用引导 Alert + 「打开系统设置」深链
- [x] [实现] 统一行 hover（HoverRow/侧栏/历史行 bgSelection）、分区 crossfade（设置 0.15s）
- [x] [实现] 深色模式：令牌走系统语义色明暗自适配；逐像素 WCAG 目检列入 review 未尽项（需 GUI 会话）
- [x] [评审] 评审结论写入 `review.md` 的「UI Review」段（代码/构建层全绿，视觉终检列出 4 项需 GUI）
- [x] [归档] 新增 `openspec/specs/app-ui/spec.md` 能力 spec（living 文档）

## 验收门禁

- 阶段 1（悬浮面板）= MVP 必达：明暗双模式、加载/空/错误态齐全、与 `mockups` 一致。
- 所有界面颜色/字阶/间距来自 `DesignTokens.swift`，`grep` 不应再有散落硬编码字号与 `.red`。
- 每个交付界面附浏览器/真机截图作为「done」证据。
