# 引擎与密钥

Parrot 内置 27+ 文本翻译引擎，以及 OCR / TTS 提供者。在「设置 → 引擎 / 密钥」中开启并配置 API Key。

**图例**：✅ 已实现 · ⛔ 暂不实现

## 文本翻译

| 引擎 | Parrot ID | 状态 | 密钥申请 |
|------|-----------|------|----------|
| Google 翻译 | `google` | ✅ | 无需 Key（见 README 合规说明） |
| DeepL | `deepl` | ✅ | [DeepL API](https://www.deepl.com/pro-api) |
| OpenAI | `openai` | ✅ | [OpenAI Platform](https://platform.openai.com/api-keys) |
| 腾讯翻译君 | `tencent` | ✅ | [腾讯云 TMT](https://cloud.tencent.com/document/product/551/35017) |
| 百度翻译 | `baidu` | ✅ | [百度翻译开放平台](https://fanyi-api.baidu.com/) |
| 有道翻译 | `youdao` | ✅ | [有道智云](https://ai.youdao.com/) |
| 彩云小译 | `caiyun` | ✅ | [彩云科技](https://platform.caiyunapp.com/) |
| Microsoft 翻译 | `microsoft` | ✅ | [Azure Translator](https://azure.microsoft.com/products/ai-services/translator) |
| 系统翻译 | `apple` | ✅ | 无需 Key（macOS 15+） |
| DeepSeek | `deepseek` | ✅ | [DeepSeek Platform](https://platform.deepseek.com/) |
| Gemini | `gemini` | ✅ | [Google AI Studio](https://aistudio.google.com/apikey) |
| Groq | `groq` | ✅ | [Groq Console](https://console.groq.com/) |
| Ollama | `ollama` | ✅ | 本地运行，无需云 Key |
| 通义千问 | `qwen` | ✅ | [阿里云 DashScope](https://dashscope.console.aliyun.com/) |
| 豆包 | `doubao` | ✅ | [火山方舟](https://console.volcengine.com/ark) |
| Kimi | `kimi` | ✅ | [Moonshot 开放平台](https://platform.moonshot.cn/) |
| 智谱 GLM | `zhipu` | ✅ | [智谱开放平台](https://open.bigmodel.cn/) |
| 硅基流动 | `siliconflow` | ✅ | [SiliconFlow](https://cloud.siliconflow.cn/) |
| 文心一言 | `ernie` | ✅ | [百度千帆](https://cloud.baidu.com/product/wenxinworkshop) |
| 混元 | `hunyuan` | ✅ | [腾讯混元](https://cloud.tencent.com/product/hunyuan) |
| 零一万物 | `yi` | ✅ | [零一万物](https://platform.lingyiwanwu.com/) |
| Azure OpenAI | `azure-openai` | ✅ | [Azure OpenAI](https://azure.microsoft.com/products/ai-services/openai-service) |
| 火山翻译 | `volcengine` | ✅ | [火山引擎翻译](https://www.volcengine.com/product/translate) |
| 阿里翻译 | `aliyun` | ✅ | [阿里云机器翻译](https://www.aliyun.com/product/ai/almt) |
| 小牛翻译 | `niutrans` | ✅ | [小牛翻译](https://niutrans.com/) |
| Amazon 翻译 | `amazon` | ✅ | [AWS Translate](https://aws.amazon.com/translate/) |
| 金山词霸 | — | ⛔ | 无公开 API |
| 简明英汉词典 | — | ⛔ | 离线词典包，后续评估 |

凭证格式：腾讯 / 百度 / 有道等多为 `Id:Secret`；详见各平台文档。

## 文本识别（OCR）

| 提供者 | Parrot ID | 状态 | 密钥申请 |
|--------|-----------|------|----------|
| Apple Vision（离线） | `apple-vision` | ✅ | 无需 Key |
| 百度 OCR | `baidu-ocr` | ✅ | [百度 OCR](https://ai.baidu.com/tech/ocr) |
| 腾讯 OCR | `tencent-ocr` | ✅ | [腾讯云 OCR](https://cloud.tencent.com/product/ocr) |
| 腾讯图片翻译 | `tencent-image-translate` | ✅ | 腾讯云 |
| Google OCR | `google-ocr` | ✅ | [Cloud Vision](https://cloud.google.com/vision) |
| 有道 OCR | `youdao-ocr` | ✅ | 有道智云 |
| 火山 OCR | `volcengine-ocr` | ✅ | 火山引擎 |

## 语音合成（TTS）

| 提供者 | Parrot ID | 状态 | 密钥申请 |
|--------|-----------|------|----------|
| 系统离线合成 | `system` | ✅ | 无需 Key |
| 腾讯语音合成 | `tencent-tts` | ✅ | [腾讯云 TTS](https://cloud.tencent.com/product/tts) |
| Google 语音合成 | `google-tts` | ✅ | [Cloud TTS](https://cloud.google.com/text-to-speech) |
| Microsoft 语音合成 | `microsoft-tts` | ✅ | [Azure Speech](https://azure.microsoft.com/products/ai-services/text-to-speech) |
| 火山语音合成 | `volcengine-tts` | ✅ | 火山引擎 |

## 环境变量

环境变量优先于本地 `secrets.json`。常用示例：

- `OPENAI_API_KEY`、`DEEPL_API_KEY`、`DEEPSEEK_API_KEY`
- `TENCENT_CREDENTIALS`、`BAIDU_CREDENTIALS`、`YOUDAO_CREDENTIALS`（`Id:Secret` 格式）
