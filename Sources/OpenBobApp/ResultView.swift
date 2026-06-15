import SwiftUI
import OpenBobCore

/// Floating result content: source text on top, one card per engine below.
struct ResultView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(state.sourceText)
                    .font(.system(size: 13, weight: .medium))
                    .textSelection(.enabled)
                    .lineLimit(4)
                Spacer()
                if state.isTranslating {
                    ProgressView().controlSize(.small)
                }
                Button {
                    state.speakSource()
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .buttonStyle(.borderless)
                .help("朗读原文")

                Button {
                    state.toggleFavorite()
                } label: {
                    Image(systemName: state.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(state.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(state.savedRecordId == nil)
                .help("收藏")
            }
            Divider()

            if state.outcomes.isEmpty && !state.isTranslating {
                Text("无可用引擎或暂无结果")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }

            ForEach(state.outcomes, id: \.providerId) { outcome in
                EngineCard(outcome: outcome) { text in
                    state.speakTranslation(text)
                }
            }
        }
        .padding(14)
        .frame(width: 380)
    }
}

private struct EngineCard: View {
    let outcome: AggregatedOutcome
    let onSpeak: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(outcome.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let result = outcome.result {
                    Button {
                        onSpeak(result.translated)
                    } label: {
                        Image(systemName: "speaker.wave.2").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help("朗读译文")
                }
                Text("\(outcome.latencyMs)ms")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            if let result = outcome.result {
                Text(result.translated)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let phonetics = result.phonetics, !phonetics.isEmpty {
                    Text(phonetics.map { "\($0.type) \($0.value)" }.joined(separator: "  "))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let defs = result.definitions {
                    ForEach(Array(defs.enumerated()), id: \.offset) { _, d in
                        Text("\(d.partOfSpeech) \(d.meanings.joined(separator: "；"))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let error = outcome.error {
                Text(errorText(error))
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func errorText(_ e: ProviderError) -> String {
        switch e {
        case .auth: return "鉴权失败，请检查 API Key"
        case .rateLimited: return "请求过于频繁，请稍后重试"
        case .network: return "网络错误"
        case .timeout: return "请求超时"
        case .unsupportedLanguage: return "不支持的语言"
        case .notConfigured: return "未配置"
        case .plugin(let m): return "插件错误：\(m)"
        }
    }
}
