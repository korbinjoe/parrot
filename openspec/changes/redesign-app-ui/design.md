# Design: Parrot macOS App UI 重设计

本文件定义 Parrot 重设计的设计 token、组件层级、各界面布局规格、状态态与交互动效。HTML 视觉稿（`mockups/index.html`）是本文件的可视化实现，二者保持一致；SwiftUI 落地以此为契约。

设计基准：**macOS Human Interface Guidelines**。准绳——「放进 macOS 与系统其它 App 并排，用户不应察觉它是第三方做的」。

---

## 1. 设计 Token

### 1.1 颜色（语义色，成对定义浅/深）

不发明色板，全部映射到 macOS 系统语义色。强调色全局唯一：systemBlue。

| Token | 浅色 | 深色 | SwiftUI 映射 | 用途 |
|------|------|------|------|------|
| `--bg-window` | #ECECEC (vibrancy) | #1E1E1E | `Color(nsColor: .windowBackgroundColor)` | 窗口底 |
| `--bg-content` | #FFFFFF | #2A2A2C | `Color(nsColor: .textBackgroundColor)` | 内容/卡片面 |
| `--bg-content-2` | #F5F5F7 | #323234 | `Color(nsColor: .underPageBackgroundColor)` | 次级面/原文区 |
| `--bg-sidebar` | rgba(246,246,246,.8) | rgba(40,40,42,.8) | `.regularMaterial` | 侧栏/Popover 材质 |
| `--separator` | rgba(0,0,0,.10) | rgba(255,255,255,.12) | `Color(nsColor: .separatorColor)` | 分隔线/描边 |
| `--label` | #1D1D1F | #F5F5F7 | `.primary` / `.labelColor` | 主文本 |
| `--label-2` | rgba(60,60,67,.6) | rgba(235,235,245,.6) | `.secondary` | 次文本 |
| `--label-3` | rgba(60,60,67,.3) | rgba(235,235,245,.3) | `.tertiary` | 三级（引擎名/延迟） |
| `--accent` | #007AFF | #0A84FF | `Color.accentColor` / systemBlue | 强调/主操作/聚焦 |
| `--accent-soft` | rgba(0,122,255,.10) | rgba(10,132,255,.18) | accent.opacity | 选中底/标签底 |
| `--success` | #34C759 | #30D158 | systemGreen | 成功/收藏可用 |
| `--warning` | #FF9F0A | #FF9F0A | systemOrange | 限流/警告 |
| `--danger` | #FF3B30 | #FF453A | systemRed | 错误/鉴权失败 |
| `--star` | #FFCC00 | #FFD60A | systemYellow | 收藏星标 |

红绿灯按钮（窗口控制）：`#FF5F57` / `#FEBC2E` / `#28C840`，直径 12px，间距 8px。

### 1.2 字体（SF 阶梯）

字体族：`-apple-system, "SF Pro Text", "SF Pro Display", "PingFang SC", system-ui`。
SwiftUI 用 `.font(.system(...))` 语义阶，HTML 用对应 px。**禁止散落硬编码字号**，统一引用：

| Token | size / weight / line-height | SwiftUI | 用途 |
|------|------|------|------|
| `title` | 17 / semibold / 22 | `.title3.weight(.semibold)` | 窗口标题、详情主词 |
| `headline` | 15 / semibold / 20 | `.headline` | 区块标题 |
| `body` | 13 / regular / 18 | `.body`(macOS 13pt) | 正文/原文 |
| `result` | 15 / regular / 21 | `.system(size:15)` | 译文主区（比原文大一档，建立主次） |
| `callout` | 12 / regular / 16 | `.callout` | 释义/音标/辅助 |
| `caption` | 11 / regular / 14 | `.caption` | 时间、延迟 |
| `tag` | 10 / semibold / 12 / +0.5 tracking | `.caption2.weight(.semibold)` | 引擎名标签（大写） |

支持动态字号：HTML 用 `rem` 演示，SwiftUI 用语义字体自动响应。

### 1.3 间距（8pt 栅格）

