import SwiftUI
import AppKit
import ParrotCore

/// Floating result content: a language-direction header, source context, then provider
/// slots displayed in the order configured in Settings.
struct ResultView: View {
    @ObservedObject var state: AppState
    @ObservedObject var panelPresentation: FloatingPanelPresentation
    let onTogglePinned: () -> Void
    let onConfigureProvider: () -> Void

    @State private var contentHeight: CGFloat = 160

    init(
        state: AppState,
        panelPresentation: FloatingPanelPresentation = FloatingPanelPresentation(),
        onTogglePinned: @escaping () -> Void = {},
        onConfigureProvider: @escaping () -> Void = {}
    ) {
        self.state = state
        self.panelPresentation = panelPresentation
        self.onTogglePinned = onTogglePinned
        self.onConfigureProvider = onConfigureProvider
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if state.isOffline {
                    WarningBar("无网络连接，翻译可能失败")
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                        header
                        sourceBlock

                        if state.isTranslating && state.outcomes.isEmpty && state.pendingProviders.isEmpty {
                            ForEach(0..<2, id: \.self) { _ in SkeletonCard() }
                        } else if state.outcomes.isEmpty && state.pendingProviders.isEmpty {
                            emptyState
                        } else {
                            ForEach(orderedSlots) { slot in
                                switch slot {
                                case .outcome(let outcome):
                                    TranslationOutcomeCard(outcome: outcome,
                                                           isSlow: state.slowProviderIDs.contains(outcome.providerId),
                                                           onSpeak: { state.speakTranslation($0) },
                                                           onCopy: { copy($0) },
                                                           onConfigure: onConfigureProvider)
                                case .pending(let provider):
                                    PendingOutcomeCard(provider: provider)
                                }
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
            .background(Theme.Palette.bgPanel)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.window))
            .overlay(panelStroke)
        }
        .frame(width: 384)
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
    }

    private var panelStroke: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.window)
            .strokeBorder(panelPresentation.isPinned ? Theme.Palette.accent.opacity(0.5) : Theme.Palette.separator, lineWidth: 0.5)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.window)
                    .strokeBorder(panelPresentation.isPinned ? Theme.Palette.accentSoft : Color.clear, lineWidth: 1)
            )
    }

    private var emptyState: some View {
        Text("无可用引擎或暂无结果")
            .foregroundStyle(Theme.Palette.label2)
            .font(Theme.Font.callout)
            .padding(.vertical, Theme.Spacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header (language direction + source actions)

    private var header: some View {
        HStack(spacing: Theme.Spacing.s8) {
            LanguageDirectionControl(
                sourceCode: state.settings.sourceLanguageCode,
                targetCode: state.settings.targetLanguageCode,
                onSourceChange: { state.setLanguageDirection(sourceCode: $0) },
                onTargetChange: { state.setLanguageDirection(targetCode: $0) },
                onSwap: swapLanguages
            )
            Spacer(minLength: 0)
            IconButton(
                panelPresentation.isPinned ? "pin.fill" : "pin",
                help: panelPresentation.isPinned ? "取消常驻" : "常驻",
                foreground: panelPresentation.isPinned ? Theme.Palette.accent : nil,
                activeBackground: panelPresentation.isPinned
            ) {
                onTogglePinned()
            }
            .help(panelPresentation.isPinned ? "取消常驻" : "常驻")
            .accessibilityLabel(panelPresentation.isPinned ? "取消常驻结果面板" : "常驻结果面板")
            Button { state.toggleFavorite() } label: {
                Image(systemName: state.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(state.isFavorite ? Theme.Palette.star : Theme.Palette.label2)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .disabled(state.savedRecordId == nil)
            .help("收藏")
            IconButton("doc.on.doc", help: "复制原文") { copy(state.sourceText) }
            IconButton("speaker.wave.2", help: "朗读原文") { state.speakSource() }
        }
        .frame(height: 28)
    }

    private func swapLanguages() {
        let sourceCode = state.settings.sourceLanguageCode
        let targetCode = state.settings.targetLanguageCode
        guard sourceCode != "auto" else { return }
        state.setLanguageDirection(sourceCode: targetCode, targetCode: sourceCode)
    }

    // MARK: - Source block

    private var sourceBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            Text(state.sourceText)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.label)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(sourceLanguageText)
                Spacer(minLength: 0)
                if state.isTranslating {
                    ProgressView().controlSize(.small)
                } else {
                    Text("\(state.sourceText.count) 个字符")
                }
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.label3)
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 11)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var sourceLanguageText: String {
        if state.sourceLanguage == .auto {
            if state.detectedSource == .auto { return "自动检测" }
            return "自动检测 \(LangPill.label(state.detectedSource, auto: ""))"
        }
        return "来源 \(LangPill.label(state.sourceLanguage, auto: ""))"
    }

    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private var orderedSlots: [TranslationSlot] {
        var outcomesByID: [String: AggregatedOutcome] = [:]
        for outcome in state.outcomes { outcomesByID[outcome.providerId] = outcome }
        var pendingByID: [String: PendingProviderViewState] = [:]
        for provider in state.pendingProviders { pendingByID[provider.id] = provider }
        let observedIDs = state.outcomes.map(\.providerId) + state.pendingProviders.map(\.id)
        let orderedIDs = EngineBootstrap.resolvedOrder(state.settings.engineOrder)
            + observedIDs.filter { !EngineBootstrap.defaultOrder.contains($0) }

        var seen: Set<String> = []
        var slots: [TranslationSlot] = []
        for id in orderedIDs where !seen.contains(id) {
            seen.insert(id)
            if let outcome = outcomesByID[id] {
                slots.append(.outcome(outcome))
            } else if let pending = pendingByID[id] {
                slots.append(.pending(pending))
            }
        }
        return slots
    }
}

