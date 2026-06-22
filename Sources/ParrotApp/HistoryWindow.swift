import AppKit
import SwiftUI
import ParrotCore

/// History & favorites browser: a 280pt list (search + scope + language-pair filter) beside a
/// detail pane that reuses the floating-panel visual language. Re-translation routes back through
/// the caller-supplied closure so the result lands in the shared floating panel.
@MainActor
final class HistoryWindow {
    private let state: AppState
    private let onRetranslate: (String) -> Void
    private var window: NSWindow?

    init(state: AppState, onRetranslate: @escaping (String) -> Void) {
        self.state = state
        self.onRetranslate = onRetranslate
    }

    func show() {
        if window == nil {
            let root = HistoryView(state: state, onRetranslate: { [weak self] text in
                self?.onRetranslate(text)
            })
            let hosting = NSHostingController(rootView: root)
            let win = NSWindow(contentViewController: hosting)
            win.title = L("Parrot 历史")
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 760, height: 500))
            win.contentMinSize = NSSize(width: 660, height: 420)
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            WindowPlacement.center(window)
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - View model

@MainActor
private final class HistoryModel: ObservableObject {
    enum Scope: String, CaseIterable, Identifiable {
        case all, favorites
        var id: String { rawValue }
        var title: String { self == .all ? L("全部") : L("收藏") }
    }

    @Published var records: [TranslationRecord] = []
    @Published var query: String = ""
    @Published var scope: Scope = .all
    @Published var langPair: String = "" // "" = all; otherwise "src→dst"
    @Published var selectedId: UUID?

    private let store: HistoryStore

    init(store: HistoryStore) {
        self.store = store
    }

    var filtered: [TranslationRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return records.filter { rec in
            if scope == .favorites && !rec.isFavorite { return false }
            if !langPair.isEmpty && Self.pairKey(rec) != langPair { return false }
            if q.isEmpty { return true }
            return rec.sourceText.lowercased().contains(q) || rec.translated.lowercased().contains(q)
        }
    }

    /// Distinct language pairs present in the records, for the filter menu.
    var availablePairs: [String] {
        var seen: [String] = []
        for rec in records {
            let key = Self.pairKey(rec)
            if !seen.contains(key) { seen.append(key) }
        }
        return seen
    }

    static func pairKey(_ rec: TranslationRecord) -> String { "\(rec.sourceLang)→\(rec.targetLang)" }

    func reload() {
        Task {
            let all = await store.all()
            self.records = all
            if let id = selectedId, !all.contains(where: { $0.id == id }) {
                selectedId = nil
            }
            if selectedId == nil { selectedId = filtered.first?.id }
        }
    }

    func toggleFavorite(_ rec: TranslationRecord) {
        Task {
            _ = await store.setFavorite(rec.id, !rec.isFavorite)
            reload()
        }
    }

    func delete(_ rec: TranslationRecord) {
        Task {
            await store.delete(rec.id)
            if selectedId == rec.id { selectedId = nil }
            reload()
        }
    }
}

// MARK: - View

private struct HistoryView: View {
    @ObservedObject var state: AppState
    let onRetranslate: (String) -> Void

    @StateObject private var model: HistoryModel

    init(state: AppState, onRetranslate: @escaping (String) -> Void) {
        self.state = state
        self.onRetranslate = onRetranslate
        _model = StateObject(wrappedValue: HistoryModel(store: state.history))
    }

    var body: some View {
        HStack(spacing: 0) {
            listColumn
            Divider()
            detailColumn
        }
        .frame(minWidth: 640, minHeight: 420)
        .onAppear { model.reload() }
    }

    // MARK: List

