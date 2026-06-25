import Foundation
import SwiftUI
import ParrotCore

struct LearningExpression: Identifiable {
    let id: String
    let term: String
    let phonetic: String?
    let kind: String
    let meaning: String
    let chunk: String
    let pairs: [(String, String)]
    let occurrenceCount: Int
    let masteryStage: Int
    let sourceSentence: String

    var displayCount: String { L("%d次", max(1, occurrenceCount)) }
    var masteryText: String {
        switch masteryStage {
        case 1: return L("阶段 1 / 5 · 已见过")
        case 2: return L("阶段 2 / 5 · 原句能认出")
        case 3: return L("阶段 3 / 5 · 迁移句可认出")
        case 4: return L("阶段 4 / 5 · 主动能写出")
        default: return L("阶段 5 / 5 · 主动可用")
        }
    }
    var masteryProgress: Double { min(1, max(0.2, Double(masteryStage) / 5.0)) }
}

struct LearningVocabularyEntry: Identifiable, Codable, Equatable {
    let id: String
    var term: String
    var meaning: String
    var sourceSentence: String
    var sceneLabel: String
    var occurrenceCount: Int
    var masteryStage: Int
    var wrongCount: Int
    var isFavorite: Bool
    var isManual: Bool
    var savedAt: Date
    var updatedAt: Date
    var lastReviewedAt: Date?
    var nextReviewAt: Date?

    init(
        id: String,
        term: String,
        meaning: String = "",
        sourceSentence: String = "",
        sceneLabel: String = "手动添加",
        occurrenceCount: Int = 1,
        masteryStage: Int = 1,
        wrongCount: Int = 0,
        isFavorite: Bool = false,
        isManual: Bool = false,
        savedAt: Date = Date(),
        updatedAt: Date = Date(),
        lastReviewedAt: Date? = nil,
        nextReviewAt: Date? = nil
    ) {
        self.id = id
        self.term = term
        self.meaning = meaning
        self.sourceSentence = sourceSentence
        self.sceneLabel = sceneLabel
        self.occurrenceCount = max(1, occurrenceCount)
        self.masteryStage = Self.clampedStage(masteryStage)
        self.wrongCount = max(0, wrongCount)
        self.isFavorite = isFavorite
        self.isManual = isManual
        self.savedAt = savedAt
        self.updatedAt = updatedAt
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
    }

    init(expression: LearningExpression, sceneLabel: String, date: Date = Date()) {
        self.init(
            id: expression.id,
            term: expression.term,
            meaning: expression.meaning,
            sourceSentence: expression.sourceSentence,
            sceneLabel: sceneLabel,
            occurrenceCount: expression.occurrenceCount,
            masteryStage: expression.masteryStage,
            isManual: false,
            savedAt: date,
            updatedAt: date
        )
    }

    static func clampedStage(_ value: Int) -> Int {
        min(5, max(1, value))
    }
}

struct LearningVocabularyItem: Identifiable {
    var id: String { expression.id }
    let expression: LearningExpression
    let nextReviewLabel: String
    let sceneLabel: String
    let entry: LearningVocabularyEntry?

    var isSaved: Bool { entry != nil }
    var isFavorite: Bool { entry?.isFavorite == true }
    var isManual: Bool { entry?.isManual == true }
    var wrongCount: Int { entry?.wrongCount ?? 0 }
    var isDue: Bool {
        guard let nextReviewAt = entry?.nextReviewAt else {
            return expression.masteryStage <= 2
        }
        return nextReviewAt <= Date()
    }
}

struct LearningReviewCard: Identifiable {
    let id: String
    let expression: LearningExpression
    let mode: String
    let title: String
    let prompt: String
    let options: [String]
    let correctAnswer: String
    let origin: String
}

enum LearningRecommendationEngine {
    private struct LexiconEntry {
        let term: String
        let phonetic: String?
        let kind: String
        let meaning: String
        let pairs: [(String, String)]
        let aliases: [String]
    }

