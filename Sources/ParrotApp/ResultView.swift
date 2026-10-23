import SwiftUI
import AppKit
import ParrotCore

/// A compact translation workspace: edit the source, translate, then copy the result.
struct ResultView: View {
    private enum Layout {
        static let minWidth: CGFloat = 520
        static let idealWidth: CGFloat = 560
        static let minHeight: CGFloat = 280
        static let toolbarControlHeight: CGFloat = 32
    }

    @ObservedObject var state: AppState
    @ObservedObject var settings: AppSettings
    @ObservedObject var panelPresentation: FloatingPanelPresentation
    let onTogglePinned: () -> Void
    let onConfigureProvider: (String?) -> Void
    let onVocabulary: () -> Void
    let onContextMemory: () -> Void
    let onReplaceInSourceApp: (String) -> Bool
    let onReturnToSourceApp: () -> Void
    let onWorkspaceNoticeAction: (WorkspaceNotice.Action) -> Void
    let onClose: () -> Void
    let onContentMetricsChange: (FloatingPanelContentMetrics) -> Void

    @State private var feedbackText: String = ""
    @State private var sourceComposerFocused: Bool = false

    init(
        state: AppState,
        panelPresentation: FloatingPanelPresentation = FloatingPanelPresentation(),
        onTogglePinned: @escaping () -> Void = {},
        onConfigureProvider: @escaping (String?) -> Void = { _ in },
        onVocabulary: @escaping () -> Void = {},
        onContextMemory: @escaping () -> Void = {},
        onReplaceInSourceApp: @escaping (String) -> Bool = { _ in false },
        onReturnToSourceApp: @escaping () -> Void = {},
        onWorkspaceNoticeAction: @escaping (WorkspaceNotice.Action) -> Void = { _ in },
        onClose: @escaping () -> Void = {},
        onContentMetricsChange: @escaping (FloatingPanelContentMetrics) -> Void = { _ in }
    ) {
        self.state = state
        self.settings = state.settings
        self.panelPresentation = panelPresentation
        self.onTogglePinned = onTogglePinned
        self.onConfigureProvider = onConfigureProvider
        self.onVocabulary = onVocabulary
        self.onContextMemory = onContextMemory
        self.onReplaceInSourceApp = onReplaceInSourceApp
        self.onReturnToSourceApp = onReturnToSourceApp
        self.onWorkspaceNoticeAction = onWorkspaceNoticeAction
        self.onClose = onClose
        self.onContentMetricsChange = onContentMetricsChange
    }

    var body: some View {
        workspaceBody
        .onPreferenceChange(WorkspaceLayoutMeasurementsKey.self) { measurements in
            guard measurements.viewportWidth > 0, measurements.contentSize.height > 0 else { return }
            onContentMetricsChange(FloatingPanelContentMetrics(
                contentSize: CGSize(width: measurements.viewportWidth,
                                    height: measurements.contentSize.height),
                chromeHeight: measurements.chromeHeight,
                preferredWidth: measurements.preferredWidth,
                sessionID: measurements.sessionID
            ))
        }
        .onDisappear {
            sourceComposerFocused = false
            state.setComposerFocused(false)
        }
        .onExitCommand {
            onClose()
        }
    }

