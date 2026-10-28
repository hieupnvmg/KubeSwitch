import Foundation

@main
struct SearchTests {
    static func main() {
        let source = Config(path: "/configs/Hồ-Chí-Minh/team.yaml", contexts: ["dev-api", "prod-api", "prod-db"], current: "dev-api")
        assert(source.matching("  \n ")?.contexts == source.contexts)
        assert(source.matching("TEAM.YAML")?.contexts == source.contexts)
        assert(source.matching("ho-chi-minh")?.path == source.path)
        assert(source.matching("PROD")?.contexts == ["prod-api", "prod-db"])
        assert(source.matching("team.yaml  prod  db")?.contexts == ["prod-db"])
        assert(source.matching("dev prod") == nil)
        assert(source.matching("missing") == nil)
        let vietnamese = Config(path: "/Đà-Nẵng/config", contexts: ["Cụm-Đông"], current: nil)
        assert(vietnamese.matching("da-nang cum-dong") != nil)
        let other = Config(path: "/other/team.yaml", contexts: ["stage"], current: "stage")
        let matches = [source, other].compactMap { $0.matching("other stage") }
        assert(matches.count == 1 && matches[0].path == other.path)
        assert(source.contexts.count == 3 && source.current == "dev-api")
        print("PASS: filename/path/context search, case, accents, whitespace, multiword matching, duplicate filenames and source preservation.")
    }
}
