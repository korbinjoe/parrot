import AppKit
import ParrotCore
import ParrotEngines

@MainActor
extension OCRCoordinator {
    func registerDefaults(settings: AppSettings) {
        register(AppleVisionOCRProvider())

        let baidu = BaiduOCRProvider()
        baidu.configure(settings.ocrProviderId == "baidu-ocr" ? settings.baiduOCRCredentials() : nil)
        register(baidu)

        let tencent = TencentOCRProvider()
        tencent.configure(credentials: settings.ocrProviderId == "tencent-ocr" ? settings.tencentOCRCredentials() : nil, region: settings.tencentOCRRegion)
        register(tencent)

        let google = GoogleOCRProvider()
        google.configure(apiKey: settings.ocrProviderId == "google-ocr" ? settings.googleOCRKey() : nil)
        register(google)

        let youdao = YoudaoOCRProvider()
        youdao.configure(settings.ocrProviderId == "youdao-ocr" ? settings.youdaoOCRCredentials() : nil)
        register(youdao)

        let imageTranslate = TencentImageTranslateProvider()
        imageTranslate.configure(credentials: settings.ocrProviderId == "tencent-image-translate" ? settings.tencentOCRCredentials() : nil, region: settings.tencentOCRRegion)
        register(imageTranslate)

        let volc = VolcengineOCRProvider()
        volc.configure(apiKey: settings.ocrProviderId == "volcengine-ocr" ? settings.volcengineOCRKey() : nil)
        register(volc)

        setDefaultProvider(id: settings.ocrProviderId)
    }

    func applySettings(_ settings: AppSettings) {
        registerDefaults(settings: settings)
    }

    func availableProviders() -> [(id: String, name: String)] {
        [
            ("apple-vision", "离线文本识别"),
            ("baidu-ocr", "百度 OCR"),
            ("tencent-ocr", "腾讯 OCR"),
            ("google-ocr", "Google OCR"),
            ("youdao-ocr", "有道 OCR"),
            ("tencent-image-translate", "腾讯图片翻译"),
            ("volcengine-ocr", "火山 OCR")
        ]
    }
}

@MainActor
extension TTSCoordinator {
    func registerDefaults(settings: AppSettings) {
        register(SystemTTSProvider())

        let tencent = TencentTTSProvider()
        tencent.configure(settings.ttsProviderId == "tencent-tts" ? settings.tencentOCRCredentials() : nil)
        register(tencent)

        let google = GoogleTTSProvider()
        google.configure(apiKey: settings.ttsProviderId == "google-tts" ? settings.googleTTSKey() : nil)
        register(google)

        let microsoft = MicrosoftTTSProvider()
        microsoft.configure(apiKey: settings.ttsProviderId == "microsoft-tts" ? settings.microsoftTTSKey() : nil, region: settings.microsoftRegion)
        register(microsoft)

        let volc = VolcengineTTSProvider()
        volc.configure(apiKey: settings.ttsProviderId == "volcengine-tts" ? settings.volcengineTTSKey() : nil)
        register(volc)

        defaultProviderId = settings.ttsProviderId
    }

    func applySettings(_ settings: AppSettings) {
        registerDefaults(settings: settings)
    }

    func availableProviders() -> [(id: String, name: String)] {
        [
            ("system", "离线语音合成"),
            ("tencent-tts", "腾讯语音合成"),
            ("google-tts", "Google 语音合成"),
            ("microsoft-tts", "Microsoft 语音合成"),
            ("volcengine-tts", "火山语音合成")
        ]
    }
}
