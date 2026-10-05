import AppKit

func runAeroSpaceStartupTests() {
    let installed = URL(fileURLWithPath: "/Applications/AeroSpace.app")
    for running in [false, true] {
        let missing = AeroSpaceStartupStatus.detect(applicationURL: nil, running: running)
        precondition(missing == .missing)
        let alert = missing.alert()!
        precondition(alert.messageText.contains("Install AeroSpace"))
        precondition(alert.buttons.map(\.title) == ["Install AeroSpace…", "Not Now"])
    }
    let stopped = AeroSpaceStartupStatus.detect(applicationURL: installed, running: false)
    precondition(stopped == .notRunning(installed), "The Open action lost the installed application URL")
    precondition(stopped.alert()!.buttons.map(\.title) == ["Open AeroSpace", "Not Now"])
    let ready = AeroSpaceStartupStatus.detect(applicationURL: installed, running: true)
    precondition(ready == .ready && ready.alert() == nil, "Running AeroSpace triggered a startup prompt")
    print("PASS: missing AeroSpace install prompt, stopped app Open prompt and silent ready startup.")
}
