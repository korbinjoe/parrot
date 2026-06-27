import AppKit
import SwiftUI
import ParrotCore

@MainActor
final class LearningReviewWindow {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        state.refreshLearningHistory()
        if window == nil {
            let hosting = NSHostingController(rootView: LearningReviewView(state: state))
            let win = NSWindow(contentViewController: hosting)
            configureTitle(for: win)
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 820, height: 520))
            win.contentMinSize = NSSize(width: 700, height: 440)
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            WindowPlacement.center(window)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshTitle() {
        if let window {
            configureTitle(for: window)
        }
    }

    private func configureTitle(for window: NSWindow) {
        let title = L("今日复习")
        window.title = title
        window.setAccessibilityTitle(title)
    }
}

@MainActor
final class VocabularyWindow {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        state.refreshLearningHistory()
        if window == nil {
            let hosting = NSHostingController(rootView: VocabularyView(state: state))
            let win = NSWindow(contentViewController: hosting)
            configureTitle(for: win)
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 900, height: 540))
            win.contentMinSize = NSSize(width: 760, height: 460)
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            WindowPlacement.center(window)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshTitle() {
        if let window {
            configureTitle(for: window)
        }
    }

    private func configureTitle(for window: NSWindow) {
        let title = L("个人词库")
        window.title = title
        window.setAccessibilityTitle(title)
    }
}

private struct LearningReviewView: View {
    @ObservedObject var state: AppState
    @ObservedObject var settings: AppSettings

    @State private var selectedID: String?
    @State private var selectedAnswer: String?
    @State private var feedbackText: String = ""

    init(state: AppState) {
        self.state = state
        self.settings = state.settings
    }

    private var cards: [LearningReviewCard] {
        LearningRecommendationEngine.reviewCards(from: state.learningVocabularyItems, limit: reviewLimit)
    }

    private var reviewLimit: Int {
        switch state.settings.learningReviewIntensity {
        case "standard": return 18
        case "intense": return 30
        default: return 12
        }
    }

    private var reviewDurationText: String {
        switch state.settings.learningReviewIntensity {
        case "standard": return "5 分钟队列"
        case "intense": return "10 分钟队列"
        default: return "3 分钟队列"
        }
    }

    private var selectedCard: LearningReviewCard? {
        if let selectedID,
           let card = cards.first(where: { $0.id == selectedID }) {
            return card
        }
        return cards.first
    }

    var body: some View {
        HStack(spacing: 0) {
            queueColumn
            Divider()
            reviewDetail
        }
        .frame(minWidth: 700, minHeight: 440)
        .onAppear {
            state.refreshLearningHistory()
            selectedID = selectedCard?.id
        }
        .onChange(of: cards.map(\.id)) { _ in
            if selectedID == nil || !cards.contains(where: { $0.id == selectedID }) {
                selectedID = cards.first?.id
                selectedAnswer = nil
                feedbackText = ""
            }
        }
    }

