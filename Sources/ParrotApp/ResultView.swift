import SwiftUI
import AppKit
import ParrotCore

/// Floating result content: a language-direction header, the source block, then one card
/// per engine. Wrapped in a height-capped ScrollView so long text / many engines stay readable.
struct ResultView: View {
    @ObservedObject var state: AppState

    @State private var contentHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: 0) {
            if state.isOffline {
                WarningBar("无网络连接，翻译可能失败")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                    header
                    sourceBlock

                    if state.isTranslating && state.outcomes.isEmpty {
                        ForEach(0..<2, id: \.self) { _ in SkeletonCard() }
                    } else if state.outcomes.isEmpty {
                        Text("无可用引擎或暂无结果")
                            .foregroundStyle(.secondary)
                            .font(Theme.Font.callout)
                            .padding(.vertical, Theme.Spacing.s8)
                    } else {
                        ForEach(Array(state.outcomes.enumerated()), id: \.element.providerId) { index, outcome in
                            EngineCard(outcome: outcome,
                                       isPrimary: index == 0 && outcome.isSuccess,
                                       onSpeak: { state.speakTranslation($0) },
                                       onCopy: { copy($0) })
                        }
                    }
                }
                .padding(Theme.Spacing.s12)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                })
            }
            .frame(height: min(contentHeight, 460))
        }
        .frame(width: 380)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.window))
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
    }

    // MARK: - Header (language direction + source actions)

    private var header: some View {
        HStack(spacing: Theme.Spacing.s8) {
            LangPill(from: state.detectedSource, to: state.targetLanguage)
            Spacer(minLength: 0)
            Button { state.toggleFavorite() } label: {
                Image(systemName: state.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(state.isFavorite ? Theme.Palette.star : Theme.Palette.label2)
            }
            .buttonStyle(.borderless)
            .disabled(state.savedRecordId == nil)
            .help("收藏")
            IconButton("doc.on.doc", help: "复制原文") { copy(state.sourceText) }
            IconButton("speaker.wave.2", help: "朗读原文") { state.speakSource() }
        }
        .frame(height: 24)
    }

    // MARK: - Source block

    private var sourceBlock: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s8) {
            Text(state.sourceText)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.label)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if state.isTranslating {
                ProgressView().controlSize(.small)
            }
        }
        .padding(Theme.Spacing.s12)
        .background(Theme.Palette.bgContent2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
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

// MARK: - Engine card

private struct EngineCard: View {
    let outcome: AggregatedOutcome
    let isPrimary: Bool
    let onSpeak: (String) -> Void
    let onCopy: (String) -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            // Primary engine gets a 2px accent rail on the leading edge.
            Rectangle()
                .fill(isPrimary ? Theme.Palette.accent : Color.clear)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: Theme.Spacing.s4 + 2) {
                head
                content
            }
            .padding(Theme.Spacing.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(outcome.error != nil ? Theme.Palette.danger : Color.clear, lineWidth: 0.5)
        )
        .onHover { hovering = $0 }
    }

    private var head: some View {
        HStack(spacing: Theme.Spacing.s8) {
            Text(outcome.displayName.uppercased())
                .font(Theme.Font.tag)
                .foregroundStyle(Theme.Palette.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.Palette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            if let result = outcome.result {
                HStack(spacing: 0) {
                    IconButton("doc.on.doc", help: "复制译文", size: 11) { onCopy(result.translated) }
                    IconButton("speaker.wave.2", help: "朗读译文", size: 11) { onSpeak(result.translated) }
                }
                .opacity(hovering ? 1 : 0)
                .animation(.easeOut(duration: 0.1), value: hovering)
            }
            Spacer(minLength: 0)
            Text(outcome.error != nil ? "失败" : "\(outcome.latencyMs)ms")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let result = outcome.result {
            Text(result.translated)
                .font(Theme.Font.result)
                .foregroundStyle(Theme.Palette.label)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let phonetics = result.phonetics, !phonetics.isEmpty {
                Text(phonetics.map { "\($0.type) \($0.value)" }.joined(separator: "  "))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.label2)
            }
            if let defs = result.definitions {
                ForEach(Array(defs.enumerated()), id: \.offset) { _, d in
                    Text("\(d.partOfSpeech) \(d.meanings.joined(separator: "；"))")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if let error = outcome.error {
            HStack(spacing: Theme.Spacing.s4 + 2) {
                Image(systemName: "exclamationmark.triangle")
                Text(errorText(error))
            }
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Palette.danger)
        }
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

// MARK: - Loading skeleton

private struct SkeletonCard: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            bar(width: 64).frame(height: 12)
            bar(width: .infinity).frame(height: 13)
            bar(width: 200).frame(height: 13)
        }
        .padding(Theme.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Theme.Palette.bgContent2)
            .frame(maxWidth: width == .infinity ? .infinity : width, alignment: .leading)
            .opacity(shimmer ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
    }
}

