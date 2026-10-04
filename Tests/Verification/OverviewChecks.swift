import AppKit
import SwiftUI
import ApplicationServices

func runLayoutTest(args: [String]) {
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
}

func runBellClickTest() {
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
}

func runPopoverTest(args: [String]) {
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
            precondition((view.layer?.opacity ?? 0) > 0.99 && (view.layer?.presentation()?.opacity ?? 1) > 0.99,
                         "Popup content fade did not complete")
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
                    precondition((view.layer?.opacity ?? 0) > 0.99 && (view.layer?.presentation()?.opacity ?? 1) > 0.99,
                                 "Reopened popup content stayed transparent")
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
                    precondition((view.layer?.opacity ?? 0) > 0.99 && (view.layer?.presentation()?.opacity ?? 1) > 0.99,
                                 "Rapid toggles left content transparent")
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
}
