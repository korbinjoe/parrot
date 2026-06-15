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
            win.title = "Parrot 历史"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 720, height: 480))
            win.contentMinSize = NSSize(width: 640, height: 420)
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - View model

@MainActor
private final class HistoryModel: ObservableObject {
    enum Scope: String, CaseIterable, Identifiable {
        case all, favorites
        var id: String { rawValue }
        var title: String { self == .all ? "全部" : "收藏" }
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
                            HistoryRow(record: rec, selected: model.selectedId == rec.id)
                                .contentShape(Rectangle())
                                .onTapGesture { model.selectedId = rec.id }
                        }
                    }
                    .padding(Theme.Spacing.s8)
                }
            }
        }
        .frame(width: 280)
        .background(.regularMaterial)
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
            .background(Theme.Palette.bgContent2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

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
        .padding(Theme.Spacing.s8)
    }

    private var emptyList: some View {
        VStack(spacing: Theme.Spacing.s8) {
            Image(systemName: model.scope == .favorites ? "star" : "clock")
                .font(.system(size: 28)).foregroundStyle(Theme.Palette.label3)
            Text(model.scope == .favorites ? "暂无收藏" : "暂无翻译记录")
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
                          onCopy: { copy(rec.translated) },
                          onSpeak: { state.speakTranslation(rec.translated) },
                          onFavorite: { model.toggleFavorite(rec) },
                          onDelete: { model.delete(rec) })
            .id(rec.id)
        } else {
            VStack(spacing: Theme.Spacing.s8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 32)).foregroundStyle(Theme.Palette.label3)
                Text("选择左侧记录查看详情")
                    .font(Theme.Font.callout).foregroundStyle(Theme.Palette.label2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.bgContent)
        }
    }

    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
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
                    .foregroundStyle(selected ? Color.white : Theme.Palette.label)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if record.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(selected ? Color.white : Theme.Palette.star)
                }
            }
            Text(record.translated)
                .font(Theme.Font.caption)
                .foregroundStyle(selected ? Color.white.opacity(0.85) : Theme.Palette.label2)
                .lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Theme.Palette.accent : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: - Detail pane

private struct HistoryDetail: View {
    let record: TranslationRecord
    let onRetranslate: () -> Void
    let onCopy: () -> Void
    let onSpeak: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
                header
                sourceBlock
                translationCard
            }
            .padding(Theme.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Palette.bgContent)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s8) {
            LangPill(from: Language(code: record.sourceLang), to: Language(code: record.targetLang))
            Spacer(minLength: 0)
            Button { onFavorite() } label: {
                Image(systemName: record.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(record.isFavorite ? Theme.Palette.star : Theme.Palette.label2)
            }
            .buttonStyle(.borderless).help("收藏")
            IconButton("doc.on.doc", help: "复制译文") { onCopy() }
            IconButton("speaker.wave.2", help: "朗读译文") { onSpeak() }
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
            .background(Theme.Palette.bgContent2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                Text(record.providerId.uppercased())
                    .font(Theme.Font.tag)
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.Palette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Spacer(minLength: 0)
                Text(Self.dateText(record.createdAt))
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.label3)
            }
            Text(record.translated)
                .font(Theme.Font.result)
                .foregroundStyle(Theme.Palette.label)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { onRetranslate() } label: {
                Label("重新翻译", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
            .padding(.top, Theme.Spacing.s4)
        }
        .padding(Theme.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
        )
    }

    private static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}
