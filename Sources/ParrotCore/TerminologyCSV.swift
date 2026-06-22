import Foundation

public struct TerminologyImportPlan: Sendable, Equatable {
    public let added: [TerminologyEntry]
    public let overwritten: [TerminologyEntry]
    public let conflicts: [TerminologyEntry]

    public var addedCount: Int { added.count }
    public var overwrittenCount: Int { overwritten.count }
    public var conflictCount: Int { conflicts.count }
    public var importableEntries: [TerminologyEntry] { added + overwritten }

    public init(
        added: [TerminologyEntry],
        overwritten: [TerminologyEntry],
        conflicts: [TerminologyEntry]
    ) {
        self.added = added
        self.overwritten = overwritten
        self.conflicts = conflicts
    }
}

public enum TerminologyCSV {
    public static let header = "source,target,from,to,caseSensitive,note,enabled"

    public static func encode(_ entries: [TerminologyEntry]) -> String {
        ([header] + entries.map(encodeEntry)).joined(separator: "\n") + "\n"
    }

    public static func decode(_ csv: String) throws -> [TerminologyEntry] {
        let rows = parseRows(csv)
        guard !rows.isEmpty else { return [] }
        let dataRows: ArraySlice<[String]>
        if rows[0].map({ $0.lowercased() }) == header.split(separator: ",").map({ String($0).lowercased() }) {
            dataRows = rows.dropFirst()
        } else {
            dataRows = rows[...]
        }

        return try dataRows.compactMap { row in
            guard row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return nil
            }
            guard row.count >= 4 else { throw TerminologyCSVError.invalidRow }
            let source = row[safe: 0]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let target = row[safe: 1]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fromCode = row[safe: 2]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "auto"
            let toCode = row[safe: 3]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let caseSensitive = parseBool(row[safe: 4]) ?? false
            let note = row[safe: 5]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let enabled = parseBool(row[safe: 6]) ?? true
            let entry = TerminologyEntry(
                source: source,
                target: target,
                from: fromCode == "auto" ? .auto : Language(code: fromCode),
                to: Language(code: toCode),
                note: note?.isEmpty == true ? nil : note,
                caseSensitive: caseSensitive,
                enabled: enabled
            )
            guard entry.isValid else { throw TerminologyCSVError.invalidRow }
            return entry
        }
    }

    public static func planImport(
        decoded: [TerminologyEntry],
        existing: [TerminologyEntry]
    ) -> TerminologyImportPlan {
        var added: [TerminologyEntry] = []
        var overwritten: [TerminologyEntry] = []
        var conflicts: [TerminologyEntry] = []

        for entry in decoded {
            let keyMatches: (TerminologyEntry) -> Bool = { other in
                other.trimmedSource.caseInsensitiveCompare(entry.trimmedSource) == .orderedSame
                    && (other.from.code ?? "auto") == (entry.from.code ?? "auto")
                    && (other.to.code ?? "auto") == (entry.to.code ?? "auto")
            }
            if let existingEntry = existing.first(where: keyMatches) {
                var replacement = entry
                replacement = TerminologyEntry(
                    id: existingEntry.id,
                    source: entry.source,
                    target: entry.target,
                    from: entry.from,
                    to: entry.to,
                    note: entry.note,
                    caseSensitive: entry.caseSensitive,
                    enabled: entry.enabled
                )
                overwritten.append(replacement)
            } else if added.contains(where: keyMatches) {
                conflicts.append(entry)
            } else {
                added.append(entry)
            }
        }
        return TerminologyImportPlan(added: added, overwritten: overwritten, conflicts: conflicts)
    }

    private static func encodeEntry(_ entry: TerminologyEntry) -> String {
        [
            entry.source,
            entry.target,
            entry.from.code ?? "auto",
            entry.to.code ?? "",
            entry.caseSensitive ? "true" : "false",
            entry.note ?? "",
            entry.enabled ? "true" : "false"
        ].map(escape).joined(separator: ",")
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func parseBool(_ raw: String?) -> Bool? {
        guard let raw else { return nil }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes", "y": return true
        case "false", "0", "no", "n": return false
        default: return nil
        }
    }

    private static func parseRows(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = csv.makeIterator()
        while let ch = iterator.next() {
            if inQuotes {
                if ch == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else if next != "\r" {
                                field.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == "," {
                row.append(field)
                field = ""
            } else if ch == "\n" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if ch != "\r" {
                field.append(ch)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

public enum TerminologyCSVError: Error, Equatable, Sendable {
    case invalidRow
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
