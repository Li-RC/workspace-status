import AppKit
import ApplicationServices

func menuStripFrame(screen: NSRect, hasNotch: Bool, native: NSRect?, menuEnd: CGFloat,
                    statusStart: CGFloat, width: CGFloat, height: CGFloat) -> NSRect? {
    if hasNotch { return native }
    let left = max(screen.minX, menuEnd + 8)
    let right = min(screen.maxX, statusStart - 8)
    guard width > 0, right > left else { return nil }
    let centered = screen.midX - width / 2
    let fitsCenter = centered >= left && centered + width <= right
    return NSRect(x: fitsCenter ? centered : left, y: screen.maxY - height,
                  width: fitsCenter ? width : min(width, right - left), height: height)
}

private func accessibilityFrame(_ element: AXUIElement, top: CGFloat) -> NSRect? {
    guard let p = axValue(element, kAXPositionAttribute), let s = axValue(element, kAXSizeAttribute),
          CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero, size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size),
          size.width > 0, size.height > 0 else { return nil }
    return NSRect(x: point.x, y: top - point.y - size.height, width: size.width, height: size.height)
}

private func isWorkspaceStatus(_ element: AXUIElement, depth: Int = 2) -> Bool {
    if [kAXTitleAttribute, kAXDescriptionAttribute].contains(where: {
        (axValue(element, $0) as? String)?.contains("Workspace Status") == true
    }) { return true }
    return depth > 0 && axChildren(element).contains { isWorkspaceStatus($0, depth: depth - 1) }
}

struct MenuGeometry {
    var menuWidth: CGFloat
    var bars: [NSRect]
    var statusItems: [(frame: NSRect, own: Bool)]

    static func read(top: CGFloat) -> MenuGeometry? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != "com.apple.loginwindow" else {
            if CommandLine.arguments.contains("--placement-live-test") { print("Live menu read: foreground application unavailable") }
            return nil
        }
        let application = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.15)
        var menu: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(application, kAXMenuBarAttribute as CFString, &menu)
        guard error == .success, let menu, CFGetTypeID(menu) == AXUIElementGetTypeID() else {
            if CommandLine.arguments.contains("--placement-live-test") {
                print("Live menu read: app=\(front.bundleIdentifier ?? "unknown"), AX error=\(error.rawValue)")
            }
            return nil
        }
        let menuElement = menu as! AXUIElement
        let frames = axChildren(menuElement).compactMap { accessibilityFrame($0, top: top) }
        guard let first = frames.min(by: { $0.minX < $1.minX }), let end = frames.map(\.maxX).max() else {
            if CommandLine.arguments.contains("--placement-live-test") {
                print("Live menu read: app=\(front.bundleIdentifier ?? "unknown"), sized items=\(frames.count), children=\(axChildren(menuElement).count)")
            }
            return nil
        }
        let menuWidth = end - (accessibilityFrame(menuElement, top: top)?.minX ?? first.minX)
        var statusItems: [(NSRect, Bool)] = []
        for process in NSWorkspace.shared.runningApplications where
            process.processIdentifier == ProcessInfo.processInfo.processIdentifier ||
            ["com.apple.MenuBarAgent", "com.apple.systemuiserver", "com.apple.controlcenter"].contains(process.bundleIdentifier ?? "") {
            let root = AXUIElementCreateApplication(process.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.15)
            if let extras = axValue(root, kAXExtrasMenuBarAttribute), CFGetTypeID(extras) == AXUIElementGetTypeID() {
                for child in axChildren(extras as! AXUIElement) {
                    guard let frame = accessibilityFrame(child, top: top) else { continue }
                    statusItems.append((frame, isWorkspaceStatus(child)))
                }
            }
            // macOS 27 hosts third-party status buttons in window children rather than Menu Extras.
            if process.bundleIdentifier == "com.apple.MenuBarAgent" {
                for window in axChildren(root) where axValue(window, kAXRoleAttribute) as? String == kAXWindowRole {
                    for child in axChildren(window) {
                        guard let frame = accessibilityFrame(child, top: top), frame.height <= 80 else { continue }
                        statusItems.append((frame, isWorkspaceStatus(child)))
                    }
                }
            }
        }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let bars = windows.compactMap { window -> NSRect? in
            guard window[kCGWindowLayer as String] as? Int == 24,
                  let bounds = window[kCGWindowBounds as String] as? [String: NSNumber],
                  let x = bounds["X"]?.doubleValue, let y = bounds["Y"]?.doubleValue,
                  let width = bounds["Width"]?.doubleValue, let height = bounds["Height"]?.doubleValue,
                  height > 0, height <= 80 else { return nil }
            return NSRect(x: x, y: top - y - height, width: width, height: height)
        }
        return MenuGeometry(menuWidth: menuWidth, bars: bars, statusItems: statusItems)
    }
}

