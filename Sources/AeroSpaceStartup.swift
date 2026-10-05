import AppKit

enum AeroSpaceStartupStatus: Equatable {
    case missing
    case notRunning(URL)
    case ready

    static func detect(applicationURL: URL?, running: Bool) -> Self {
        guard let applicationURL else { return .missing }
        return running ? .ready : .notRunning(applicationURL)
    }

    func alert() -> NSAlert? {
        guard self != .ready else { return nil }
        let alert = NSAlert()
        alert.alertStyle = .informational
        switch self {
        case .missing:
            alert.messageText = "Install AeroSpace to use Workspace Status"
            alert.informativeText = "Workspace Status uses AeroSpace to display and switch workspaces. Install AeroSpace, then open it to get started."
            alert.addButton(withTitle: "Install AeroSpace…")
        case .notRunning:
            alert.messageText = "AeroSpace is not running"
            alert.informativeText = "Open AeroSpace to display your workspaces and switch between them."
            alert.addButton(withTitle: "Open AeroSpace")
        case .ready: break
        }
        alert.addButton(withTitle: "Not Now")
        return alert
    }
}

extension AppDelegate {
    @discardableResult func promptForAeroSpaceIfNeeded() -> Bool {
        guard !aeroSpacePromptVisible else { return true }
        let status = AeroSpaceStartupStatus.detect(applicationURL: AeroSpace.applicationURL,
            running: !NSRunningApplication.runningApplications(withBundleIdentifier: AeroSpace.bundleIdentifier).isEmpty)
        guard let alert = status.alert() else { return false }
        aeroSpacePromptVisible = true
        defer { aeroSpacePromptVisible = false }
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return true }
        switch status {
        case .missing:
            NSWorkspace.shared.open(URL(string: "https://nikitabobko.github.io/AeroSpace/guide#installation")!)
        case .notRunning(let url):
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, error in
                DispatchQueue.main.async {
                    if let error {
                        let failure = NSAlert()
                        failure.messageText = "Could not open AeroSpace"
                        failure.informativeText = error.localizedDescription
                        NSApp.activate(ignoringOtherApps: true)
                        failure.runModal()
                    } else {
                        self?.workspaces.refresh()
                    }
                }
            }
        case .ready: break
        }
        return true
    }
}