    private static let lexicon: [LexiconEntry] = [
        LexiconEntry(
            term: "insufficient evidence",
            phonetic: "/ˌɪnsəˈfɪʃnt/",
            kind: "关键理解",
            meaning: "证据不足；通常用于解释申请、提案或研究结论被拒绝的原因。",
            pairs: [("insufficient data", "数据不足"), ("insufficient funds", "资金不足"), ("insufficient time", "时间不够")],
            aliases: ["insufficient evidence"]
        ),
        LexiconEntry(
            term: "due to",
            phonetic: "/duː tuː/",
            kind: "连接词",
            meaning: "由于、因为；语气偏书面，常用于说明原因。",
            pairs: [("due to weather", "由于天气"), ("due to a delay", "由于延误"), ("due to lack of data", "由于缺少数据")],
            aliases: ["due to"]
        ),
        LexiconEntry(
            term: "proposal",
            phonetic: "/prəˈpoʊzəl/",
            kind: "高频",
            meaning: "提案、方案；常见于商务、产品、研究和审批语境。",
            pairs: [("submit a proposal", "提交提案"), ("approve a proposal", "批准提案"), ("reject a proposal", "驳回提案")],
            aliases: ["proposal", "proposals"]
        ),
        LexiconEntry(
            term: "evidence",
            phonetic: "/ˈevɪdəns/",
            kind: "高频",
            meaning: "证据、依据；用于支持判断、结论或主张。",
            pairs: [("clear evidence", "明确证据"), ("supporting evidence", "支持性证据"), ("lack of evidence", "缺少证据")],
            aliases: ["evidence"]
        ),
        LexiconEntry(
            term: "early intervention",
            phonetic: nil,
            kind: "词块",
            meaning: "早期干预；常见于教育、医疗、产品风控等场景。",
            pairs: [("intervention strategy", "干预策略"), ("timely intervention", "及时干预"), ("policy intervention", "政策干预")],
            aliases: ["early intervention"]
        ),
        LexiconEntry(
            term: "highlight the importance of",
            phonetic: nil,
            kind: "写作表达",
            meaning: "强调……的重要性；适合报告、论文和总结表达。",
            pairs: [("highlight the risk of", "强调……的风险"), ("highlight the need for", "强调……的必要性"), ("highlight key findings", "强调关键发现")],
            aliases: ["highlight the importance of", "highlights the importance of"]
        ),
        LexiconEntry(
            term: "proprietary",
            phonetic: "/prəˈpraɪəteri/",
            kind: "技术词",
            meaning: "专有的、私有的；这里指由特定厂商控制，通常不是开源或自建的产品。",
            pairs: [("proprietary software", "专有软件"), ("proprietary product", "专有产品"), ("proprietary platform", "厂商平台")],
            aliases: ["proprietary"]
        ),
        LexiconEntry(
            term: "observability",
            phonetic: "/əbˌzɜːrvəˈbɪləti/",
            kind: "技术词",
            meaning: "可观测性；通过日志、指标和链路追踪理解系统线上状态的能力。",
            pairs: [("observability stack", "可观测性工具栈"), ("improve observability", "提升可观测性"), ("observability platform", "可观测性平台")],
            aliases: ["observability"]
        ),
        LexiconEntry(
            term: "tracing",
            phonetic: "/ˈtreɪsɪŋ/",
            kind: "技术词",
            meaning: "链路追踪；记录一次请求在多个服务间经过的路径和耗时。",
            pairs: [("distributed tracing", "分布式追踪"), ("trace a request", "追踪一次请求"), ("tracing data", "追踪数据")],
            aliases: ["tracing"]
        ),
        LexiconEntry(
            term: "evals",
            phonetic: nil,
            kind: "AI 术语",
            meaning: "评测；这里指用测试集或标准流程评估模型、系统或功能效果。",
            pairs: [("run evals", "跑评测"), ("model evals", "模型评测"), ("eval results", "评测结果")],
            aliases: ["evals", "eval"]
        ),
        LexiconEntry(
            term: "hosted",
            phonetic: "/ˈhoʊstɪd/",
            kind: "技术词",
            meaning: "托管的；指服务由第三方或云厂商运行和维护，用户直接使用。",
            pairs: [("hosted service", "托管服务"), ("hosted product", "托管产品"), ("self-hosted", "自托管")],
            aliases: ["hosted"]
        )
    ]

