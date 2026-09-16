import Testing
import Foundation
import Combine
@testable import ParrotApp

/// Regression tests around the `AppState` / `AppSettings` / `PermissionsHolder` observation
/// graph. Before the fan-out fix, `AppState.init` forwarded every `AppSettings` change to
/// `AppState.objectWillChange`, so a plain settings toggle re-rendered every view that
/// observed `AppState` — including the entire 2500-line `SettingsView`. These tests pin
/// that behavior so it does not silently regress.
@MainActor
@Test func mutatingAppSettingsDoesNotRepublishThroughAppState() {
    let state = AppState()
    var stateBumps = 0
    var settingsBumps = 0

    let stateSink = state.objectWillChange.sink { _ in stateBumps += 1 }
    let settingsSink = state.settings.objectWillChange.sink { _ in settingsBumps += 1 }
    defer {
        stateSink.cancel()
        settingsSink.cancel()
    }

    state.settings.googleEnabled.toggle()
    state.settings.googleEnabled.toggle()
    state.settings.openAIEnabled.toggle()

    #expect(settingsBumps == 3)
    #expect(stateBumps == 0, "AppState must not fan-out AppSettings.objectWillChange or SettingsView repaints on every toggle")
}

/// The high-frequency ``AppState`` fields (source draft, translation outcomes …) still
/// notify their own observers — we only broke the *cross* subscription.
@MainActor
@Test func mutatingAppStateStillPublishesToAppStateObservers() {
    let state = AppState()
    var bumps = 0
    let sink = state.objectWillChange.sink { _ in bumps += 1 }
    defer { sink.cancel() }

    state.sourceDraft = "hello"
    state.sourceDraft = "hello world"

    #expect(bumps >= 2)
}

/// The floating panel drives ``sourceDraft`` every keystroke. Before the fix, that firehose
/// also pumped ``AppSettings.objectWillChange`` (because SettingsView observed AppState which
/// forwarded settings), painting the Settings window on every character. This test locks
/// that regression.
@MainActor
@Test func typingSourceDraftDoesNotDisturbSettingsObservers() {
    let state = AppState()
    var settingsBumps = 0
    var permissionBumps = 0
    let settingsSink = state.settings.objectWillChange.sink { _ in settingsBumps += 1 }
    let permissionsSink = state.permissionsHolder.objectWillChange.sink { _ in permissionBumps += 1 }
    defer {
        settingsSink.cancel()
        permissionsSink.cancel()
    }

    for i in 0..<50 {
        state.sourceDraft = "keystroke \(i)"
    }

    #expect(settingsBumps == 0)
    #expect(permissionBumps == 0)
}

/// ``refreshPermissions`` used to live on ``AppState.permissions`` and thus repainted the
/// whole ``AppState`` graph. It now writes to a dedicated ``PermissionsHolder`` so only the
/// views that care about permission status react.
@MainActor
@Test func refreshPermissionsOnlyBumpsPermissionsHolder() {
    let state = AppState()
    var stateBumps = 0
    var permissionBumps = 0
    let stateSink = state.objectWillChange.sink { _ in stateBumps += 1 }
    let permissionsSink = state.permissionsHolder.objectWillChange.sink { _ in permissionBumps += 1 }
    defer {
        stateSink.cancel()
        permissionsSink.cancel()
    }

    state.refreshPermissions()

    #expect(stateBumps == 0)
    #expect(permissionBumps == 1)
}
