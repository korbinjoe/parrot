import AVFoundation
import ParrotCore

/// Routes read-aloud to the configured TTS provider (default: system offline).
@MainActor
final class Speaker {
    static let shared = Speaker()
    weak var coordinator: TTSCoordinator?

    func speak(_ text: String, language: Language) {
        guard !text.isEmpty else { return }
        Task { await coordinator?.speak(text, language: language) }
    }

    func stop() {
        Task { await coordinator?.stop() }
    }
}