final class MenuStripView: NSView {
    var image: NSImage?
    var contentWidth: CGFloat = 1
    var click: ((NSPoint, TimeInterval) -> Void)?
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    var scale: CGFloat { min(1, bounds.width / max(1, contentWidth)) }
    var contentOriginX: CGFloat { (bounds.width - contentWidth * scale) / 2 }

    override func draw(_ dirtyRect: NSRect) {
        guard let image, scale > 0 else { return }
        image.draw(in: NSRect(x: contentOriginX + 2 * scale, y: (bounds.height - 22 * scale) / 2,
                              width: image.size.width * scale, height: 22 * scale),
                   from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        click?(window.convertPoint(toScreen: event.locationInWindow), event.timestamp)
    }

    override func accessibilityPerformPress() -> Bool {
        guard let window, let click else { return false }
        click(NSPoint(x: window.frame.minX + contentOriginX + (contentWidth - 12) * scale, y: window.frame.midY),
              ProcessInfo.processInfo.systemUptime)
        return true
    }
}

final class MenuPlacement: ObservableObject {
    @Published private(set) var notice: String?
    private(set) var usesOverlays = false
    private(set) var menuWidth: CGFloat = 0
    private(set) var statusStarts: [CGDirectDisplayID: CGFloat] = [:]
    private(set) var overlays: [CGDirectDisplayID: NSPanel] = [:]
    private weak var item: NSStatusItem?
    private var image: (() -> NSImage?)?
    private var click: ((NSPoint, TimeInterval) -> Void)?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var loading = false
    private var started = false
    private var lastNativeFrame: NSRect?

    func start(item: NSStatusItem, image: @escaping () -> NSImage?, click: @escaping (NSPoint, TimeInterval) -> Void) {
        self.item = item; self.image = image; self.click = click
        started = true
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        refresh()
    }

    func refresh() {
        guard started else { return }
        let screens = NSScreen.screens
        guard let item, screens.contains(where: { $0.auxiliaryTopLeftArea == nil }) else {
            timer?.invalidate(); timer = nil
            restoreNative(); notice = nil
            return
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        }
        guard AXIsProcessTrusted() else {
            restoreNative(); notice = "Enable Accessibility to position Workspace Status between application menus."
            return
        }
        guard !loading else { return }
        loading = true
        if let button = item.button, let window = button.window, item.isVisible {
            lastNativeFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        }
        let top = screens.first?.frame.maxY ?? 0
        DispatchQueue.global(qos: .utility).async {
            let geometry = MenuGeometry.read(top: top)
            DispatchQueue.main.async {
                self.loading = false
                guard self.started, NSScreen.screens.contains(where: { $0.auxiliaryTopLeftArea == nil }) else { return }
                guard let geometry else {
                    self.restoreNative(); self.notice = "Application-menu positions are currently unavailable."
                    return
                }
                self.apply(geometry)
            }
        }
    }

