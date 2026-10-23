/// Keeps every result state in the user's configured engine/model order.
/// Historical or plugin providers absent from that configuration retain their
/// relative order after the configured providers.
enum TranslationResultOrdering {
    static func ordered<Value>(
        _ values: [Value],
        providerOrder: [String],
        providerID: KeyPath<Value, String>
    ) -> [Value] {
        var ranks: [String: Int] = [:]
        for (index, id) in providerOrder.enumerated() where ranks[id] == nil {
            ranks[id] = index
        }
        return values.enumerated().sorted { lhs, rhs in
            let left = ranks[lhs.element[keyPath: providerID]] ?? Int.max
            let right = ranks[rhs.element[keyPath: providerID]] ?? Int.max
            return left == right ? lhs.offset < rhs.offset : left < right
        }.map(\.element)
    }
}