    private var queueColumn: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L(reviewDurationText))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
                Text(L("%d 个来自历史翻译，高频表达优先。", cards.count))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label2)
            }
            .padding(Theme.Spacing.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            if cards.isEmpty {
                emptyQueue
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            Button {
                                selectedID = card.id
                                selectedAnswer = nil
                                feedbackText = ""
                            } label: {
                                HStack(spacing: Theme.Spacing.s8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.expression.term)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Palette.label)
                                            .lineLimit(1)
                                        Text("\(card.mode) · \(card.expression.displayCount)")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Palette.label3)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Text("\(index + 1)")
                                        .font(Theme.Font.caption.monospacedDigit())
                                        .foregroundStyle(Theme.Palette.label2)
                                        .frame(minWidth: 24, minHeight: 20)
                                        .background(Theme.Palette.bgControl)
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .frame(minHeight: 52)
                                .background(selectedCard?.id == card.id ? Theme.Palette.bgSelection : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.s8)
                }
            }
        }
        .frame(width: 250)
        .background(Theme.Palette.bgSidebar)
    }

    private var emptyQueue: some View {
        VStack(spacing: Theme.Spacing.s8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 30))
                .foregroundStyle(Theme.Palette.label3)
            Text(L("暂无可复习表达"))
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
            Text(L("完成几次英译或译英后，高频表达会出现在这里。"))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var reviewDetail: some View {
        if let card = selectedCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
                    HStack(spacing: Theme.Spacing.s8) {
                        LearningWindowTag(card.mode)
                        Text(card.origin)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.label3)
                        Spacer()
                        FrequencyBadge(count: card.expression.occurrenceCount)
                    }
                    Text(card.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(card.prompt)
                        .font(Theme.Font.result)
                        .foregroundStyle(Theme.Palette.label2)
                    VStack(spacing: Theme.Spacing.s8) {
                        ForEach(card.options, id: \.self) { option in
                            Button {
                                selectedAnswer = option
                                let correct = isCorrect(option, card: card)
                                settings.recordLearningReview(card.expression, correct: correct)
                                feedbackText = correct
                                    ? L("回答正确。该表达进入下一掌握阶段。")
                                    : L("答案是 %@。该表达会保留在今日队列。", card.correctAnswer)
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(Theme.Font.body)
                                    Spacer()
                                    if selectedAnswer != nil, isCorrect(option, card: card) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.s12)
                                .frame(minHeight: 38)
                                .foregroundStyle(optionForeground(option, card: card))
                                .background(optionBackground(option, card: card))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(optionBorder(option, card: card), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
                .background(Theme.Palette.bgContent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.group))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.group).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))

                if !feedbackText.isEmpty {
                    Text(feedbackText)
                        .font(Theme.Font.callout)
                        .foregroundStyle(selectedAnswer.map { isCorrect($0, card: card) } == true ? Theme.Palette.success : Theme.Palette.warning)
                        .padding(.horizontal, Theme.Spacing.s12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((selectedAnswer.map { isCorrect($0, card: card) } == true ? Theme.Palette.success : Theme.Palette.warning).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }

                HStack {
                    Spacer()
                    Button(L("稍后再练")) {
                        feedbackText = L("已保留在今日队列，稍后会再次出现。")
                    }
                    .buttonStyle(.borderless)
                    .font(Theme.Font.callout)
                    Button {
                        moveToNextCard()
                    } label: {
                        Label(L("下一张"), systemImage: "arrow.right")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.Palette.bgCanvas)
        } else {
            emptyReviewDetail
        }
    }

    private var emptyReviewDetail: some View {
        VStack(spacing: Theme.Spacing.s8) {
            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.system(size: 34))
                .foregroundStyle(Theme.Palette.label3)
            Text(L("没有复习卡片"))
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.bgCanvas)
    }

    private func isCorrect(_ option: String, card: LearningReviewCard) -> Bool {
        LearningRecommendationEngine.key(for: option) == LearningRecommendationEngine.key(for: card.correctAnswer)
    }

    private func optionForeground(_ option: String, card: LearningReviewCard) -> Color {
        guard let selectedAnswer else { return Theme.Palette.label }
        if isCorrect(option, card: card) { return Theme.Palette.success }
        if selectedAnswer == option { return Theme.Palette.danger }
        return Theme.Palette.label2
    }

    private func optionBackground(_ option: String, card: LearningReviewCard) -> Color {
        guard let selectedAnswer else { return Theme.Palette.bgControl }
        if isCorrect(option, card: card) { return Theme.Palette.success.opacity(0.14) }
        if selectedAnswer == option { return Theme.Palette.danger.opacity(0.12) }
        return Theme.Palette.bgControl
    }

    private func optionBorder(_ option: String, card: LearningReviewCard) -> Color {
        guard let selectedAnswer else { return Theme.Palette.separator }
        if isCorrect(option, card: card) { return Theme.Palette.success.opacity(0.45) }
        if selectedAnswer == option { return Theme.Palette.danger.opacity(0.45) }
        return Theme.Palette.separator
    }

    private func moveToNextCard() {
        guard let current = selectedCard,
              let index = cards.firstIndex(where: { $0.id == current.id }) else { return }
        let next = cards[(index + 1) % cards.count]
        selectedID = next.id
        selectedAnswer = nil
        feedbackText = ""
    }
}