    private var listColumn: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            if model.filtered.isEmpty {
                emptyList
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.filtered) { rec in
                            Button {
                                model.selectedId = rec.id
                            } label: {
                                HistoryRow(record: rec, selected: model.selectedId == rec.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L("查看历史记录"))
                        }
                    }
                    .padding(Theme.Spacing.s8)
                }
            }
        }
        .frame(width: 280)
        .background(Theme.Palette.bgSidebar)
    }

    private var filterBar: some View {
        VStack(spacing: Theme.Spacing.s8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12)).foregroundStyle(Theme.Palette.label3)
                TextField("搜索原文或译文", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.body)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .frame(minHeight: 30)
            .background(Theme.Palette.bgControl)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: Theme.Spacing.s8) {
                Picker("", selection: $model.scope) {
                    ForEach(HistoryModel.Scope.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                if !model.availablePairs.isEmpty {
                    Menu {
                        Button("全部语言") { model.langPair = "" }
                        ForEach(model.availablePairs, id: \.self) { pair in
                            Button(pair) { model.langPair = pair }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(model.langPair.isEmpty ? Theme.Palette.label2 : Theme.Palette.accent)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(10)
    }

    private var emptyList: some View {
        VStack(spacing: Theme.Spacing.s8) {
            Image(systemName: model.scope == .favorites ? "star" : "clock")
                .font(.system(size: 28)).foregroundStyle(Theme.Palette.label3)
            Text(model.scope == .favorites ? L("暂无收藏") : L("暂无翻译记录"))
                .font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Detail

    @ViewBuilder
    private var detailColumn: some View {
        if let rec = model.filtered.first(where: { $0.id == model.selectedId }) {
            HistoryDetail(record: rec,
                          onRetranslate: { onRetranslate(rec.sourceText) },
                          onCopy: { copy($0) },
                          onSpeak: { state.speakTranslation($0) },
                          onFavorite: { model.toggleFavorite(rec) },
                          onDelete: { confirmDelete(rec) })
            .id(rec.id)
        } else {
            VStack(spacing: Theme.Spacing.s8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 32)).foregroundStyle(Theme.Palette.label3)
                Text("选择左侧记录查看详情")
                    .font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.bgCanvas)
        }
    }

    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func confirmDelete(_ rec: TranslationRecord) {
        let alert = NSAlert()
        alert.messageText = L("删除这条历史记录？")
        alert.informativeText = L("删除后不会影响已复制的文本或当前翻译结果。")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("删除"))
        alert.addButton(withTitle: L("取消"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        model.delete(rec)
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let record: TranslationRecord
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(record.sourceText)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.label)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if record.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.Palette.star)
                }
            }
            Text(record.translated)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label2)
                .lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(minHeight: 54)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Theme.Palette.bgSelection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - Detail pane

private struct HistoryDetail: View {
    let record: TranslationRecord
    let onRetranslate: () -> Void
    let onCopy: (String) -> Void
    let onSpeak: (String) -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
                header
                sourceBlock
                translationCard
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Palette.bgCanvas)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s8) {
            LangPill(from: Language(code: record.sourceLang), to: Language(code: record.targetLang))
            Spacer(minLength: 0)
            Button { onFavorite() } label: {
                Image(systemName: record.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(record.isFavorite ? Theme.Palette.star : Theme.Palette.label2)
            }
            .buttonStyle(.borderless).help(L("收藏"))
            IconButton("doc.on.doc", help: "复制译文") { onCopy(record.translated) }
            IconButton("speaker.wave.2", help: "朗读译文") { onSpeak(record.translated) }
            IconButton("trash", help: "删除") { onDelete() }
        }
    }

    private var sourceBlock: some View {
        Text(record.sourceText)
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Palette.label)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.s12)
            .background(Theme.Palette.bgContent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.group))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.group).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            ForEach(record.displayOutcomes) { outcome in
                outcomeCard(outcome)
            }
            Button { onRetranslate() } label: {
                Label("重新翻译", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.top, Theme.Spacing.s4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.group))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.group)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
    }

    private func outcomeCard(_ outcome: TranslationRecordOutcome) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                outcomeTag(outcome.displayName, foreground: Theme.Palette.accent, background: Theme.Palette.accentSoft)
                if let modelName = outcome.modelName, !modelName.isEmpty {
                    outcomeTag(modelName, foreground: Theme.Palette.label2, background: Theme.Palette.bgControl)
                }
                Spacer(minLength: 0)
                if let latency = outcome.latencyMs {
                    Text("\(latency)ms")
                        .font(Theme.Font.caption.monospacedDigit())
                        .foregroundStyle(Theme.Palette.label3)
                }
                if let application = outcome.terminologyApplication, application.matchCount > 0 {
                    outcomeTag(terminologyHistoryLabel(application), foreground: Theme.Palette.label2, background: Theme.Palette.accentSoft)
                }
                IconButton("doc.on.doc", help: "复制此结果", size: 11) { onCopy(outcome.translated) }
                IconButton("speaker.wave.2", help: "朗读此结果", size: 11) { onSpeak(outcome.translated) }
            }
            Text(outcome.translated)
                .font(Theme.Font.result)
                .foregroundStyle(Theme.Palette.label)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, Theme.Spacing.s8)
        .overlay(alignment: .bottom) {
            if outcome.id != record.displayOutcomes.last?.id {
                Divider()
            }
        }
    }

    private func outcomeTag(_ text: String, foreground: Color, background: Color) -> some View {
        Text(L(text).uppercased())
            .font(Theme.Font.tag)
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var dateLine: some View {
        Text(Self.dateText(record.createdAt))
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
    }

    private static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    private func terminologyHistoryLabel(_ application: TerminologyApplication) -> String {
        if !application.restorationSucceeded { return "术语恢复失败" }
        switch application.strategy {
        case .prompt:
            return "术语约束 · \(application.matchCount)"
        default:
            return "术语已应用 · \(application.matchCount)"
        }
    }
}
