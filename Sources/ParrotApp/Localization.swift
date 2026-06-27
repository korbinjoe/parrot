import Foundation

enum L10n {
    struct AppLanguage: Identifiable, Equatable, Sendable {
        let code: String
        let localeIdentifier: String
        let nativeName: String

        var id: String { code }
    }

    static let defaultLanguageCode = "en"
    static let languagePreferenceKey = "app.languageCode"
    static let appLanguageDidChange = Notification.Name("parrotAppLanguageDidChange")

    static let supportedLanguages: [AppLanguage] = [
        AppLanguage(code: "en", localeIdentifier: "en", nativeName: "English"),
        AppLanguage(code: "zh-Hans", localeIdentifier: "zh-Hans", nativeName: "简体中文"),
        AppLanguage(code: "ja", localeIdentifier: "ja", nativeName: "日本語"),
        AppLanguage(code: "ko", localeIdentifier: "ko", nativeName: "한국어"),
        AppLanguage(code: "fr", localeIdentifier: "fr", nativeName: "Français"),
        AppLanguage(code: "de", localeIdentifier: "de", nativeName: "Deutsch"),
        AppLanguage(code: "es", localeIdentifier: "es", nativeName: "Español")
    ]

    static func languageCode(defaults: UserDefaults = .standard) -> String {
        normalizedLanguageCode(defaults.string(forKey: languagePreferenceKey))
    }

    static func setLanguageCode(_ code: String, defaults: UserDefaults = .standard, notify: Bool = true) {
        let oldValue = languageCode(defaults: defaults)
        let normalized = normalizedLanguageCode(code)
        defaults.set(normalized, forKey: languagePreferenceKey)
        guard notify, oldValue != normalized else { return }
        NotificationCenter.default.post(name: appLanguageDidChange, object: normalized)
    }

    static func normalizedLanguageCode(_ code: String?) -> String {
        let trimmed = (code ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultLanguageCode }
        if supportedLanguages.contains(where: { $0.code == trimmed }) {
            return trimmed
        }

        let lowercased = trimmed.lowercased()
        if lowercased == "zh" || lowercased.hasPrefix("zh-") {
            return "zh-Hans"
        }

        if let match = supportedLanguages.first(where: { lowercased == $0.code.lowercased() || lowercased.hasPrefix("\($0.code.lowercased())-") }) {
            return match.code
        }

        return defaultLanguageCode
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        string(key, arguments: args)
    }

    static func string(_ key: String, arguments: [CVarArg]) -> String {
        let languageCode = languageCode()
        let format = localizedFormat(forKey: key, languageCode: languageCode)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale(for: languageCode), arguments: arguments)
    }

    private static func localizedFormat(forKey key: String, languageCode: String) -> String {
        if let localized = localizedString(forKey: key, languageCode: languageCode), localized != key {
            return localized
        }

        if languageCode == "zh-Hans" {
            return key
        }

        if let english = localizedString(forKey: key, languageCode: defaultLanguageCode), english != key {
            return english
        }

        return key
    }

    private static func localizedString(forKey key: String, languageCode: String) -> String? {
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }

        let developmentPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(languageCode).lproj")
            .path
        guard FileManager.default.fileExists(atPath: developmentPath),
              let bundle = Bundle(path: developmentPath) else {
            return nil
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static func locale(for languageCode: String) -> Locale {
        let identifier = supportedLanguages.first(where: { $0.code == languageCode })?.localeIdentifier ?? defaultLanguageCode
        return Locale(identifier: identifier)
    }
}

func L(_ key: String, _ args: CVarArg...) -> String {
    L10n.string(key, arguments: args)
}