    private static let stopWords: Set<String> = [
        "about", "after", "again", "against", "because", "before", "being", "between",
        "could", "every", "first", "from", "their", "there", "these", "those", "through",
        "under", "where", "which", "while", "would", "should", "translated", "translation"
    ]

    static func recommendations(
        in translatedText: String,
        sourceText: String,
        limit: Int,
        occurrenceCounts: [String: Int]
    ) -> [LearningExpression] {
        guard containsLatinText(translatedText) else { return [] }
        let cappedLimit = min(6, max(1, limit))
        let text = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        var results: [LearningExpression] = []
        var seen: Set<String> = []
        var occupiedRanges: [Range<String.Index>] = []
        for entry in lexicon {
            guard let match = firstMatch(for: entry.aliases, in: text),
                  !occupiedRanges.contains(where: { overlaps($0, match.range) }) else { continue }
            let key = key(for: entry.term)
            guard seen.insert(key).inserted else { continue }
            occupiedRanges.append(match.range)
            results.append(expression(for: entry, matchedTerm: match.alias, text: text, sourceText: sourceText, occurrenceCounts: occurrenceCounts))
        }

        for word in extractedWords(from: text) where results.count < cappedLimit * 2 {
            let key = key(for: word)
            guard !seen.contains(key),
                  let range = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]),
                  !occupiedRanges.contains(where: { overlaps($0, range) }) else { continue }
            seen.insert(key)
            occupiedRanges.append(range)
            results.append(genericExpression(term: word, text: text, sourceText: sourceText, occurrenceCounts: occurrenceCounts))
        }

        return Array(results.sorted { lhs, rhs in
            if lhs.occurrenceCount != rhs.occurrenceCount {
                return lhs.occurrenceCount > rhs.occurrenceCount
            }
            let lhsLexicon = lexiconIndex(for: lhs.term)
            let rhsLexicon = lexiconIndex(for: rhs.term)
            if lhsLexicon != rhsLexicon {
                return lhsLexicon < rhsLexicon
            }
            return lhs.term < rhs.term
        }.prefix(cappedLimit))
    }

    static func expressionForManualSelection(
        _ rawSelection: String,
        contextText: String,
        sourceText: String,
        occurrenceCounts: [String: Int]
    ) -> LearningExpression? {
        let selected = normalizedManualSelection(rawSelection)
        guard !selected.isEmpty else { return nil }
        let context = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = context.isEmpty ? (source.isEmpty ? selected : source) : context

        if let entry = lexicon.first(where: { entry in
            key(for: entry.term) == key(for: selected)
                || entry.aliases.contains { key(for: $0) == key(for: selected) }
        }) {
            return expression(
                for: entry,
                matchedTerm: selected,
                text: text,
                sourceText: source,
                occurrenceCounts: occurrenceCounts
            )
        }

        return genericExpression(
            term: selected,
            text: text,
            sourceText: source,
            occurrenceCounts: occurrenceCounts
        )
    }

    static func occurrenceCounts(records: [TranslationRecord]) -> [String: Int] {
        var counts: [String: Int] = [:]
        let texts = records.map { record in
            uniqueTexts([record.sourceText, record.translated] + record.displayOutcomes.map(\.translated))
                .joined(separator: "\n")
        }
        for entry in lexicon {
            let total = texts.reduce(0) { partial, text in
                partial + entry.aliases.reduce(0) { $0 + countOccurrences(of: $1, in: text) }
            }
            if total > 0 { counts[key(for: entry.term)] = total }
        }
        for text in texts {
            for word in extractedWords(from: text) {
                let wordKey = key(for: word)
                guard counts[wordKey] == nil else { continue }
                counts[wordKey, default: 0] += countOccurrences(of: word, in: text)
            }
        }
        return counts
    }

    static func vocabularyItems(
        records: [TranslationRecord],
        occurrenceCounts: [String: Int],
        vocabularyEntries: [LearningVocabularyEntry] = [],
        includeHistoryRecommendations: Bool = false,
        limit: Int = 80
    ) -> [LearningVocabularyItem] {
        let entriesByID = Dictionary(uniqueKeysWithValues: vocabularyEntries.map { ($0.id, $0) })
        var byID: [String: LearningVocabularyItem] = [:]
        if includeHistoryRecommendations {
            for record in records {
                let translated = record.displayOutcomes.first?.translated ?? record.translated
                let text = learningText(
                    translatedText: translated,
                    sourceText: record.sourceText,
                    sourceLanguage: language(from: record.sourceLang),
                    targetLanguage: language(from: record.targetLang)
                )
                for expression in recommendations(
                    in: text,
                    sourceText: record.sourceText,
                    limit: 6,
                    occurrenceCounts: occurrenceCounts
                ) where byID[expression.id] == nil {
                    byID[expression.id] = vocabularyItem(expression: expression, entry: entriesByID[expression.id])
                }
            }
        }

        for entry in vocabularyEntries where byID[entry.id] == nil {
            byID[entry.id] = vocabularyItem(expression: expression(from: entry, fallback: nil), entry: entry)
        }

        return byID.values
            .sorted {
                if $0.isSaved != $1.isSaved { return $0.isSaved && !$1.isSaved }
                if $0.isDue != $1.isDue { return $0.isDue && !$1.isDue }
                if $0.expression.occurrenceCount != $1.expression.occurrenceCount {
                    return $0.expression.occurrenceCount > $1.expression.occurrenceCount
                }
                return $0.expression.term < $1.expression.term
            }
            .prefix(limit)
            .map { $0 }
    }

    static func learningText(
        translatedText: String,
        sourceText: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) -> String {
        let translated = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translated.isEmpty else { return source }

        let sourceHasLatin = containsLatinText(source)
        let translatedHasLatin = containsLatinText(translated)
        let sourceIsEnglishCandidate = sourceLanguage == .en || sourceLanguage == .auto
        if sourceHasLatin, sourceIsEnglishCandidate, targetLanguage == .zh {
            return source
        }
        if translatedHasLatin {
            return translated
        }
        if sourceHasLatin {
            return source
        }
        return translated
    }

    static func reviewCards(from items: [LearningVocabularyItem], limit: Int = 12) -> [LearningReviewCard] {
        items.prefix(limit).enumerated().map { index, item in
            let expression = item.expression
            return LearningReviewCard(
                id: expression.id,
                expression: expression,
                mode: index % 3 == 0 ? "原句挖空" : (index % 3 == 1 ? "中文回忆英文" : "迁移句"),
                title: clozeSentence(for: expression),
                prompt: "选择最符合当前语境的表达。",
                options: stableReviewOptions(for: expression.term),
                correctAnswer: expression.term,
                origin: "来自历史翻译"
            )
        }
    }

    static func key(for term: String) -> String {
        term.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func containsTerm(_ term: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        let pattern = "\\b\(escaped)\\b"
        return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))
            .map { regex in
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                return regex.firstMatch(in: text, range: range) != nil
            } ?? text.localizedCaseInsensitiveContains(term)
    }

    static func countOccurrences(of term: String, in text: String) -> Int {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.localizedCaseInsensitiveContains(term) ? 1 : 0
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.numberOfMatches(in: text, range: range)
    }

    private static func firstMatch(
        for aliases: [String],
        in text: String
    ) -> (alias: String, range: Range<String.Index>)? {
        for alias in aliases {
            if let range = rangeOfTerm(alias, in: text) {
                return (alias, range)
            }
        }
        return nil
    }

    private static func rangeOfTerm(_ term: String, in text: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive])
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else { return nil }
        return range
    }

    private static func overlaps(_ lhs: Range<String.Index>, _ rhs: Range<String.Index>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private static func lexiconIndex(for term: String) -> Int {
        let normalized = key(for: term)
        return lexicon.firstIndex { key(for: $0.term) == normalized } ?? Int.max
    }

    private static func expression(
        for entry: LexiconEntry,
        matchedTerm: String,
        text: String,
        sourceText: String,
        occurrenceCounts: [String: Int]
    ) -> LearningExpression {
        let count = max(1, occurrenceCounts[key(for: entry.term)] ?? countOccurrences(of: matchedTerm, in: text))
        return LearningExpression(
            id: key(for: entry.term),
            term: entry.term,
            phonetic: entry.phonetic,
            kind: entry.kind,
            meaning: entry.meaning,
            chunk: chunk(for: entry.term, text: text, sourceText: sourceText),
            pairs: entry.pairs,
            occurrenceCount: count,
            masteryStage: masteryStage(for: count),
            sourceSentence: text
        )
    }

    private static func genericExpression(
        term: String,
        text: String,
        sourceText: String,
        occurrenceCounts: [String: Int]
    ) -> LearningExpression {
        let count = max(1, occurrenceCounts[key(for: term)] ?? countOccurrences(of: term, in: text))
        return LearningExpression(
            id: key(for: term),
            term: term,
            phonetic: nil,
            kind: count >= 3 ? "高频" : "新词",
            meaning: "当前译文中的英文表达；建议结合原句语境记忆，而不是孤立背释义。",
            chunk: chunk(for: term, text: text, sourceText: sourceText),
            pairs: [
                ("use \(term) in context", "在语境中使用"),
                ("recognize \(term)", "识别这个表达"),
                ("review \(term)", "复习这个表达")
            ],
            occurrenceCount: count,
            masteryStage: masteryStage(for: count),
            sourceSentence: text
        )
    }

    private static func extractedWords(from text: String) -> [String] {
        guard containsLatinText(text),
              let regex = try? NSRegularExpression(pattern: #"\b[A-Za-z][A-Za-z'-]{4,}\b"#) else {
            return []
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        var words: [String] = []
        var seen: Set<String> = []
        for match in regex.matches(in: text, range: range) {
            let raw = nsText.substring(with: match.range)
            let normalized = key(for: raw)
            guard !stopWords.contains(normalized), seen.insert(normalized).inserted else { continue }
            words.append(raw)
        }
        return words
    }

    private static func normalizedManualSelection(_ raw: String) -> String {
        let collapsed = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?()[]{}\"'“”‘’"))
    }

    private static func uniqueTexts(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    private static func language(from code: String) -> Language {
        code == "auto" ? .auto : Language(code: code)
    }

    private static func containsLatinText(_ text: String) -> Bool {
        text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
    }

    private static func chunk(for term: String, text: String, sourceText: String) -> String {
        if !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(term) · \(sourceText)"
        }
        return text
    }

    private static func masteryStage(for count: Int) -> Int {
        switch count {
        case 0...1: return 1
        case 2...3: return 2
        case 4...6: return 3
        case 7...10: return 4
        default: return 5
        }
    }

    private static func vocabularyItem(
        expression baseExpression: LearningExpression,
        entry: LearningVocabularyEntry?
    ) -> LearningVocabularyItem {
        let merged = expression(from: entry, fallback: baseExpression)
        return LearningVocabularyItem(
            expression: merged,
            nextReviewLabel: nextReviewLabel(for: merged, entry: entry),
            sceneLabel: entry?.sceneLabel.isEmpty == false ? entry!.sceneLabel : sceneLabel(for: merged),
            entry: entry
        )
    }

    private static func expression(
        from entry: LearningVocabularyEntry?,
        fallback: LearningExpression?
    ) -> LearningExpression {
        guard let entry else {
            return fallback ?? LearningExpression(
                id: "",
                term: "",
                phonetic: nil,
                kind: "表达",
                meaning: "个人词库表达。",
                chunk: "",
                pairs: [],
                occurrenceCount: 1,
                masteryStage: 1,
                sourceSentence: ""
            )
        }
        return LearningExpression(
            id: entry.id,
            term: entry.term,
            phonetic: fallback?.phonetic,
            kind: fallback?.kind ?? (entry.isManual ? "自定义" : "表达"),
            meaning: entry.meaning.isEmpty ? (fallback?.meaning ?? "个人词库表达；建议结合来源句复习。") : entry.meaning,
            chunk: fallback?.chunk ?? (entry.sourceSentence.isEmpty ? entry.term : "\(entry.term) · \(entry.sourceSentence)"),
            pairs: fallback?.pairs ?? defaultPairs(for: entry.term),
            occurrenceCount: max(entry.occurrenceCount, fallback?.occurrenceCount ?? 1),
            masteryStage: LearningVocabularyEntry.clampedStage(entry.masteryStage),
            sourceSentence: entry.sourceSentence.isEmpty ? (fallback?.sourceSentence ?? entry.term) : entry.sourceSentence
        )
    }

    private static func defaultPairs(for term: String) -> [(String, String)] {
        [
            ("use \(term) in context", "在语境中使用"),
            ("recognize \(term)", "识别这个表达"),
            ("review \(term)", "复习这个表达")
        ]
    }

    private static func nextReviewLabel(for expression: LearningExpression) -> String {
        switch expression.masteryStage {
        case 1, 2: return "今天"
        case 3: return "明天"
        case 4: return "3 天"
        default: return "6 天"
        }
    }

    private static func nextReviewLabel(
        for expression: LearningExpression,
        entry: LearningVocabularyEntry?
    ) -> String {
        guard let nextReviewAt = entry?.nextReviewAt else {
            return nextReviewLabel(for: expression)
        }
        let calendar = Calendar.current
        if nextReviewAt <= Date() || calendar.isDateInToday(nextReviewAt) {
            return "今天"
        }
        if calendar.isDateInTomorrow(nextReviewAt) {
            return "明天"
        }
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: nextReviewAt)
        let days = max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 1)
        return "\(days) 天"
    }

    private static func sceneLabel(for expression: LearningExpression) -> String {
        if expression.term.contains("proposal") || expression.term.contains("evidence") { return "商务 / 审批" }
        if expression.term.contains("intervention") { return "论文 / 教育" }
        if expression.term.contains("due to") { return "通用连接词" }
        return "翻译历史"
    }

    private static func clozeSentence(for expression: LearningExpression) -> String {
        let sentence = expression.sourceSentence
        guard containsTerm(expression.term, in: sentence) else {
            return "选择表达：___"
        }
        return sentence.replacingOccurrences(
            of: expression.term,
            with: "___",
            options: [.caseInsensitive, .diacriticInsensitive]
        )
    }

    private static func reviewDistractors(for term: String) -> [String] {
        let fallback = ["available", "accurate", "potential", "efficient", "general", "current"]
        return fallback.filter { key(for: $0) != key(for: term) }
    }

    static func stableReviewOptions(for term: String, limit: Int = 3) -> [String] {
        let cappedLimit = max(2, limit)
        var options = Array(reviewDistractors(for: term).prefix(cappedLimit - 1))
        let stableIndex = term.unicodeScalars.reduce(0) { $0 + Int($1.value) } % cappedLimit
        options.insert(term, at: min(stableIndex, options.count))
        return options
    }
}

