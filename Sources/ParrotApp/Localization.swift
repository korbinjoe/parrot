import Foundation

enum L10n {
    static func string(_ key: String, _ args: CVarArg...) -> String {
        string(key, arguments: args)
    }

    static func string(_ key: String, arguments: [CVarArg]) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}

func L(_ key: String, _ args: CVarArg...) -> String {
    L10n.string(key, arguments: args)
}
