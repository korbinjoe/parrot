import AVFoundation
import Foundation
import ParrotCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Tencent Cloud Text-to-Speech (basic HTTP API).
public final class TencentTTSProvider: TTSProvider, @unchecked Sendable {
    public let id = "tencent-tts"
    public let displayName = "腾讯语音合成"
    public let isOfflineCapable = false

    private var credentials: String?
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }
    public func configure(_ credentials: String?) { self.credentials = credentials }

    public func speak(_ text: String, language: Language) async throws {
        guard let creds = TencentCloudSigner.splitCredentials(credentials) else {
            throw ProviderError.notConfigured
        }
        let payload: [String: Any] = [
            "Text": text,
            "SessionId": UUID().uuidString,
            "VoiceType": language == .zh ? 101001 : 1001
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
        let host = "tts.tencentcloudapi.com"
        let signed = TencentCloudSigner.authorize(
            secretId: creds.id, secretKey: creds.secret,
            host: host, service: "tts", action: "TextToVoice", version: "2019-08-23",
            region: "ap-guangzhou", payload: bodyString
        )
        var request = URLRequest(url: URL(string: "https://\(host)/")!)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue("TextToVoice", forHTTPHeaderField: "X-TC-Action")
        request.setValue("2019-08-23", forHTTPHeaderField: "X-TC-Version")
        request.setValue(String(signed.timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue("ap-guangzhou", forHTTPHeaderField: "X-TC-Region")
        request.setValue(signed.authorization, forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resp = json["Response"] as? [String: Any],
              let audioB64 = resp["Audio"] as? String,
              let audioData = Data(base64Encoded: audioB64) else {
            throw ProviderError.network
        }
        try await AudioPlayer.shared.play(data: audioData)
    }

    public func stop() async { await AudioPlayer.shared.stop() }
}

/// Google Cloud TTS REST.
public final class GoogleTTSProvider: TTSProvider, @unchecked Sendable {
    public let id = "google-tts"
    public let displayName = "Google 语音合成"
    public let isOfflineCapable = false

    private var apiKey: String?
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }
    public func configure(apiKey: String?) { self.apiKey = apiKey }

    public func speak(_ text: String, language: Language) async throws {
        guard let key = apiKey, !key.isEmpty else { throw ProviderError.notConfigured }
        let lang = language == .zh ? "cmn-CN" : (language.code ?? "en-US")
        let url = URL(string: "https://texttospeech.googleapis.com/v1/text:synthesize?key=\(key)")!
        let body: [String: Any] = [
            "input": ["text": text],
            "voice": ["languageCode": lang, "ssmlGender": "NEUTRAL"],
            "audioConfig": ["audioEncoding": "MP3"]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let b64 = json["audioContent"] as? String,
              let audio = Data(base64Encoded: b64) else {
            throw ProviderError.network
        }
        try await AudioPlayer.shared.play(data: audio)
    }

    public func stop() async { await AudioPlayer.shared.stop() }
}

/// Azure Speech TTS (region + key).
public final class MicrosoftTTSProvider: TTSProvider, @unchecked Sendable {
    public let id = "microsoft-tts"
    public let displayName = "Microsoft 语音合成"
    public let isOfflineCapable = false

    private var apiKey: String?
    private var region: String = "eastasia"
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }
    public func configure(apiKey: String?, region: String = "eastasia") {
        self.apiKey = apiKey
        self.region = region
    }

    public func speak(_ text: String, language: Language) async throws {
        guard let key = apiKey, !key.isEmpty else { throw ProviderError.notConfigured }
        let lang = language == .zh ? "zh-CN" : (language.code ?? "en-US")
        let url = URL(string: "https://\(region).tts.speech.microsoft.com/cognitiveservices/v1")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("audio-24khz-48kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        let ssml = "<speak version='1.0' xml:lang='\(lang)'><voice xml:lang='\(lang)'>\(text)</voice></speak>"
        request.httpBody = ssml.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ProviderError.auth }
        try await AudioPlayer.shared.play(data: data)
    }

    public func stop() async { await AudioPlayer.shared.stop() }
}

public final class VolcengineTTSProvider: TTSProvider, @unchecked Sendable {
    public let id = "volcengine-tts"
    public let displayName = "火山语音合成"
    public let isOfflineCapable = false

    private var apiKey: String?
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }
    public func configure(apiKey: String?) { self.apiKey = apiKey }

    public func speak(_ text: String, language: Language) async throws {
        guard let key = apiKey, !key.isEmpty else { throw ProviderError.notConfigured }
        let body: [String: Any] = [
            "text": text,
            "voice_type": language == .zh ? "BV001_streaming" : "BV002_streaming"
        ]
        var request = URLRequest(url: URL(string: "https://openspeech.bytedance.com/api/v1/tts")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let b64 = json["data"] as? String,
              let audio = Data(base64Encoded: b64) else {
            throw ProviderError.network
        }
        try await AudioPlayer.shared.play(data: audio)
    }

    public func stop() async { await AudioPlayer.shared.stop() }
}

/// Minimal MP3 player for cloud TTS responses.
@MainActor
final class AudioPlayer {
    static let shared = AudioPlayer()
    private var player: AVAudioPlayer?

    func play(data: Data) throws {
        player?.stop()
        player = try AVAudioPlayer(data: data)
        player?.play()
    }

    func stop() { player?.stop() }
}