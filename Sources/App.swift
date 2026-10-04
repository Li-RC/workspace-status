import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: SettingsStore
    lazy var settingsWindow = SettingsWindowController(settings: settings, notifications: notifications)
    let workspaces = WorkspaceModel()
    let notifications = NotificationModel()
    let overviewState = OverviewState()
    let placement = MenuPlacement()
    private(set) var statusImage: NSImage?
    private var overviewAnchor: (rect: NSRect, screen: NSScreen)?
    private(set) var naturalHeight: CGFloat = 240
    var item: NSStatusItem!
    private(set) var workspaceFrames: [String: NSRect] = [:]
    private(set) var appFrames: [String: [String: NSRect]] = [:]
    private(set) var bellFrame = NSRect.zero
    private var appearanceObservation: NSKeyValueObservation?
    private(set) var menuOrder: [String] = []
    let panel = OverviewPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var hosting: NSHostingController<Overview>!
    private var lastAppClick: (space: String, bundle: String, point: NSPoint, timestamp: TimeInterval)?

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        placement.automatic = settings.menuBarPosition == .automatic
        settings.changed = { [weak self] in self?.applySettings() }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(menuBarClicked(_:))
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        item.button?.imagePosition = .imageLeft
        item.button?.attributedTitle = NSAttributedString(string: "")
        item.button?.imageHugsTitle = true
        item.button?.toolTip = "Workspace Status: click a workspace to switch, an app in the current workspace to focus, or the bell for overview. Double-click any app to focus it."
        item.button?.setAccessibilityLabel("Workspace Status")
        appearanceObservation = item.button?.observe(\.effectiveAppearance, options: [.old, .new]) { [weak self] _, change in
            guard change.oldValue?.name != change.newValue?.name else { return }
            self?.updateStatus()
        }
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissIfOutside(at: NSEvent.mouseLocation)
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let point = event.window === self?.item.button?.window ? NSEvent.mouseLocation :
                (event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation)
            self?.dismissIfOutside(at: point)
            return event
        }
        hosting = NSHostingController(rootView:
            Overview(workspaces: workspaces, notifications: notifications, placement: placement,
                     close: { [weak self] in self?.panel.dismiss() }, state: overviewState,
                     resized: { [weak self] height in self?.resizeOverview(to: height) },
                     openSettings: { [weak self] in self?.showSettings(nil) }))
        hosting.sizingOptions = []
        let container = NSViewController()
        container.addChild(hosting)
        let backdrop = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 560))
        backdrop.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: backdrop.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor)
        ])
        container.view = backdrop
        panel.contentViewController = container
        workspaces.changed = { [weak self] in self?.updateStatus() }
        notifications.changed = { [weak self] in self?.updateStatus() }
        updateStatus()
        let fixture = ["--menu-test", "--layout-test", "--placement-test", "--settings-test"].contains { CommandLine.arguments.contains($0) }
        if !fixture {
            workspaces.start()
            notifications.setMonitoring(settings.dockBadgesEnabled)
            notifications.start()
        }
        let check = ["--menu-test", "--layout-test", "--placement-test", "--bell-click-test", "--popover-test", "--settings-test"]
            .contains { CommandLine.arguments.contains($0) }
        if !check {
            placement.start(item: item, image: { [weak self] in self?.statusImage },
                click: { [weak self] point, time in self?.clickMenuBar(at: point, timestamp: time) },
                contextClick: { [weak self] point in self?.showBellContextMenu(at: point) })
        }
    }

    private func installMainMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu(title: "Workspace Status")
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Workspace Status", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
    }

    private func applySettings() {
        placement.automatic = settings.menuBarPosition == .automatic
        notifications.setMonitoring(settings.dockBadgesEnabled)
        updateStatus()
    }

    @objc func showSettings(_ sender: Any?) {
        let point = ((sender as? NSMenuItem)?.representedObject as? NSValue)?.pointValue ?? NSEvent.mouseLocation
        let screen = panel.isPresented ? popupAnchor()?.1 : NSScreen.screens.first { $0.frame.contains(point) }
        panel.dismiss()
        // Release the nonactivating panel's key window before requesting settings activation.
        panel.orderOut(nil)
        lastAppClick = nil
        settingsWindow.show(on: screen)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings(nil)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func bellContextMenu(at point: NSPoint) -> NSMenu? {
        guard let location = menuPoint(at: point), bellFrame.contains(location.point) else { return nil }
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.representedObject = NSValue(point: point)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        return menu
    }

    func showBellContextMenu(at point: NSPoint) {
        guard let menu = bellContextMenu(at: point) else { return }
        panel.dismiss()
        lastAppClick = nil
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    func updateStatus() {
        let snapshot = workspaces.snapshot
        menuOrder = snapshot.menuSpaces
        workspaceFrames = [:]
        appFrames = [:]
        var x: CGFloat = 0
        for space in menuOrder {
            let badge = workspaceBadge(space)
            let bundles = snapshot.appBundles(in: space)
            let width = badge.size.width + (bundles.isEmpty ? 0 : CGFloat(bundles.count * 21 + 4) + 2) + 4
            workspaceFrames[space] = NSRect(x: x, y: 0, width: width, height: 22)
            appFrames[space] = Dictionary(uniqueKeysWithValues: bundles.enumerated().map { index, bundle in
                (bundle, NSRect(x: x + badge.size.width + 6 + CGFloat(index * 21), y: 0, width: 16, height: 22))
            })
            x += width
        }
        bellFrame = NSRect(x: x, y: 0, width: 24, height: 22)
        let hasBadges = !notifications.badges.isEmpty
        let bell = NSImage(systemSymbolName: hasBadges ? "bell.badge.fill" : "bell", accessibilityDescription: nil)!
        let bellImage = hasBadges ? bell.withSymbolConfiguration(.init(paletteColors: [.systemOrange]))! : bell
        bellImage.isTemplate = !hasBadges
        let frames = workspaceFrames
        let bellRect = bellFrame
        // Share the same strip and hit regions between the native item and positioned displays.
        statusImage = NSImage(size: NSSize(width: x + 20, height: 22), flipped: true) { [weak self] _ in
            guard let button = self?.item.button else { return false }
            for space in snapshot.menuSpaces {
                let frame = frames[space]!
                let current = space == snapshot.current
                let badge = workspaceBadge(current && self?.workspaces.error != nil ? "!" : space, selected: current)
                (button.cell as! NSButtonCell).drawImage(badge, withFrame: NSRect(origin: frame.origin, size: badge.size), in: button)
                let bundles = snapshot.appBundles(in: space)
                if !bundles.isEmpty {
                    let icons = iconStrip(bundles)
                    icons.draw(in: NSRect(x: frame.minX + badge.size.width + 2, y: 0, width: icons.size.width, height: 22),
                               from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                }
            }
            let size = bellImage.size
            (button.cell as! NSButtonCell).drawImage(bellImage,
                withFrame: NSRect(x: bellRect.midX - size.width / 2 - 2, y: (22 - size.height) / 2,
                                  width: size.width, height: size.height), in: button)
            return true
        }
        if let statusImage {
            item.button?.image = placement.usesOverlays
                ? NSImage(size: statusImage.size, flipped: false) { _ in true } : statusImage
        }
        item.length = x + 24
        placement.updateImage()
        placement.refresh()
    }

    func selectWorkspace(_ space: String) {
        panel.dismiss()
        if space != workspaces.snapshot.current {
            workspaces.perform(["workspace", space], completion: {})
        }
    }

    private func workspaceTarget(at point: NSPoint, padding: CGFloat? = nil) -> (space: String, bundle: String?)? {
        guard let button = item.button,
              let space = menuOrder.first(where: { workspaceFrames[$0]!.contains(point) }) else { return nil }
        // App frames share the image's coordinates; the native button adds image padding.
        let imagePoint = NSPoint(x: point.x - (padding ?? button.cell!.imageRect(forBounds: button.bounds).minX), y: 11)
        let bundle = appFrames[space]?.first(where: { $0.value.contains(imagePoint) })?.key
        return (space, bundle)
    }

    func navigationArguments(at point: NSPoint) -> [String]? {
        guard let target = workspaceTarget(at: point) else { return nil }
        return workspaces.navigationArguments(to: target.space, appBundle: target.bundle)
    }

    private func menuPoint(at screenPoint: NSPoint) -> (point: NSPoint, padding: CGFloat)? {
        if let overlay = placement.overlay(at: screenPoint), let view = overlay.contentView as? MenuStripView, view.scale > 0 {
            return (NSPoint(x: (screenPoint.x - overlay.frame.minX - view.contentOriginX) / view.scale, y: 11), 2)
        }
        guard !placement.usesOverlays, let button = item.button, let window = button.window,
              window.frame.contains(screenPoint) else { return nil }
        let location = button.convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        return (NSPoint(x: location.x, y: button.bounds.midY), button.cell!.imageRect(forBounds: button.bounds).minX)
    }

    func menuNavigation(at screenPoint: NSPoint, timestamp: TimeInterval) -> (workspaceClick: Bool, arguments: [String]?) {
        let previous = lastAppClick
        lastAppClick = nil
        if let previous, timestamp > previous.timestamp,
           timestamp - previous.timestamp <= NSEvent.doubleClickInterval,
           abs(screenPoint.x - previous.point.x) <= 4, abs(screenPoint.y - previous.point.y) <= 4 {
            // Keep the first app target even if switching rearranges the menu bar.
            return (true, workspaces.navigationArguments(to: previous.space, appBundle: previous.bundle, focusApp: true))
        }
        guard let location = menuPoint(at: screenPoint),
              let target = workspaceTarget(at: location.point, padding: location.padding) else { return (false, nil) }
        if let bundle = target.bundle { lastAppClick = (target.space, bundle, screenPoint, timestamp) }
        return (true, workspaces.navigationArguments(to: target.space, appBundle: target.bundle))
    }

    @objc func menuBarClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseDown {
            showBellContextMenu(at: NSEvent.mouseLocation)
        } else if let event = NSApp.currentEvent, event.type == .leftMouseDown {
            // macOS's menu bar host forwards mouse events at the item's center.
            clickMenuBar(at: NSEvent.mouseLocation, timestamp: event.timestamp)
        } else {
            overviewAnchor = nil
            toggle()
        }
    }

    func clickMenuBar(at screenPoint: NSPoint, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let navigation = menuNavigation(at: screenPoint, timestamp: timestamp)
        if navigation.workspaceClick {
            panel.dismiss()
            if let arguments = navigation.arguments { workspaces.perform(arguments, completion: {}) }
            return
        }
        guard let location = menuPoint(at: screenPoint), bellFrame.contains(location.point) else { return }
        if let overlay = placement.overlay(at: screenPoint), let screen = overlay.screen,
           let view = overlay.contentView as? MenuStripView {
            overviewAnchor = (NSRect(x: overlay.frame.minX + view.contentOriginX + bellFrame.minX * view.scale,
                y: overlay.frame.midY - 11 * view.scale, width: bellFrame.width * view.scale, height: 22 * view.scale), screen)
        } else { overviewAnchor = nil }
        toggle()
    }

    @objc func toggle() {
        lastAppClick = nil
        showOverview()
    }

    func dismissIfOutside(at point: NSPoint) {
        guard panel.isPresented, !panel.frame.contains(point) else { return }
        if let location = menuPoint(at: point), bellFrame.contains(location.point) { return }
        if let button = item.button, let window = button.window {
            let bell = window.convertToScreen(button.convert(bellFrame, to: nil))
            if point.y >= window.frame.minY, point.y <= window.frame.maxY,
               point.x >= bell.minX, point.x <= bell.maxX { return }
        }
        panel.dismiss()
    }

    private func showOverview() {
        if panel.isPresented { panel.dismiss(); return }
        guard let (anchor, screen) = popupAnchor() else { return }
        hosting.rootView.width = max(1, min(360, screen.visibleFrame.width - 28))
        fitOverview(visibleFrame: screen.visibleFrame, anchor: anchor)
        if !["--layout-test", "--placement-test", "--settings-test"].contains(where: { CommandLine.arguments.contains($0) }) { workspaces.refresh() }
        panel.present()
    }

    private func resizeOverview(to height: CGFloat) {
        guard height > 0, abs(naturalHeight - height) > 0.5 else { return }
        naturalHeight = height
        guard panel.isPresented, let (anchor, screen) = popupAnchor() else { return }
        fitOverview(visibleFrame: screen.visibleFrame, anchor: anchor)
    }

    private func popupAnchor() -> (NSRect, NSScreen)? {
        if let overviewAnchor { return (overviewAnchor.rect, overviewAnchor.screen) }
        guard let button = item.button, let window = button.window, let screen = window.screen else { return nil }
        return (window.convertToScreen(button.convert(bellFrame, to: nil)), screen)
    }

    private func fitOverview(visibleFrame: NSRect, anchor: NSRect) {
        let size = overviewSize(visibleFrame: visibleFrame, anchor: anchor, contentHeight: naturalHeight)
        hosting.rootView.canvasHeight = naturalHeight
        hosting.rootView.scale = size.height / naturalHeight
        let top = min(anchor.minY - 8, visibleFrame.maxY - 8)
        let origin = NSPoint(x: max(visibleFrame.minX, min(anchor.maxX - size.width, visibleFrame.maxX - size.width)),
                             y: top - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        workspaces.stop(); notifications.stop()
        placement.stop()
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
    }
}
