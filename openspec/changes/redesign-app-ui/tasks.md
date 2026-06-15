# Tasks: 重设计 Parrot macOS App UI 与交互

落地顺序：设计基线 → 悬浮面板（MVP 门禁）→ 输入面板 → 菜单栏 Popover → 设置 → 历史/收藏 → OCR 浮层 → 全局态与动效。
图例：`[设计]` ui-designer · `[实现]` fullstack-engineer · `[评审]` code-reviewer/architect。

## 阶段 0 — 设计基线（已交付视觉稿）

- [x] [设计] proposal.md / design.md
- [x] [设计] 高保真可交互 HTML 视觉稿 `mockups/index.html`（6 界面 + 明暗 + 加载/错误态）
- [x] [设计] 浏览器渲染验证 + 截图存档（`mockups/*.png`）
- [ ] [实现] 新建 `Sources/ParrotApp/DesignTokens.swift`：语义色 `Color` 扩展、`Font` 扩展（`.result`/`.tag`/`.caption` 等）、`Spacing` 常量、圆角常量
- [ ] [实现] 全量替换散落的硬编码字号（10/11/13/14）、`.red`、`padding(12/14)` 魔法数为 token

## 阶段 1 — 悬浮结果面板（核心 / MVP 门禁）

- [ ] [实现] 抽出可复用 `SourceBlock` 与 `EngineCard` View（供面板与历史窗口共用）
- [ ] [实现] `ResultView` 重构：顶部 LangPill 栏 + 操作组、原文区用 `--bg-content-2`、引擎卡用 `--bg-content`
- [ ] [实现] 译文字阶提升至 15pt（`.result`），引擎名改 Tag 样式（accent-soft 底）
- [ ] [实现] 主引擎左侧 2px accent 竖条标识
- [ ] [实现] 卡片 hover 才显复制/朗读 IconButton（`opacity` 切换，禁用 `display` 切换避免抖动）
- [ ] [实现] 错误卡：danger 描边 + 文案映射 `ProviderError` + 重试按钮
- [ ] [实现] 加载态骨架屏（`Skeleton` shimmer），翻译中原文区右上小 ProgressView
- [ ] [实现] FloatingPanel 改 `.regularMaterial` 底；入场 opacity+offset 180ms、退场 120ms
- [ ] [实现] 面板底部指向光标的箭头 Shape（可选；不影响验收）
- [ ] [评审] 对照 `mockups` 截图做像素/交互验收（明暗双模式）

## 阶段 2 — 输入翻译面板

- [ ] [实现] `InputView` 升级 Spotlight 式：左图标 + 大号输入 + 右 LangPill
- [ ] [实现] 底部提示行（`↩ 翻译 / ⎋ 关闭`）+ accent 主按钮，仅有文字时出现
- [ ] [实现] 聚焦 accent 外环；`Esc` 关闭；LangPill ⇄ 互换源/目标语言
- [ ] [实现] InputPanel 改 `.regularMaterial` + `radius-window` + `shadow-panel`

## 阶段 3 — 菜单栏 Popover

- [ ] [实现] 用 `NSPopover` + SwiftUI 替换 AppDelegate 的裸 `NSMenu`
- [ ] [实现] 四大动作行（图标 + 名 + 快捷键 caption，hover accent-soft）
- [ ] [实现] 「最近」区：注入最多 3 条 HistoryStore 记录，点击再翻译 + 「查看全部历史」入口
- [ ] [实现] 引擎快捷开关（Google/DeepL/OpenAI Toggle），与 AppSettings 双向同步
- [ ] [实现] 底部「设置… ⌘,」「退出 ⌘Q」

## 阶段 4 — 设置窗口

- [ ] [实现] `SettingsView` 改「侧栏 + 内容面板」（6 分区：通用/引擎/密钥/快捷键/插件/关于）
- [ ] [实现] 通用：默认目标语言、开机启动、失焦自动隐藏、菜单栏图标开关
- [ ] [实现] 引擎：每引擎行（状态点 + Toggle + 拖拽手柄定优先级）；优先级落地到 ProviderRegistry 排序
- [ ] [实现] 密钥：SecureField + 校验状态点 + 「保存到钥匙串」+ 安全提示 callout
- [ ] [实现] 快捷键：可录制的 KeyRecorder（胶囊键帽样式）
- [ ] [实现] 插件：已安装列表（名/版本/开关/打开目录）+ 目录/文档链接
- [ ] [实现] 关于：图标 + 版本 + 开源链接 + License

## 阶段 5 — 历史 / 收藏窗口（新增）

- [ ] [实现] 新建 `HistoryWindow`（NSWindow + SwiftUI），列表 280 + 详情双栏
- [ ] [实现] 列表：搜索框 + 全部/收藏分段 + 语言对筛选 + HistoryRow
- [ ] [实现] 详情：复用 SourceBlock/EngineCard + 再翻译/复制/朗读/删除/收藏
- [ ] [实现] 接 HistoryStore（检索/收藏/删除）；空态占位
- [ ] [实现] 菜单栏 Popover「查看全部历史」打开此窗口

## 阶段 6 — 截图 OCR 取词浮层（新增）

- [ ] [实现] SelectionCapture 反馈升级：遮罩 40% + accent 边 + 四角把手 + 实时尺寸 caption
- [ ] [实现] 识别中骨架态；识别完成后选区下方逐行可勾选卡片
- [ ] [实现] 「翻译选中」→ 结果走 ResultPanel

## 阶段 7 — 全局态与动效收口

- [ ] [实现] 无网络顶部 warning 细条；未授权（辅助功能）引导卡 + 「打开系统设置」
- [ ] [实现] 统一行 hover、主题切换、分区 crossfade、LangPill 旋转动效（仅状态反馈，无装饰动画）
- [ ] [实现] 深色模式全界面 WCAG AA 对比自查
- [ ] [评审] 多视图最终评审，结论写入 `review.md` 的「UI Review」段
- [ ] [归档] 通过后合并 delta 设计规范到 `openspec/specs/`（新增 `app-ui` 能力 spec）

## 验收门禁

- 阶段 1（悬浮面板）= MVP 必达：明暗双模式、加载/空/错误态齐全、与 `mockups` 一致。
- 所有界面颜色/字阶/间距来自 `DesignTokens.swift`，`grep` 不应再有散落硬编码字号与 `.red`。
- 每个交付界面附浏览器/真机截图作为「done」证据。
