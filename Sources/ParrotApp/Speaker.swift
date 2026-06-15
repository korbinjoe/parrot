import AVFoundation
import ParrotCore

/// Text-to-speech wrapper around AVSpeechSynthesizer. Picks a voice by language.
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String, language: Language) {
        guard !text.isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        if let code = voiceCode(for: language),
           let voice = AVSpeechSynthesisVoice(language: code) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

    /// Map our Language to a BCP-47 voice locale.
    private func voiceCode(for language: Language) -> String? {
        switch language {
        case .zh: return "zh-CN"
        case .en: return "en-US"
        case .ja: return "ja-JP"
        case .ko: return "ko-KR"
        case .fr: return "fr-FR"
        case .de: return "de-DE"
        case .es: return "es-ES"
        case .ru: return "ru-RU"
        case .custom(let c): return c
        case .auto: return nil
        }
    }
}
