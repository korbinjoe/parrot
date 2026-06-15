import AVFoundation
import ParrotCore

@MainActor
public final class SystemTTSProvider: TTSProvider {
    public let id = "system"
    public let displayName = "离线语音合成"
    public let isOfflineCapable = true
    private let synth = AVSpeechSynthesizer()

    public init() {}

    public func speak(_ text: String, language: Language) async throws {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        if let code = voiceCode(for: language),
           let voice = AVSpeechSynthesisVoice(language: code) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utterance)
    }

    public func stop() async {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

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
