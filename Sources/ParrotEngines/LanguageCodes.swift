import ParrotCore

enum LanguageCodes {
    /// Baidu: zh/en/jp/kor/fra/de/spa/ru/auto
    static func baidu(_ lang: Language) -> String {
        switch lang {
        case .auto: return "auto"
        case .zh: return "zh"
        case .en: return "en"
        case .ja: return "jp"
        case .ko: return "kor"
        case .fr: return "fra"
        case .de: return "de"
        case .es: return "spa"
        case .ru: return "ru"
        case .custom(let c): return c
        }
    }

    /// Youdao: zh-CHS / en / ja / ko / …
    static func youdao(_ lang: Language) -> String {
        switch lang {
        case .auto: return "auto"
        case .zh: return "zh-CHS"
        case .en: return "en"
        case .ja: return "ja"
        case .ko: return "ko"
        case .fr: return "fr"
        case .de: return "de"
        case .es: return "es"
        case .ru: return "ru"
        case .custom(let c): return c
        }
    }

    /// Microsoft Translator BCP-47-ish.
    static func microsoft(_ lang: Language) -> String {
        switch lang {
        case .auto: return ""
        case .zh: return "zh-Hans"
        case .en: return "en"
        case .ja: return "ja"
        case .ko: return "ko"
        case .fr: return "fr"
        case .de: return "de"
        case .es: return "es"
        case .ru: return "ru"
        case .custom(let c): return c
        }
    }

    /// Tencent TMT: zh / en / ja / ko / …
    static func tencent(_ lang: Language) -> String {
        lang.code ?? "auto"
    }

    /// Caiyun trans_type suffix pair, e.g. en2zh.
    static func caiyunType(from: Language, to: Language) -> String {
        let f = from == .auto ? "auto" : (from.code ?? "auto")
        let t = to.code ?? "zh"
        return "\(f)2\(t)"
    }
}
