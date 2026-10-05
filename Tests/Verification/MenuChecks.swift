import AppKit
import SwiftUI
import ApplicationServices

func runAppClickTest() {
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
}

func runPlacementTest() {
    let suite = "WorkspaceStatus.placement-check.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let application = NSApplication.shared
    let delegate = AppDelegate(settings: SettingsStore(defaults: defaults))
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
        let height = native.frame.height
        let requestedFrame = NSRect(x: nativeFrame.minX, y: screen.frame.maxY - height, width: item.length * 0.75, height: height)
        // Install the real renderer and click callback without starting live geometry polling.
        delegate.placement.start(item: item, image: { delegate.statusImage },
            click: { point, time in delegate.clickMenuBar(at: point, timestamp: time) })
        delegate.placement.stop()
        delegate.placement.display(frames: [id: requestedFrame], reserveNativeSlot: false)
        let overlay = delegate.placement.overlays[id]!
        let frame = overlay.frame
        let view = overlay.contentView as! MenuStripView
        print("Positioned fixture: frame=\(frame), scale=\(view.scale), content width=\(item.length)")
        precondition(!item.isVisible && delegate.placement.usesOverlays && overlay.isVisible)
        precondition(!overlay.isOpaque && !overlay.hasShadow && abs(view.scale - 0.75) <= 1 / item.length,
                     "Positioned strip opacity=\(overlay.isOpaque), shadow=\(overlay.hasShadow), scale=\(view.scale), bounds=\(view.bounds)")
        precondition(view.image?.tiffRepresentation != nil, "The positioned strip lost its image when the native item was hidden")
        func point(_ x: CGFloat, _ y: CGFloat? = nil) -> NSPoint {
            NSPoint(x: frame.minX + x * view.scale, y: y ?? frame.midY)
        }
        let workspaceEdge = point(delegate.workspaceFrames["2"]!.maxX + 2 - 0.25)
        guard delegate.menuNavigation(at: workspaceEdge, timestamp: 100).arguments == ["workspace", "2"] else {
            print("FAIL: the right edge of a drawn workspace selected its neighbour")
            exit(1)
        }
        print("Drawn workspace edge routes to its own group: PASS")
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
        print("Positioned app routing and double-click target preservation: PASS")
        delegate.placement.display(frames: [id: frame], reserveNativeSlot: true)
        precondition(item.isVisible, "A mixed-display setup lost its reserved native position")
        let bell = point(delegate.bellFrame.midX)
        delegate.clickMenuBar(at: bell)
        precondition(delegate.panel.isPresented, "A positioned bell could not open the dropdown")
        precondition(delegate.panel.frame.maxY <= frame.midY - 11 * view.scale && screen.visibleFrame.contains(delegate.panel.frame),
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
        var timestamp: TimeInterval = 1000
        for compact in [false, true] {
            delegate.settings.compactViewEnabled = compact
            for factor in [CGFloat(1), 0.75, 0.4] {
                let centered = menuStripFrame(screen: screen.frame, hasNotch: false, native: nil,
                    menuEnd: screen.frame.minX + 40, statusStart: screen.frame.maxX,
                    width: item.length, workspaceWidth: delegate.bellFrame.minX, height: height)!
                var requested = centered
                requested.size.width *= factor
                delegate.placement.display(frames: [id: requested], reserveNativeSlot: false)
                let placed = overlay.frame
                // Derive target points from the drawable image inset, independently of hit testing.
                let scale = min(1, view.bounds.width / item.length)
                let origin = placed.minX + (view.bounds.width - item.length * scale) / 2 + 2 * scale
                if factor == 1 {
                    precondition(abs(origin + delegate.bellFrame.minX / 2 - screen.frame.midX) < 1,
                                 "The workspace group included the bell in its center")
                }
                func drawnPoint(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                    NSPoint(x: origin + x * scale, y: y)
                }
                for space in delegate.menuOrder {
                    let region = delegate.workspaceFrames[space]!
                    let expected = space == "2" ? nil : ["workspace", space]
                    for x in [region.minX + 0.25, region.maxX - 0.25] {
                        for y in [placed.minY + 1, placed.midY, placed.maxY - 1] {
                            timestamp += 2
                            let result = delegate.menuNavigation(at: drawnPoint(x, y), timestamp: timestamp)
                            precondition(result.workspaceClick && result.arguments == expected,
                                         "A drawn workspace edge selected the wrong group")
                        }
                    }
                }
                for (bundle, region) in delegate.appFrames["2"] ?? [:] {
                    let expected = delegate.workspaces.navigationArguments(to: "2", appBundle: bundle)
                    for x in [region.minX + 0.25, region.maxX - 0.25] {
                        timestamp += 2
                        precondition(delegate.menuNavigation(at: drawnPoint(x, placed.midY), timestamp: timestamp).arguments == expected,
                                     "A drawn app edge did not focus its application")
                    }
                }
                let bell = drawnPoint(delegate.bellFrame.midX, placed.midY)
                precondition(delegate.bellContextMenu(at: bell) != nil)
                precondition(delegate.bellContextMenu(at: drawnPoint(delegate.bellFrame.minX - 0.25, placed.midY)) == nil,
                             "The bell context menu overlaps a drawn workspace")
            }
        }
        delegate.settings.compactViewEnabled = false
        defaults.removePersistentDomain(forName: suite)
        print("Workspace-only centering and exact workspace/app edges in full, compact and scaled strips: PASS")
        delegate.placement.stop()
        precondition(item.isVisible && !delegate.placement.usesOverlays && !overlay.isVisible)
        precondition(item.button?.image === delegate.statusImage, "Stopping placement did not restore the native strip")
        print("Positioned strip rendering, scaled clicks, app focus, double click, bell toggle, popup anchoring and native restoration: PASS")
        exit(0)
    }
    application.run()
}

func runMenuTest(args: [String]) {
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
                for x in stride(from: frame.minX + imageRect.minX + 0.5, to: frame.maxX + imageRect.minX, by: 1) {
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
}
