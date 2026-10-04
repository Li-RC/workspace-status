import AppKit
import SwiftUI
import ApplicationServices

func menuFixture() -> Snapshot {
    let bundles = ["com.apple.finder", "com.apple.Safari", "com.apple.iCal", "com.apple.mail",
                   "com.apple.Notes", "com.apple.Preview", "com.apple.Music", "com.apple.TextEdit"]
    var windows = bundles.enumerated().map {
        AppWindow(id: $0.offset, app: "App \($0.offset)", bundle: $0.element, title: "Test window", workspace: "1")
    }
    windows.append(AppWindow(id: 20, app: "App 0", bundle: bundles[0], title: "Second window", workspace: "1"))
    windows.append(AppWindow(id: 21, app: "Preview", bundle: bundles[5], title: "Test window", workspace: "2"))
    windows.append(AppWindow(id: 22, app: "Calendar", bundle: bundles[2], title: "Test window", workspace: "10"))
    return Snapshot(spaces: ["10", "3", "2", "1", "9"], current: "3", windows: windows)
}

let args = CommandLine.arguments
setbuf(stdout, nil)
if args.contains("--self-test") {
    let json = #"[{"window-id":42,"app-name":"Editor","app-bundle-id":"test.editor","window-title":"quote \" newline\n $(echo no)","workspace":"dev space"}]"#
    let windows = try JSONDecoder().decode([AppWindow].self, from: Data(json.utf8))
    precondition(windows[0].id == 42 && windows[0].workspace == "dev space")
    precondition(windows[0].title.contains("\n") && windows[0].title.contains("$(echo no)"))
    precondition(windows[0].isWorkspaceApplication)
    for bundle in ["local.WorkspaceStatus", "com.apple.notificationcenterui", "com.apple.UserNotificationCenter"] {
        precondition(!AppWindow(id: 0, app: "Utility", bundle: bundle, title: "Popup", workspace: "2").isWorkspaceApplication)
    }
    let snapshot = Snapshot(spaces: ["dev space", "empty"], current: "empty", windows: windows)
    precondition(snapshot.windows(in: "empty").isEmpty && snapshot.windows(in: "dev space").count == 1)
    let shortScreen = NSRect(x: 0, y: 40, width: 800, height: 500)
    let shortSize = overviewSize(visibleFrame: shortScreen, anchor: NSRect(x: 600, y: 540, width: 100, height: 24))
    precondition(shortSize.width + 28 <= shortScreen.width && shortSize.height + 28 <= shortScreen.height)
    let secondaryScreen = NSRect(x: -500, y: -700, width: 400, height: 600)
    let secondarySize = overviewSize(visibleFrame: secondaryScreen, anchor: NSRect(x: -200, y: -100, width: 80, height: 24))
    precondition(secondarySize.width + 28 <= secondaryScreen.width && secondarySize.height + 28 <= secondaryScreen.height)
    let tallSize = overviewSize(visibleFrame: shortScreen, anchor: NSRect(x: 600, y: 540, width: 24, height: 24), contentHeight: 1800)
    precondition(tallSize.height + 28 <= shortScreen.height && tallSize.width < 360)
    let fixture = menuFixture()
    precondition(fixture.occupiedSpaces == ["1", "2", "10"])
    precondition(fixture.menuSpaces == ["1", "2", "3", "10"])
    precondition(fixture.appBundles(in: "1").count == 8)
    precondition(fixture.appBundles(in: "1").first == "com.apple.finder")
    precondition(fixture.appBundles(in: "3").isEmpty)
    print("PASS: JSON, screen sizing, workspace ordering/filtering and all-app deduplication.")
} else if args.contains("--menu-test") {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        let fixture = menuFixture()
        delegate.workspaces.snapshot = fixture
        delegate.updateStatus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            precondition(delegate.menuOrder == ["1", "2", "3", "10"])
            let originalItem = delegate.item!
            let button = originalItem.button!
            let imageRect = button.cell!.imageRect(forBounds: button.bounds)
            precondition(imageRect.minX >= 1 && imageRect.minX <= 3, "Menu bar padding changed")
            precondition(imageRect.maxX <= button.bounds.maxX - 1, "Menu bar image clipped")
            precondition(iconStrip(fixture.appBundles(in: "1")).size.width == 8 * 21 + 4,
                         "App icons were truncated")
            let added = Snapshot(spaces: fixture.spaces + ["4"], current: fixture.current,
                windows: fixture.windows + [AppWindow(id: 100, app: "Finder", bundle: "com.apple.finder", title: "Added workspace", workspace: "4")])
            let emptyCurrent = Snapshot(spaces: fixture.spaces + ["5"], current: "5", windows: fixture.windows)
            for snapshot in [added, emptyCurrent, fixture, added, fixture] {
                delegate.workspaces.snapshot = snapshot
                delegate.updateStatus()
                precondition(delegate.item === originalItem && delegate.item.button === button,
                             "Workspace updates replaced the menu bar item")
                precondition(delegate.menuOrder == snapshot.menuSpaces)
                precondition(Set(delegate.workspaceFrames.keys) == Set(snapshot.menuSpaces),
                             "Workspace updates left missing or stale click regions")
                var rightEdge: CGFloat = 0
                for space in delegate.menuOrder {
                    let frame = delegate.workspaceFrames[space]!
                    precondition(abs(frame.minX - rightEdge) < 0.5, "Workspace regions overlap or have a gap")
                    rightEdge = frame.maxX
                }
                precondition(abs(delegate.bellFrame.minX - rightEdge) < 0.5, "Bell is detached from the workspace group")
                precondition(abs(delegate.bellFrame.maxX - delegate.item.length) < 0.5, "Controls extend beyond their menu bar item")
            }
            print("Workspace insertion, removal and empty-current changes keep one persistent menu bar item: PASS")
            print("Ordered workspace regions, compact padding and all 8 application icons: PASS")
            if let index = args.firstIndex(of: "--render-menu-preview"), args.count > index + 1 {
                let bitmap = button.bitmapImageRepForCachingDisplay(in: button.bounds)!
                button.cacheDisplay(in: button.bounds, to: bitmap)
                try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[index + 1]))
            }
            let frame = delegate.workspaceFrames[fixture.current]!
            let window = button.window!
            let workspacePoint = window.convertPoint(toScreen: button.convert(NSPoint(x: frame.midX, y: frame.midY), to: nil))
            for y in [window.frame.minY + 1, workspacePoint.y, window.frame.maxY - 1] {
                delegate.clickMenuBar(at: NSPoint(x: workspacePoint.x, y: y))
                precondition(!delegate.panel.isVisible, "A workspace click opened the dropdown")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                precondition(!delegate.panel.isVisible, "A workspace click opened the dropdown")
                precondition(delegate.workspaces.snapshot.current == fixture.current, "Current workspace click changed the workspace")
                print("Screen-coordinate workspace routing across the full menu bar height: PASS")
                if !args.contains("--hold-menu-preview") { exit(0) }
            }
        }
    }
    application.run()
} else if args.contains("--layout-test") {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    var initialFrame = NSRect.zero
    var expandedFrame = NSRect.zero
    func capture(_ suffix: String) {
        guard let index = args.firstIndex(of: "--render-layout-preview"), args.count > index + 1 else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(delegate.panel.windowNumber), args[index + 1] + "-" + suffix + ".png"]
        try! process.run(); process.waitUntilExit()
        precondition(process.terminationStatus == 0)
    }
    func check(_ step: Int) {
        let frame = delegate.panel.frame
        print("Layout step \(step): panel height \(frame.height), content height \(delegate.naturalHeight)")
        switch step {
        case 0:
            initialFrame = frame
            capture("collapsed")
            delegate.overviewState.expanded = ["1"]
        case 1:
            precondition(frame.height > initialFrame.height + 100, "Expanded windows did not grow the dropdown")
            precondition(abs(frame.maxY - initialFrame.maxY) < 1, "Expansion moved the top edge")
            expandedFrame = frame
            capture("expanded")
            let fixture = menuFixture()
            delegate.workspaces.snapshot = Snapshot(spaces: fixture.spaces + ["4"], current: fixture.current,
                windows: fixture.windows + [AppWindow(id: 100, app: "Finder", bundle: "com.apple.finder", title: "Added workspace", workspace: "4")])
            delegate.updateStatus()
        case 2:
            precondition(frame.height > expandedFrame.height + 20, "New workspace did not move lower sections down")
            precondition(abs(frame.maxY - initialFrame.maxY) < 1, "New workspace moved the top edge")
            delegate.overviewState.expanded = []
            delegate.workspaces.snapshot = menuFixture()
            delegate.updateStatus()
        case 3:
            precondition(abs(frame.height - initialFrame.height) < 2, "Collapsing did not restore natural height")
            let windows = (1...80).map { AppWindow(id: $0, app: "Finder", bundle: "com.apple.finder", title: "Test window", workspace: String($0)) }
            delegate.workspaces.snapshot = Snapshot(spaces: (1...80).map(String.init), current: "1", windows: windows)
            delegate.updateStatus()
        default:
            let screen = delegate.item.button!.window!.screen!
            precondition(screen.visibleFrame.insetBy(dx: -1, dy: -1).contains(frame), "Tall list went off screen")
            precondition(frame.width < 360, "Tall list was not scaled to fit")
            func containsScroll(_ view: NSView) -> Bool { view is NSScrollView || view.subviews.contains(where: containsScroll) }
            precondition(!containsScroll(delegate.panel.contentView!), "Dropdown still contains a scroll view")
            print("Expansion, new workspace and collapse resize downward: PASS")
            print("Anchored top, no scroll view and tall-list screen fit: PASS")
            delegate.panel.orderOut(nil)
            exit(0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { check(step + 1) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        delegate.workspaces.snapshot = menuFixture()
        delegate.notifications.authorized = true
        delegate.updateStatus()
        delegate.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { check(0) }
    }
    application.run()
} else if args.contains("--bell-click-test") {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    func clickBell(_ index: Int) {
        guard let button = delegate.item.button, let window = button.window else { exit(1) }
        var point = window.convertPoint(toScreen: button.convert(NSPoint(x: delegate.bellFrame.midX, y: delegate.bellFrame.midY), to: nil))
        point.y = index % 2 == 1 ? window.frame.minY + 1 : window.frame.maxY - 1
        delegate.dismissIfOutside(at: point)
        if index % 2 == 0 { precondition(delegate.panel.isVisible, "Bell press was dismissed before it could toggle closed") }
        delegate.clickMenuBar(at: point)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let expected = index % 2 == 1
            guard delegate.panel.isVisible == expected else {
                print("FAIL: bell screen-coordinate click \(index), expected \(expected ? "open" : "closed")")
                delegate.panel.orderOut(nil)
                exit(1)
            }
            print("Bell screen-coordinate click \(index): \(expected ? "OPEN" : "CLOSED")")
            if index < 4 { clickBell(index + 1) }
            else { delegate.workspaces.stop(); delegate.notifications.stop(); exit(0) }
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { clickBell(1) }
    application.run()
} else if args.contains("--popover-test") {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        if delegate.workspaceFrames[delegate.workspaces.snapshot.current] != nil {
            delegate.selectWorkspace(delegate.workspaces.snapshot.current)
            precondition(!delegate.panel.isVisible, "Current workspace must not open the popup")
        }
        delegate.toggle()
        precondition(delegate.panel.isVisible, "Bell failed to open the popup")
        if !args.contains("--render-popup-preview") {
            // Grow the scroll content after opening: the host must not enlarge/reposition the popup.
            let snapshot = delegate.workspaces.snapshot
            let longList = (1...80).map {
                AppWindow(id: $0, app: "Test app", bundle: "com.apple.finder", title: "Test window", workspace: String($0))
            }
            delegate.workspaces.snapshot = Snapshot(spaces: (1...80).map(String.init), current: snapshot.current, windows: longList)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let view = delegate.panel.contentViewController?.view, let window = view.window,
                  let screen = delegate.item.button?.window?.screen else {
                print("FAIL: popup window or status-item display missing")
                exit(1)
            }
            let frame = window.frame
            let available = screen.visibleFrame
            let contentFrame = window.convertToScreen(view.convert(view.bounds, to: nil))
            // A borderless panel and its content must both fit the usable area.
            let fits = screen.frame.insetBy(dx: -1, dy: -1).contains(frame)
                && available.insetBy(dx: -1, dy: -1).contains(contentFrame)
            print("Popup frame: \(frame)")
            print("Popup content frame: \(contentFrame)")
            print("Display usable frame: \(available)")
            print("Content size: \(delegate.panel.contentView!.bounds.size)")
            print("Popup opacity: \(window.alphaValue)")
            precondition(window.alphaValue > 0.99, "Popup fade did not complete")
            print("Status button flipped: \(delegate.item.button?.isFlipped ?? false)")
            precondition(!window.styleMask.contains(.titled), "Popup has window chrome")
            precondition(window.backgroundColor == .clear && !window.isOpaque, "Popup background is not borderless")
            precondition(!window.hasShadow, "Backdrop still has a rectangular window shadow")
            precondition(view.subviews.count == 1 && !(view.subviews.first is NSVisualEffectView),
                         "An extra backdrop blur is still present")
            precondition(view.subviews.first?.frame == view.bounds && view.subviews.first?.alphaValue == 1,
                         "Glass controls were faded or do not fill the panel")
            print("Transparent background without extra blur, native glass and bell-only dropdown: PASS")
            if let index = args.firstIndex(of: "--render-popup-preview"), args.count > index + 1 {
                // Native blur/glass is composited by WindowServer, outside cacheDisplay.
                let capture = Process()
                capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), args[index + 1]]
                try! capture.run(); capture.waitUntilExit()
                precondition(capture.terminationStatus == 0, "Popup window capture failed")
                let desktopCapture = Process()
                desktopCapture.executableURL = capture.executableURL
                let desktopTop = NSScreen.screens.first!.frame.maxY
                let region = "\(Int(frame.minX)),\(Int(desktopTop - frame.maxY)),\(Int(frame.width)),\(Int(frame.height))"
                let compositePath = URL(fileURLWithPath: args[index + 1]).deletingPathExtension().path + "-composited.png"
                desktopCapture.arguments = ["-x", "-R", region, compositePath]
                try! desktopCapture.run(); desktopCapture.waitUntilExit()
                precondition(desktopCapture.terminationStatus == 0, "Composited popup capture failed")
            }
            print("Popup containment: \(fits ? "PASS" : "FAIL")")
            let bell = delegate.item.button!
            let bellFrame = bell.window!.convertToScreen(bell.convert(delegate.bellFrame, to: nil))
            delegate.dismissIfOutside(at: NSPoint(x: bellFrame.midX, y: bellFrame.midY))
            precondition(delegate.panel.isVisible, "Bell mouse-down dismissed the popup before its toggle action")
            delegate.toggle()
            precondition(!delegate.panel.isPresented, "Second bell click did not start dismissal")
            func checkTransition(_ step: Int) {
                switch step {
                case 0:
                    precondition(!delegate.panel.isVisible, "Close animation did not finish")
                    delegate.toggle()
                case 1:
                    precondition(delegate.panel.isVisible && delegate.panel.alphaValue > 0.99, "Open animation did not finish")
                    precondition(delegate.panel.contentView?.layer?.transform.m42 == 0, "Open animation left content displaced")
                    delegate.panel.cancelOperation(nil)
                case 2:
                    precondition(!delegate.panel.isVisible, "Escape did not finish dismissal")
                    delegate.toggle()
                case 3:
                    delegate.dismissIfOutside(at: NSPoint(x: delegate.panel.frame.minX - 10, y: delegate.panel.frame.minY - 10))
                    precondition(!delegate.panel.isPresented, "Outside click did not start dismissal")
                case 4:
                    precondition(!delegate.panel.isVisible, "Outside click did not finish dismissal")
                    delegate.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                        delegate.toggle()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { delegate.toggle() }
                    }
                default:
                    precondition(delegate.panel.isPresented && delegate.panel.isVisible && delegate.panel.alphaValue > 0.99,
                                 "Interrupted close animation hid the reopened popup")
                    precondition(delegate.panel.contentView?.layer?.transform.m42 == 0, "Rapid toggles left content displaced")
                    print("Bell mouse-down exclusion, animated toggle, outside click and Escape dismissal: PASS")
                    print("Rapid close/reopen keeps the dropdown visible and fully opaque: PASS")
                    delegate.workspaces.stop(); delegate.notifications.stop()
                    exit(fits ? 0 : 1)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { checkTransition(step + 1) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { checkTransition(0) }
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
    var overview = Overview(workspaces: workspace, notifications: notifications, close: {}, state: OverviewState(), resized: { _ in })
    overview.canvasHeight = overview.contentHeight
    let hosting = NSHostingView(rootView: overview)
    hosting.frame = NSRect(x: 0, y: 0, width: 360, height: overview.contentHeight)
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
