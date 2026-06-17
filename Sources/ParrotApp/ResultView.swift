import SwiftUI
import AppKit
import ParrotCore

/// Floating result content: a language-direction header, source context, then provider
/// slots displayed in the order configured in Settings.
struct ResultView: View {
    private enum Layout {
        static let minWidth: CGFloat = 480
        static let idealWidth: CGFloat = 560
        static let minHeight: CGFloat = 320
        static let minScrollHeight: CGFloat = 260
        static let idealScrollFloor: CGFloat = 520
        static let maxPreferredHeight: CGFloat = 680
    }

    @ObservedObject var state: AppState
    @ObservedObject var panelPresentation: FloatingPanelPresentation
    let onTogglePinned: () -> Void
    let onConfigureProvider: (String?) -> Void
    let onWorkspaceNoticeAction: (WorkspaceNotice.Action) -> Void
    let onClose: () -> Void

    @State private var contentHeight: CGFloat = 160
    @State private var feedbackText: String = ""
    @State private var sourceComposerFocused: Bool = false

    init(
        state: AppState,
        panelPresentation: FloatingPanelPresentation = FloatingPanelPresentation(),
        onTogglePinned: @escaping () -> Void = {},
        onConfigureProvider: @escaping (String?) -> Void = { _ in },
        onWorkspaceNoticeAction: @escaping (WorkspaceNotice.Action) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        self.state = state
        self.panelPresentation = panelPresentation
        self.onTogglePinned = onTogglePinned
        self.onConfigureProvider = onConfigureProvider
        self.onWorkspaceNoticeAction = onWorkspaceNoticeAction
        self.onClose = onClose
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
                        if let notice = state.workspaceNotice {
                            WorkspaceNoticeView(notice: notice, onAction: handleNoticeAction)
                        }
                        sourceBlock

                        if state.isTranslating && state.outcomes.isEmpty && state.pendingProviders.isEmpty {
                            ForEach(0..<2, id: \.self) { _ in SkeletonCard() }
                        } else if state.outcomes.isEmpty && state.pendingProviders.isEmpty {
                            if state.isRecognizingOCR {
                                recognizingState
                            } else if state.canTranslateDraft {
                                readyToTranslateState
                            } else {
                                emptyState
                            }
                        } else {
                            ForEach(orderedSlots) { slot in
                                switch slot {
                                case .outcome(let outcome):
                                    TranslationOutcomeCard(outcome: outcome,
                                                           isSlow: state.slowProviderIDs.contains(outcome.providerId),
                                                           onSpeak: { state.speakTranslation($0) },
                                                           onCopy: { copy($0) },
                                                           onRetry: { state.retryProvider(outcome.providerId) },
                                                           onConfigure: { onConfigureProvider(outcome.providerId) })
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
                .frame(
                    minHeight: Layout.minScrollHeight,
                    idealHeight: min(max(contentHeight, Layout.idealScrollFloor), Layout.maxPreferredHeight),
                    maxHeight: .infinity
                )
                if !feedbackText.isEmpty {
                    Divider()
                    Text(feedbackText)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label2)
                        .frame(maxWidth: .infinity, minHeight: 26)
                }
            }
            .background(Theme.Palette.bgPanel)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.window))
            .overlay(panelStroke)
        }
        .frame(
            minWidth: Layout.minWidth,
            idealWidth: Layout.idealWidth,
            maxWidth: .infinity,
            minHeight: Layout.minHeight,
            idealHeight: min(max(contentHeight, Layout.idealScrollFloor), Layout.maxPreferredHeight),
            maxHeight: .infinity
        )
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        .onDisappear {
            sourceComposerFocused = false
            state.setComposerFocused(false)
        }
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
        Text("输入、划词或截图后，源文会出现在这里。")
            .foregroundStyle(Theme.Palette.label2)
            .font(Theme.Font.callout)
            .padding(.vertical, Theme.Spacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readyToTranslateState: some View {
        HStack(spacing: Theme.Spacing.s8) {
            Image(systemName: "keyboard")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.accent)
            Text("校对源文后按 ⌘↩ 翻译，或点击源文区右下角的“翻译”。")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 10)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var recognizingState: some View {
        HStack(spacing: Theme.Spacing.s8) {
            ProgressView().controlSize(.small)
            Text("正在识别截图文字…")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 10)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    // MARK: - Header (language direction + source actions)

    private var header: some View {
        HStack(spacing: Theme.Spacing.s8) {
            LanguageDirectionControl(
                sourceCode: state.sourceLanguage == .auto ? "auto" : (state.sourceLanguage.code ?? state.settings.sourceLanguageCode),
                targetCode: state.targetLanguage.code ?? state.settings.targetLanguageCode,
                onSourceChange: { state.setLanguageDirection(sourceCode: $0) },
                onTargetChange: { state.setLanguageDirection(targetCode: $0) },
                onSwap: swapLanguages
            )
            Spacer(minLength: 0)
            IconButton("arrow.clockwise", help: state.isSourceDirty ? "翻译当前编辑内容" : "重新翻译") {
                state.retryCurrentTranslation()
            }
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
            Button {
                state.toggleFavorite()
                showFeedback(state.isFavorite ? "已收藏" : "已取消收藏")
            } label: {
                Image(systemName: state.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(state.isFavorite ? Theme.Palette.star : Theme.Palette.label2)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .disabled(state.savedRecordId == nil)
            .help("收藏")
            IconButton("doc.on.doc", help: "复制原文") { copy(state.actionSourceText) }
            IconButton("speaker.wave.2", help: "朗读原文") { state.speakSource() }
            IconButton("gearshape", help: "打开设置") { onConfigureProvider(nil) }
            IconButton("xmark", help: "关闭面板") { onClose() }
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
            ZStack(alignment: .topLeading) {
                if state.sourceDraft.isEmpty {
                    Text("输入或粘贴要翻译的文本…")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label3)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                SourceComposerTextView(
                    text: sourceDraftBinding,
                    focusRequest: state.composerFocusRequest,
                    onCommandReturn: { state.translateDraft() },
                    onFocusChange: { focused in
                        sourceComposerFocused = focused
                        state.setComposerFocused(focused)
                    }
                )
                    .frame(height: sourceEditorHeight)
                    .accessibilityLabel("源文编辑器")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(sourceStatusText)
                Spacer(minLength: 0)
                if state.isTranslating {
                    ProgressView().controlSize(.small)
                } else if state.isSourceDirty {
                    Text("已修改，⌘↩ 重新翻译")
                } else {
                    Text("\(state.sourceDraft.count) 个字符")
                }
                Menu {
                    Button("删除空行") { state.removeBlankDraftLines() }
                    Button("合并为一段") { state.mergeDraftLines() }
                    Divider()
                    Button("清空源文", role: .destructive) { state.clearDraft() }
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundStyle(state.canTranslateDraft ? Theme.Palette.label2 : Theme.Palette.label3)
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .disabled(!state.canTranslateDraft)
                .help("整理源文")
                .accessibilityLabel("整理源文")
                Button {
                    state.translateDraft()
                } label: {
                    Label("翻译", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!state.canTranslateDraft)
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.label3)
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 11)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(sourceComposerFocused ? Theme.Palette.accent.opacity(0.75) : Theme.Palette.hairline,
                              lineWidth: sourceComposerFocused ? 1.2 : 0.5)
        )
    }

    private var sourceDraftBinding: Binding<String> {
        Binding(
            get: { state.sourceDraft },
            set: { state.updateDraft($0) }
        )
    }

    private var sourceEditorHeight: CGFloat {
        let explicitLines = max(1, state.sourceDraft.reduce(1) { count, char in
            char.isNewline ? count + 1 : count
        })
        let wrappedLines = max(1, Int(ceil(Double(max(state.sourceDraft.count, 1)) / 42.0)))
        let lines = min(7, max(2, max(explicitLines, wrappedLines)))
        return CGFloat(lines) * 18 + 22
    }

    private var sourceStatusText: String {
        if state.sourceDraftTrimmed.isEmpty {
            return "编辑源文"
        }
        return sourceLanguageText
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
        showFeedback("已复制")
    }

    private func showFeedback(_ text: String) {
        feedbackText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if feedbackText == text { feedbackText = "" }
        }
    }

    private func handleNoticeAction(_ action: WorkspaceNotice.Action) {
        if action == .dismiss {
            state.dismissWorkspaceNotice()
        } else {
            onWorkspaceNoticeAction(action)
        }
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

private struct WorkspaceNoticeView: View {
    let notice: WorkspaceNotice
    let onAction: (WorkspaceNotice.Action) -> Void

    var body: some View {
        if notice.prominence == .compact {
            compactBody
        } else {
            cardBody
        }
    }

    private var compactBody: some View {
        HStack(spacing: Theme.Spacing.s8) {
            Image(systemName: notice.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.85))
                .frame(width: 16, height: 18)
            Text(notice.title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label2)
                .lineLimit(1)
            Text(notice.detail)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                onAction(.dismiss)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label3)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help("隐藏提示")
            .accessibilityLabel("隐藏提示")
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Theme.Palette.bgControl.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private var cardBody: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s8) {
            Image(systemName: notice.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 20)
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                Text(notice.title)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.label)
                Text(notice.detail)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                if notice.primaryAction != nil || notice.secondaryAction != nil {
                    HStack(spacing: Theme.Spacing.s8) {
                        if let primary = notice.primaryAction {
                            Button(primary.title) { onAction(primary.action) }
                                .controlSize(.small)
                        }
                        if let secondary = notice.secondaryAction {
                            Button(secondary.title) { onAction(secondary.action) }
                                .controlSize(.small)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            Button {
                onAction(.dismiss)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label3)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("隐藏提示")
            .accessibilityLabel("隐藏提示")
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
    }

    private var tint: Color {
        switch notice.tone {
        case .info: return Theme.Palette.accent
        case .warning: return Theme.Palette.warning
        case .error: return Theme.Palette.danger
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

private struct SourceComposerTextView: NSViewRepresentable {
    @Binding var text: String
    let focusRequest: Int
    let onCommandReturn: () -> Void
    let onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = CommandAwareTextView()
        textView.delegate = context.coordinator
        textView.onCommandReturn = onCommandReturn
        textView.string = text
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.setAccessibilityElement(true)
        textView.setAccessibilityLabel("源文编辑器")

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? CommandAwareTextView else { return }
        textView.onCommandReturn = onCommandReturn
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = .labelColor
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            let location = min(selectedRange.location, length)
            let selectionLength = min(selectedRange.length, max(0, length - location))
            textView.setSelectedRange(NSRange(location: location, length: selectionLength))
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceComposerTextView
        weak var textView: CommandAwareTextView?
        var lastFocusRequest: Int

        init(_ parent: SourceComposerTextView) {
            self.parent = parent
            self.lastFocusRequest = parent.focusRequest
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
        }
    }

    final class CommandAwareTextView: NSTextView {
        var onCommandReturn: (() -> Void)?

        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let commandReturn = flags.contains(.command)
                && (event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\u{3}")
            if commandReturn {
                onCommandReturn?()
                return
            }
            super.keyDown(with: event)
        }
    }
}

// MARK: - Provider slots

private struct TranslationOutcomeCard: View {
    let outcome: AggregatedOutcome
    let isSlow: Bool
    let onSpeak: (String) -> Void
    let onCopy: (String) -> Void
    let onRetry: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            head
            content
            if let result = outcome.result {
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    IconButton("arrow.clockwise", help: "重试此引擎", size: 11) { onRetry() }
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
            Text(outcome.error == nil ? "\(outcome.latencyMs)ms" : providerStatusText(outcome.error))
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
                } else {
                    Button { onRetry() } label: {
                        Label("重试此引擎", systemImage: "arrow.clockwise")
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

private func providerStatusText(_ e: ProviderError?) -> String {
    switch e {
    case .notConfigured: return "需配置"
    case .auth: return "鉴权失败"
    case .rateLimited: return "限流"
    case .timeout: return "超时"
    case .none: return ""
    default: return "失败"
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