private enum TranslationSlot: Identifiable {
    case outcome(AggregatedOutcome)
    case pending(PendingProviderViewState)

    var id: String {
        switch self {
        case .outcome(let outcome): return outcome.providerId
        case .pending(let provider): return provider.id
        }
    }
}

private struct LanguageDirectionControl: View {
    let sourceCode: String
    let targetCode: String
    let onSourceChange: (String) -> Void
    let onTargetChange: (String) -> Void
    let onSwap: () -> Void

    private let sourceOptions: [(String, String)] = [
        ("auto", "自动"), ("zh", "中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"),
        ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"), ("ru", "Русский")
    ]
    private let targetOptions: [(String, String)] = [
        ("zh", "中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"),
        ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"), ("ru", "Русский")
    ]

    var body: some View {
        HStack(spacing: 4) {
            languageMenu(title: shortLabel(sourceCode, auto: "自动"), options: sourceOptions, action: onSourceChange)
            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(sourceCode == "auto" ? Theme.Palette.label3 : Theme.Palette.accent)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .disabled(sourceCode == "auto")
            .help(sourceCode == "auto" ? "自动检测来源语言时不可互换" : "互换来源与目标语言")
            languageMenu(title: shortLabel(targetCode, auto: "中"), options: targetOptions, action: onTargetChange)
        }
        .font(.system(size: 11, weight: .semibold))
        .frame(height: 24)
        .padding(.horizontal, 10)
        .background(Theme.Palette.bgControl)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
    }

