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
    let display = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let saved = NSRect(x: 1020, y: 876, width: 320, height: 24)
    func strip(_ screen: NSRect = display, notch: Bool = false, menus: CGFloat = 480,
               status: CGFloat = 1120, width: CGFloat = 320) -> NSRect? {
        menuStripFrame(screen: screen, hasNotch: notch, native: saved, menuEnd: menus,
                       statusStart: status, width: width, height: 24)
    }
    precondition(strip(notch: true, menus: 1200) == saved, "Notched display lost its saved position")
    precondition(strip() == NSRect(x: 560, y: 876, width: 320, height: 24), "A clear center was not used")
    precondition(strip(menus: 600)?.minX == 608, "Long app menus should place the strip just after them")
    precondition(strip(menus: 400, status: 850)?.minX == 408, "Right-side icons overlapped a centered strip")
    precondition(strip(menus: 700, status: 900)?.width == 184, "A crowded bar overlapped other icons")
    precondition(strip(menus: 900, status: 900) == nil, "A strip was drawn without any available space")
    let offsetDisplay = NSRect(x: -1600, y: -400, width: 1600, height: 1000)
    precondition(strip(offsetDisplay, menus: -1200, status: -300)?.midX == -800,
                 "A secondary display was centered using primary-display coordinates")
    precondition(menuStripFrame(screen: display, hasNotch: true, native: nil, menuEnd: 0,
        statusStart: 1440, width: 320, height: 24) == nil, "A missing native slot invented a notched position")
    print("PASS: saved notched position; non-notched centering, after-menus placement, crowded bars and display offsets.")
    let fixture = menuFixture()
    precondition(fixture.occupiedSpaces == ["1", "2", "10"])
    precondition(fixture.menuSpaces == ["1", "2", "3", "10"])
    precondition(fixture.appBundles(in: "1").count == 8)
    precondition(fixture.appBundles(in: "1").first == "com.apple.finder")
    precondition(fixture.appBundles(in: "3").isEmpty)
    let model = WorkspaceModel()
    model.snapshot = Snapshot(spaces: fixture.spaces, current: "1", windows: fixture.windows)
    precondition(model.navigationArguments(to: "2", appBundle: "com.apple.Preview") == ["workspace", "2"])
    precondition(model.navigationArguments(to: "2", appBundle: "com.apple.Preview", focusApp: true) == ["focus", "--window-id", "21"])
    precondition(model.navigationArguments(to: "2", appBundle: "missing.app", focusApp: true) == nil)
    precondition(model.navigationArguments(to: "1") == nil)
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "0"])
    model.consumeEvents(Data(#"{"_event":"focus-changed","windowId":20}"#.utf8))
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "0"],
                 "A partial event changed focus history")
    model.consumeEvents(Data("\n{\"_event\":\"mode-changed\",\"mode\":\"main\"}\n{\"_event\":\"focus-changed\",\"windowId\":21}\n".utf8))
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "20"])
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.Preview") == ["focus", "--window-id", "5"],
                 "App focus crossed into another workspace")
    model.consumeEvents(Data("invalid JSON\n{\"_event\":\"focus-changed\",\"windowId\":null}\n{\"_event\":\"focus-changed\",\"windowId\":0}\n".utf8))
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "0"])
    model.snapshot = Snapshot(spaces: fixture.spaces, current: "1", windows: fixture.windows.filter { $0.id != 0 })
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "20"],
                 "App focus selected a closed window")
    precondition(model.navigationArguments(to: "1", appBundle: "missing.app") == nil)
    print("PASS: inactive switching, current-app focus, streamed focus history and closed-window fallback.")
    print("PASS: JSON, screen sizing, workspace ordering/filtering and all-app deduplication.")
} else if args.contains("--app-click-test") {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    let button = AppClickButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    var actions: [String] = []
    button.singleClick = { actions.append("single") }
    button.doubleClick = { actions.append("double") }
    button.target = button
    button.action = #selector(AppClickButton.activate)
    let hosting = NSHostingView(rootView: WorkspaceAppButton(bundle: "com.apple.finder", name: "Finder",
        current: false, space: "1", singleClick: {}, doubleClick: {}).frame(width: 20, height: 20))
    hosting.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
    hosting.layoutSubtreeIfNeeded()
    func findButton(in view: NSView) -> AppClickButton? {
        (view as? AppClickButton) ?? view.subviews.compactMap { findButton(in: $0) }.first
    }
    let hostedButton = findButton(in: hosting)!
    precondition(hostedButton.frame.size == NSSize(width: 20, height: 20), "App buttons changed the icon layout")
    func click(_ count: Int) { button.handleMouseClick(count: count) }
    let wait = NSEvent.doubleClickInterval + 0.15
    click(1)
    precondition(actions.isEmpty, "An inactive app switched before double-click recognition")
    click(2)
    precondition(actions == ["double"])
    DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
        precondition(actions == ["double"], "A double-click also ran the pending single click")
        actions = []
        click(1)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            precondition(actions == ["single"], "An inactive app single click never completed")
            actions = []
            click(1)
            button.performClick(nil)
            precondition(actions == ["single"], "Keyboard activation did not act immediately")
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                precondition(actions == ["single"], "Keyboard activation left a duplicate pending click")
                print("Dropdown app single/double clicks, cancellation and keyboard activation: PASS")
                exit(0)
            }
        }
    }
    application.run()
} else if args.contains("--placement-test") {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let fixture = menuFixture()
        delegate.workspaces.snapshot = Snapshot(spaces: fixture.spaces, current: "1", windows: fixture.windows)
        delegate.updateStatus()
        let item = delegate.item!
        let button = item.button!, native = button.window!
        let screen = native.screen!
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        let nativeFrame = native.convertToScreen(button.convert(button.bounds, to: nil))
        let requestedFrame = NSRect(x: nativeFrame.minX, y: screen.frame.maxY - 39, width: item.length * 0.75, height: 39)
        // Install the real renderer and click callback without starting live geometry polling.
        delegate.placement.start(item: item, image: { delegate.statusImage },
            click: { point, time in delegate.clickMenuBar(at: point, timestamp: time) })
        delegate.placement.stop()
        delegate.placement.display(frames: [id: requestedFrame], reserveNativeSlot: false)
        let overlay = delegate.placement.overlays[id]!
        let frame = overlay.frame
        let view = overlay.contentView as! MenuStripView
        precondition(!item.isVisible && delegate.placement.usesOverlays && overlay.isVisible)
        precondition(!overlay.isOpaque && !overlay.hasShadow && abs(view.scale - 0.75) <= 1 / item.length,
                     "Positioned strip opacity=\(overlay.isOpaque), shadow=\(overlay.hasShadow), scale=\(view.scale), bounds=\(view.bounds)")
        precondition(view.image?.tiffRepresentation != nil, "The positioned strip lost its image when the native item was hidden")
        func point(_ x: CGFloat, _ y: CGFloat? = nil) -> NSPoint {
            NSPoint(x: frame.minX + x * view.scale, y: y ?? frame.midY)
        }
        let preview = delegate.appFrames["2"]!["com.apple.Preview"]!
        let finder = delegate.appFrames["1"]!["com.apple.finder"]!
        for (index, y) in [frame.minY + 1, frame.midY, frame.maxY - 1].enumerated() {
            precondition(delegate.menuNavigation(at: point(preview.midX + 2, y), timestamp: Double(index * 10 + 1)).arguments == ["workspace", "2"],
                         "An inactive app in the positioned strip did not switch its workspace")
        }
        precondition(delegate.menuNavigation(at: point(finder.midX + 2), timestamp: 40).arguments == ["focus", "--window-id", "0"],
                     "An active app in the positioned strip did not focus")
        let previewPoint = point(preview.midX + 2)
        precondition(delegate.menuNavigation(at: previewPoint, timestamp: 50).arguments == ["workspace", "2"])
        precondition(delegate.menuNavigation(at: previewPoint, timestamp: 50 + NSEvent.doubleClickInterval / 2).arguments == ["focus", "--window-id", "21"])
        delegate.workspaces.snapshot = Snapshot(spaces: fixture.spaces, current: "2", windows: fixture.windows)
        delegate.updateStatus()
        precondition(view.image === delegate.statusImage && view.contentWidth == item.length,
                     "The positioned strip showed stale icons while click regions updated")
        precondition(delegate.menuNavigation(at: previewPoint, timestamp: 55).arguments == ["focus", "--window-id", "21"])
        delegate.placement.display(frames: [id: frame], reserveNativeSlot: true)
        precondition(item.isVisible, "A mixed-display setup lost its reserved native position")
        let bell = point(delegate.bellFrame.midX)
        delegate.clickMenuBar(at: bell)
        precondition(delegate.panel.isPresented, "A positioned bell could not open the dropdown")
        precondition(delegate.panel.frame.maxY <= frame.minY && screen.visibleFrame.contains(delegate.panel.frame),
                     "The positioned bell anchored the dropdown to the wrong screen")
        delegate.dismissIfOutside(at: point(delegate.bellFrame.midX, frame.maxY - 1))
        precondition(delegate.panel.isPresented, "The positioned bell was treated as an outside click")
        let eventPoint = overlay.convertPoint(fromScreen: bell)
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: eventPoint, modifierFlags: [],
            timestamp: 60, windowNumber: overlay.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        view.mouseDown(with: event)
        precondition(!delegate.panel.isPresented, "A real overlay mouse event failed to toggle the dropdown closed")
        precondition(view.accessibilityPerformPress() && delegate.panel.isPresented,
                     "Accessibility activation could not open the positioned dropdown")
        delegate.panel.dismiss()
        delegate.placement.stop()
        precondition(item.isVisible && !delegate.placement.usesOverlays && !overlay.isVisible)
        precondition(item.button?.image === delegate.statusImage, "Stopping placement did not restore the native strip")
        print("Positioned strip rendering, scaled clicks, app focus, double click, bell toggle, popup anchoring and native restoration: PASS")
        exit(0)
    }
    application.run()
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
            delegate.workspaces.snapshot = Snapshot(spaces: fixture.spaces, current: "1", windows: fixture.windows)
            delegate.workspaces.consumeEvents(Data("{\"_event\":\"focus-changed\",\"windowId\":20}\n".utf8))
            delegate.updateStatus()
            for space in delegate.menuOrder where space != "1" {
                let frame = delegate.workspaceFrames[space]!
                for x in stride(from: frame.minX + 0.5, to: frame.maxX, by: 1) {
                    precondition(delegate.navigationArguments(at: NSPoint(x: x, y: 11)) == ["workspace", space],
                                 "Part of an inactive workspace group did not select its workspace")
                }
            }
            let activeFrame = delegate.workspaceFrames["1"]!
            precondition(delegate.navigationArguments(at: NSPoint(x: activeFrame.minX + 11, y: 11)) == nil,
                         "The current workspace number changed focus")
            for (index, bundle) in fixture.appBundles(in: "1").enumerated() {
                let left = imageRect.minX + activeFrame.minX + workspaceBadge("1").size.width + 6 + CGFloat(index * 21)
                let id = bundle == "com.apple.finder" ? 20 : fixture.windows(in: "1").first { $0.bundle == bundle }!.id
                for x in [left + 0.5, left + 8, left + 15.5] {
                    precondition(delegate.navigationArguments(at: NSPoint(x: x, y: 11)) == ["focus", "--window-id", String(id)],
                                 "An app icon selected the wrong window")
                }
                precondition(delegate.navigationArguments(at: NSPoint(x: left - 0.5, y: 11)) == nil,
                             "Space between app icons changed focus")
            }
            precondition(delegate.navigationArguments(at: NSPoint(x: delegate.bellFrame.midX, y: 11)) == nil)
            delegate.workspaces.snapshot = fixture
            delegate.updateStatus()
            print("Whole inactive groups switch; all active app icons focus their own most recent window: PASS")
            let window = button.window!
            let previewFrame = delegate.appFrames["2"]!["com.apple.Preview"]!
            let previewPoint = window.convertPoint(toScreen: button.convert(
                NSPoint(x: previewFrame.midX + imageRect.minX, y: 11), to: nil))
            precondition(delegate.menuNavigation(at: previewPoint, timestamp: 10).arguments == ["workspace", "2"])
            precondition(delegate.menuNavigation(at: previewPoint, timestamp: 10 + NSEvent.doubleClickInterval / 2).arguments == ["focus", "--window-id", "21"],
                         "A double-click did not focus an app in an inactive workspace")
            precondition(delegate.menuNavigation(at: previewPoint, timestamp: 20).arguments == ["workspace", "2"])
            delegate.workspaces.snapshot = Snapshot(spaces: fixture.spaces + ["0"], current: "2",
                windows: fixture.windows + [AppWindow(id: 200, app: "Finder", bundle: "com.apple.finder", title: "Layout change", workspace: "0")])
            delegate.updateStatus()
            precondition(delegate.menuNavigation(at: previewPoint, timestamp: 20 + NSEvent.doubleClickInterval / 2).arguments == ["focus", "--window-id", "21"],
                         "Menu bar rearrangement changed the double-click's app target")
            delegate.workspaces.snapshot = fixture
            delegate.updateStatus()
            precondition(delegate.menuNavigation(at: previewPoint, timestamp: 30).arguments == ["workspace", "2"])
            precondition(delegate.menuNavigation(at: previewPoint, timestamp: 30 + NSEvent.doubleClickInterval + 0.1).arguments == ["workspace", "2"],
                         "Separate single clicks were mistaken for a double-click")
            let bellPoint = window.convertPoint(toScreen: button.convert(NSPoint(x: delegate.bellFrame.midX, y: 11), to: nil))
            precondition(!delegate.menuNavigation(at: bellPoint, timestamp: 40).workspaceClick)
            print("Inactive app double-click focus, original target after rearrangement and system click timing: PASS")
            if let index = args.firstIndex(of: "--render-menu-preview"), args.count > index + 1 {
                let bitmap = button.bitmapImageRepForCachingDisplay(in: button.bounds)!
                button.cacheDisplay(in: button.bounds, to: bitmap)
                try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[index + 1]))
            }
            let frame = delegate.workspaceFrames[fixture.current]!
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
} else if args.contains("--diagnose") {
    do {
        let snapshot = try AeroSpace.snapshot()
        var result: [String: Any] = ["currentWorkspace": snapshot.current, "workspaces": snapshot.spaces,
            "windowCount": snapshot.windows.count, "accessibilityEnabled": AXIsProcessTrusted(),
            "appsByWorkspace": Dictionary(uniqueKeysWithValues: snapshot.spaces.map {
                ($0, Array(Set(snapshot.windows(in: $0).map(\.app))).sorted())
            })]
        let screens = NSScreen.screens
        if AXIsProcessTrusted(), let geometry = MenuGeometry.read(top: screens.first?.frame.maxY ?? 0) {
            result["menuPlacement"] = ["applicationMenuWidth": geometry.menuWidth,
                "visibleMenuBars": geometry.bars.count, "statusIconCount": geometry.statusItems.count,
                "displays": screens.count, "notchedDisplays": screens.filter { $0.auxiliaryTopLeftArea != nil }.count]
        }
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
} else if let index = args.firstIndex(of: "--render-preview"), args.count > index + 1 {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let workspace = WorkspaceModel(), notifications = NotificationModel()
    workspace.snapshot = try AeroSpace.snapshot()
    var overview = Overview(workspaces: workspace, notifications: notifications, placement: MenuPlacement(), close: {}, state: OverviewState(), resized: { _ in })
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
    if args.contains("--placement-live-test") {
        guard let index = args.firstIndex(of: "--menu-command"), args.count > index + 1 else {
            print("FAIL: start Tests/MenuFixture.swift and provide its --menu-command file"); exit(1)
        }
        let commandURL = URL(fileURLWithPath: args[index + 1])
        func setMenus(long: Bool) {
            try! (long ? "long" : "short").write(to: commandURL, atomically: true, encoding: .utf8)
            delegate.placement.refresh()
        }
        var notchedFrames: [CGDirectDisplayID: NSRect] = [:]
        func check(long: Bool) {
            guard delegate.placement.usesOverlays else {
                print("FAIL: live placement unavailable; Accessibility=\(AXIsProcessTrusted()), reason=\(delegate.placement.notice ?? "none")")
                exit(1)
            }
            var externalCount = 0
            for screen in NSScreen.screens {
                let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
                guard let overlay = delegate.placement.overlays[id], overlay.isVisible,
                      let view = overlay.contentView as? MenuStripView else {
                    print("FAIL: no strip on \(screen.localizedName)"); exit(1)
                }
                print("Live \(long ? "long" : "short") menus: \(screen.localizedName), strip=\(overlay.frame), menu width=\(delegate.placement.menuWidth)")
                if screen.auxiliaryTopLeftArea != nil {
                    if long { precondition(overlay.frame == notchedFrames[id], "The notched display moved when app menus changed") }
                    else { notchedFrames[id] = overlay.frame }
                } else {
                    externalCount += 1
                    let statusStart = delegate.placement.statusStarts[id]!
                    let left = screen.frame.minX + delegate.placement.menuWidth + 8
                    let centered = screen.frame.midX - view.contentWidth / 2
                    let canCenter = centered >= left && centered + view.contentWidth <= statusStart - 8
                    if canCenter {
                        precondition(abs(overlay.frame.midX - screen.frame.midX) <= 1,
                                     "The external strip was not centered when there was room")
                        print("External placement: CENTER")
                    } else {
                        precondition(abs(overlay.frame.minX - (screen.frame.minX + delegate.placement.menuWidth + 8)) <= 1,
                                     "The external strip was not placed after menus in a crowded bar")
                        print("External placement: AFTER MENUS (status icons start at \(statusStart))")
                    }
                    precondition(overlay.frame.maxX <= statusStart - 7, "The strip overlapped another status icon")
                }
                let point = NSPoint(x: overlay.frame.minX + view.contentOriginX + delegate.bellFrame.midX * view.scale, y: overlay.frame.midY)
                delegate.clickMenuBar(at: point)
                precondition(delegate.panel.isPresented && screen.visibleFrame.contains(delegate.panel.frame),
                             "The live dropdown opened on the wrong display")
                delegate.dismissIfOutside(at: point)
                precondition(delegate.panel.isPresented)
                delegate.clickMenuBar(at: point)
                precondition(!delegate.panel.isPresented, "The live bell did not toggle closed")
            }
            precondition(externalCount > 0, "Connect a display without a notch for the live placement test")
            if long {
                print("Live notched position, external centering, after-menu placement and per-display bell dropdowns: PASS")
                delegate.placement.stop(); delegate.workspaces.stop(); delegate.notifications.stop()
                exit(0)
            } else {
                setMenus(long: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { check(long: true) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            setMenus(long: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { check(long: false) }
        }
    }
    if args.contains("--smoke-test") {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            let healthy = !delegate.workspaces.snapshot.spaces.isEmpty && delegate.workspaces.error == nil
                && delegate.item.button?.image != nil
            print("Menu bar runtime: \(healthy ? "PASS" : "FAIL")")
            print("Current workspace: \(delegate.workspaces.snapshot.current)")
            print("Workspaces: \(delegate.workspaces.snapshot.spaces.count)")
            print("Notification monitor: \(delegate.notifications.monitorStatus)")
            print("Dock apps with badges: \(delegate.notifications.badges.count)")
            if let button = delegate.item.button, let window = button.window {
                print("Native item visible: \(delegate.item.isVisible), window visible: \(window.isVisible), frame: \(window.frame)")
                print("Native button frame: \(button.frame), accessibility frame: \(button.accessibilityFrame())")
            }
            if let error = delegate.workspaces.error { print(error) }
            delegate.workspaces.stop(); delegate.notifications.stop()
            exit(healthy ? 0 : 1)
        }
    }
    application.run()
}