    private var workspaceBody: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    if state.isOffline {
                        WarningBar("无网络连接，翻译可能失败")
                    }
                    fixedToolbar
                }
                .background(GeometryReader { geometry in
                    Color.clear.preference(
                        key: WorkspaceLayoutMeasurementsKey.self,
                        value: WorkspaceLayoutMeasurements(chromeHeight: geometry.size.height)
                    )
                })
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s16) {
                        if panelPresentation.isCapturingSelection {
                            selectionCaptureState
                        } else {
                            if let notice = state.workspaceNotice {
                                WorkspaceNoticeView(notice: notice, onAction: handleNoticeAction)
                            }
                            if state.ocrCandidates.count > 1 {
                                OCRCandidatesView(
                                    candidates: state.ocrCandidates,
                                    selectedID: state.selectedOCRCandidateID,
                                    onSelect: { state.selectOCRCandidate(id: $0) }
                                )
                            }
                            sourceBlock
                            resultsList
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.s20)
                    .padding(.bottom, Theme.Spacing.s20)
                    .background(GeometryReader { geo in
                        Color.clear.preference(
                            key: WorkspaceLayoutMeasurementsKey.self,
                            value: WorkspaceLayoutMeasurements(
                                contentSize: geo.size,
                                sessionID: sizingSessionID,
                                preferredWidth: preferredContentWidth
                            )
                        )
                    })
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(GeometryReader { geometry in
                    Color.clear.preference(
                        key: WorkspaceLayoutMeasurementsKey.self,
                        value: WorkspaceLayoutMeasurements(viewportWidth: geometry.size.width)
                    )
                })
                if !feedbackText.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                        Text(feedbackText)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.label2)
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .background(GeometryReader { geometry in
                        Color.clear.preference(
                            key: WorkspaceLayoutMeasurementsKey.self,
                            value: WorkspaceLayoutMeasurements(chromeHeight: geometry.size.height)
                        )
                    })
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
            maxHeight: .infinity
        )
    }

    private var sizingSessionID: String {
        [state.currentOrigin.rawValue, state.isLookupMode ? "lookup" : (state.isPolishMode ? "polish" : "translate"),
         state.sourceLanguage.code ?? "auto", state.targetLanguage.code ?? "auto",
         state.sourceText].joined(separator: "\u{0}")
    }

    private var preferredContentWidth: CGFloat {
        let longestResult = state.outcomes.compactMap { $0.result?.translated.count }.max() ?? 0
        return FloatingPanelSizing.preferredWidth(
            longestTextCount: max(state.sourceDraft.count, longestResult),
            providerCount: state.outcomes.count + state.pendingProviders.count
        )
    }

    private var panelStroke: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.window)
            .strokeBorder(panelPresentation.isPinned ? Theme.Palette.accent.opacity(0.5) : Theme.Palette.separator, lineWidth: 0.5)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.window)
                    .strokeBorder(panelPresentation.isPinned ? Theme.Palette.accentSoft : Color.clear, lineWidth: 1)
            )
    }

    private var recognizingState: some View {
        HStack(spacing: Theme.Spacing.s8) {
            ProgressView().controlSize(.small)
            Text(L("正在识别截图文字…"))
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

    private var selectionCaptureState: some View {
        HStack(spacing: Theme.Spacing.s8) {
            ProgressView().controlSize(.small)
            Text(L("正在获取选中文字…"))
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var resultsList: some View {
        if state.isTranslating && state.outcomes.isEmpty && state.pendingProviders.isEmpty {
            HStack(spacing: Theme.Spacing.s8) {
                ProgressView().controlSize(.small)
                Text(L("正在请求翻译结果。"))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.label2)
            }
            .padding(Theme.Spacing.s12)
        } else if state.outcomes.isEmpty && state.pendingProviders.isEmpty {
            if state.isRecognizingOCR {
                recognizingState
            }
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                if state.settings.advancedFeaturesEnabled,
                   state.isPolishMode, !state.polishVariants.isEmpty {
                    PolishVariantsView(
                        variants: state.polishVariants,
                        selectedTone: state.selectedPolishTone,
                        onSelect: { state.selectPolishTone($0, autoRun: false) },
                        onCopy: { copy($0) },
                        onReplace: { replaceInSourceApp($0) },
                        onSave: { saveCurrentExpression($0) }
                    )
                }
                ForEach(visibleOrderedSlots) { slot in
                    providerSlotView(slot, isPrimary: slot.id == state.primarySuccessfulOutcome?.providerId)
                }
            }
        }
    }

    @ViewBuilder
    private func providerSlotView(_ slot: TranslationSlot, isPrimary: Bool = false) -> some View {
        switch slot {
        case .outcome(let outcome):
            TranslationOutcomeCard(
                outcome: outcome,
                isPrimary: isPrimary,
                isSlow: state.slowProviderIDs.contains(outcome.providerId),
                advancedFeaturesEnabled: state.settings.advancedFeaturesEnabled,
                onSpeak: { state.speakTranslation($0) },
                onCopy: { copy($0) },
                onCopyAndReturn: isPrimary && canReturnToSourceApp ? { copyAndReturn($0) } : nil,
                onReplaceInSourceApp: state.isPolishMode ? { replaceInSourceApp($0) } : nil,
                onRetry: { state.retryProvider(outcome.providerId) },
                onConfigure: { onConfigureProvider(outcome.providerId) }
            )
        case .pending(let provider):
            PendingOutcomeCard(provider: provider)
        }
    }

    // MARK: - Header (language direction + global actions)

    private var fixedToolbar: some View {
        header
            .padding(.horizontal, Theme.Spacing.s16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(MacMaterialBackground(material: .headerView))
            .overlay(alignment: .bottom) { Divider().opacity(0.45) }
            .zIndex(1)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s8) {
            LanguageDirectionControl(
                sourceCode: state.sourceLanguage == .auto ? "auto" : (state.sourceLanguage.code ?? state.settings.sourceLanguageCode),
                targetCode: state.targetLanguage.code ?? state.settings.targetLanguageCode,
                onSourceChange: { state.setLanguageDirection(sourceCode: $0) },
                onTargetChange: { state.setLanguageDirection(targetCode: $0) },
                onSwap: swapLanguages
            )
            if state.contextProfile == .privateLocal {
                Menu {
                    Button(L("切换到常规翻译")) { state.setContextProfile(.quickTranslate) }
                } label: {
                    Label(L("仅本地翻译"), systemImage: "lock.shield")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label2)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(L("仅本地翻译"))
            }
            Spacer(minLength: 0)
            HStack(spacing: Theme.Spacing.s4) {
                IconButton(
                    panelPresentation.isPinned ? "pin.fill" : "pin",
                    help: panelPresentation.isPinned ? "取消常驻" : "常驻",
                    foreground: panelPresentation.isPinned ? Theme.Palette.accent : nil,
                    activeBackground: panelPresentation.isPinned
                ) {
                    onTogglePinned()
                }
                Menu {
                    Button { copy(state.actionSourceText) } label: {
                        Label(L("复制原文"), systemImage: "text.alignleft")
                    }
                    .disabled(!state.canTranslateDraft)
                    Button { state.speakSource() } label: {
                        Label(L("朗读原文"), systemImage: "speaker.wave.2")
                    }
                    .disabled(!state.canTranslateDraft)
                    Button { state.clearDraft() } label: {
                        Label(L("清空源文"), systemImage: "xmark.circle")
                    }
                    .disabled(!state.canTranslateDraft)
                    Divider()
                    if state.canCompareOtherEngines {
                        Button { state.compareOtherEngines() } label: {
                            Label(L("比较其他引擎"), systemImage: "square.stack")
                        }
                    }
                    Button {
                        state.toggleFavorite()
                        showFeedback(state.isFavorite ? "已收藏" : "已取消收藏")
                    } label: {
                        Label(L(state.isFavorite ? "取消收藏" : "收藏"), systemImage: state.isFavorite ? "star.fill" : "star")
                    }
                    .disabled(state.savedRecordId == nil)
                    if state.settings.advancedFeaturesEnabled {
                        Divider()
                        Menu(L("更多工具")) {
                            Button(L("输入润色")) { state.translateDraft(mode: .polish) }
                                .disabled(!state.canTranslateDraft)
                            Button(L("删除空行")) { state.removeBlankDraftLines() }
                                .disabled(!state.canTranslateDraft)
                            Button(L("合并为一段")) { state.mergeDraftLines() }
                                .disabled(!state.canTranslateDraft)
                            ContextProfileMenu(selection: state.contextProfile) { profile in
                                state.setContextProfile(profile)
                            }
                            Divider()
                            Button(L("个人词库")) { onVocabulary() }
                            Button(L("规则记忆")) { onContextMemory() }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Palette.label2)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(L("更多操作"))
                .accessibilityLabel(L("更多操作"))
                IconButton("gearshape", help: "打开设置") { onConfigureProvider(nil) }
                IconButton("xmark", help: "关闭") { onClose() }
            }
        }
        .frame(height: Layout.toolbarControlHeight)
    }

    private func swapLanguages() {
        let sourceCode = state.settings.sourceLanguageCode
        let targetCode = state.settings.targetLanguageCode
        guard sourceCode != "auto" else { return }
        state.setLanguageDirection(sourceCode: targetCode, targetCode: sourceCode)
    }

    // MARK: - Source block

    private var sourceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("原文"))
                    .font(Theme.Font.callout.weight(.medium))
                    .foregroundStyle(Theme.Palette.label2)
                Spacer(minLength: 0)
            }
            ZStack(alignment: .topLeading) {
                if state.sourceDraft.isEmpty {
                    Text(state.isPolishMode
                        ? L("输入或粘贴要润色的草稿…")
                        : L("输入或粘贴要翻译的文本…"))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Palette.label3)
                        .padding(.top, 10)
                        .allowsHitTesting(false)
                }
                SourceComposerTextView(
                    text: sourceDraftBinding,
                    focusRequest: state.composerFocusRequest,
                    onReturn: { state.translateDraft() },
                    onFocusChange: { focused in
                        sourceComposerFocused = focused
                        state.setComposerFocused(focused)
                    },
                    onSelectionChange: { _ in }
                )
                    .frame(height: sourceEditorHeight)
                    .accessibilityLabel(L("源文编辑器"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.bgContent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.input))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.input)
                    .strokeBorder(sourceComposerFocused ? Theme.Palette.accent.opacity(0.55) : Theme.Palette.hairline,
                                  lineWidth: sourceComposerFocused ? 1 : 0.5)
            )
            HStack {
                Spacer(minLength: 0)
                if state.settings.advancedFeaturesEnabled && state.isPolishMode {
                    Button {
                        state.cyclePolishTone()
                    } label: {
                        Label(L("切换语气"), systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!state.canTranslateDraft)
                    .help(L("当前语气：%@", state.selectedPolishTone.title))
                    .accessibilityLabel(L("切换语气"))
                    Button {
                        state.translateDraft(mode: .polish)
                    } label: {
                        Label(L("生成改写"), systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryActionButtonStyle(isProminent: state.isSourceDirty || state.outcomes.isEmpty))
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!state.canTranslateDraft)
                } else {
                    Button {
                        state.translateDraft(mode: .translate)
                    } label: {
                        Label(L("翻译"), systemImage: "arrow.right")
                    }
                    .buttonStyle(PrimaryActionButtonStyle(isProminent: state.isSourceDirty || state.outcomes.isEmpty))
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!state.canTranslateDraft)
                }
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.label3)
        }
        .padding(.top, Theme.Spacing.s16)
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
        let lines = min(6, max(2, max(explicitLines, wrappedLines)))
        return CGFloat(lines) * 20 + 12
    }

    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        showFeedback("已复制")
    }

    private func copyAndReturn(_ text: String) {
        copy(text)
        onReturnToSourceApp()
    }

    private func saveCurrentExpression(_ translatedText: String) {
        let label = state.currentOrigin == .ocr ? "研究摘录" : "工作区表达"
        if state.saveCurrentExpression(translatedText: translatedText, sceneLabel: label) {
            showFeedback(state.currentOrigin == .ocr ? "已保存到研究摘录" : "已存为表达")
        } else {
            showFeedback("暂无可保存内容")
        }
    }

    private func replaceInSourceApp(_ translatedText: String) {
        showFeedback(onReplaceInSourceApp(translatedText) ? "已发送替换" : "没有可替换的原 App")
    }

    private func showFeedback(_ text: String) {
        let localized = L(text)
        feedbackText = localized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if feedbackText == localized { feedbackText = "" }
        }
    }

    private func handleNoticeAction(_ action: WorkspaceNotice.Action) {
        if action == .dismiss {
            state.dismissWorkspaceNotice()
        } else {
            onWorkspaceNoticeAction(action)
        }
    }

    private var canReturnToSourceApp: Bool {
        state.currentContextSourceApp != nil
    }

    private var orderedSlots: [TranslationSlot] {
        translationSlotsForPresentation(
            outcomes: state.outcomes,
            pendingProviders: state.pendingProviders,
            providerOrder: state.providerDisplayOrder
        )
    }

    private var visibleOrderedSlots: [TranslationSlot] {
        let slots = orderedSlots
        guard state.settings.advancedFeaturesEnabled, state.isPolishMode, !state.polishVariants.isEmpty else { return slots }
        return slots.filter { slot in
            switch slot {
            case .outcome(let outcome):
                return outcome.result == nil
            case .pending:
                return true
            }
        }
    }


}

