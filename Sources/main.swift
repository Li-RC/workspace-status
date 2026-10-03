import AppKit
import SwiftUI
import ApplicationServices

let args = CommandLine.arguments
if args.contains("--self-test") {
    let json = #"[{"window-id":42,"app-name":"Editor","app-bundle-id":"test.editor","window-title":"quote \" newline\n $(echo no)","workspace":"dev space"}]"#
    let windows = try JSONDecoder().decode([AppWindow].self, from: Data(json.utf8))
    precondition(windows[0].id == 42 && windows[0].workspace == "dev space")
    precondition(windows[0].title.contains("\n") && windows[0].title.contains("$(echo no)"))
    let snapshot = Snapshot(spaces: ["dev space", "empty"], current: "empty", windows: windows)
    precondition(snapshot.windows(in: "empty").isEmpty && snapshot.windows(in: "dev space").count == 1)
    let apps = ["Mail": "com.apple.mail", "Messages": "com.apple.MobileSMS"]
    precondition(notificationSource(["Mail", "Inbox", "Mail"], apps: apps) == "com.apple.mail")
    precondition(notificationSource(["Mail", "Messages"], apps: apps) == nil)
    precondition(notificationSource(["You have Mail", "2 notifications"], apps: apps) == nil)
    precondition(notificationSource([], apps: apps) == nil)
    let shortScreen = NSRect(x: 0, y: 40, width: 800, height: 500)
    let shortSize = overviewSize(visibleFrame: shortScreen, anchor: NSRect(x: 600, y: 540, width: 100, height: 24))
    precondition(shortSize.width + 28 <= shortScreen.width && shortSize.height + 28 <= shortScreen.height)
    let secondaryScreen = NSRect(x: -500, y: -700, width: 400, height: 600)
    let secondarySize = overviewSize(visibleFrame: secondaryScreen, anchor: NSRect(x: -200, y: -100, width: 80, height: 24))
    precondition(secondarySize.width + 28 <= secondaryScreen.width && secondarySize.height + 28 <= secondaryScreen.height)
    print("PASS: JSON decoding, workspace contents, notification attribution, compact and secondary display sizing.")
} else if args.contains("--popover-test") {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        delegate.toggle()
        // Grow the scroll content after opening: the host must not enlarge/reposition the popup.
        let snapshot = delegate.workspaces.snapshot
        delegate.workspaces.snapshot = Snapshot(spaces: (1...80).map(String.init), current: snapshot.current, windows: snapshot.windows)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let view = delegate.popover.contentViewController?.view, let window = view.window,
                  let screen = delegate.item.button?.window?.screen else {
                print("FAIL: popup window or status-item display missing")
                exit(1)
            }
            let frame = window.frame
            let available = screen.visibleFrame
            let contentFrame = window.convertToScreen(view.convert(view.bounds, to: nil))
            // The arrow can overlap the menu bar; the content must fit the usable area.
            let fits = screen.frame.insetBy(dx: -1, dy: -1).contains(frame)
                && available.insetBy(dx: -1, dy: -1).contains(contentFrame)
            print("Popup frame: \(frame)")
            print("Popup content frame: \(contentFrame)")
            print("Display usable frame: \(available)")
            print("Content size: \(delegate.popover.contentSize)")
            print("Status button flipped: \(delegate.item.button?.isFlipped ?? false)")
            print("Popup containment: \(fits ? "PASS" : "FAIL")")
            delegate.popover.close()
            delegate.workspaces.stop(); delegate.notifications.stop()
            exit(fits ? 0 : 1)
        }
    }
    application.run()
} else if args.contains("--diagnose") {
    do {
        let snapshot = try AeroSpace.snapshot()
        let result: [String: Any] = ["currentWorkspace": snapshot.current, "workspaces": snapshot.spaces,
            "windowCount": snapshot.windows.count, "accessibilityEnabled": AXIsProcessTrusted(),
            "appsByWorkspace": Dictionary(uniqueKeysWithValues: snapshot.spaces.map {
                ($0, Array(Set(snapshot.windows(in: $0).map(\.app))).sorted())
            })]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
} else if let index = args.firstIndex(of: "--render-preview"), args.count > index + 1 {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let workspace = WorkspaceModel(), notifications = NotificationModel()
    workspace.snapshot = try AeroSpace.snapshot()
    let hosting = NSHostingView(rootView: Overview(workspaces: workspace, notifications: notifications, close: {}))
    hosting.frame = NSRect(x: 0, y: 0, width: 430, height: 650)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = hosting
    hosting.layoutSubtreeIfNeeded()
    guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { exit(1) }
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[index + 1]))
    print("Rendered live workspace overview.")
} else {
    let application = NSApplication.shared
    // Launch Services normally prevents a second instance; also protect direct executable launches.
    let bundle = Bundle.main.bundleIdentifier ?? "local.WorkspaceStatus"
    if NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
        .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) { exit(0) }
    let delegate = AppDelegate()
    application.delegate = delegate
    if args.contains("--smoke-test") {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            let healthy = !delegate.workspaces.snapshot.spaces.isEmpty && delegate.workspaces.error == nil
                && delegate.item.button?.image != nil
            print("Menu bar runtime: \(healthy ? "PASS" : "FAIL")")
            print("Current workspace: \(delegate.workspaces.snapshot.current)")
            print("Workspaces: \(delegate.workspaces.snapshot.spaces.count)")
            print("Notification monitor: \(delegate.notifications.monitorStatus)")
            print("Dock apps with badges: \(delegate.notifications.badges.count)")
            if let error = delegate.workspaces.error { print(error) }
            delegate.workspaces.stop(); delegate.notifications.stop()
            exit(healthy ? 0 : 1)
        }
    }
    application.run()
}
