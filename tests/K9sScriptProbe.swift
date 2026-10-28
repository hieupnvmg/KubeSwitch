import Foundation

@main
struct ScriptProbe {
    static func main() throws {
        try K9sLaunch.script(kubeconfig: CommandLine.arguments[2], context: CommandLine.arguments[3])
            .write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
    }
}