    private func apply(_ geometry: MenuGeometry) {
        guard let item else { return }
        menuWidth = geometry.menuWidth
        let screens = NSScreen.screens
        var frames: [CGDirectDisplayID: NSRect] = [:]
        var starts: [CGDirectDisplayID: CGFloat] = [:]
        for screen in screens {
            let bounds = screen.frame
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let bar = geometry.bars.first(where: { abs($0.maxY - bounds.maxY) < 2 && $0.intersection(bounds).width > bounds.width * 0.8 }) else { continue }
            let menuEnd = bounds.minX + geometry.menuWidth
            let entries = geometry.statusItems.filter { $0.frame.intersects(bar) && $0.frame.width < bounds.width }
            let native = entries.first(where: \.own)?.frame ?? lastNativeFrame.flatMap { bounds.contains($0) ? $0 : nil }
            if screen.auxiliaryTopLeftArea != nil && native == nil {
                restoreNative(); notice = "The saved menu bar position is currently unavailable."
                return
            }
            // The native slot is a conservative boundary when other status items cannot be read.
            let statusStart = entries.filter { !$0.own && $0.frame.minX >= menuEnd }.map { $0.frame.minX }.min()
                ?? native?.minX
            starts[id] = statusStart
            guard screen.auxiliaryTopLeftArea != nil || statusStart != nil else {
                restoreNative(); notice = "Status icon positions are currently unavailable."
                return
            }
            if let frame = menuStripFrame(screen: bounds, hasNotch: screen.auxiliaryTopLeftArea != nil,
                native: native, menuEnd: menuEnd, statusStart: statusStart ?? bounds.maxX,
                width: item.length, height: bar.height) {
                if screen.auxiliaryTopLeftArea == nil || frame.minX >= menuEnd + 8 { frames[id] = frame }
            }
        }
        let hasNotch = screens.contains { $0.auxiliaryTopLeftArea != nil }
        statusStarts = starts
        display(frames: frames, reserveNativeSlot: hasNotch)
    }

    // Rendering also accepts fixture frames so external-display clicks can be checked on a laptop.
    func display(frames: [CGDirectDisplayID: NSRect], reserveNativeSlot: Bool) {
        guard let item, let image = image?() else { return }
        usesOverlays = true
        notice = nil
        item.button?.image = NSImage(size: image.size, flipped: false) { _ in true }
        item.isVisible = reserveNativeSlot
        for id in Array(overlays.keys) where frames[id] == nil {
            overlays.removeValue(forKey: id)?.close()
        }
        for (id, frame) in frames {
            let overlay: NSPanel
            if let existing = overlays[id] { overlay = existing }
            else {
                overlay = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                overlay.isOpaque = false; overlay.backgroundColor = .clear; overlay.hasShadow = false
                overlay.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
                overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                overlay.hidesOnDeactivate = false
                overlay.isReleasedWhenClosed = false
                let view = MenuStripView(frame: NSRect(origin: .zero, size: frame.size))
                view.autoresizingMask = [.width, .height]
                view.setAccessibilityElement(true)
                view.setAccessibilityRole(.button)
                view.setAccessibilityLabel("Workspace Status")
                view.setAccessibilityHelp("Click a workspace to switch, an app to focus, or the bell for overview. Double-click any app to focus it.")
                view.click = click
                overlay.contentView = view
                overlays[id] = overlay
            }
            let view = overlay.contentView as! MenuStripView
            view.image = image; view.contentWidth = item.length
            view.appearance = item.button?.effectiveAppearance
            overlay.setFrame(frame, display: false)
            view.needsDisplay = true
            overlay.orderFrontRegardless()
        }
    }

    func overlay(at point: NSPoint) -> NSPanel? {
        overlays.values.first { $0.isVisible && $0.frame.contains(point) }
    }

    func updateImage() {
        guard let item, let image = image?() else { return }
        for overlay in overlays.values {
            let view = overlay.contentView as! MenuStripView
            view.image = image; view.contentWidth = item.length
            view.needsDisplay = true
        }
    }

    private func restoreNative() {
        for overlay in overlays.values { overlay.orderOut(nil) }
        if usesOverlays {
            item?.button?.image = image?()
            item?.isVisible = true
        }
        usesOverlays = false
    }

    func stop() {
        started = false
        timer?.invalidate(); timer = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers = []
        restoreNative()
    }
}
