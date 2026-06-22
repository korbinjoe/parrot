import Foundation

struct EngineModelConfig: Identifiable, Codable, Equatable {
    static let primaryID = "primary"
    static let providerSeparator = "#"

    var id: String
    var name: String
    var enabled: Bool

    init(id: String = UUID().uuidString, name: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.enabled = enabled
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func providerID(engineID: String) -> String {
        id == Self.primaryID ? engineID : "\(engineID)\(Self.providerSeparator)\(id)"
    }

    static func baseEngineID(forProviderID providerID: String) -> String {
        providerID.components(separatedBy: providerSeparator).first ?? providerID
    }
}
