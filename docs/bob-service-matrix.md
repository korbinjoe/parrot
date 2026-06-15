# Bob ↔ Parrot 服务对照表

参考 [Bob 添加服务](https://bobtranslate.com/guide/advance/service.html) 与 `openspec/changes/bob-engine-services/design.md`。

**图例**：✅ 已实现 · ⛔ 暂不实现（Deferred）

## 文本翻译（27）

| Bob 服务 | Parrot 引擎 ID | 路径 | 阶段 | 状态 | 密钥申请 |
|----------|----------------|------|------|------|----------|
| Google 翻译 | `google` | Swift 内置 | — | ✅ | 无需 Key |
| DeepL 翻译 | `deepl` | Swift 内置 | — | ✅ | [DeepL API](https://www.deepl.com/pro-api) |
| OpenAI | `openai` | Swift 内置 | P1 | ✅ | [OpenAI Platform](https://platform.openai.com/api-keys) |
| 腾讯翻译君 | `tencent` | Swift 内置 | P0 | ✅ | [腾讯云 TMT](https://cloud.tencent.com/document/product/551/35017) |
| 百度翻译 | `baidu` | Swift 内置 | P0 | ✅ | [百度翻译开放平台](https://fanyi-api.baidu.com/) |
| 有道翻译 | `youdao` | Swift 内置 | P0 | ✅ | [有道智云](https://ai.youdao.com/) |
| 彩云小译 | `caiyun` | Swift 内置 | P0 | ✅ | [彩云科技](https://platform.caiyunapp.com/) |
| Microsoft 翻译 | `microsoft` | Swift 内置 | P0 | ✅ | [Azure Translator](https://azure.microsoft.com/products/ai-services/translator) |
| 系统翻译 | `apple` | Swift 内置 | P0 | ✅ | 无需 Key（macOS 15+，SwiftUI bridge） |
| DeepSeek | `deepseek` | Swift 内置 | P1 | ✅ | [DeepSeek Platform](https://platform.deepseek.com/) |
| Gemini | `gemini` | Swift 内置 | P1 | ✅ | [Google AI Studio](https://aistudio.google.com/apikey) |
| Groq | `groq` | Swift 内置 | P1 | ✅ | [Groq Console](https://console.groq.com/) |
| Ollama | `ollama` | Swift 内置 | P1 | ✅ | 本地运行，无需云 Key |
| 通义千问 | `qwen` | Swift 内置 | P1 | ✅ | [阿里云 DashScope](https://dashscope.console.aliyun.com/) |
| 豆包 | `doubao` | Swift 内置 | P1 | ✅ | [火山方舟](https://console.volcengine.com/ark) |
| Kimi | `kimi` | Swift 内置 | P1 | ✅ | [Moonshot 开放平台](https://platform.moonshot.cn/) |
| 智谱 GLM | `zhipu` | Swift 内置 | P1 | ✅ | [智谱开放平台](https://open.bigmodel.cn/) |
| 硅基流动 | `siliconflow` | Swift 内置 | P1 | ✅ | [SiliconFlow](https://cloud.siliconflow.cn/) |
| 文心一言 | `ernie` | Swift 内置 | P2 | ✅ | [百度千帆](https://cloud.baidu.com/product/wenxinworkshop) |
| 混元 | `hunyuan` | Swift 内置 | P2 | ✅ | [腾讯混元](https://cloud.tencent.com/product/hunyuan) |
| 零一万物 | `yi` | Swift 内置 | P2 | ✅ | [零一万物](https://platform.lingyiwanwu.com/) |
| Azure OpenAI | `azure-openai` | Swift 内置 | P2 | ✅ | [Azure OpenAI](https://azure.microsoft.com/products/ai-services/openai-service) |
| 火山翻译 | `volcengine` | Swift 内置 | P3 | ✅ | [火山引擎翻译](https://www.volcengine.com/product/translate) |
| 阿里翻译 | `aliyun` | Swift 内置 | P3 | ✅ | [阿里云机器翻译](https://www.aliyun.com/product/ai/alimt) |
| 小牛翻译 | `niutrans` | Swift 内置 | P3 | ✅ | [小牛翻译](https://niutrans.com/) |
| Amazon 翻译 | `amazon` | Swift 内置 | P3 | ✅ | [AWS Translate](https://aws.amazon.com/translate/) |
| 智谱/硅基 Bob 内置免费代理 | — | — | — | ⛔ | 无公开 API；请自备 Key 使用上表内置引擎 |
| 金山词霸 | — | — | — | ⛔ | 无公开 API |
| 简明英汉词典 | — | — | — | ⛔ | 离线词典包，后续评估 |

## 文本识别 / OCR（8）

| Bob 服务 | Parrot Provider ID | 路径 | 阶段 | 状态 | 密钥申请 |
|----------|-------------------|------|------|------|----------|
| 离线文本识别 | `apple-vision` | Swift 内置 | P1 | ✅ | 无需 Key |
| 百度 OCR | `baidu-ocr` | Swift 内置 | P1 | ✅ | [百度 OCR](https://ai.baidu.com/tech/ocr) |
| 腾讯 OCR | `tencent-ocr` | Swift 内置 | P1 | ✅ | [腾讯云 OCR](https://cloud.tencent.com/product/ocr) |
| 腾讯图片翻译 | `tencent-image-translate` | Swift 内置 | P2 | ✅ | 腾讯云 |
| Google OCR | `google-ocr` | Swift 内置 | P2 | ✅ | [Cloud Vision](https://cloud.google.com/vision) |
| 有道 OCR | `youdao-ocr` | Swift 内置 | P2 | ✅ | 有道智云 |
| 火山 OCR | `volcengine-ocr` | Swift 内置 | P3 | ✅ | 火山引擎 |
| 百度 OCR 试用版 | — | — | — | ⛔ | Bob 内置代理，不做 |

## 语音合成 / TTS（5）

| Bob 服务 | Parrot Provider ID | 路径 | 阶段 | 状态 | 密钥申请 |
|----------|-------------------|------|------|------|----------|
| 离线语音合成 | `system` | Swift 内置 | — | ✅ | 无需 Key |
| 腾讯语音合成 | `tencent-tts` | Swift 内置 | P2 | ✅ | [腾讯云 TTS](https://cloud.tencent.com/product/tts) |
| Google 语音合成 | `google-tts` | Swift 内置 | P2 | ✅ | [Cloud TTS](https://cloud.google.com/text-to-speech) |
| Microsoft 语音合成 | `microsoft-tts` | Swift 内置 | P2/P3 | ✅ | [Azure Speech](https://azure.microsoft.com/products/ai-services/text-to-speech) |
| 火山语音合成 | `volcengine-tts` | Swift 内置 | P3 | ✅ | 火山引擎 |

## 从 Bob 迁移提示

1. **文本翻译**：在 Parrot「设置 → 翻译」开启对应内置引擎，在「密钥」页填入 API Key（格式见各引擎说明）。
2. **OCR**：默认使用 Apple Vision（等同 Bob「离线文本识别」）；云端 OCR 在「识别」设置中切换。
3. **TTS**：默认系统离线合成；云端 TTS 在「语音」设置中切换。
4. **Bob 插件**：Parrot 使用 `.parrotplugin` 格式，不保证二进制兼容；主流 LLM 已 Swift 内置，通常无需插件。
5. **Bob 零配置免费 LLM**（智谱 Flash、硅基 Qwen 等）：Parrot 不提供等价代理，请申请官方 Key 或使用 Gemini/Groq 免费额度 / Ollama 本地。

## 真机验收清单（需本地 Key）

| 项目 | 说明 |
|------|------|
| P0 机翻 | 腾讯/百度/有道/彩云/Microsoft 各测中→英、英→中一条 |
| P1 LLM | OpenAI + DeepSeek + 智谱 各测一条 |
| OCR | Vision ↔ 百度/腾讯 切换后 ⌥S 截图识别 |
| TTS | 系统 ↔ 云端 provider 切换后朗读 |
