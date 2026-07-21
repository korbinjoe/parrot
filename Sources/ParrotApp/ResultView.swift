import SwiftUI
import AppKit
import ParrotCore

/// Floating result content: a language-direction header, source context, then provider
/// slots displayed in the order configured in Settings.
struct ResultView: View {
    private enum Layout {
        static let minWidth: CGFloat = 520
        static let idealWidth: CGFloat = 560
        static let minHeight: CGFloat = 320
        static let minScrollHeight: CGFloat = 260
        static let idealScrollFloor: CGFloat = 520
        static let maxPreferredHeight: CGFloat = 680
        static let toolbarControlHeight: CGFloat = 28
        static let fixedToolbarHeight = toolbarControlHeight + Theme.Spacing.s12 + Theme.Spacing.s8
    }

    @ObservedObject var state: AppState
    @ObservedObject var panelPresentation: FloatingPanelPresentation
    let onTogglePinned: () -> Void
    let onConfigureProvider: (String?) -> Void
    let onVocabulary: () -> Void
    let onContextMemory: () -> Void
    let onReplaceInSourceApp: (String) -> Bool
    let onReturnToSourceApp: () -> Void
    let onWorkspaceNoticeAction: (WorkspaceNotice.Action) -> Void
    let onClose: () -> Void

