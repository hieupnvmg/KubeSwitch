// Runs only in an isolated test bundle; checks the real Sparkle feed validator.
import Cocoa
import Sparkle

final class Probe: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    var updater: SPUUpdater!
    var loaded = false
    let expectsRejection = CommandLine.arguments.contains("--reject")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let driver = SPUStandardUserDriver(hostBundle: .main, delegate: nil)
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        do { try updater.start() } catch { print("START ERROR: \(error)"); exit(2) }
        updater.checkForUpdateInformation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { print("TIMEOUT"); exit(3) }
    }
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) { loaded = true }
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        print("FOUND \(item.versionString)")
        exit(expectsRejection ? 1 : 0)
    }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        print("REJECTED: \(error)")
        exit(expectsRejection && !loaded ? 0 : 1)
    }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) { print("NO UPDATE"); exit(1) }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let probe = Probe()
app.delegate = probe
app.run()