`4 / 8 / 12 / 16 / 20 / 24`。卡片内边距 12，区块间距 10，窗口边距 16，侧栏行高 28。禁止任意像素（如 13px、7px）。

### 1.4 圆角与阴影

| Token | 值 | 用途 |
|------|------|------|
| `radius-window` | 12 | 浮窗/窗口圆角 |
| `radius-card` | 10 | 卡片 |
| `radius-control` | 6 | 按钮/输入/标签 |
| `radius-pill` | 999 | 语言切换药丸、状态点 |
| `shadow-panel` | 0 12px 32px rgba(0,0,0,.18), 0 0 0 .5px var(--separator) | 浮层/窗口投影 |
| `shadow-card` | none（用 `--bg` 区分层次，不靠阴影堆叠） | 卡片 |

原则：层次靠**背景明度差 + 0.5px 描边**，不靠多层投影。全局唯一一处大投影＝浮窗本体。

---

## 2. 组件层级

```
Tokens（颜色/字体/间距/圆角）
  └─ Primitives
       ├─ IconButton（borderless，hover 出现 --bg-content-2 圆底，20×20 命中区）
       ├─ Tag（引擎名/语言对，--accent-soft 底 + tag 字阶）
       ├─ LangPill（源→目标，中间 ⇄ 可点互换）
       ├─ StatusDot（success/warning/danger 小圆点 + caption 文案）
       └─ Skeleton（--bg-content-2 + shimmer，用于加载）
  └─ Blocks
       ├─ SourceBlock（原文 + 复制/朗读/收藏 + 检测语言标签）
       ├─ EngineCard（引擎名 Tag + 延迟 + 译文 result 字阶 + 释义 + 复制/朗读；error 态红卡）
       ├─ HistoryRow（语言对 + 原文截断 + 时间 + 星标）
       └─ SettingRow（label + 控件，右对齐控件）
  └─ Surfaces（窗口/浮层）
       ├─ ResultPanel（悬浮结果面板）★核心
       ├─ InputBar（Spotlight 式输入）
       ├─ MenuBarPopover（菜单栏弹出）
       ├─ SettingsWindow（侧栏 + 面板）
       ├─ HistoryWindow（列表 + 详情双栏）
       └─ OCROverlay（截图取词浮层）
```

---

## 3. 各界面布局规格

### 3.1 ResultPanel 悬浮结果面板（核心）

宽 **380**，高自适应（上限 ~460 后内滚）。`.regularMaterial` 底 + `shadow-panel` + `radius-window`。无标题栏、无红绿灯（即用即走）。底部尖角箭头指向触发光标（CSS 三角形演示；SwiftUI 用自定义 Shape 或省略）。

结构（从上到下）：
1. **顶部细栏**（高 28）：左 `LangPill`（检测语言 → 目标，如 `EN ⇄ 中`），右侧 IconButton 组（Pin 常驻 / 收藏★ / 复制原文 / 朗读原文）。
2. **SourceBlock**：`--bg-content-2` 底，原文 body 字阶、`--label`；翻译中右上角小号 ProgressView。
3. **分隔**：8px 间距，无可见线（靠背景差）。
4. **EngineCard 区**：多引擎纵向堆叠，每卡：
   - 头行：引擎名 `Tag`（如 GOOGLE，accent-soft 底）+ 右侧延迟 caption（`128ms`）+ hover 出现复制/朗读 IconButton。
   - 译文：`result` 字阶（15pt，比原文大），`--label`，可选文本。
   - 查词态额外：音标 callout（`--label-2`）+ 词性·释义逐行 callout。
   - 主引擎（第一个/用户置顶）左侧 2px `--accent` 竖条做轻标识。
   - error 态：整卡 `--danger` 0.5px 描边 + `--danger` 文案 + 重试 IconButton。

