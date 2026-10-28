import Foundation

struct Config: Decodable {
    let path: String
    let contexts: [String]
    let current: String?

    func matching(_ query: String) -> Config? {
        let tokens = Self.normalized(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return self }
        let matches = contexts.filter { context in
            let text = Self.normalized(path + "\n" + context)
            return tokens.allSatisfy { text.contains($0) }
        }
        guard !matches.isEmpty else { return nil }
        return Config(path: path, contexts: matches, current: current)
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
    }
}