    @State private var contentHeight: CGFloat = 160
    @State private var feedbackText: String = ""
    @State private var sourceComposerFocused: Bool = false
    @State private var sourceLearningSelection: String = ""
    @State private var showAlternativeResults = false

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
        onClose: @escaping () -> Void = {}
    ) {
        self.state = state
        self.panelPresentation = panelPresentation
        self.onTogglePinned = onTogglePinned
        self.onConfigureProvider = onConfigureProvider
        self.onVocabulary = onVocabulary
        self.onContextMemory = onContextMemory
        self.onReplaceInSourceApp = onReplaceInSourceApp
        self.onReturnToSourceApp = onReturnToSourceApp
        self.onWorkspaceNoticeAction = onWorkspaceNoticeAction
        self.onClose = onClose
    }

    var body: some View {
        workspaceBody
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        .onDisappear {
            sourceComposerFocused = false
            state.setComposerFocused(false)
        }
        .onChange(of: state.manualLearningSelectionRevision) { _ in
            sourceLearningSelection = ""
        }
        .onChange(of: state.sourceText) { _ in
            showAlternativeResults = false
        }
        .onExitCommand {
            onClose()
        }
    }

    private var workspaceBody: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if state.isOffline {
                    WarningBar("无网络连接，翻译可能失败")
                }
                fixedToolbar
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
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
                    .padding(.horizontal, Theme.Spacing.s12)
                    .padding(.bottom, Theme.Spacing.s12)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    })
                }
                .frame(
                    minHeight: Layout.minScrollHeight,
                    idealHeight: preferredScrollHeight,
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
            idealHeight: preferredPanelHeight,
            maxHeight: .infinity
        )
    }

    private var preferredScrollHeight: CGFloat {
        let floor = max(Layout.minScrollHeight, Layout.idealScrollFloor - Layout.fixedToolbarHeight)
        let ceiling = Layout.maxPreferredHeight - Layout.fixedToolbarHeight
        return min(max(contentHeight, floor), ceiling)
    }

    private var preferredPanelHeight: CGFloat {
        min(max(contentHeight + Layout.fixedToolbarHeight, Layout.idealScrollFloor), Layout.maxPreferredHeight)
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
        Text(L("输入、划词或截图后，源文会出现在这里。"))
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
            Text(L("校对文本后选择“润色”或“翻译”。"))
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

    @ViewBuilder
    private var resultsList: some View {
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
            if showsAlignedBilingualResult,
               let outcome = state.primarySuccessfulOutcome,
               let result = outcome.result {
                BilingualParagraphView(
                    sourceHints: state.paragraphHints,
                    translatedText: result.translated,
                    providerName: outcome.displayName,
                    onCopyParagraph: { copy($0) },
                    onCopyAll: { copy(result.translated) },
                    onCopyAndReturn: canReturnToSourceApp ? { copyAndReturn(result.translated) } : nil
                )
            }
            if state.isPolishMode, !state.polishVariants.isEmpty {
                PolishVariantsView(
                    variants: state.polishVariants,
                    selectedTone: state.selectedPolishTone,
                    onSelect: { state.selectPolishTone($0, autoRun: false) },
                    onCopy: { copy($0) },
                    onReplace: { replaceInSourceApp($0) },
                    onSave: { saveCurrentExpression($0) }
                )
                ForEach(visibleOrderedSlots) { slot in
                    providerSlotView(slot)
                }
            } else {
                if !showsAlignedBilingualResult,
                   let primaryOutcome = state.primarySuccessfulOutcome {
                    providerSlotView(.outcome(primaryOutcome), isPrimary: true)
                }
                ForEach(recoverySlots) { slot in
                    providerSlotView(slot)
                }
                if !successfulAlternativeSlots.isEmpty {
                    alternativeResults
                }
            }
        }
    }

    @ViewBuilder
    private func providerSlotView(_ slot: TranslationSlot, isPrimary: Bool = false) -> some View {
        switch slot {
        case .outcome(let outcome):
            TranslationOutcomeCard(outcome: outcome,
                                   isPrimary: isPrimary,
                                   isSlow: state.slowProviderIDs.contains(outcome.providerId),
                                   settings: state.settings,
                                   sourceText: state.sourceText,
                                   learningEnabled: state.settings.learningRecognitionEnabled,
                                   microPracticeEnabled: state.settings.learningMicroPracticeEnabled,
                                   occurrenceCounts: state.learningOccurrenceCounts,
                                   sourceSelection: sourceLearningSelection,
                                   onSpeak: { state.speakTranslation($0) },
                                   onCopy: { copy($0) },
                                   onLookupSelection: { selection, contextText, usesTranslation in
                                       await state.lookupLearningSelection(
                                           selection,
                                           contextText: contextText,
                                           providerID: outcome.providerId,
                                           usesTranslation: usesTranslation
                                       )
                                   },
                                   onSaveExpression: { saveCurrentExpression($0) },
                                   onCopyAndReturn: isPrimary && canReturnToSourceApp ? { copyAndReturn($0) } : nil,
                                   onReplaceInSourceApp: state.isPolishMode ? { replaceInSourceApp($0) } : nil,
                                   onRetry: { state.retryProvider(outcome.providerId) },
                                   onConfigure: { onConfigureProvider(outcome.providerId) })
                .id("\(outcome.providerId)-\(state.manualLearningSelectionRevision)")
        case .pending(let provider):
            PendingOutcomeCard(provider: provider)
        }
    }

    // MARK: - Header (language direction + global actions)

    private var fixedToolbar: some View {
        header
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.top, Theme.Spacing.s12)
            .padding(.bottom, Theme.Spacing.s8)
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.bgPanel)
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
            ContextProfileMenu(selection: state.contextProfile) { profile in
                state.setContextProfile(profile)
            }
            toolbarStatus
            Spacer(minLength: 0)
            HStack(spacing: Theme.Spacing.s4) {
                IconButton(
                    state.isFavorite ? "star.fill" : "star",
                    help: state.savedRecordId == nil ? "翻译完成后可收藏" : (state.isFavorite ? "取消收藏" : "收藏"),
                    foreground: state.isFavorite ? Theme.Palette.star : nil,
                    activeBackground: state.isFavorite,
                    isEnabled: state.savedRecordId != nil
                ) {
                    state.toggleFavorite()
                    showFeedback(state.isFavorite ? "已收藏" : "已取消收藏")
                }

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
                    .disabled(state.actionSourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { state.speakSource() } label: {
                        Label(L("朗读原文"), systemImage: "speaker.wave.2")
                    }
                    .disabled(state.actionSourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Divider()
                    Button { onVocabulary() } label: {
                        Label(L("个人词库"), systemImage: "text.book.closed")
                    }
                    Button { onContextMemory() } label: {
                        Label(L("规则记忆"), systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Palette.label2)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(L("更多操作"))
                .accessibilityLabel(L("更多操作"))
                IconButton("gearshape", help: "打开设置") { onConfigureProvider(nil) }
                IconButton("xmark", help: "关闭") { onClose() }
            }
        }
        .frame(height: Layout.toolbarControlHeight)
    }

    @ViewBuilder
    private var toolbarStatus: some View {
        if state.isTranslating {
            LearningStatusChip(text: state.isPolishMode ? "润色中" : "翻译中", tone: Theme.Palette.accent)
        } else if state.isSourceDirty {
            LearningStatusChip(text: "已修改", tone: Theme.Palette.warning)
        } else if state.settings.learningRecognitionEnabled {
            LearningStatusChip(text: "选词学习", tone: Theme.Palette.success)
        }
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
                    Text(state.isPolishMode
                        ? L("输入或粘贴要润色的草稿…")
                        : L("输入或粘贴要翻译的文本…"))
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
                    },
                    onSelectionChange: { selection in
                        sourceLearningSelection = selection
                    }
                )
                    .frame(height: sourceEditorHeight)
                    .accessibilityLabel(L("源文编辑器"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(sourceStatusText)
                Spacer(minLength: 0)
                if state.isTranslating {
                    ProgressView().controlSize(.small)
                } else if state.isSourceDirty {
                    Text(L("已修改，可重新润色或翻译"))
                } else {
                    Text(L("%d 个字符", state.sourceDraft.count))
                }
                Menu {
                    Button(L("删除空行")) { state.removeBlankDraftLines() }
                    Button(L("合并为一段")) { state.mergeDraftLines() }
                    Divider()
                    Button(L("清空源文"), role: .destructive) { state.clearDraft() }
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundStyle(state.canTranslateDraft ? Theme.Palette.label2 : Theme.Palette.label3)
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(!state.canTranslateDraft)
                .help(state.isPolishMode ? L("整理草稿") : L("整理源文"))
                .accessibilityLabel(state.isPolishMode ? L("整理草稿") : L("整理源文"))
                if state.isPolishMode {
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
                    .buttonStyle(PrimaryActionButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!state.canTranslateDraft)
                } else {
                    Button {
                        state.translateDraft(mode: .polish)
                    } label: {
                        Label(L("润色"), systemImage: "sparkles")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!state.canTranslateDraft)
                    .help(L("润色当前草稿"))
                    .accessibilityLabel(L("润色当前草稿"))
                    Button {
                        state.translateDraft(mode: .translate)
                    } label: {
                        Label(L("翻译"), systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!state.canTranslateDraft)
                }
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
            return state.isPolishMode ? L("编辑草稿") : L("编辑源文")
        }
        if state.isPolishMode, state.didCaptureFocusedInputDraft {
            return L("来自当前输入框")
        }
        return sourceLanguageText
    }

    private var sourceLanguageText: String {
        if state.isPolishMode {
            let language = state.targetLanguage == .auto ? state.detectedSource : state.targetLanguage
            return L("润色 %@", LangPill.label(language, auto: "原文"))
        }
        if state.sourceLanguage == .auto {
            if state.detectedSource == .auto { return L("自动检测") }
            return L("自动检测 %@", LangPill.label(state.detectedSource, auto: ""))
        }
        return L("来源 %@", LangPill.label(state.sourceLanguage, auto: ""))
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

    @ViewBuilder
    private func qualityBadges(for result: TranslateResult) -> some View {
        if result.qualitySummary?.isRecommended == true {
            QualityStatusBadge("推荐", tone: .accent)
        }
        if result.qualitySummary?.needsReview == true {
            QualityStatusBadge("需复核", tone: .warning)
        }
        if let report = result.privacyMaskingReport, report.applied {
            QualityStatusBadge("隐私遮罩 \(report.totalCount)", tone: .secondary)
        }
    }

    private func profileLabel(_ profile: TranslationContextProfile) -> String {
        switch profile {
        case .quickTranslate: return L("快译")
        case .understand: return L("理解")
        case .nativePolish: return L("润色")
        case .reply: return L("回复")
        case .strictTerminology: return L("术语")
        case .privateLocal: return L("隐私")
        case .github: return "GitHub"
        case .social: return L("社媒")
        case .email: return L("邮件")
        case .document: return L("长文")
        }
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

    private var showsAlignedBilingualResult: Bool {
        guard state.canShowParagraphBilingualView,
              let translated = state.primarySuccessfulOutcome?.result?.translated else { return false }
        return BilingualParagraphView.canAlign(
            sourceHints: state.paragraphHints,
            translatedText: translated
        )
    }

    private var recoverySlots: [TranslationSlot] {
        visibleOrderedSlots.filter { slot in
            switch slot {
            case .outcome(let outcome): return outcome.result == nil
            case .pending: return true
            }
        }
    }

    private var successfulAlternativeSlots: [TranslationSlot] {
        let primaryID = state.primarySuccessfulOutcome?.providerId
        return visibleOrderedSlots.filter { slot in
            guard case .outcome(let outcome) = slot else { return false }
            return outcome.result != nil && outcome.providerId != primaryID
        }
    }

    private var alternativeResults: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    showAlternativeResults.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.s8) {
                    Image(systemName: "square.stack.3d.up")
                    Text(L("对比其他引擎 (%d)", successfulAlternativeSlots.count))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showAlternativeResults ? 90 : 0))
                }
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
                .padding(.horizontal, Theme.Spacing.s12)
                .frame(height: 38)
                .background(Theme.Palette.bgControl.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
            .buttonStyle(.plain)
            .accessibilityValue(showAlternativeResults ? L("已展开") : L("已折叠"))

            if showAlternativeResults {
                ForEach(successfulAlternativeSlots) { slot in
                    providerSlotView(slot)
                }
            }
        }
    }

    private var orderedSlots: [TranslationSlot] {
        var outcomesByID: [String: AggregatedOutcome] = [:]
        for outcome in state.outcomes { outcomesByID[outcome.providerId] = outcome }
        var pendingByID: [String: PendingProviderViewState] = [:]
        for provider in state.pendingProviders { pendingByID[provider.id] = provider }
        let observedIDs = state.outcomes.map(\.providerId) + state.pendingProviders.map(\.id)
        let configuredIDs = state.providerDisplayOrder
        let orderedIDs = configuredIDs + observedIDs.filter { !configuredIDs.contains($0) }

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

    private var visibleOrderedSlots: [TranslationSlot] {
        guard state.isPolishMode, !state.polishVariants.isEmpty else { return orderedSlots }
        return orderedSlots.filter { slot in
            switch slot {
            case .outcome(let outcome):
                return outcome.result == nil
            case .pending:
                return true
            }
        }
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
            Text(L(notice.title))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label2)
                .lineLimit(1)
            Text(L(notice.detail))
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
            .help(L("隐藏提示"))
            .accessibilityLabel(L("隐藏提示"))
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
                                .controlSize(.small)
                        }
                        if let secondary = notice.secondaryAction {
                            Button(L(secondary.title)) { onAction(secondary.action) }
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
            .help(L("隐藏提示"))
            .accessibilityLabel(L("隐藏提示"))
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
            .help(L(sourceCode == "auto" ? "自动检测来源语言时不可互换" : "互换来源与目标语言"))
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
                Button(L(name)) { action(code) }
            }
        } label: {
            Text(L(title))
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
        textView.setAccessibilityLabel(L("源文编辑器"))

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
    private enum ManualLearningState {
        case resolved(LearningExpression)
        case pending(LearningExpression)
    }

    private struct ManualSelectionContext: Equatable {
        let key: String
        let selection: String
        let contextText: String
        let usesTranslation: Bool
    }

    let outcome: AggregatedOutcome
    let isPrimary: Bool
    let isSlow: Bool
    @ObservedObject var settings: AppSettings
    let sourceText: String
    let learningEnabled: Bool
    let microPracticeEnabled: Bool
    let occurrenceCounts: [String: Int]
    let sourceSelection: String
    let onSpeak: (String) -> Void
    let onCopy: (String) -> Void
    let onLookupSelection: (String, String, Bool) async -> TranslateResult?
    let onSaveExpression: (String) -> Void
    let onCopyAndReturn: ((String) -> Void)?
    let onReplaceInSourceApp: ((String) -> Void)?
    let onRetry: () -> Void
    let onConfigure: () -> Void
    @State private var showTerminologyDetails = false
    @State private var translatedSelection: String = ""
    @State private var manualLookupResults: [String: TranslateResult] = [:]
    @State private var manualLookupFailures: Set<String> = []
    @State private var manualLookupInFlight: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            head
            content
            terminologyDetails
            if let result = outcome.result {
                HStack(spacing: Theme.Spacing.s4) {
                    if let onCopyAndReturn {
                        Button {
                            onCopyAndReturn(result.translated)
                        } label: {
                            Label(L("复制并返回"), systemImage: "arrowshape.turn.up.backward")
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                    Spacer(minLength: 0)
                    IconButton("bookmark", help: "存为表达", size: 11) { onSaveExpression(result.translated) }
                    if let onReplaceInSourceApp {
                        IconButton("arrowshape.turn.up.left", help: "替换到原 App", size: 11) { onReplaceInSourceApp(result.translated) }
                    }
                    IconButton("arrow.clockwise", help: "重试此引擎", size: 11) { onRetry() }
                    IconButton("doc.on.doc", help: "复制译文", size: 11) { onCopy(result.translated) }
                    IconButton("speaker.wave.2", help: "朗读译文", size: 11) { onSpeak(result.translated) }
                }
                .frame(maxWidth: .infinity, minHeight: 26, alignment: .trailing)
                .padding(.top, Theme.Spacing.s4)
            }
        }
        .padding(.horizontal, Theme.Spacing.s12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(cardStroke, lineWidth: cardStrokeWidth)
        )
    }

    private var head: some View {
        HStack(spacing: Theme.Spacing.s8) {
            EngineTag(outcome.displayName, tone: outcome.error == nil ? .accent : .danger)
            if let modelName = outcome.modelName, !modelName.isEmpty {
                EngineTag(modelName, tone: .secondary, preservesCase: true)
            }
            if let application = outcome.result?.terminologyApplication {
                TerminologyStatusButton(
                    application: application,
                    isExpanded: $showTerminologyDetails
                )
            }
            if isPrimary {
                QualityStatusBadge("推荐结果", tone: .accent)
            } else if outcome.result?.qualitySummary?.isRecommended == true {
                QualityStatusBadge("推荐", tone: .accent)
            }
            if outcome.result?.qualitySummary?.needsReview == true {
                QualityStatusBadge("需复核", tone: .warning)
            }
            if let report = outcome.result?.privacyMaskingReport, report.applied {
                QualityStatusBadge("隐私遮罩 \(report.totalCount)", tone: .secondary)
            }
            if isSlow {
                Text(L("较慢生成"))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
            }
            Spacer(minLength: 0)
            Text(outcome.error == nil ? "\(outcome.latencyMs)ms" : providerStatusText(outcome.error))
                .font(Theme.Font.caption.monospacedDigit())
                .foregroundStyle(outcome.error == nil ? Theme.Palette.label3 : Theme.Palette.danger)
        }
    }

    private var cardStroke: Color {
        if outcome.error != nil { return Theme.Palette.danger.opacity(0.6) }
        if isPrimary || outcome.result?.qualitySummary?.isRecommended == true { return Theme.Palette.accent.opacity(0.65) }
        if outcome.result?.qualitySummary?.needsReview == true { return Theme.Palette.warning.opacity(0.65) }
        return Theme.Palette.hairline
    }

    private var cardStrokeWidth: CGFloat {
        isPrimary || outcome.result?.qualitySummary?.isRecommended == true || outcome.result?.qualitySummary?.needsReview == true ? 0.8 : 0.5
    }

    @ViewBuilder
    private var content: some View {
        if let result = outcome.result {
            learningBody(for: result)
        } else if let error = outcome.error {
            VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
                Text(providerErrorText(error))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                if providerNeedsConfiguration(error) {
                    Button { onConfigure() } label: {
                        Label(L("配置密钥"), systemImage: "gearshape")
                    }
                    .controlSize(.small)
                } else {
                    Button { onRetry() } label: {
                        Label(L("重试此引擎"), systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func learningBody(for result: TranslateResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            TranslationBody(result: result, lineLimit: nil) { selection in
                translatedSelection = selection
            }
            translationDetails(for: result)

            if learningEnabled, let selectionState = manualLearningState(for: result) {
                switch selectionState {
                case .resolved(let selected):
                    manualLearningPanel(expression: selected, origin: manualSelectionOrigin)
                case .pending(let selected):
                    manualLearningPanel(expression: selected, origin: manualSelectionOrigin, isPending: true)
                }
            }
        }
        .task(id: manualLookupTaskID(for: result)) {
            await runManualLookupIfNeeded(for: result)
        }
    }

    @ViewBuilder
    private func manualLearningPanel(
        expression selected: LearningExpression,
        origin: String,
        isPending: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack {
                LearningStatusChip(text: origin)
                Text(L("已选中“%@”", selected.term))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            LearningContextCard(
                expression: selected,
                saved: savedLearningIDs.contains(selected.id),
                mastered: masteredLearningIDs.contains(selected.id),
                actionsEnabled: !isPending,
                onKnown: { settings.markLearningMastered(selected) },
                onSave: { settings.markLearningSaved(selected) }
            )
            if microPracticeEnabled && !isPending {
                LearningMicroPracticeView(expression: selected) {
                    settings.recordLearningReview(selected, correct: true)
                } onWrong: {
                    settings.recordLearningReview(selected, correct: false)
                }
                .id(selected.id)
            }
        }
        .padding(10)
        .background(Theme.Palette.bgControl.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
    }

    private var manualSelectionText: String {
        let translated = translatedSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !translated.isEmpty { return translated }
        return sourceSelection.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var manualSelectionUsesTranslation: Bool {
        !translatedSelection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var manualSelectionOrigin: String {
        manualSelectionUsesTranslation ? "译文选词" : "原文选词"
    }

    private func manualLearningState(for result: TranslateResult) -> ManualLearningState? {
        guard let selectionContext = manualSelectionContext(for: result) else { return nil }
        if let directExpression = manualLearningExpression(
            for: result,
            selectionContext: selectionContext,
            lookupResult: nil,
            allowGenericFallback: false
        ) {
            return .resolved(directExpression)
        }
        if let lookupResult = manualLookupResults[selectionContext.key],
           let lookupExpression = manualLearningExpression(
                for: result,
                selectionContext: selectionContext,
                lookupResult: lookupResult,
                allowGenericFallback: true
           ) {
            return .resolved(lookupExpression)
        }
        if manualLookupFailures.contains(selectionContext.key),
           let fallbackExpression = manualLearningExpression(
                for: result,
                selectionContext: selectionContext,
                lookupResult: nil,
                allowGenericFallback: true
           ) {
            return .resolved(fallbackExpression)
        }
        guard let pendingExpression = LearningRecommendationEngine.pendingManualSelectionExpression(
            selectionContext.selection,
            contextText: selectionContext.contextText,
            sourceText: sourceText,
            occurrenceCounts: occurrenceCounts
        ) else { return nil }
        return .pending(pendingExpression)
    }

    private func manualLearningExpression(
        for result: TranslateResult,
        selectionContext: ManualSelectionContext,
        lookupResult: TranslateResult?,
        allowGenericFallback: Bool
    ) -> LearningExpression? {
        LearningRecommendationEngine.expressionForManualSelection(
            selectionContext.selection,
            contextText: selectionContext.contextText,
            sourceText: sourceText,
            occurrenceCounts: occurrenceCounts,
            definitions: selectionContext.usesTranslation
                ? lookupResult?.definitions
                : (lookupResult?.definitions ?? result.definitions),
            phonetics: selectionContext.usesTranslation
                ? lookupResult?.phonetics
                : (lookupResult?.phonetics ?? result.phonetics),
            lookupText: lookupResult?.translated,
            allowGenericFallback: allowGenericFallback
        )
    }

    private func manualSelectionContext(for result: TranslateResult) -> ManualSelectionContext? {
        let selection = manualSelectionText
        guard !selection.isEmpty else { return nil }
        let usesTranslation = manualSelectionUsesTranslation
        let contextText = usesTranslation ? result.translated : sourceText
        return ManualSelectionContext(
            key: manualLookupKey(selection: selection, contextText: contextText, usesTranslation: usesTranslation),
            selection: selection,
            contextText: contextText,
            usesTranslation: usesTranslation
        )
    }

    private func manualLookupTaskID(for result: TranslateResult) -> String? {
        manualLookupRequest(for: result)?.key
    }

    private func manualLookupRequest(for result: TranslateResult) -> ManualSelectionContext? {
        guard learningEnabled,
              let selectionContext = manualSelectionContext(for: result),
              manualLookupResults[selectionContext.key] == nil,
              !manualLookupFailures.contains(selectionContext.key),
              manualLearningExpression(
                for: result,
                selectionContext: selectionContext,
                lookupResult: nil,
                allowGenericFallback: false
              ) == nil else { return nil }
        return selectionContext
    }

    @MainActor
    private func runManualLookupIfNeeded(for result: TranslateResult) async {
        guard let request = manualLookupRequest(for: result),
              !manualLookupInFlight.contains(request.key) else { return }
        manualLookupInFlight.insert(request.key)
        let lookupResult = await onLookupSelection(request.selection, request.contextText, request.usesTranslation)
        manualLookupInFlight.remove(request.key)
        if let lookupResult,
           manualLearningExpression(
                for: result,
                selectionContext: request,
                lookupResult: lookupResult,
                allowGenericFallback: false
           ) != nil {
            manualLookupResults[request.key] = lookupResult
        } else {
            manualLookupFailures.insert(request.key)
        }
    }

    private func manualLookupKey(selection: String, contextText: String, usesTranslation: Bool) -> String {
        [
            outcome.providerId,
            usesTranslation ? "translated" : "source",
            LearningRecommendationEngine.key(for: selection),
            LearningRecommendationEngine.key(for: contextText)
        ].joined(separator: "|")
    }

    @ViewBuilder
    private func translationDetails(for result: TranslateResult) -> some View {
        if let phonetics = result.phonetics, !phonetics.isEmpty {
            Text(phonetics.map { "\($0.type) \($0.value)" }.joined(separator: "  "))
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
        }
        if let defs = result.definitions {
            ForEach(Array(defs.enumerated()), id: \.offset) { _, definition in
                VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                    Text("\(definition.partOfSpeech) \(definition.meanings.joined(separator: "；"))")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.label2)
                    ForEach(definition.examples.prefix(2), id: \.self) { example in
                        Text(example)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.label3)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var savedLearningIDs: Set<String> {
        Set(settings.learningSavedExpressionIDs)
    }

    private var masteredLearningIDs: Set<String> {
        Set(settings.learningMasteredExpressionIDs)
    }

    @ViewBuilder
    private var terminologyDetails: some View {
        if showTerminologyDetails,
           let matches = outcome.result?.terminologyApplication?.matches,
           !matches.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(matches) { match in
                    Text("\(match.source) -> \(match.target)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.label2)
                }
            }
            .padding(.horizontal, Theme.Spacing.s8)
            .padding(.vertical, Theme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        }
    }
}

private struct PendingOutcomeCard: View {
    let provider: PendingProviderViewState

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                EngineTag(provider.displayName, tone: .secondary)
                if let modelName = provider.modelName, !modelName.isEmpty {
                    EngineTag(modelName, tone: .secondary, preservesCase: true)
                }
                Spacer(minLength: 0)
                Text(L(provider.softTimedOut ? "仍在生成" : (provider.isSlow ? "生成中" : "请求中")))
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
            return L("仍在生成；其他已返回结果会按设置顺序保持在原位。")
        }
        if provider.isSlow {
            return L("正在生成；不会改变结果列表顺序。")
        }
        return L("正在请求翻译结果。")
    }
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
            .frame(height: 24)
            .padding(.horizontal, 9)
            .background(Theme.Palette.bgControl)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.Palette.separator, lineWidth: 0.5))
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
        Text(preservesCase ? label : L(label).uppercased())
            .font(Theme.Font.tag)
            .lineLimit(1)
            .truncationMode(.middle)
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
            .frame(height: 20)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
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