enum TranslationSlot: Identifiable {
    case outcome(AggregatedOutcome)
    case pending(PendingProviderViewState)

    var id: String {
        switch self {
        case .outcome(let outcome): return outcome.providerId
        case .pending(let provider): return provider.id
        }
    }

}

@MainActor
func translationSlotsForPresentation(
    outcomes: [AggregatedOutcome],
    pendingProviders: [PendingProviderViewState],
    providerOrder: [String]
) -> [TranslationSlot] {
    var outcomesByID: [String: AggregatedOutcome] = [:]
    for outcome in outcomes { outcomesByID[outcome.providerId] = outcome }
    let observedIDs = outcomes.map(\.providerId) + pendingProviders.map(\.id)
    var pendingByID: [String: PendingProviderViewState] = [:]
    for provider in pendingProviders { pendingByID[provider.id] = provider }
    var seen: Set<String> = []
    let slots: [TranslationSlot] = observedIDs.compactMap { id in
        guard seen.insert(id).inserted else { return nil }
        if let outcome = outcomesByID[id] { return .outcome(outcome) }
        return pendingByID[id].map(TranslationSlot.pending)
    }
    return TranslationResultOrdering.ordered(slots, providerOrder: providerOrder, providerID: \.id)
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
            Text(L(notice.title))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label2)
                .lineLimit(1)
            Text(L(notice.detail))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let primary = notice.primaryAction, primary.action != .dismiss {
                Button { onAction(primary.action) } label: {
                    Text(L(primary.title))
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            IconButton("xmark", help: "隐藏提示", size: 9, foreground: Theme.Palette.label3) {
                onAction(.dismiss)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
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
                Text(L(notice.title))
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.label)
                Text(L(notice.detail))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                if notice.primaryAction != nil || notice.secondaryAction != nil {
                    HStack(spacing: Theme.Spacing.s8) {
                        if let primary = notice.primaryAction {
                            Button(L(primary.title)) { onAction(primary.action) }
                                .buttonStyle(SecondaryActionButtonStyle())
                        }
                        if let secondary = notice.secondaryAction {
                            Button(L(secondary.title)) { onAction(secondary.action) }
                                .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            IconButton("xmark", help: "隐藏提示", size: 10, foreground: Theme.Palette.label3) {
                onAction(.dismiss)
            }
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 10)
        .background(Theme.Palette.bgControl.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
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
        ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"), ("ru", "Русский"),
        ("pt", "Português"), ("it", "Italiano"), ("nl", "Nederlands"), ("pl", "Polski"),
        ("uk", "Українська"), ("tr", "Türkçe"), ("ar", "العربية"), ("hi", "हिन्दी"),
        ("id", "Bahasa Indonesia"), ("vi", "Tiếng Việt"), ("th", "ไทย"), ("ms", "Bahasa Melayu"),
        ("he", "עברית"), ("fa", "فارسی"), ("el", "Ελληνικά"), ("sv", "Svenska"),
        ("da", "Dansk"), ("fi", "Suomi"), ("no", "Norsk"), ("cs", "Čeština"),
        ("hu", "Magyar"), ("ro", "Română")
    ]
    private let targetOptions: [(String, String)] = [
        ("zh", "中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"),
        ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"), ("ru", "Русский"),
        ("pt", "Português"), ("it", "Italiano"), ("nl", "Nederlands"), ("pl", "Polski"),
        ("uk", "Українська"), ("tr", "Türkçe"), ("ar", "العربية"), ("hi", "हिन्दी"),
        ("id", "Bahasa Indonesia"), ("vi", "Tiếng Việt"), ("th", "ไทย"), ("ms", "Bahasa Melayu"),
        ("he", "עברית"), ("fa", "فارسی"), ("el", "Ελληνικά"), ("sv", "Svenska"),
        ("da", "Dansk"), ("fi", "Suomi"), ("no", "Norsk"), ("cs", "Čeština"),
        ("hu", "Magyar"), ("ro", "Română")
    ]

    var body: some View {
        HStack(spacing: 8) {
            languageMenu(title: shortLabel(sourceCode, auto: "自动"), options: sourceOptions, action: onSourceChange)
            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(sourceCode == "auto" ? Theme.Palette.label3 : Theme.Palette.accent)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(sourceCode == "auto")
            .help(L(sourceCode == "auto" ? "自动检测来源语言时不可互换" : "互换来源与目标语言"))
            languageMenu(title: shortLabel(targetCode, auto: "中"), options: targetOptions, action: onTargetChange)
        }
        .font(.system(size: 13, weight: .medium))
        .frame(height: 32)
    }

    private func languageMenu(
        title: String,
        options: [(String, String)],
        action: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.0) { code, name in
                Button(L(name)) { action(code) }
            }
        } label: {
            Text(L(title))
                .foregroundStyle(Theme.Palette.label)
                .padding(.horizontal, 6)
                .frame(minWidth: 40, minHeight: 32)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func shortLabel(_ code: String, auto: String) -> String {
        if code == "auto" { return auto }
        return LangPill.label(Language(code: code), auto: auto)
    }
}

/// The scroll document reports its full natural height; fixed chrome is measured
/// separately so the window can grow before the scroll view needs a scrollbar.
private struct WorkspaceLayoutMeasurements: Equatable {
    var contentSize: CGSize = .zero
    var chromeHeight: CGFloat = 0
    var sessionID = ""
    var preferredWidth: CGFloat = 0
    var viewportWidth: CGFloat = 0
}

private struct WorkspaceLayoutMeasurementsKey: PreferenceKey {
    static let defaultValue = WorkspaceLayoutMeasurements()

    static func reduce(value: inout WorkspaceLayoutMeasurements,
                       nextValue: () -> WorkspaceLayoutMeasurements) {
        let next = nextValue()
        if next.contentSize != .zero {
            value.contentSize = next.contentSize
            value.sessionID = next.sessionID
            value.preferredWidth = next.preferredWidth
        }
        value.chromeHeight += next.chromeHeight
        if next.viewportWidth > 0 { value.viewportWidth = next.viewportWidth }
    }
}

private struct SourceComposerTextView: NSViewRepresentable {
    @Binding var text: String
    let focusRequest: Int
    let onReturn: () -> Void
    let onFocusChange: (Bool) -> Void
    let onSelectionChange: (String) -> Void

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
        textView.onReturn = onReturn
        textView.string = text
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 0, height: 6)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.setAccessibilityElement(true)
        textView.setAccessibilityLabel(L("源文编辑器"))

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? CommandAwareTextView else { return }
        textView.onReturn = onReturn
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = .labelColor
        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            onSelectionChange("")
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

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onSelectionChange(Self.selectedText(in: textView))
        }

        private static func selectedText(in textView: NSTextView) -> String {
            let range = textView.selectedRange()
            guard range.length > 0,
                  let swiftRange = Range(range, in: textView.string) else { return "" }
            return String(textView.string[swiftRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    final class CommandAwareTextView: NSTextView {
        var onReturn: (() -> Void)?

        override func keyDown(with event: NSEvent) {
            if shouldSubmitSourceComposer(
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: event.modifierFlags
            ) {
                onReturn?()
                return
            }
            super.keyDown(with: event)
        }
    }
}

func shouldSubmitSourceComposer(
    charactersIgnoringModifiers: String?,
    modifierFlags: NSEvent.ModifierFlags
) -> Bool {
    let isReturn = charactersIgnoringModifiers == "\r" || charactersIgnoringModifiers == "\u{3}"
    let editingModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
    let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
    return isReturn && flags.intersection(editingModifiers).isEmpty
}

private struct PolishVariantsView: View {
    let variants: [PolishVariantViewState]
    let selectedTone: PolishTone
    let onSelect: (PolishTone) -> Void
    let onCopy: (String) -> Void
    let onReplace: (String) -> Void
    let onSave: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 165), spacing: Theme.Spacing.s8, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                LearningStatusChip(text: "Native Polish", tone: Theme.Palette.accent)
                Text(L("选择语气后替换回原 App"))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2)
                Spacer(minLength: 0)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.s8) {
                ForEach(variants) { variant in
                    variantCard(variant)
                }
            }
        }
    }

    private func variantCard(_ variant: PolishVariantViewState) -> some View {
        let selected = variant.tone == selectedTone
        return VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s4) {
                Text(variant.tone.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
                    .lineLimit(1)
                QualityStatusBadge(variant.tone.badge, tone: selected ? .accent : .secondary)
                Spacer(minLength: 0)
            }
            Text(variant.text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.label)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack(spacing: Theme.Spacing.s4) {
                Button {
                    onSelect(variant.tone)
                } label: {
                    Label(selected ? L("已选") : L("选择"), systemImage: selected ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selected)
                Spacer(minLength: 0)
                IconButton("bookmark", help: "存为表达", size: 11) { onSave(variant.text) }
                IconButton("doc.on.doc", help: "复制", size: 11) { onCopy(variant.text) }
            }
            Button {
                onReplace(variant.text)
            } label: {
                Label(L("替换到原 App"), systemImage: "arrowshape.turn.up.left.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(selected ? Theme.Palette.accent.opacity(0.72) : Theme.Palette.hairline, lineWidth: selected ? 1.2 : 0.5)
        )
    }
}

// MARK: - Provider slots

private struct TranslationOutcomeCard: View {
    let outcome: AggregatedOutcome
    let isPrimary: Bool
    let isSlow: Bool
    let advancedFeaturesEnabled: Bool
    let onSpeak: (String) -> Void
    let onCopy: (String) -> Void
    let onCopyAndReturn: ((String) -> Void)?
    let onReplaceInSourceApp: ((String) -> Void)?
    let onRetry: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            Divider().opacity(0.6)
                .padding(.bottom, Theme.Spacing.s4)
            HStack(spacing: Theme.Spacing.s8) {
                Text(L("译文"))
                    .font(Theme.Font.callout.weight(.medium))
                    .foregroundStyle(Theme.Palette.label2)
                Spacer(minLength: 0)
                Text(outcome.displayName)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2)
                    .lineLimit(1)
                if let modelName = outcome.modelName, !modelName.isEmpty {
                    Text(modelName)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label2)
                        .lineLimit(1)
                }
                if outcome.error != nil {
                    Text(providerStatusText(outcome.error))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.danger)
                }
                if let result = outcome.result {
                    Menu {
                        Button { onSpeak(result.translated) } label: {
                            Label(L("朗读译文"), systemImage: "speaker.wave.2")
                        }
                        Button { onRetry() } label: {
                            Label(L("重试此引擎"), systemImage: "arrow.clockwise")
                        }
                        if let onReplaceInSourceApp {
                            Button { onReplaceInSourceApp(result.translated) } label: {
                                Label(L("替换到原 App"), systemImage: "arrowshape.turn.up.left")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Palette.label2)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(L("更多操作"))
                    .accessibilityLabel(L("更多操作"))
                }
            }
            if let result = outcome.result {
                TranslationBody(result: result, lineLimit: nil)
                HStack(spacing: Theme.Spacing.s8) {
                    Spacer(minLength: 0)
                    if let onCopyAndReturn {
                        Button { onCopyAndReturn(result.translated) } label: {
                            Label(L("复制并返回"), systemImage: "arrowshape.turn.up.backward")
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                    Button { onCopy(result.translated) } label: {
                        Label(L("复制译文"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                .padding(.top, Theme.Spacing.s4)
            } else if let error = outcome.error {
                VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                    Text(providerErrorText(error))
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Theme.Spacing.s8) {
                        if !providerNeedsConfiguration(error) || CredentialCatalog.descriptor(matching: outcome.providerId) == nil {
                            Button { onRetry() } label: {
                                Label(L("重试此引擎"), systemImage: "arrow.clockwise")
                            }
                            .controlSize(.small)
                        }
                        if CredentialCatalog.descriptor(matching: outcome.providerId) != nil {
                            Button { onConfigure() } label: {
                                Label(L("配置服务"), systemImage: "gearshape")
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(.bottom, Theme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PendingOutcomeCard: View {
    let provider: PendingProviderViewState

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                ProgressView().controlSize(.small)
                EngineTag(provider.displayName, tone: .secondary)
                if let model = provider.modelName, !model.isEmpty {
                    Text(model).font(Theme.Font.caption).foregroundStyle(Theme.Palette.label2).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(L(provider.softTimedOut ? "仍在生成" : (provider.isSlow ? "生成中" : "请求中")))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
            }
            if provider.softTimedOut {
                Text(message)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Theme.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var message: String {
        if provider.softTimedOut {
            return L("仍在生成；完成后会自动归入结果列表。")
        }
        if provider.isSlow {
            return L("正在生成；完成后会自动归入结果列表。")
        }
        return L("正在请求翻译结果。")
    }
}

private struct InterpretationBody: View {
    let interpretation: InterpretationResult
    var onSelectionChange: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            interpretationSection(title: L("自然译法"), systemImage: "character.book.closed") {
                if let onSelectionChange {
                    SelectableResultTextView(
                        text: interpretation.localizedTranslation,
                        lineLimit: nil,
                        onSelectionChange: onSelectionChange
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(interpretation.localizedTranslation)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                        .textSelection(.enabled)
                }
            }

            if shouldShowIntendedMeaning(interpretation) {
                interpretationSection(title: L("这段在说什么"), systemImage: "brain.head.profile") {
                    Text(interpretation.intendedMeaning)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.label2)
                        .textSelection(.enabled)
                }
            }

            if !interpretation.toneTags.isEmpty {
                HStack(spacing: Theme.Spacing.s4) {
                    Text(L("语气"))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label3)
                    ForEach(Array(interpretation.toneTags.prefix(4)), id: \.self) { tag in
                        Text(tag)
                            .font(Theme.Font.tag)
                            .foregroundStyle(Theme.Palette.label2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Palette.bgControl)
                            .clipShape(Capsule())
                    }
                }
            }

            if !interpretation.culturalNotes.isEmpty {
                interpretationSection(title: L("文化与表达"), systemImage: "quote.bubble") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                        ForEach(Array(interpretation.culturalNotes.prefix(4).enumerated()), id: \.offset) { _, note in
                            Text("\(note.phrase)：\(note.explanation)")
                                .font(Theme.Font.callout)
                                .foregroundStyle(Theme.Palette.label2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if !interpretation.ambiguities.isEmpty || interpretation.confidenceNote != nil {
                interpretationSection(title: L("可能存在歧义"), systemImage: "questionmark.bubble") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                        ForEach(Array(interpretation.ambiguities.prefix(3).enumerated()), id: \.offset) { _, alternative in
                            Text("• \(alternative.interpretation) — \(alternative.when)")
                                .font(Theme.Font.callout)
                                .foregroundStyle(Theme.Palette.label2)
                        }
                        if let note = interpretation.confidenceNote,
                           !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(note)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.label3)
                        }
                        Text(L("理解置信度 %d%%", Int((interpretation.confidence * 100).rounded())))
                            .font(Theme.Font.caption.monospacedDigit())
                            .foregroundStyle(Theme.Palette.label3)
                    }
                }
            } else {
                interpretationSection(title: L("理解置信度"), systemImage: "gauge.with.dots.needle.67percent") {
                    Text("\(Int((interpretation.confidence * 100).rounded()))%")
                        .font(Theme.Font.caption.monospacedDigit())
                        .foregroundStyle(Theme.Palette.label3)
                }
            }

            if let literal = usefulLiteralTranslation {
                interpretationSection(title: L("字面参考"), systemImage: "text.quote") {
                    Text(literal)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.label2)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func interpretationSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            Label(title, systemImage: systemImage)
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.label3)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var usefulLiteralTranslation: String? {
        guard let literal = interpretation.literalTranslation?.trimmingCharacters(in: .whitespacesAndNewlines),
              !literal.isEmpty,
              shouldShowLiteralTranslation(
                literal,
                comparedTo: interpretation.localizedTranslation
              ) else {
            return nil
        }
        return literal
    }
}

func shouldShowIntendedMeaning(_ interpretation: InterpretationResult) -> Bool {
    let meaning = normalizedInterpretationText(interpretation.intendedMeaning)
    let translation = normalizedInterpretationText(interpretation.localizedTranslation)
    guard !meaning.isEmpty, meaning != translation else { return false }
    if let meaningAddsValue = interpretation.meaningAddsValue {
        return meaningAddsValue
    }
    // Legacy results did not carry the explicit signal. Only retain the explanation
    // when the model also reported ambiguity; otherwise prefer the copy-ready result.
    return !interpretation.ambiguities.isEmpty
}

private func normalizedInterpretationText(_ value: String) -> String {
    let removable = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
    return String(value.lowercased().unicodeScalars.filter { !removable.contains($0) })
}

func shouldShowLiteralTranslation(_ literal: String, comparedTo localized: String) -> Bool {
    func normalized(_ value: String) -> String {
        let removable = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return String(value.lowercased().unicodeScalars.filter { !removable.contains($0) })
    }
    let normalizedLiteral = normalized(literal)
    return !normalizedLiteral.isEmpty && normalizedLiteral != normalized(localized)
}

private struct TranslationBody: View {
    let result: TranslateResult
    let lineLimit: Int?
    var onSelectionChange: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4 + 2) {
            if let onSelectionChange {
                SelectableResultTextView(
                    text: result.translated,
                    lineLimit: lineLimit,
                    onSelectionChange: onSelectionChange
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .clipped()
            } else {
                Text(result.translated)
                    .font(Theme.Font.result)
                    .lineSpacing(4)
                    .foregroundStyle(Theme.Palette.label)
                    .textSelection(.enabled)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

private struct SelectableResultTextView: NSViewRepresentable {
    let text: String
    let lineLimit: Int?
    let onSelectionChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextView {
        let textView = SizingTextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.font = Self.font
        textView.textColor = .labelColor
        textView.textContainerInset = Self.textContainerInset
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.autoresizingMask = [.width]
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setAccessibilityElement(true)
        textView.setAccessibilityLabel(L("译文，可选择表达加入学习"))
        textView.string = text
        configure(textView)
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        context.coordinator.parent = self
        textView.font = Self.font
        textView.textColor = .labelColor
        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            onSelectionChange("")
        }
        configure(textView)
        textView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        let width = Self.resolvedWidth(proposed: proposal.width, bounds: nsView.bounds.width)
        return CGSize(width: width, height: Self.measuredHeight(for: text, width: width, lineLimit: lineLimit))
    }

    private func configure(_ textView: NSTextView) {
        if let sizingTextView = textView as? SizingTextView {
            sizingTextView.lineLimit = lineLimit
        }
        textView.textContainerInset = Self.textContainerInset
        textView.textContainer?.maximumNumberOfLines = lineLimit ?? 0
        textView.textContainer?.lineBreakMode = lineLimit == nil ? .byWordWrapping : .byTruncatingTail
        textView.textContainer?.containerSize = NSSize(
            width: Self.textContainerWidth(for: Self.resolvedWidth(bounds: textView.bounds.width)),
            height: .greatestFiniteMagnitude
        )
    }

    private static let textContainerInset = NSSize(width: 0, height: 5)
    private static let measurementWidthSafety: CGFloat = 18

    private static var font: NSFont {
        NSFont.systemFont(ofSize: 15)
    }

    private static func resolvedWidth(proposed: CGFloat? = nil, bounds: CGFloat? = nil) -> CGFloat {
        for candidate in [proposed, bounds] {
            if let candidate, candidate.isFinite, candidate > 1 {
                return candidate
            }
        }
        return 448
    }

    private static func textContainerWidth(for width: CGFloat) -> CGFloat {
        max(1, width - textContainerInset.width * 2 - measurementWidthSafety)
    }

    private static func measuredHeight(for text: String, width: CGFloat, lineLimit: Int?) -> CGFloat {
        let textStorage = NSTextStorage(string: text, attributes: [.font: font])
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(containerSize: NSSize(
            width: textContainerWidth(for: width),
            height: .greatestFiniteMagnitude
        ))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = lineLimit ?? 0
        textContainer.lineBreakMode = lineLimit == nil ? .byWordWrapping : .byTruncatingTail

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let tailRoom = lineLimit == nil ? lineHeight : 4
        return max(ceil(usedRect.height), lineHeight) + textContainerInset.height * 2 + tailRoom
    }

    final class SizingTextView: NSTextView {
        var lineLimit: Int? {
            didSet { invalidateIntrinsicContentSize() }
        }

        override var intrinsicContentSize: NSSize {
            let width = SelectableResultTextView.resolvedWidth(bounds: bounds.width)
            let height = SelectableResultTextView.measuredHeight(for: string, width: width, lineLimit: lineLimit)
            return NSSize(width: NSView.noIntrinsicMetric, height: height)
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            textContainer?.containerSize = NSSize(
                width: SelectableResultTextView.textContainerWidth(
                    for: SelectableResultTextView.resolvedWidth(bounds: newSize.width)
                ),
                height: .greatestFiniteMagnitude
            )
            invalidateIntrinsicContentSize()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableResultTextView

        init(_ parent: SelectableResultTextView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            guard range.length > 0,
                  let swiftRange = Range(range, in: textView.string) else {
                parent.onSelectionChange("")
                return
            }
            parent.onSelectionChange(
                String(textView.string[swiftRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}

private struct OCRCandidatesView: View {
    let candidates: [OCRCandidateViewState]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                LearningStatusChip(text: "OCR 候选", tone: Theme.Palette.accent)
                if candidates.contains(where: \.isLowConfidence) {
                    QualityStatusBadge("含低置信块", tone: .warning)
                }
                Spacer(minLength: 0)
                Text(L("%d 个候选", candidates.count))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s8) {
                    ForEach(candidates) { candidate in
                        Button {
                            onSelect(candidate.id)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                                HStack(spacing: Theme.Spacing.s4) {
                                    Image(systemName: candidateIcon(candidate.kind))
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(candidateTitle(candidate.kind))
                                        .font(Theme.Font.tag)
                                    Text("\(Int((candidate.confidence * 100).rounded()))%")
                                        .font(Theme.Font.tag.monospacedDigit())
                                        .foregroundStyle(candidate.isLowConfidence ? Theme.Palette.warning : Theme.Palette.label3)
                                }
                                Text(candidate.text)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Palette.label2)
                                    .lineLimit(2)
                                    .frame(width: 150, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, Theme.Spacing.s8)
                            .padding(.vertical, 7)
                            .frame(width: 174, alignment: .leading)
                            .background(selectedID == candidate.id ? Theme.Palette.bgSelection : Theme.Palette.bgControl.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .strokeBorder(selectedID == candidate.id ? Theme.Palette.accent.opacity(0.65) : Theme.Palette.separator, lineWidth: 0.5)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(L("切换 OCR 候选并重新翻译"))
                    }
                }
                .padding(.bottom, 1)
            }
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func candidateTitle(_ kind: OCRCandidateViewState.Kind) -> String {
        switch kind {
        case .fullText:
            return L("全文")
        case .primaryBody:
            return L("正文")
        case .reply:
            return L("回复句")
        case .block:
            return L("文本块")
        }
    }

    private func candidateIcon(_ kind: OCRCandidateViewState.Kind) -> String {
        switch kind {
        case .fullText:
            return "doc.text"
        case .primaryBody:
            return "text.alignleft"
        case .reply:
            return "bubble.left"
        case .block:
            return "viewfinder"
        }
    }
}

private struct ContextProfileMenu: View {
    let selection: TranslationContextProfile
    let onSelect: (TranslationContextProfile) -> Void

    private let taskProfiles: [TranslationContextProfile] = [
        .quickTranslate, .understand, .document, .nativePolish, .reply
    ]
    private let sceneProfiles: [TranslationContextProfile] = [
        .github, .email, .social
    ]
    private let policyProfiles: [TranslationContextProfile] = [
        .strictTerminology, .privateLocal
    ]

    var body: some View {
        Menu {
            Section(L("处理方式")) {
                profileButtons(taskProfiles)
            }
            Section(L("内容场景")) {
                profileButtons(sceneProfiles)
            }
            Section(L("约束策略")) {
                profileButtons(policyProfiles)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon(for: selection))
                    .font(.system(size: 10, weight: .semibold))
                Text(label(for: selection))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label3)
            }
            .foregroundStyle(Theme.Palette.label2)
            .frame(minHeight: 32)
            .padding(.horizontal, 9)
            .background(Theme.Palette.bgControl)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L("切换上下文模式"))
        .accessibilityLabel(L("上下文模式"))
    }

    @ViewBuilder
    private func profileButtons(_ profiles: [TranslationContextProfile]) -> some View {
        ForEach(profiles, id: \.self) { profile in
            Button {
                onSelect(profile)
            } label: {
                Label(label(for: profile), systemImage: profile == selection ? "checkmark" : icon(for: profile))
            }
        }
    }

    private func label(for profile: TranslationContextProfile) -> String {
        switch profile {
        case .quickTranslate: return L("快译")
        case .understand: return L("理解")
        case .nativePolish: return L("润色")
        case .reply: return L("回复")
        case .strictTerminology: return L("术语严格")
        case .privateLocal: return L("隐私本地")
        case .github: return "GitHub"
        case .social: return L("社媒")
        case .email: return L("邮件")
        case .document: return L("长文")
        }
    }

    private func icon(for profile: TranslationContextProfile) -> String {
        switch profile {
        case .quickTranslate: return "bolt"
        case .understand: return "brain.head.profile"
        case .nativePolish: return "sparkles"
        case .reply: return "arrowshape.turn.up.left"
        case .strictTerminology: return "text.book.closed"
        case .privateLocal: return "lock.shield"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .social: return "bubble.left.and.bubble.right"
        case .email: return "envelope"
        case .document: return "doc.text"
        }
    }
}

private struct BilingualParagraphView: View {
    let sourceHints: [ParagraphHint]
    let translatedText: String
    let providerName: String
    let onCopyParagraph: (String) -> Void
    let onCopyAll: () -> Void
    let onCopyAndReturn: (() -> Void)?

    static func canAlign(sourceHints: [ParagraphHint], translatedText: String) -> Bool {
        sourceHints.count > 1
            && splitTranslatedParagraphs(translatedText).count == sourceHints.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                LearningStatusChip(text: "双语段落", tone: Theme.Palette.accent)
                Text(providerName)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let onCopyAndReturn {
                    Button {
                        onCopyAndReturn()
                    } label: {
                        Label(L("复制并返回"), systemImage: "arrowshape.turn.up.backward")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                IconButton("doc.on.doc", help: "复制全部译文", size: 11) { onCopyAll() }
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top, spacing: Theme.Spacing.s12) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                        HStack(spacing: Theme.Spacing.s4) {
                            Text("#\(index + 1)")
                                .font(Theme.Font.tag.monospacedDigit())
                                .foregroundStyle(Theme.Palette.label3)
                            Text(L("原文"))
                                .font(Theme.Font.tag)
                                .foregroundStyle(Theme.Palette.label3)
                            if row.isProtected {
                                QualityStatusBadge("保留格式", tone: .secondary)
                            }
                        }
                        Text(row.source)
                            .font(Theme.Font.callout)
                            .foregroundStyle(Theme.Palette.label2)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Theme.Palette.separator.opacity(0.65))
                        .frame(width: 0.5)

                    VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                        HStack(spacing: Theme.Spacing.s4) {
                            Text(L("译文"))
                                .font(Theme.Font.tag)
                                .foregroundStyle(Theme.Palette.label3)
                            Spacer(minLength: 0)
                            IconButton("doc.on.doc", help: "复制本段译文", size: 10, isEnabled: !row.translation.isEmpty) {
                                onCopyParagraph(row.translation)
                            }
                        }
                        Text(row.translation)
                            .font(Theme.Font.result)
                            .foregroundStyle(Theme.Palette.label)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Theme.Spacing.s8)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.bgControl.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.accent.opacity(0.32), lineWidth: 0.6))
    }

    private var rows: [BilingualParagraphRow] {
        let translations = Self.splitTranslatedParagraphs(translatedText)
        return sourceHints.enumerated().map { index, hint in
            BilingualParagraphRow(
                id: hint.id,
                source: hint.source,
                translation: index < translations.count ? translations[index] : "",
                isProtected: hint.isProtected
            )
        }
    }

    private static func splitTranslatedParagraphs(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        return normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct BilingualParagraphRow: Identifiable {
    let id: UUID
    let source: String
    let translation: String
    let isProtected: Bool
}

private struct QualityStatusBadge: View {
    enum Tone {
        case accent
        case warning
        case secondary
    }

    let text: String
    let tone: Tone

    init(_ text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(L(text))
            .font(Theme.Font.tag)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private var foreground: Color {
        switch tone {
        case .accent: return Theme.Palette.accent
        case .warning: return Theme.Palette.warning
        case .secondary: return Theme.Palette.label2
        }
    }

    private var background: Color {
        switch tone {
        case .accent: return Theme.Palette.accentSoft
        case .warning: return Theme.Palette.warning.opacity(0.12)
        case .secondary: return Theme.Palette.bgControl
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
    let preservesCase: Bool

    init(_ label: String, tone: Tone, preservesCase: Bool = false) {
        self.label = label
        self.tone = tone
        self.preservesCase = preservesCase
    }

    var body: some View {
        Text(preservesCase ? label : L(label))
            .font(Theme.Font.tag)
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(tone == .danger ? Theme.Palette.danger : Theme.Palette.label2)
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

private struct TerminologyStatusButton: View {
    let application: TerminologyApplication
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            if application.matchCount > 0 {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 3) {
                Text(label)
                if application.matchCount > 0 {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
            }
            .font(Theme.Font.tag)
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .frame(minHeight: 32)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(application.matchCount == 0)
        .help(label)
    }

    private var label: String {
        if !application.restorationSucceeded { return "术语恢复失败" }
        if application.matchCount == 0 { return "术语未命中" }
        switch application.strategy {
        case .placeholder, .promptAndPlaceholder, .nativeGlossary:
            return "术语已应用 · \(application.matchCount)"
        case .prompt:
            return "术语约束 · \(application.matchCount)"
        case .unsupported:
            return "不支持术语"
        }
    }

    private var foreground: Color {
        if !application.restorationSucceeded { return Theme.Palette.danger }
        if application.matchCount == 0 { return Theme.Palette.label3 }
        return Theme.Palette.label2
    }

    private var background: Color {
        if !application.restorationSucceeded { return Theme.Palette.danger.opacity(0.12) }
        if application.matchCount == 0 { return Theme.Palette.bgControl }
        return Theme.Palette.accentSoft
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
    case .auth: return L("鉴权失败，请检查 API Key")
    case .rateLimited: return L("请求过于频繁，请稍后重试")
    case .network: return L("网络错误")
    case .timeout: return L("请求超时")
    case .unsupportedLanguage: return L("不支持的语言")
    case .notConfigured: return L("未配置")
    case .service(let m):
        if m.hasPrefix("系统翻译") { return L(m) }
        return L("服务错误：%@", m)
    case .plugin(let m): return L("插件错误：%@", m)
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
    case .notConfigured: return L("需配置")
    case .auth: return L("鉴权失败")
    case .rateLimited: return L("限流")
    case .timeout: return L("超时")
    case .none: return ""
    default: return L("失败")
    }
}
