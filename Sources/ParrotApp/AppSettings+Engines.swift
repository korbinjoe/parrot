import Foundation

extension AppSettings {
    func isEngineEnabled(_ id: String) -> Bool {
        switch id {
        case "google": return googleEnabled
        case "deepl": return deepLEnabled
        case "openai": return openAIEnabled
        case "apple": return appleEnabled
        case "tencent": return tencentEnabled
        case "baidu": return baiduEnabled
        case "youdao": return youdaoEnabled
        case "caiyun": return caiyunEnabled
        case "microsoft": return microsoftEnabled
        case "opencode": return openCodeEnabled
        case "deepseek": return deepSeekEnabled
        case "gemini": return geminiEnabled
        case "groq": return groqEnabled
        case "ollama": return ollamaEnabled
        case "qwen": return qwenEnabled
        case "doubao": return doubaoEnabled
        case "kimi": return kimiEnabled
        case "zhipu": return zhipuEnabled
        case "siliconflow": return siliconFlowEnabled
        case "ernie": return ernieEnabled
        case "hunyuan": return hunyuanEnabled
        case "yi": return yiEnabled
        case "azure-openai": return azureOpenAIEnabled
        case "volcengine": return volcengineEnabled
        case "aliyun": return aliyunEnabled
        case "niutrans": return niutransEnabled
        case "amazon": return amazonEnabled
        default: return false
        }
    }

    func setEngineEnabled(_ id: String, _ value: Bool) {
        switch id {
        case "google": googleEnabled = value
        case "deepl": deepLEnabled = value
        case "openai": openAIEnabled = value
        case "apple": appleEnabled = value
        case "tencent": tencentEnabled = value
        case "baidu": baiduEnabled = value
        case "youdao": youdaoEnabled = value
        case "caiyun": caiyunEnabled = value
        case "microsoft": microsoftEnabled = value
        case "opencode": openCodeEnabled = value
        case "deepseek": deepSeekEnabled = value
        case "gemini": geminiEnabled = value
        case "groq": groqEnabled = value
        case "ollama": ollamaEnabled = value
        case "qwen": qwenEnabled = value
        case "doubao": doubaoEnabled = value
        case "kimi": kimiEnabled = value
        case "zhipu": zhipuEnabled = value
        case "siliconflow": siliconFlowEnabled = value
        case "ernie": ernieEnabled = value
        case "hunyuan": hunyuanEnabled = value
        case "yi": yiEnabled = value
        case "azure-openai": azureOpenAIEnabled = value
        case "volcengine": volcengineEnabled = value
        case "aliyun": aliyunEnabled = value
        case "niutrans": niutransEnabled = value
        case "amazon": amazonEnabled = value
        default: break
        }
    }

    func isEngineConfigured(_ descriptor: EngineDescriptor) -> Bool {
        guard let credential = descriptor.credential else { return true }
        return hasSecret(credential.account, env: credential.env)
    }

    func engineStatusText(_ descriptor: EngineDescriptor) -> String? {
        if let credential = descriptor.credential {
            return isEngineConfigured(descriptor) ? nil : credential.missingText
        }
        return descriptor.noCredentialNote
    }
}
