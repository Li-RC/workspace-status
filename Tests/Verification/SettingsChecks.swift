import AppKit
import ServiceManagement

func runSettingsStoreTests() {
    let suite = "WorkspaceStatus.settings-check.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = SettingsStore(defaults: defaults)
    precondition(settings.menuBarPosition == .automatic && settings.dockBadgesEnabled)
    var changes = 0
    settings.changed = { changes += 1 }
    settings.menuBarPosition = .system
    settings.dockBadgesEnabled = false
    settings.dockBadgesEnabled = false
    precondition(changes == 2, "Unchanged preferences caused extra updates")
    let reloaded = SettingsStore(defaults: defaults)
    precondition(reloaded.menuBarPosition == .system && !reloaded.dockBadgesEnabled,
                 "Preferences were lost after reloading")
    defaults.set("unknown", forKey: "menuBarPosition")
    precondition(SettingsStore(defaults: defaults).menuBarPosition == .automatic)

    var status = SMAppService.Status.notRegistered
    var registrations = 0
    var fail = false
    let login = LoginItemModel(readStatus: { status }, register: {
        registrations += 1
        if fail { throw NSError(domain: "SettingsChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "Registration denied"]) }
        status = .requiresApproval
    }, unregister: {
        if fail { throw NSError(domain: "SettingsChecks", code: 2, userInfo: [NSLocalizedDescriptionKey: "Removal denied"]) }
        status = .notRegistered
    })
    precondition(!login.requested)
    fail = true
    login.setEnabled(true)
    precondition(!login.requested && login.error == "Registration denied", "Failed registration reported success")
    fail = false
    login.setEnabled(true)
    precondition(login.status == .requiresApproval && login.requested && login.error == nil)
    login.setEnabled(true)
    precondition(registrations == 2, "Pending approval caused duplicate registration")
    status = .enabled
    login.refresh()
    precondition(login.status == .enabled)
    fail = true
    login.setEnabled(false)
    precondition(login.requested && login.error == "Removal denied", "Failed removal reported success")
    fail = false
    login.setEnabled(false)
    precondition(!login.requested && login.error == nil)
    status = .notFound
    login.refresh()
    precondition(!login.requested && !login.description.isEmpty)

    let screen = NSRect(x: -1200, y: -200, width: 1200, height: 800)
    let fitted = settingsWindowFrame(NSRect(x: 2000, y: 2000, width: 544, height: 412), visibleFrame: screen)
    precondition(screen.contains(fitted) && fitted.size == NSSize(width: 544, height: 412))
    precondition(screen.contains(settingsWindowFrame(NSRect(x: 0, y: 0, width: 1800, height: 1200), visibleFrame: screen)))
    print("PASS: settings defaults/persistence, login approval/error/retry states and disconnected-display window bounds.")
}

func runSettingsTest(args: [String]) {
    let suite = "WorkspaceStatus.settings-ui-check.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let application = NSApplication.shared
    let delegate = AppDelegate(settings: SettingsStore(defaults: defaults))
    application.delegate = delegate
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        delegate.workspaces.snapshot = menuFixture()
        delegate.updateStatus()
        let item = delegate.item!, button = item.button!, native = button.window!, screen = native.screen!
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        let bell = native.convertPoint(toScreen: button.convert(NSPoint(x: delegate.bellFrame.midX, y: 11), to: nil))
        let space = native.convertPoint(toScreen: button.convert(NSPoint(x: delegate.workspaceFrames["1"]!.midX, y: 11), to: nil))
        precondition(delegate.bellContextMenu(at: space) == nil, "Workspace right-click opened the bell menu")
        let menu = delegate.bellContextMenu(at: bell)!
        precondition(menu.items.map(\.title) == ["Settings…", "", "Quit"])
        delegate.toggle()
        precondition(delegate.panel.isPresented)
        menu.performActionForItem(at: 0)
        let controller = delegate.settingsWindow, window = controller.window!
        precondition(window.isVisible && !delegate.panel.isPresented, "Settings did not replace the dropdown")
        precondition(application.activationPolicy() == .accessory, "Settings created a Dock app")
        let settingsFrame = window.frame
        delegate.showSettings(nil)
        precondition(delegate.settingsWindow === controller && window.frame == settingsFrame,
                     "Repeated opening created or repositioned the settings window")
        window.performClose(nil)
        precondition(!window.isVisible && item.isVisible && !delegate.applicationShouldTerminateAfterLastWindowClosed(application))
        _ = delegate.applicationShouldHandleReopen(application, hasVisibleWindows: false)
        precondition(window.isVisible, "App reopening did not restore Settings")
        window.setFrameOrigin(NSPoint(x: 30000, y: 30000))
        delegate.showSettings(nil)
        precondition(NSScreen.screens.contains { $0.visibleFrame.contains(window.frame) }, "Settings stayed on a disconnected display")

        let command = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: 1, windowNumber: window.windowNumber, context: nil, characters: ",", charactersIgnoringModifiers: ",", isARepeat: false, keyCode: 43)!
        precondition(application.mainMenu!.performKeyEquivalent(with: command), "Command-comma did not invoke Settings")
        precondition(window.isVisible && delegate.settingsWindow === controller)

        var contextPoint: NSPoint?
        delegate.placement.start(item: item, image: { delegate.statusImage },
            click: { point, time in delegate.clickMenuBar(at: point, timestamp: time) }, contextClick: { contextPoint = $0 })
        delegate.placement.stop()
        let frame = NSRect(x: native.frame.minX, y: screen.frame.maxY - 39, width: item.length * 0.8, height: 39)
        delegate.placement.display(frames: [id: frame], reserveNativeSlot: false)
        let overlay = delegate.placement.overlays[id]!, view = overlay.contentView as! MenuStripView
        let overlayBell = NSPoint(x: frame.minX + view.contentOriginX + delegate.bellFrame.midX * view.scale, y: frame.midY)
        let event = NSEvent.mouseEvent(with: .rightMouseDown, location: overlay.convertPoint(fromScreen: overlayBell), modifierFlags: [],
            timestamp: 2, windowNumber: overlay.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        view.rightMouseDown(with: event)
        precondition(contextPoint == overlayBell, "Overlay right-click lost screen coordinates")
        precondition(delegate.bellContextMenu(at: overlayBell)?.items.first?.title == "Settings…")
        let overlaySpace = NSPoint(x: frame.minX + view.contentOriginX + delegate.workspaceFrames["1"]!.midX * view.scale, y: frame.midY)
        precondition(delegate.bellContextMenu(at: overlaySpace) == nil)
        delegate.settings.menuBarPosition = .system
        precondition(!delegate.placement.usesOverlays && item.isVisible && item.button?.image === delegate.statusImage,
                     "System position did not restore the native item")
        delegate.settings.menuBarPosition = .automatic
        precondition(delegate.placement.automatic)
        delegate.notifications.badges = [DockBadge(name: "Fixture", bundle: "fixture", value: "2")]
        delegate.settings.dockBadgesEnabled = false
        precondition(!delegate.notifications.monitoringEnabled && delegate.notifications.badges.isEmpty)
        delegate.notifications.checkPermission()
        precondition(!delegate.notifications.monitoringEnabled && delegate.notifications.badges.isEmpty)
        let saved = SettingsStore(defaults: defaults)
        precondition(saved.menuBarPosition == .automatic && !saved.dockBadgesEnabled)
        defaults.removePersistentDomain(forName: suite)
        delegate.workspaces.stop(); delegate.notifications.stop(); delegate.placement.stop()
        // Application activation is asynchronous; check focus after returning to the event loop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            precondition(delegate.settingsWindow === controller)
            precondition(!delegate.notifications.monitoringEnabled && delegate.notifications.badges.isEmpty,
                         "A completed scan repopulated disabled notifications")
            print("Settings window visible: \(window.isVisible), key: \(window.isKeyWindow), app active: \(application.isActive)")
            if !args.contains("--hold-settings-preview") {
                precondition(window.isKeyWindow && application.isActive, "Settings became visible without keyboard focus")
            }
            print("Settings reuse/reopen/close, command-comma, bell-only context menus on both renderers and live preferences: PASS")
            if let index = args.firstIndex(of: "--render-settings-preview"), args.count > index + 1,
               let view = window.contentView?.superview {
                view.layoutSubtreeIfNeeded()
                let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[index + 1]))
            }
            if !args.contains("--hold-settings-preview") {
                window.miniaturize(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    delegate.showSettings(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        precondition(!window.isMiniaturized && window.isKeyWindow, "Reopening did not restore minimized Settings")
                        let close = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                            timestamp: 3, windowNumber: window.windowNumber, context: nil, characters: "w", charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13)!
                        precondition(application.mainMenu!.performKeyEquivalent(with: close) && !window.isVisible,
                                     "Command-W did not close only Settings")
                        print("Settings keyboard focus, minimized restoration and Command-W dismissal: PASS")
                        exit(0)
                    }
                }
            }
        }
    }
    withExtendedLifetime(delegate) { application.run() }
}
