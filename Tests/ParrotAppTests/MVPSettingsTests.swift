import Foundation
import Testing
@testable import ParrotApp

@MainActor
@Test func mvpDefaultsReduceFanoutWithoutDiscardingExistingConfiguration() {
    let suite = "parrot.test.mvp.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let fresh = AppSettings(defaults: defaults)
    #expect(!fresh.compareTranslations)
    #expect(!fresh.advancedFeaturesEnabled)
    #expect(!fresh.deepLEnabled)
    #expect(!fresh.openAIEnabled)

    // Existing providers, order and learning data survive the simplified default.
    defaults.set(true, forKey: "engine.openai.enabled")
    defaults.set(["openai", "deepl"], forKey: "engine.order")
    defaults.set(["saved-expression"], forKey: "learning.savedExpressionIDs")
    let migrated = AppSettings(defaults: defaults)
    #expect(migrated.openAIEnabled)
    #expect(migrated.engineOrder == ["openai", "deepl"])
    #expect(migrated.learningSavedExpressionIDs == ["saved-expression"])
    #expect(!migrated.compareTranslations)
    #expect(!migrated.advancedFeaturesEnabled)

    migrated.compareTranslations = true
    migrated.advancedFeaturesEnabled = true
    let reopened = AppSettings(defaults: defaults)
    #expect(reopened.compareTranslations)
    #expect(reopened.advancedFeaturesEnabled)
}
