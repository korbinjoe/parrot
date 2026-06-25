# Settings Keys Provider Picker Design

## Design Decision

Keys 页不采用单一 provider 下拉框。推荐结构是「任务状态平铺 + provider 目录选择器」：

- **平铺卡片负责状态**：缺 Key、已配置、环境变量、无需 Key 需要直接可见。
- **provider picker 负责目录**：低频 provider 不常驻主列表，通过搜索和分组快速添加。
- **表单按 provider 展开**：用户选中 provider 后只处理一个服务，减少同屏多表单干扰。

## Information Architecture

### 主页面

1. Context banner：说明当前页用于修复服务配置。
2. Summary strip：显示需处理、已配置、环境变量三个关键计数。
3. Primary action：`添加服务` 打开 picker。
4. Quick filters：需处理、已配置、环境变量、OCR/TTS、LLM。
5. Status cards：默认只展示需要处理和已配置的 provider。
6. Security note：iOS 说明存储在 Keychain；macOS 说明存储在本机密钥库，环境变量优先。

### Provider Picker

- 作为 bottom sheet 出现，保留当前页面上下文。
- 顶部搜索框支持 provider 名、环境变量名、类别关键词。
- 列表按 `常用 / LLM / OCR & TTS / 云厂商` 分组。
- 每行展示 provider 名、用途、状态点、是否需要 Key。
- 选中后关闭 picker，并把 provider 表单插入主页面顶部。

### Provider Form

- 表单包含 Key、Model、Endpoint 等 provider 相关字段。
- 主按钮使用「保存并返回工作区」或「保存」语义。
- 次级动作：验证、清除。
- 环境变量 provider 只展示只读说明，不强制保存本地 Key。

## Interaction Rules

- 首次进入 Keys：默认筛选 `需处理`。
- 从失败结果进入：把失败 provider 置顶并展开表单。
- 点击 `添加服务`：打开 picker，搜索框自动聚焦。
- 选中 provider：关闭 picker，选中卡片展开。
- 保存成功：状态更新为 `已配置`，卡片移动到已配置区域。
- 清除：状态回到缺 Key 或未配置。
- Esc / 点击遮罩 / 下滑句柄：关闭 picker。

## Visual Direction

- iOS 原生设置页气质：安静、紧凑、可扫描。
- 色彩使用绿、琥珀、蓝、红做状态区分，避免单一色相。
- 卡片圆角控制在 8px，符合当前 iOS mockup 的工具型界面基调。
- 不使用营销式 hero、不使用装饰性渐变球。

## Future SwiftUI Impact

生产落地主要影响 `Apps/iOS/ParrotiOS/SettingsView.swift` 的 Keys pane：

- 增加 provider picker sheet 状态。
- 将 `credentialSections` 拆为可用于 picker 的 provider catalog。
- 保留现有 `credentialAccounts`、Keychain store、保存/清除逻辑。
- 不影响翻译引擎、OCR/TTS 执行路径。

## macOS Variant

macOS Settings 窗口沿用系统设置式 sidebar + 详情页结构，不使用 iOS bottom sheet：

- Provider picker 使用靠近 `添加 Provider` 按钮的浮层或居中轻量 panel。
- Keys 内容区默认展示状态摘要、当前需处理卡片、已配置卡片和安全说明。
- 从结果面板错误态点击 `配置密钥` 时，Settings 窗口应切到 Keys，并展开对应 provider 表单。
- 表单按钮使用 macOS 语义：`保存到本机`、`验证`、`清除`，不自动关闭 Settings 窗口。

## Implementation Decision

本轮生产实现只还原 macOS `Settings > 密钥`。底层 `CredentialCatalog`、`AppSettings` 密钥存储、`EngineValidator` 和错误态打开设置的路由保持不变；视觉稿中的右侧错误面板只作为恢复路径说明，不嵌入设置窗口。