交互态：
- 入场：opacity 0→1 + translateY 8px→0，**180ms ease-out**。
- 退场（失焦自动隐藏）：opacity 1→0 + translateY 0→4px，**120ms ease-in**。
- 常驻：默认关闭。点击 Pin 后，面板不再因失焦隐藏，并保持当前位置；再次点击 Pin 后恢复默认失焦隐藏。
- 异步引擎返回：新卡片 fade-in 120ms；面板高度变化由 SwiftUI 自适应（不手动补间高度，避免抖动）。
- IconButton hover：圆底 `--bg-content-2` 80ms。

### 3.2 InputBar 输入翻译面板

宽 **520**，单行起高 56，可增长至 4 行。Spotlight 式：无标题栏、`radius-window`、`shadow-panel`、`.regularMaterial`。
- 左侧搜索/翻译图标（`character.bubble`），中间大号输入（`result` 15pt），右侧 `LangPill`。
- 底行（仅有文字时出现）：左提示 `↩ 翻译  ⎋ 关闭`，右 `翻译` 主按钮（accent 实心）。
- 聚焦：accent 0.5px 外环。`Esc` 关闭，回车提交后此窗隐藏、结果走 ResultPanel。

### 3.3 MenuBarPopover 菜单栏弹出

宽 **260**，`.regularMaterial`，从状态栏图标下方箭头弹出。替换裸 NSMenu。
1. 四大动作行（图标 + 名称 + 右侧快捷键 caption）：划词翻译 ⌥D / 查词 ⌥E / 截图翻译 ⌥S / 输入翻译 ⌥A。hover 整行 `--accent-soft` 底。
2. 分隔线。
3. **最近**：标题 caption + 最多 3 条 `HistoryRow`（点击再翻译），「查看全部历史」链接。
4. 分隔线。
5. **引擎快捷开关**：Google / DeepL / OpenAI 三个 Toggle（小号），与设置同步。
6. 底行：设置… ⌘, / 退出 ⌘Q（次要文字按钮）。

### 3.4 SettingsWindow 设置窗口

宽 **640** 高 **460**。标准标题栏 + 红绿灯。左 **侧栏**（宽 180，`.regularMaterial`，6 个分区图标+名）：通用 / 引擎 / 密钥 / 快捷键 / 插件 / 关于。右内容面板（`--bg-content`，边距 20）：
- 通用：默认目标语言 Picker、开机启动 Toggle、浮窗自动隐藏延时。
- 引擎：每引擎一行 `SettingRow`（图标 + 名 + 状态点 + Toggle + 拖拽排序手柄定优先级）。
- 密钥：DeepL / OpenAI SecureField + 校验状态点 + 「保存到钥匙串」按钮 + 安全提示 callout。
- 快捷键：四项可录制快捷键的 `KeyRecorder`（视觉稿用胶囊键帽展示）。
- 插件：已安装插件列表（名/版本/开关/打开目录），「插件目录」「开发文档」链接。
- 关于：图标 + 版本 + 开源链接 + License。

用 `SettingRow`：label 左、控件右对齐，行高 28，分区用 `headline` 标题 + 16px 上间距。

### 3.5 HistoryWindow 历史 / 收藏（新增）

宽 **720** 高 **480**。标准窗口。左 **列表栏**（宽 280）：顶搜索框 + 分段控件（全部 / 收藏）+ 语言对筛选；下方 `HistoryRow` 列表（语言对 Tag + 原文单行截断 + 时间 caption + 右侧星标）。右 **详情**：原文 SourceBlock + 各引擎 EngineCard（复用结果面板组件）+ 操作（复制/朗读/再翻译/删除/收藏）。空态：居中插画占位 + 「还没有历史记录」。

### 3.6 OCROverlay 截图取词浮层（新增）

全屏暗化 40% 遮罩 + 框选区高亮（accent 1px 边 + 四角把手）。三态：
1. 框选中：实时尺寸 caption 跟随。
2. 识别中：选区内骨架行 + 「识别中…」。
3. 识别完成：选区下方浮出小卡，逐行可勾选 OCR 文本 + 「翻译选中」主按钮（结果走 ResultPanel）。

---

## 4. 状态态规范（全界面通用）

