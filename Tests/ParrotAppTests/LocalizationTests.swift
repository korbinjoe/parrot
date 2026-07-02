import Foundation
import Testing
@testable import ParrotApp

@Suite(.serialized)
struct LocalizationTests {
    @MainActor
    @Test func appLanguageDefaultsToEnglish() {
        let suiteName = "parrot.test.localization.default.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)

        #expect(settings.appLanguageCode == "en")
    }

    @MainActor
    @Test func unsupportedSavedLanguageFallsBackToEnglish() {
        let suiteName = "parrot.test.localization.unsupported.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("xx-Unknown", forKey: L10n.languagePreferenceKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)

        #expect(settings.appLanguageCode == "en")
        #expect(defaults.string(forKey: L10n.languagePreferenceKey) == "en")
    }

    @Test func selectedLanguageControlsFormattingAndFallback() {
        let previous = UserDefaults.standard.string(forKey: L10n.languagePreferenceKey)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: L10n.languagePreferenceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: L10n.languagePreferenceKey)
            }
        }

        L10n.setLanguageCode("en", notify: false)
        #expect(L("%d 个字符", 3) == "3 characters")
        #expect(L("润色") == "Polish")
        #expect(L("输入润色") == "Input Polish")

        L10n.setLanguageCode("zh-Hans", notify: false)
        #expect(L("%d 个字符", 3) == "3 个字符")
        #expect(L("润色") == "润色")

        L10n.setLanguageCode("fr", notify: false)
        #expect(L("通用") == "Général")
        #expect(L("%d 个字符", 3) == "3 characters")
    }
}
