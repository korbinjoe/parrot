import SwiftUI
import AppKit
import ParrotCore

/// Floating result content: source text on top, one card per engine below.
/// Wrapped in a height-capped ScrollView so long text / many engines stay readable.
struct ResultView: View {
    @ObservedObject var state: AppState

    @State private var contentHeight: CGFloat = 160

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 10) {
            // Source block — same card language as the engine results. Full text (no line cap)
            // so nothing is hidden; long content scrolls within the height-capped window.
            HStack(alignment: .top, spacing: 8) {
                    Text(state.sourceText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if state.isTranslating {
                        ProgressView().controlSize(.small)
                    }
                    HStack(spacing: 10) {
                        iconButton("doc.on.doc", help: "复制原文") { copy(state.sourceText) }
                        iconButton("speaker.wave.2", help: "朗读原文") { state.speakSource() }
                        Button { state.toggleFavorite() } label: {
                            Image(systemName: state.isFavorite ? "star.fill" : "star")
                                .foregroundStyle(state.isFavorite ? .yellow : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .disabled(state.savedRecordId == nil)
                        .help("收藏")
                    }
                    .fixedSize()
                }
                .padding(12)
                .background(Self.blockBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if state.outcomes.isEmpty && !state.isTranslating {
                    Text("无可用引擎或暂无结果")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                        .padding(.vertical, 8)
                }

                ForEach(state.outcomes, id: \.providerId) { outcome in
                    EngineCard(outcome: outcome,
                               onSpeak: { text in state.speakTranslation(text) },
                               onCopy: { text in copy(text) })
                }
        }
        .padding(14)
        .background(GeometryReader { geo in
            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
        })
        }
        .frame(width: 380, height: min(contentHeight, 460))
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
    }

    /// Shared soft-gray block background used by both source and engine cards.
    static let blockBackground = Color(nsColor: .windowBackgroundColor)

    @ViewBuilder
    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

/// Measures the intrinsic content height so the window can hug short content
/// and switch to scrolling once it exceeds the cap.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct EngineCard: View {
    let outcome: AggregatedOutcome
    let onSpeak: (String) -> Void
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(outcome.displayName.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)
                Spacer()
                if let result = outcome.result {
                    Button {
                        onCopy(result.translated)
                    } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("复制译文")
                    Button {
                        onSpeak(result.translated)
                    } label: {
                        Image(systemName: "speaker.wave.2").font(.system(size: 11)).foregroundStyle(.secondary)
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
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
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
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if let error = outcome.error {
                Text(errorText(error))
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ResultView.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