| 态 | 样式 |
|----|------|
| 加载 | `Skeleton`：`--bg-content-2` 底 + 自左向右 shimmer（1.2s linear infinite）；引擎卡显 2 行骨架 |
| 空 | 居中：SF Symbol 占位图（`--label-3`）+ headline 标题 + callout 说明，左对齐说明文字 |
| 错误 | 卡片 `--danger` 0.5px 描边 + 图标 + 文案 + 重试；文案映射 ProviderError（鉴权/限流/网络/超时/未配置/插件） |
| 无网络 | 顶部细条 `--warning` 软底 + 「离线，仅本地引擎可用」 |
| 未授权 | 首次划词失败时，ResultPanel 显示授权引导卡：说明 + 「打开系统设置 › 辅助功能」按钮 |

---

## 5. 交互动效总表

| 触发 | 动效 | 时长 / 缓动 |
|------|------|------|
| 浮窗出现 | opacity 0→1 + Y 8→0 | 180ms / ease-out |
| 浮窗失焦隐藏 | 未 Pin 时 opacity 1→0 + Y 0→4 | 120ms / ease-in |
| Pin 常驻切换 | pin 图标填充/取消填充 + 状态文案切换 | 120ms / ease |
| 引擎结果到达 | 卡片 fade-in | 120ms / ease-out |
| IconButton hover | 圆底淡入 | 80ms / ease |
| 行 hover（菜单/历史） | 背景 `--accent-soft` | 80ms |
| 主题切换 | 全局色过渡 | 200ms / ease |
| 设置分区切换 | 内容区 crossfade | 120ms |
| LangPill ⇄ 互换 | 图标旋转 180° | 200ms / ease-in-out |

原则：只做**状态反馈**动效，无装饰性动画（无 bounce/pulse/float）。

---

## 6. Decisions

1. **材质近似而非像素一致**：HTML 用 `backdrop-filter: blur()` 模拟 vibrancy，SwiftUI 用 `.regularMaterial`；实现验收以观感与层次为准，不追求与 HTML 完全一致。
2. **层次靠明度+描边，不堆阴影**：全局仅浮窗本体一处大投影，卡片间用 `--bg-content` / `--bg-content-2` 明度差区分。原因：避免「AI 味」多层 glow。
3. **强调色全局唯一 systemBlue**：收藏星黄、状态点红绿橙属语义色不计入强调色预算；每个视图最多 1 处蓝。
4. **悬浮窗高度不手动补间**：沿用现有 `preferredContentSize` 自适应，动画只做 opacity+offset，规避 NSPanel 高度抖动（见 proposal Risks）。
5. **历史/收藏与 OCR 浮层视觉稿先行**：UI 与交互契约在本次定义，数据接线在 apply 阶段由 fullstack-engineer 承接。
6. **OCR 选区沿用系统 `screencapture -i`，不自绘选区窗口**：macOS 原生选区已自带遮罩/十字线/四角把手/实时尺寸读数，且久经验证；自绘全屏拖拽选区需重做截图链路并依赖屏幕录制权限，对一个已可用路径是回归风险。本次只新增「识别后逐行可勾选卡片」这一真正增量（`OCRResultPanel`）：单行直接翻译保「即用即走」，多行才弹选择浮层。

---

## 7. SwiftUI 落地映射要点

- 颜色：新建 `DesignTokens.swift`，将上表语义色封装为 `Color` 扩展，深浅由系统语义色自动切换，避免硬编码 `.red`/`Color(nsColor:.windowBackgroundColor)` 散落。
- 字体：封装 `Font` 扩展（`.result`/`.tag` 等），替换现有 `.system(size: 10/11/13/14)` 散值。
- 间距：用常量 `Spacing.s4/s8/...`，替换 `padding(12/14)` 魔法数。
- 材质：浮层/侧栏/Popover 改用 `.background(.regularMaterial)`。
- 组件：`SourceBlock` / `EngineCard` 抽为独立 View，供 ResultPanel 与 HistoryWindow 复用。