struct FrequencyBadge: View {
    let count: Int

    var body: some View {
        Text(L("%d次", max(1, count)))
            .font(.system(size: 10, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.Palette.warning)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Theme.Palette.warning.opacity(0.14))
            .clipShape(Capsule())
    }
}

struct LearningStatusChip: View {
    let text: String
    var tone: Color = Theme.Palette.accent

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tone).frame(width: 7, height: 7)
            Text(L(text))
        }
        .font(Theme.Font.caption)
        .foregroundStyle(Theme.Palette.label2)
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(Theme.Palette.bgControl)
        .clipShape(Capsule())
    }
}

struct LearningFlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? 360, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for item in result.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, items: [(index: Int, origin: CGPoint, size: CGSize)]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var items: [(Int, CGPoint, CGSize)] = []
        let availableWidth = max(width, 1)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > availableWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            items.append((index, CGPoint(x: x, y: y), size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: availableWidth, height: y + rowHeight), items)
    }
}

struct LearningHighlightedText: View {
    let text: String
    let expressions: [LearningExpression]
    let selectedID: String?
    let masteredIDs: Set<String>
    let onSelect: (LearningExpression) -> Void

    var body: some View {
        LearningFlowLayout(spacing: 3, lineSpacing: 6) {
            ForEach(segments) { segment in
                switch segment.kind {
                case .plain:
                    Text(segment.text)
                        .font(Theme.Font.result)
                        .foregroundStyle(Theme.Palette.label)
                        .textSelection(.enabled)
                case .expression(let expression):
                    LearningTermButton(
                        expression: expression,
                        selected: selectedID == expression.id,
                        mastered: masteredIDs.contains(expression.id),
                        action: { onSelect(expression) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var segments: [Segment] {
        var matches: [(range: Range<String.Index>, expression: LearningExpression)] = []
        for expression in expressions {
            guard let range = text.range(
                of: expression.term,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) else { continue }
            if matches.contains(where: { overlaps($0.range, range) }) { continue }
            matches.append((range, expression))
        }
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }
        guard !matches.isEmpty else { return [.plain(text)] }
        var result: [Segment] = []
        var cursor = text.startIndex
        for match in matches {
            if cursor < match.range.lowerBound {
                appendPlain(String(text[cursor..<match.range.lowerBound]), to: &result)
            }
            result.append(.expression(String(text[match.range]), match.expression))
            cursor = match.range.upperBound
        }
        if cursor < text.endIndex {
            appendPlain(String(text[cursor..<text.endIndex]), to: &result)
        }
        return result
    }

    private func appendPlain(_ raw: String, to result: inout [Segment]) {
        let tokens = raw.split(separator: " ", omittingEmptySubsequences: false)
        if tokens.isEmpty {
            result.append(.plain(raw))
            return
        }
        for token in tokens {
            let value = String(token)
            guard !value.isEmpty else {
                result.append(.plain(" "))
                continue
            }
            result.append(.plain(value))
        }
    }

    private func overlaps(_ lhs: Range<String.Index>, _ rhs: Range<String.Index>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private struct Segment: Identifiable {
        enum Kind {
            case plain
            case expression(LearningExpression)
        }
        let id = UUID()
        let text: String
        let kind: Kind

        static func plain(_ text: String) -> Segment {
            Segment(text: text, kind: .plain)
        }

        static func expression(_ text: String, _ expression: LearningExpression) -> Segment {
            Segment(text: text, kind: .expression(expression))
        }
    }
}

private struct LearningTermButton: View {
    let expression: LearningExpression
    let selected: Bool
    let mastered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(expression.term)
                    .lineLimit(1)
                FrequencyBadge(count: expression.occurrenceCount)
                    .scaleEffect(0.86)
            }
            .font(Theme.Font.result)
            .foregroundStyle(selected ? Theme.Palette.accent : Theme.Palette.label)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        if mastered { return Theme.Palette.success.opacity(0.14) }
        if selected { return Theme.Palette.accent.opacity(0.24) }
        return Theme.Palette.accentSoft
    }

    private var border: Color {
        if mastered { return Theme.Palette.success.opacity(0.52) }
        return Theme.Palette.accent.opacity(selected ? 0.68 : 0.45)
    }
}

struct LearningStripView: View {
    let expressions: [LearningExpression]
    let selectedID: String?
    let savedIDs: Set<String>
    let onSelect: (LearningExpression) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            Divider()
            HStack(spacing: Theme.Spacing.s8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.accent)
                Text(L("建议掌握 %d 个表达", expressions.count))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
                Spacer(minLength: 0)
                Text(estimatedTime)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
            }
            LearningFlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(expressions) { expression in
                    Button {
                        onSelect(expression)
                    } label: {
                        HStack(spacing: 5) {
                            if savedIDs.contains(expression.id) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.success)
                            }
                            Text(expression.term)
                                .font(Theme.Font.callout)
                            FrequencyBadge(count: expression.occurrenceCount)
                                .scaleEffect(0.88)
                        }
                        .foregroundStyle(selectedID == expression.id ? Theme.Palette.accent : Theme.Palette.label2)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(selectedID == expression.id ? Theme.Palette.bgSelection : Theme.Palette.bgControl)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(selectedID == expression.id ? Theme.Palette.accent.opacity(0.48) : Theme.Palette.separator, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }

    private var estimatedTime: String {
        L("预计 %d 秒", expressions.count * 14)
    }
}

struct LearningContextCard: View {
    let expression: LearningExpression
    let saved: Bool
    let mastered: Bool
    let onKnown: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s8) {
                Text("选中")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(expression.term)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                    if !metaText.isEmpty {
                        Text(metaText)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.label3)
                    }
                }
                Spacer(minLength: 0)
                LearningTag(expression.kind)
            }
            meaningBlock
            contextLine
            HStack(spacing: Theme.Spacing.s8) {
                FrequencyBadge(count: expression.occurrenceCount)
                Text(mastered ? "已认识" : expression.masteryText)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.label3)
                    .lineLimit(1)
                Spacer()
                Button(mastered ? L("已标记认识") : L("认识")) { onKnown() }
                    .buttonStyle(.borderless)
                    .font(Theme.Font.callout)
                    .foregroundStyle(mastered ? Theme.Palette.success : Theme.Palette.label2)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Theme.Palette.bgControl)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                Button(saved ? L("已加入词库") : L("加入词库")) { onSave() }
                    .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(Theme.Spacing.s12)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var metaText: String {
        expression.phonetic ?? "来自当前句子"
    }

    private var meaningBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("句中含义")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.label3)
            Text(expression.meaning)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contextLine: some View {
        Text("原句：\(expression.chunk)")
            .font(Theme.Font.callout)
            .foregroundStyle(Theme.Palette.label2)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct LearningTag: View {
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

struct LearningMicroPracticeView: View {
    let expression: LearningExpression
    let onCorrect: () -> Void
    var onWrong: () -> Void = {}

    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            HStack(spacing: Theme.Spacing.s8) {
                Image(systemName: "textformat")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.label2)
                Text("10 秒微练习")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
                Spacer(minLength: 0)
                LearningStatusChip(text: "原句挖空")
            }
            Text(cloze)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selected = option
                        if isCorrect(option) {
                            onCorrect()
                        } else {
                            onWrong()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(Theme.Font.callout)
                    .foregroundStyle(optionForeground(option))
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(optionBackground(option))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(optionBorder(option), lineWidth: 0.5)
                    )
                }
            }
            if let selected {
                Text(isCorrect(selected)
                     ? L("答对了。%@ 进入下一掌握阶段。", expression.term)
                     : L("答案是 %@。这个表达会在稍后的复习队列中再次出现。", expression.term))
                    .font(Theme.Font.caption)
                    .foregroundStyle(isCorrect(selected) ? Theme.Palette.success : Theme.Palette.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((isCorrect(selected) ? Theme.Palette.success : Theme.Palette.warning).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
        }
        .padding(Theme.Spacing.s12)
        .background(Theme.Palette.bgContent)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var cloze: String {
        let sentence = LearningRecommendationEngine.containsTerm(expression.term, in: expression.sourceSentence)
            ? expression.sourceSentence
            : expression.chunk
        return sentence.replacingOccurrences(
            of: expression.term,
            with: "___",
            options: [.caseInsensitive, .diacriticInsensitive]
        )
    }

    private var options: [String] {
        LearningRecommendationEngine.stableReviewOptions(for: expression.term)
    }

    private func isCorrect(_ option: String) -> Bool {
        LearningRecommendationEngine.key(for: option) == expression.id
    }

    private func optionForeground(_ option: String) -> Color {
        guard let selected else { return Theme.Palette.label }
        if isCorrect(option) { return Theme.Palette.success }
        if selected == option { return Theme.Palette.danger }
        return Theme.Palette.label2
    }

    private func optionBackground(_ option: String) -> Color {
        guard let selected else { return Theme.Palette.bgControl }
        if isCorrect(option) { return Theme.Palette.success.opacity(0.14) }
        if selected == option { return Theme.Palette.danger.opacity(0.12) }
        return Theme.Palette.bgControl
    }

    private func optionBorder(_ option: String) -> Color {
        guard let selected else { return Theme.Palette.separator }
        if isCorrect(option) { return Theme.Palette.success.opacity(0.45) }
        if selected == option { return Theme.Palette.danger.opacity(0.45) }
        return Theme.Palette.separator
    }
}
