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

    func ernieKey() -> String? { key(Self.ernieAccount, env: "ERNIE_API_KEY") }
    func hunyuanKey() -> String? { key(Self.hunyuanAccount, env: "HUNYUAN_API_KEY") }
    func yiKey() -> String? { key(Self.yiAccount, env: "YI_API_KEY") }
    func azureOpenAIKey() -> String? { key(Self.azureOpenAIAccount, env: "AZURE_OPENAI_API_KEY") }
    func volcengineKey() -> String? { key(Self.volcengineAccount, env: "VOLCENGINE_API_KEY") }
    func aliyunCredentials() -> String? { key(Self.aliyunAccount, env: "ALIYUN_CREDENTIALS") }
    func niutransKey() -> String? { key(Self.niutransAccount, env: "NIUTRANS_API_KEY") }
    func amazonCredentials() -> String? { key(Self.amazonAccount, env: "AWS_CREDENTIALS") }

    func baiduOCRCredentials() -> String? { key(Self.baiduOCRKeyAccount, env: "BAIDU_OCR_CREDENTIALS") ?? baiduCredentials() }
    func tencentOCRCredentials() -> String? { key(Self.tencentOCRKeyAccount, env: "TENCENT_OCR_CREDENTIALS") ?? tencentCredentials() }
    func youdaoOCRCredentials() -> String? { key(Self.youdaoOCRKeyAccount, env: "YOUDAO_OCR_CREDENTIALS") ?? youdaoCredentials() }
    func googleOCRKey() -> String? { key(Self.googleOCRKeyAccount, env: "GOOGLE_OCR_API_KEY") }
    func googleTTSKey() -> String? { key(Self.googleTTSKeyAccount, env: "GOOGLE_TTS_API_KEY") }
    func microsoftTTSKey() -> String? { key(Self.microsoftTTSKeyAccount, env: "MICROSOFT_TTS_KEY") ?? microsoftKey() }
    func volcengineOCRKey() -> String? { key(Self.volcengineOCRKeyAccount, env: "VOLCENGINE_OCR_KEY") }
    func volcengineTTSKey() -> String? { key(Self.volcengineTTSKeyAccount, env: "VOLCENGINE_TTS_KEY") }

    func setErnieKey(_ v: String) { KeychainStore.set(v, account: Self.ernieAccount) }
    func setHunyuanKey(_ v: String) { KeychainStore.set(v, account: Self.hunyuanAccount) }
    func setYiKey(_ v: String) { KeychainStore.set(v, account: Self.yiAccount) }
    func setAzureOpenAIKey(_ v: String) { KeychainStore.set(v, account: Self.azureOpenAIAccount) }
    func setVolcengineKey(_ v: String) { KeychainStore.set(v, account: Self.volcengineAccount) }
    func setAliyunCredentials(_ v: String) { KeychainStore.set(v, account: Self.aliyunAccount) }
    func setNiutransKey(_ v: String) { KeychainStore.set(v, account: Self.niutransAccount) }
    func setAmazonCredentials(_ v: String) { KeychainStore.set(v, account: Self.amazonAccount) }
    func setBaiduOCRCredentials(_ v: String) { KeychainStore.set(v, account: Self.baiduOCRKeyAccount) }
    func setTencentOCRCredentials(_ v: String) { KeychainStore.set(v, account: Self.tencentOCRKeyAccount) }
    func setYoudaoOCRCredentials(_ v: String) { KeychainStore.set(v, account: Self.youdaoOCRKeyAccount) }
    func setGoogleOCRKey(_ v: String) { KeychainStore.set(v, account: Self.googleOCRKeyAccount) }
    func setGoogleTTSKey(_ v: String) { KeychainStore.set(v, account: Self.googleTTSKeyAccount) }
    func setMicrosoftTTSKey(_ v: String) { KeychainStore.set(v, account: Self.microsoftTTSKeyAccount) }
    func setVolcengineOCRKey(_ v: String) { KeychainStore.set(v, account: Self.volcengineOCRKeyAccount) }
    func setVolcengineTTSKey(_ v: String) { KeychainStore.set(v, account: Self.volcengineTTSKeyAccount) }
}
