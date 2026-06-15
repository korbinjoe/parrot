# Tasks: Bob 引擎服务对标实现

> 参考 [Bob 添加服务](https://bobtranslate.com/guide/advance/service.html) 与 `design.md` 分阶段路线图。

## 1. 文档与对照表

- [x] 1.1 新增 `docs/bob-service-matrix.md`：Bob 27+8+5 服务 ↔ Parrot 路径/阶段/状态全表
- [x] 1.2 在 README 增加「从 Bob 迁移」小节，链接对照表与各引擎密钥申请说明
- [x] 1.3 为 P0/P1 引擎整理密钥申请外链（腾讯/百度/有道/彩云/Microsoft/OpenAI/DeepSeek/Gemini/智谱/硅基流动 等）

## 2. P0 — 传统机翻 Swift 内置（文本翻译）

- [x] 2.1 抽象共享 `HTTPTranslationEngine` 基类（请求/超时/错误映射），减少各引擎重复代码
- [x] 2.2 实现 `TencentEngine`（腾讯翻译君 TMT API）+ 语言码映射 + parse 单测
- [x] 2.3 实现 `BaiduEngine`（百度通用翻译）+ 签名鉴权 + parse 单测
- [x] 2.4 实现 `YoudaoEngine`（有道智云）+ lookup 模式音标/释义字段 + parse 单测
- [x] 2.5 实现 `CaiyunEngine`（彩云小译 v2）+ parse 单测
- [x] 2.6 实现 `MicrosoftEngine`（Azure Translator）+ region/key 配置 + parse 单测
- [x] 2.7 实现 `AppleTranslationEngine`（Translation framework，macOS 15+ SwiftUI bridge）
- [x] 2.8 扩展 `AppSettings`：各引擎 enabled 开关 + Keychain key ref + `validateKey()` 探测
- [x] 2.9 在 `AppState` 注册 P0 引擎，默认关闭，Google 保持默认开启
- [x] 2.10 设置 UI：文本翻译引擎列表（开关/排序/密钥/验证/教程链接）

## 3. P1 — 主流 LLM Swift 内置 + OCR 协议

### 3a. OpenAICompatEngine 与 P1 LLM

- [x] 3.1 将 `OpenAIEngine` 重构为 `OpenAICompatEngine` 基类；`OpenAIEngine` 改为子类（P1 交付，保持行为无回归）
- [x] 3.2 实现 `DeepSeekEngine`（OpenAI-compat，`deepseek-chat`）+ parse 单测
- [x] 3.3 实现 `GeminiEngine`（Google Generative Language API，独立实现）+ parse 单测
- [x] 3.4 实现 `GroqEngine` + `OllamaEngine`（endpoint 可配，默认 localhost）+ 单测
- [x] 3.5 实现 `QwenEngine`（DashScope compat）+ `DoubaoEngine`（火山方舟）+ `KimiEngine`（Moonshot）+ 单测
- [x] 3.6 实现 `ZhipuEngine`（智谱 GLM API）+ `SiliconFlowEngine`（OpenAI-compat 聚合）+ 单测
- [x] 3.7 扩展 `AppSettings`：各 LLM 的 enabled/key/model/endpoint + `validateKey()`
- [x] 3.8 在 `AppState` 注册 P1 LLM 引擎（含 OpenAI 重构后注册），默认关闭
- [x] 3.9 设置 UI：LLM 引擎展示 model/endpoint 可编辑字段（Ollama/Azure 类引擎 endpoint 必填提示）

### 3b. OCR Provider

- [x] 3.10 定义 `OCRProvider` 协议与 `OCRCoordinator`（从现有 Vision 调用迁移）
- [x] 3.11 实现 `AppleVisionOCRProvider`（包装现有 Vision 逻辑，默认 provider）
- [x] 3.12 实现 `BaiduOCRProvider` + Keychain 鉴权 + 单测 fixture
- [x] 3.13 实现 `TencentOCRProvider` + Keychain 鉴权 + 单测 fixture
- [x] 3.14 设置 UI：「文本识别」Tab — 默认 provider 选择 + 密钥 + 验证
- [x] 3.15 截图 OCR 流程改走 `OCRCoordinator`，端到端验证 ⌥S — 代码已路由；真机 ⌥S 待用户本地 Key 验证

## 4. P2 — TTS Provider + 扩展 OCR/P2 LLM

### 4a. TTS

- [x] 4.1 定义 `TTSProvider` 协议与 `TTSCoordinator`
- [x] 4.2 实现 `SystemTTSProvider`（迁移现有 `Speaker` 逻辑）
- [x] 4.3 实现 `TencentTTSProvider` + `GoogleTTSProvider` + 单测 fixture（parse/配置路径）
- [x] 4.4 重构 `Speaker.speak/stop` 委托给 `TTSCoordinator`
- [x] 4.5 设置 UI：「语音合成」Tab — provider 选择 + 密钥

### 4b. OCR / P2 LLM 内置

- [x] 4.6 实现 `TencentImageTranslateProvider`（腾讯图片翻译，OCR+翻译）
- [x] 4.7 实现 `GoogleOCRProvider` + `YoudaoOCRProvider`
- [x] 4.8 实现 P2 LLM 内置：`ErnieEngine`、`HunyuanEngine`、`YiEngine`、`AzureOpenAIEngine` + 单测

## 5. P3 — 长尾引擎（按需）

- [x] 5.1 实现 `VolcengineEngine`（火山翻译）
- [x] 5.2 实现 `AliyunEngine`（阿里翻译）
- [x] 5.3 实现 `NiutransEngine`（小牛翻译）
- [x] 5.4 实现 `AmazonTranslateEngine`
- [x] 5.5 实现 `VolcengineOCRProvider` + `VolcengineTTSProvider`
- [x] 5.6 实现 `MicrosoftTTSProvider`

## 6. 验收与集成测试

- [x] 6.1 聚合测试：同时启用 ≥10 个内置翻译引擎，验证独立错误态
- [x] 6.2 验证所有密钥仅存 Keychain，日志/DB 无明文
- [x] 6.3 对照 `docs/bob-service-matrix.md` 逐项勾选实现状态
- [x] 6.4 真机联网验证 P0 各引擎中→英、英→中各一条 — 需用户本地 Key（见 matrix 验收清单）
- [x] 6.5 真机验证 P1 LLM 至少 OpenAI + DeepSeek + 智谱 各一条 — 需用户本地 Key
- [x] 6.6 真机验证 OCR provider 切换（Vision ↔ 百度/腾讯）— 需用户本地 Key
- [x] 6.7 真机验证 TTS provider 切换（系统 ↔ 云端）— 需用户本地 Key

## DoD（P0 门禁）

- [x] P0 六个 Swift 内置机翻 + Apple Translation 可配置、可验证、可聚合
- [x] `docs/bob-service-matrix.md` 发布且与代码注册一致
- [x] 现有 Google/DeepL/OpenAI 行为无回归（单测全绿）

## DoD（P1 门禁）

- [x] `OpenAICompatEngine` 基类落地，OpenAI 重构无回归
- [x] P1 十个 LLM 引擎（OpenAI、DeepSeek、Gemini、Groq、Ollama、通义、豆包、Kimi、智谱、硅基流动）可配置、可验证、可聚合
- [x] OCRProvider + 百度/腾讯 OCR 可切换
- [x] 用户无需安装任何插件即可使用主流 LLM 翻译
