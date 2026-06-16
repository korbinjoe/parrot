import Foundation
import ParrotCore

extension AppSettings {
    static let ernieAccount = "engine.ernie.apiKey"
    static let hunyuanAccount = "engine.hunyuan.apiKey"
    static let yiAccount = "engine.yi.apiKey"
    static let azureOpenAIAccount = "engine.azure-openai.apiKey"
    static let volcengineAccount = "engine.volcengine.apiKey"
    static let aliyunAccount = "engine.aliyun.credentials"
    static let niutransAccount = "engine.niutrans.apiKey"
    static let amazonAccount = "engine.amazon.credentials"
    static let baiduOCRKeyAccount = "ocr.baidu.credentials"
    static let tencentOCRKeyAccount = "ocr.tencent.credentials"
    static let youdaoOCRKeyAccount = "ocr.youdao.credentials"
    static let googleOCRKeyAccount = "ocr.google.apiKey"
    static let googleTTSKeyAccount = "tts.google.apiKey"
    static let microsoftTTSKeyAccount = "tts.microsoft.apiKey"
    static let volcengineOCRKeyAccount = "ocr.volcengine.apiKey"
    static let volcengineTTSKeyAccount = "tts.volcengine.apiKey"

    func ernieKey(allowPrompt: Bool = false) -> String? { key(Self.ernieAccount, env: "ERNIE_API_KEY", allowPrompt: allowPrompt) }
    func hunyuanKey(allowPrompt: Bool = false) -> String? { key(Self.hunyuanAccount, env: "HUNYUAN_API_KEY", allowPrompt: allowPrompt) }
    func yiKey(allowPrompt: Bool = false) -> String? { key(Self.yiAccount, env: "YI_API_KEY", allowPrompt: allowPrompt) }
    func azureOpenAIKey(allowPrompt: Bool = false) -> String? { key(Self.azureOpenAIAccount, env: "AZURE_OPENAI_API_KEY", allowPrompt: allowPrompt) }
    func volcengineKey(allowPrompt: Bool = false) -> String? { key(Self.volcengineAccount, env: "VOLCENGINE_API_KEY", allowPrompt: allowPrompt) }
    func aliyunCredentials(allowPrompt: Bool = false) -> String? { key(Self.aliyunAccount, env: "ALIYUN_CREDENTIALS", allowPrompt: allowPrompt) }
    func niutransKey(allowPrompt: Bool = false) -> String? { key(Self.niutransAccount, env: "NIUTRANS_API_KEY", allowPrompt: allowPrompt) }
    func amazonCredentials(allowPrompt: Bool = false) -> String? { key(Self.amazonAccount, env: "AWS_CREDENTIALS", allowPrompt: allowPrompt) }

    func baiduOCRCredentials(allowPrompt: Bool = false) -> String? { key(Self.baiduOCRKeyAccount, env: "BAIDU_OCR_CREDENTIALS", allowPrompt: allowPrompt) ?? baiduCredentials(allowPrompt: allowPrompt) }
    func tencentOCRCredentials(allowPrompt: Bool = false) -> String? { key(Self.tencentOCRKeyAccount, env: "TENCENT_OCR_CREDENTIALS", allowPrompt: allowPrompt) ?? tencentCredentials(allowPrompt: allowPrompt) }
    func youdaoOCRCredentials(allowPrompt: Bool = false) -> String? { key(Self.youdaoOCRKeyAccount, env: "YOUDAO_OCR_CREDENTIALS", allowPrompt: allowPrompt) ?? youdaoCredentials(allowPrompt: allowPrompt) }
    func googleOCRKey(allowPrompt: Bool = false) -> String? { key(Self.googleOCRKeyAccount, env: "GOOGLE_OCR_API_KEY", allowPrompt: allowPrompt) }
    func googleTTSKey(allowPrompt: Bool = false) -> String? { key(Self.googleTTSKeyAccount, env: "GOOGLE_TTS_API_KEY", allowPrompt: allowPrompt) }
    func microsoftTTSKey(allowPrompt: Bool = false) -> String? { key(Self.microsoftTTSKeyAccount, env: "MICROSOFT_TTS_KEY", allowPrompt: allowPrompt) ?? microsoftKey(allowPrompt: allowPrompt) }
    func volcengineOCRKey(allowPrompt: Bool = false) -> String? { key(Self.volcengineOCRKeyAccount, env: "VOLCENGINE_OCR_KEY", allowPrompt: allowPrompt) }
    func volcengineTTSKey(allowPrompt: Bool = false) -> String? { key(Self.volcengineTTSKeyAccount, env: "VOLCENGINE_TTS_KEY", allowPrompt: allowPrompt) }

    func setErnieKey(_ v: String) { setKey(v, account: Self.ernieAccount) }
    func setHunyuanKey(_ v: String) { setKey(v, account: Self.hunyuanAccount) }
    func setYiKey(_ v: String) { setKey(v, account: Self.yiAccount) }
    func setAzureOpenAIKey(_ v: String) { setKey(v, account: Self.azureOpenAIAccount) }
    func setVolcengineKey(_ v: String) { setKey(v, account: Self.volcengineAccount) }
    func setAliyunCredentials(_ v: String) { setKey(v, account: Self.aliyunAccount) }
    func setNiutransKey(_ v: String) { setKey(v, account: Self.niutransAccount) }
    func setAmazonCredentials(_ v: String) { setKey(v, account: Self.amazonAccount) }
    func setBaiduOCRCredentials(_ v: String) { setKey(v, account: Self.baiduOCRKeyAccount) }
    func setTencentOCRCredentials(_ v: String) { setKey(v, account: Self.tencentOCRKeyAccount) }
    func setYoudaoOCRCredentials(_ v: String) { setKey(v, account: Self.youdaoOCRKeyAccount) }
    func setGoogleOCRKey(_ v: String) { setKey(v, account: Self.googleOCRKeyAccount) }
    func setGoogleTTSKey(_ v: String) { setKey(v, account: Self.googleTTSKeyAccount) }
    func setMicrosoftTTSKey(_ v: String) { setKey(v, account: Self.microsoftTTSKeyAccount) }
    func setVolcengineOCRKey(_ v: String) { setKey(v, account: Self.volcengineOCRKeyAccount) }
    func setVolcengineTTSKey(_ v: String) { setKey(v, account: Self.volcengineTTSKeyAccount) }
}
