import Foundation
import Testing
@testable import ParrotApp

@MainActor
struct SettingsNavigationTests {
    @Test func openingWithoutPaneRestoresThePreviouslyViewedPane() {
        let navigation = SettingsNavigation()
        navigation.open(pane: .keys, serviceID: nil, retryProviderID: nil)

        navigation.open(pane: nil, serviceID: nil, retryProviderID: nil)

        #expect(navigation.selection == .keys)
    }

    @Test func explicitPaneRoutesToRequestedSettingsArea() {
        let navigation = SettingsNavigation()
        navigation.open(pane: .keys, serviceID: nil, retryProviderID: nil)

        navigation.open(pane: .engines, serviceID: nil, retryProviderID: nil)

        #expect(navigation.selection == .engines)
    }

    @Test(arguments: [SettingsView.Pane.general, .engines])
    func explicitPaneWithoutServiceClearsOldRecoveryFocus(_ pane: SettingsView.Pane) {
        let navigation = SettingsNavigation()
        navigation.open(pane: .keys, serviceID: "openai#alternate-model", retryProviderID: "openai#alternate-model")

        navigation.open(pane: pane, serviceID: nil, retryProviderID: nil)

        #expect(navigation.selection == pane)
        #expect(navigation.focusedServiceID == nil)
        #expect(navigation.retryProviderID == nil)
    }

    @Test func modelSpecificRecoveryFocusesServiceAndPreservesExactRetryProvider() {
        let navigation = SettingsNavigation()

        navigation.open(pane: .keys, serviceID: "openai#alternate-model", retryProviderID: "openai#alternate-model")

        #expect(navigation.selection == .keys)
        #expect(navigation.focusedServiceID == "openai")
        #expect(navigation.retryProviderID == "openai#alternate-model")
    }

    @Test func repeatedIdenticalRoutesStillNotifyTheExistingSettingsView() {
        let navigation = SettingsNavigation()
        let originalRoute = navigation.routeID

        navigation.open(pane: .keys, serviceID: "ollama#secondary", retryProviderID: "ollama#secondary")
        let firstRoute = navigation.routeID
        navigation.open(pane: .keys, serviceID: "ollama#secondary", retryProviderID: "ollama#secondary")

        #expect(firstRoute != originalRoute)
        #expect(navigation.routeID != firstRoute)
        #expect(navigation.focusedServiceID == "ollama")
        #expect(navigation.retryProviderID == "ollama#secondary")
    }

    @Test func ordinaryReopeningDoesNotKeepAnObsoleteRetryAction() {
        let navigation = SettingsNavigation()
        navigation.open(pane: .keys, serviceID: "openai#alternate-model", retryProviderID: "openai#alternate-model")

        navigation.open(pane: nil, serviceID: nil, retryProviderID: nil)

        #expect(navigation.selection == .keys)
        #expect(navigation.focusedServiceID == "openai")
        #expect(navigation.retryProviderID == nil)
    }

    @Test func ordinaryReopeningDoesNotReplayOldServiceRouteAfterManualPaneSelection() {
        let navigation = SettingsNavigation()
        navigation.open(pane: .keys, serviceID: "openai#alternate-model", retryProviderID: "openai#alternate-model")
        navigation.selection = .engines
        let previousRoute = navigation.routeID

        navigation.open(pane: nil, serviceID: nil, retryProviderID: nil)

        #expect(navigation.selection == .engines)
        #expect(navigation.routeID == previousRoute)
        #expect(navigation.focusedServiceID == "openai")
        #expect(navigation.retryProviderID == nil)
    }
}
