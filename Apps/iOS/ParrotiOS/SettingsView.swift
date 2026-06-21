import ParrotPlatformiOS
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                EngineSettingsView()
                PrivacySettingsView()
                Section("Post-MVP") {
                    Label("Parrot Keyboard", systemImage: "keyboard")
                    Label("App Shortcuts", systemImage: "wand.and.stars")
                    Label("Safari Extension", systemImage: "safari")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct EngineSettingsView: View {
    @State private var apiKey = ""
    @State private var status = "Google translation is active by default. Social explanation runs locally as a fallback."
    private let store = IOSKeychainSecretStore()
    private let account = "openai-compatible-api-key"

    var body: some View {
        Section("Engines") {
            SecureField("Provider API key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            HStack {
                Button("Save key") {
                    Task { await save() }
                }
                Button("Validate") {
                    Task { await validate() }
                }
            }
            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .task { await load() }
    }

    private func load() async {
        apiKey = (try? await store.get(account: account)) ?? ""
    }

    private func save() async {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            try? await store.remove(account: account)
            status = "Key removed. Current drafts and history are unchanged."
            return
        }
        do {
            try await store.set(value, account: account)
            status = "Key saved in iOS Keychain."
        } catch {
            status = "Unable to save this key."
        }
    }

    private func validate() async {
        let saved = (try? await store.get(account: account)) ?? ""
        status = saved.isEmpty ? "Default Google translation does not require a key." : "Keychain lookup succeeded. This build currently uses default Google translation."
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        Section("Privacy") {
            Text("Clipboard text is read only while Parrot is foregrounded and after you choose an action.")
            Text("Share Extension handoff stores text, URLs, and screenshot references in App Group storage.")
            Text("Provider secrets are stored in iOS Keychain and are never written to App Group files, history, or prompt records.")
        }
    }
}