    private func languageMenu(
        title: String,
        options: [(String, String)],
        action: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.0) { code, name in
                Button(name) { action(code) }
            }
        } label: {
            Text(title)
                .foregroundStyle(Theme.Palette.label2)
                .frame(minWidth: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func shortLabel(_ code: String, auto: String) -> String {
        if code == "auto" { return auto }
        return LangPill.label(Language(code: code), auto: auto)
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

// MARK: - Provider slots

private struct TranslationOutcomeCard: View {
    let outcome: AggregatedOutcome
    let isSlow: Bool
    let onSpeak: (String) -> Void
    let onCopy: (String) -> Void
    let onConfigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            head
            content
            if let result = outcome.result {
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    IconButton("doc.on.doc", help: "复制译文", size: 11) { onCopy(result.translated) }
                    IconButton("speaker.wave.2", help: "朗读译文", size: 11) { onSpeak(result.translated) }
                }
                .padding(.top, -2)
            }
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(outcome.error != nil ? Theme.Palette.danger.opacity(0.6) : Theme.Palette.hairline, lineWidth: 0.5)
        )
    }

    private var head: some View {
        HStack(spacing: Theme.Spacing.s8) {
            EngineTag(outcome.displayName, tone: outcome.error == nil ? .accent : .danger)
            if isSlow {
                Text("较慢生成")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
            }
            Spacer(minLength: 0)
            Text(outcome.error == nil ? "\(outcome.latencyMs)ms" : "失败")
                .font(Theme.Font.caption.monospacedDigit())
                .foregroundStyle(outcome.error == nil ? Theme.Palette.label3 : Theme.Palette.danger)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let result = outcome.result {
            TranslationBody(result: result, lineLimit: nil)
        } else if let error = outcome.error {
            VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                Text(providerErrorText(error))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                if providerNeedsConfiguration(error) {
                    Button { onConfigure() } label: {
                        Label("配置密钥", systemImage: "gearshape")
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}

private struct PendingOutcomeCard: View {
    let provider: PendingProviderViewState

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                EngineTag(provider.displayName, tone: .secondary)
                Spacer(minLength: 0)
                Text(provider.softTimedOut ? "仍在生成" : (provider.isSlow ? "生成中" : "请求中"))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
            }
            SkeletonLine(width: nil)
            SkeletonLine(width: 210)
            if provider.softTimedOut {
                Text(message)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
    }

    private var message: String {
        if provider.softTimedOut {
            return "仍在生成；其他已返回结果会按设置顺序保持在原位。"
        }
        if provider.isSlow {
            return "正在生成；不会改变结果列表顺序。"
        }
        return "正在请求翻译结果。"
    }
}

private struct TranslationBody: View {
    let result: TranslateResult
    let lineLimit: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4 + 2) {
            Text(result.translated)
                .font(Theme.Font.result)
                .foregroundStyle(Theme.Palette.label)
                .textSelection(.enabled)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let phonetics = result.phonetics, !phonetics.isEmpty {
                Text(phonetics.map { "\($0.type) \($0.value)" }.joined(separator: "  "))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.label2)
            }
            if let defs = result.definitions {
                ForEach(Array(defs.enumerated()), id: \.offset) { _, definition in
                    Text("\(definition.partOfSpeech) \(definition.meanings.joined(separator: "；"))")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct EngineTag: View {
    enum Tone {
        case accent
        case secondary
        case danger
    }

    let label: String
    let tone: Tone

    init(_ label: String, tone: Tone) {
        self.label = label
        self.tone = tone
    }

    var body: some View {
        Text(label.uppercased())
            .font(Theme.Font.tag)
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var foreground: Color {
        switch tone {
        case .accent: return Theme.Palette.accent
        case .secondary: return Theme.Palette.label2
        case .danger: return Theme.Palette.danger
        }
    }

    private var background: Color {
        switch tone {
        case .accent: return Theme.Palette.accentSoft
        case .secondary: return Theme.Palette.bgControl
        case .danger: return Theme.Palette.danger.opacity(0.12)
        }
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Palette.separator.opacity(0.7))
            .frame(height: 0.5)
            .padding(.leading, Theme.Spacing.s12)
    }
}

private func providerErrorText(_ e: ProviderError) -> String {
    switch e {
    case .auth: return "鉴权失败，请检查 API Key"
    case .rateLimited: return "请求过于频繁，请稍后重试"
    case .network: return "网络错误"
    case .timeout: return "请求超时"
    case .unsupportedLanguage: return "不支持的语言"
    case .notConfigured: return "未配置"
    case .service(let m):
        if m.hasPrefix("系统翻译") { return m }
        return "服务错误：\(m)"
    case .plugin(let m): return "插件错误：\(m)"
    }
}

private func providerNeedsConfiguration(_ e: ProviderError) -> Bool {
    switch e {
    case .auth, .notConfigured: return true
    default: return false
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
            .fill(Theme.Palette.bgSkeleton)
            .frame(maxWidth: width == .infinity ? .infinity : width, alignment: .leading)
            .opacity(shimmer ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
    }
}

private struct SkeletonLine: View {
    let width: CGFloat?
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Theme.Palette.bgSkeleton)
            .frame(width: width, height: 13)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(shimmer ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
    }
}