private struct VocabularyView: View {
    @ObservedObject var state: AppState
    @ObservedObject var settings: AppSettings

    enum Scope: String, CaseIterable, Identifiable {
        case all, saved, due, mastered, favorites
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "全部"
            case .saved: return "已加入"
            case .due: return "待复习"
            case .mastered: return "已掌握"
            case .favorites: return "收藏"
            }
        }
    }

    @State private var query = ""
    @State private var scope: Scope = .all
    @State private var selectedID: String?
    @State private var showAddSheet = false
    @State private var newTerm = ""
    @State private var newMeaning = ""
    @State private var newSourceSentence = ""

    init(state: AppState) {
        self.state = state
        self.settings = state.settings
    }

    private var items: [LearningVocabularyItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return state.learningVocabularyItems.filter { item in
            if scope == .saved && !item.isSaved { return false }
            if scope == .due && !item.isDue { return false }
            if scope == .mastered && item.expression.masteryStage < 4 { return false }
            if scope == .favorites && !item.isFavorite { return false }
            guard !q.isEmpty else { return true }
            return item.expression.term.lowercased().contains(q)
                || item.expression.meaning.lowercased().contains(q)
                || item.sceneLabel.lowercased().contains(q)
                || item.expression.sourceSentence.lowercased().contains(q)
        }
    }

    private var selectedItem: LearningVocabularyItem? {
        if let selectedID,
           let item = items.first(where: { $0.id == selectedID }) {
            return item
        }
        return items.first
    }

    var body: some View {
        HStack(spacing: 0) {
            listColumn
            Divider()
            detailColumn
        }
        .frame(minWidth: 760, minHeight: 460)
        .onAppear {
            state.refreshLearningHistory()
            selectedID = selectedItem?.id
        }
        .onChange(of: items.map(\.id)) { _ in
            if selectedID == nil || !items.contains(where: { $0.id == selectedID }) {
                selectedID = items.first?.id
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addVocabularySheet
        }
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.label3)
                    TextField(L("搜索表达或来源句"), text: $query)
                        .textFieldStyle(.plain)
                        .font(Theme.Font.body)
                }
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(Theme.Palette.bgControl)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                IconButton("plus", help: "添加表达", size: 12) {
                    showAddSheet = true
                }
            }
            .padding(10)

            Picker("", selection: $scope) {
                ForEach(Scope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            if items.isEmpty {
                emptyVocabularyList
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { item in
                            Button {
                                selectedID = item.id
                            } label: {
                                VocabularyRow(item: item, selected: selectedItem?.id == item.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.s8)
                    .padding(.bottom, Theme.Spacing.s8)
                }
            }
        }
        .frame(width: 300)
        .background(Theme.Palette.bgSidebar)
    }

    private var emptyVocabularyList: some View {
        VStack(spacing: Theme.Spacing.s8) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 30))
                .foregroundStyle(Theme.Palette.label3)
            Text(L("暂无词库记录"))
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
            Text(L("加入或手动添加表达后会出现在这里。"))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
        }
        .padding(Theme.Spacing.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let item = selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
                    metrics
                    vocabularyDetail(item)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.Palette.bgCanvas)
        } else {
            VStack(spacing: Theme.Spacing.s8) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.Palette.label3)
                Text(L("选择左侧表达查看详情"))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.label2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.bgCanvas)
        }
    }

    private var metrics: some View {
        let allItems = state.learningVocabularyItems
        let entries = settings.learningVocabularyEntries
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekNewCount = entries.filter { $0.savedAt >= weekStart }.count
        let dueCount = allItems.filter(\.isDue).count
        let masteredCount = allItems.filter { $0.expression.masteryStage >= 4 }.count
        let repeatedCount = entries.filter { $0.wrongCount >= 2 }.count
        let searchReduction = min(36, max(0, masteredCount * 3 + allItems.count / 8))
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
            metricTile("\(allItems.count)", "已沉淀表达")
            metricTile("\(weekNewCount)", "本周新增")
            metricTile("\(masteredCount)", "已掌握")
            metricTile("\(dueCount)", "今日待复习")
            metricTile("\(repeatedCount)", "反复遗忘")
            metricTile("\(searchReduction)%", "预计少查词")
        }
    }

    private func metricTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.label)
            Text(L(label))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label2)
        }
        .padding(Theme.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func vocabularyDetail(_ item: LearningVocabularyItem) -> some View {
        let expression = item.expression
        let sourceLabel = item.isSaved ? L("个人词库") : L("历史推荐")
        return VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            HStack(alignment: .top, spacing: Theme.Spacing.s12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(expression.term)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                    Text("\(L(expression.kind)) · \(expression.displayCount) · \(L(item.sceneLabel)) · \(sourceLabel)")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.label2)
                }
                Spacer()
                FrequencyBadge(count: expression.occurrenceCount)
                IconButton(item.isFavorite ? "star.fill" : "star", help: item.isFavorite ? "取消收藏" : "收藏", foreground: item.isFavorite ? Theme.Palette.star : nil) {
                    saveIfNeeded(item)
                    settings.toggleLearningVocabularyFavorite(item.id)
                }
                IconButton("speaker.wave.2", help: "朗读") {
                    state.speakTranslation(expression.term)
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(expression.masteryText)
                    Spacer()
                    Text(L("下次复习：%@", item.nextReviewLabel))
                }
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
                ProgressView(value: expression.masteryProgress)
                    .tint(Theme.Palette.accent)
            }
            HStack(alignment: .top, spacing: 10) {
                detailSection("语境释义", expression.meaning)
                detailSection("常见搭配", expression.pairs.map { "\($0.0) / \($0.1)" }.joined(separator: "\n"))
            }
            Text(expression.sourceSentence)
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.s8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Divider() }
            HStack(spacing: Theme.Spacing.s8) {
                if item.wrongCount > 0 {
                    LearningWindowTag(L("错过 %d 次", item.wrongCount))
                }
                Spacer()
                Button(item.isSaved ? L("移出词库") : L("加入词库")) {
                    if item.isSaved {
                        settings.removeLearningVocabularyEntry(item.id)
                        selectedID = items.first?.id
                    } else {
                        saveIfNeeded(item)
                    }
                }
                .buttonStyle(.borderless)
                .font(Theme.Font.callout)
                Button(item.expression.masteryStage >= 5 ? L("已掌握") : L("标记掌握")) {
                    settings.markLearningMastered(item.expression, sceneLabel: item.sceneLabel)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(16)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.group))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.group).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func detailSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L(title))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.label2)
            Text(L(text))
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var addVocabularySheet: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            Text(L("添加表达"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Palette.label)
            VStack(alignment: .leading, spacing: 8) {
                TextField(L("表达"), text: $newTerm)
                TextField(L("语境释义"), text: $newMeaning)
                TextField(L("来源句"), text: $newSourceSentence)
            }
            .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(L("取消")) {
                    showAddSheet = false
                }
                Button(L("加入词库")) {
                    if let id = settings.addLearningVocabularyTerm(
                        term: newTerm,
                        meaning: newMeaning,
                        sourceSentence: newSourceSentence
                    ) {
                        selectedID = id
                        newTerm = ""
                        newMeaning = ""
                        newSourceSentence = ""
                        showAddSheet = false
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 420)
        .background(Theme.Palette.bgPanel)
    }

    private func saveIfNeeded(_ item: LearningVocabularyItem) {
        guard !item.isSaved else { return }
        settings.markLearningSaved(item.expression, sceneLabel: item.sceneLabel)
    }
}

private struct VocabularyRow: View {
    let item: LearningVocabularyItem
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.expression.term)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.label)
                        .lineLimit(1)
                    if item.isSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Palette.success)
                    }
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Palette.star)
                    }
                }
                Text("\(item.sceneLabel) · \(item.expression.masteryText)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                FrequencyBadge(count: item.expression.occurrenceCount)
                Text(item.nextReviewLabel)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 58)
        .background(selected ? Theme.Palette.bgSelection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct LearningWindowTag: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(L(text).uppercased())
            .font(Theme.Font.tag)
            .lineLimit(1)
            .foregroundStyle(Theme.Palette.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.Palette.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
