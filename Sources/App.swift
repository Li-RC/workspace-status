import AppKit
import SwiftUI
import CoreText
import QuartzCore

private var iconCache: [String: NSImage] = [:]
func appIcon(_ bundle: String) -> NSImage {
    if let icon = iconCache[bundle] { return icon }
    let image: NSImage
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
        image = NSWorkspace.shared.icon(forFile: url.path)
    } else { image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)! }
    iconCache[bundle] = image
    return image
}

struct AppIcon: View {
    let bundle: String
    var body: some View { Image(nsImage: appIcon(bundle)).resizable().frame(width: 20, height: 20) }
}

func workspaceBadge(_ label: String, selected: Bool = true) -> NSImage {
    let font = NSFont.systemFont(ofSize: 12, weight: .bold)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: label,
        attributes: [.font: font, .foregroundColor: NSColor.black]))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let width = max(22, ceil(bounds.width) + 10)
    let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { _ in
        NSColor.black.setFill()
        let badge = NSBezierPath(roundedRect: NSRect(x: 0.75, y: 2.75, width: width - 1.5, height: 16.5), xRadius: 5, yRadius: 5)
        if selected { badge.fill() } else { NSColor.black.setStroke(); badge.lineWidth = 1.5; badge.stroke() }
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: width / 2 - bounds.midX, y: 11 - bounds.midY)
        // Cut the centered number out of the template's solid badge.
        if selected { context.setBlendMode(.destinationOut) }
        CTLineDraw(line, context)
        context.restoreGState()
        return true
    }
    image.isTemplate = true
    return image
}

func iconStrip(_ bundles: [String]) -> NSAttributedString {
    guard !bundles.isEmpty else { return NSAttributedString(string: "") }
    let width = CGFloat(bundles.count * 21 + 4)
    let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { _ in
        for (index, bundle) in bundles.enumerated() {
            appIcon(bundle).draw(in: NSRect(x: CGFloat(index * 21 + 4), y: 3, width: 16, height: 16))
        }
        return true
    }
    let attachment = NSTextAttachment()
    attachment.image = image
    attachment.bounds = NSRect(x: 0, y: (NSFont.systemFont(ofSize: 12).capHeight - 22) / 2, width: width, height: 22)
    return NSAttributedString(attachment: attachment)
}

func overviewSize(visibleFrame: NSRect, anchor: NSRect, contentHeight: CGFloat = 240) -> NSSize {
    let width = max(1, min(360, visibleFrame.width - 28))
    let availableHeight = max(1, min(anchor.minY, visibleFrame.maxY) - visibleFrame.minY - 28)
    let scale = min(1, availableHeight / max(1, contentHeight))
    return NSSize(width: floor(width * scale), height: max(1, floor(contentHeight * scale)))
}

final class OverviewState: ObservableObject {
    @Published var expanded: Set<String> = []
}

struct GlassControl: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) { content.buttonStyle(.glass) }
        else { content.buttonStyle(.borderless) }
    }
}

struct WorkspaceSurface: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(),
                                in: RoundedRectangle(cornerRadius: 12))
        } else {
            content.background(Color.secondary.opacity(0.05),
                               in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct Overview: View {
    @ObservedObject var workspaces: WorkspaceModel
    @ObservedObject var notifications: NotificationModel
    let close: () -> Void
    @ObservedObject var state: OverviewState
    let resized: (CGFloat) -> Void
    var width: CGFloat = 360
    var scale: CGFloat = 1
    var canvasHeight: CGFloat = 240

    func appRowHeight(in space: String) -> CGFloat {
        let columns = max(1, Int((width - 130) / 28))
        let rows = max(1, Int(ceil(Double(workspaces.snapshot.appBundles(in: space).count) / Double(columns))))
        return max(26, CGFloat(rows * 22 + (rows - 1) * 6))
    }

    var contentHeight: CGFloat {
        var workspaceElements: [CGFloat] = [34]
        if workspaces.error != nil { workspaceElements += [28, 14] }
        let spaces = workspaces.snapshot.occupiedSpaces
        if spaces.isEmpty { workspaceElements.append(34) }
        for space in spaces {
            let windowsHeight = state.expanded.contains(space) ? CGFloat(workspaces.snapshot.windows(in: space).count * 44) : 0
            workspaceElements.append(appRowHeight(in: space) + windowsHeight + 12)
            if space != spaces.last { workspaceElements.append(1) }
        }
        let workspaceHeight = workspaceElements.reduce(0, +) + CGFloat(workspaceElements.count - 1) * 8 + 24
        let noticesHeight: CGFloat = notifications.authorized
            ? (notifications.badges.isEmpty ? 60 : 38 + CGFloat(notifications.badges.count * 32)) : 104
        return workspaceHeight + noticesHeight + 66
    }

    func select(_ space: String) {
        if space == workspaces.snapshot.current { close() }
        else { workspaces.perform(["workspace", space], completion: close) }
    }
    func focus(_ window: AppWindow) {
        workspaces.perform(["focus", "--window-id", String(window.id)], completion: close)
    }
    func openApp(_ bundle: String, in space: String? = nil) {
        if let window = workspaces.snapshot.windows.first(where: {
            $0.bundle == bundle && (space == nil || $0.workspace == space)
        }) {
            focus(window)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
            close()
        }
    }

    @ViewBuilder var sections: some View {
        VStack(spacing: 10) {
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill").foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Workspace Status").font(.headline)
                            Text("Workspace \(workspaces.snapshot.current)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { workspaces.refresh() } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.borderless).help("Refresh workspaces")
                    }.frame(height: 34)
                    if let error = workspaces.error {
                        Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).lineLimit(2).frame(height: 28)
                        Text("Start AeroSpace, then refresh.").font(.caption).foregroundStyle(.secondary).frame(height: 14)
                    }
                    if workspaces.snapshot.occupiedSpaces.isEmpty {
                        Text("No workspaces with open windows.").font(.caption).foregroundStyle(.secondary).frame(height: 34)
                    }
                    ForEach(workspaces.snapshot.occupiedSpaces, id: \.self) { space in
                        let windows = workspaces.snapshot.windows(in: space)
                        let bundles = workspaces.snapshot.appBundles(in: space)
                        let current = space == workspaces.snapshot.current
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Button { select(space) } label: {
                                    Text(space).font(.system(.body, design: .rounded).weight(.bold))
                                        .frame(minWidth: 26, minHeight: 26)
                                        .background(current ? Color.blue : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(current ? Color.white : Color.primary)
                                }.buttonStyle(.plain).help("Switch to workspace \(space)")
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 22, maximum: 22))], alignment: .leading, spacing: 6) {
                                    ForEach(bundles, id: \.self) { bundle in
                                        Button { openApp(bundle, in: space) } label: { AppIcon(bundle: bundle) }
                                            .buttonStyle(.plain).help("Open \(windows.first { $0.bundle == bundle }?.app ?? bundle)")
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    withAnimation(.easeOut(duration: 0.12)) {
                                        if state.expanded.contains(space) { state.expanded.remove(space) } else { state.expanded.insert(space) }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(windows.count)").monospacedDigit()
                                        Image(systemName: state.expanded.contains(space) ? "chevron.up" : "chevron.down")
                                    }.font(.caption).foregroundStyle(.secondary)
                                }.buttonStyle(.borderless).help("Show windows in workspace \(space)")
                            }
                            if state.expanded.contains(space) {
                                ForEach(windows) { window in
                                    Button { focus(window) } label: {
                                        HStack(spacing: 8) {
                                            AppIcon(bundle: window.bundle)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(window.app).font(.caption.weight(.medium)).lineLimit(1)
                                                Text(window.title.isEmpty ? "Untitled window" : window.title)
                                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                                        }.padding(5).frame(height: 38).contentShape(Rectangle())
                                    }.buttonStyle(.plain).help("Focus \(window.title)")
                                }
                            }
                        }.padding(.vertical, 6).frame(maxWidth: .infinity)
                        if space != workspaces.snapshot.occupiedSpaces.last { Divider() }
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(WorkspaceSurface())
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(height: 14)
                    if !notifications.authorized {
                        Text("Allow Accessibility to read app badges in the Dock.").font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(height: 28)
                        Button("Enable Accessibility…") { notifications.enable() }.modifier(GlassControl()).controlSize(.small).frame(height: 22)
                    } else if notifications.badges.isEmpty {
                        Text("No notifications to show.").font(.caption).foregroundStyle(.secondary).frame(height: 14)
                    } else {
                        ForEach(notifications.badges) { badge in
                            Button { openApp(badge.bundle) } label: {
                                HStack {
                                    AppIcon(bundle: badge.bundle)
                                    Text(badge.name).font(.callout).lineLimit(1)
                                    Spacer()
                                    Text(badge.value).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                                }.frame(height: 24).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(WorkspaceSurface())
            }.padding(2)
            Button("Quit") { NSApp.terminate(nil) }
                .modifier(GlassControl()).buttonBorderShape(.capsule).controlSize(.small).font(.caption).frame(height: 22)
        }.padding(10)
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) { GlassEffectContainer(spacing: 4) { sections } }
            else { sections }
        }.frame(width: width, height: contentHeight, alignment: .top)
            .onChange(of: contentHeight, initial: true) { _, height in
                DispatchQueue.main.async { resized(height) }
            }
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width * scale, height: canvasHeight * scale, alignment: .topLeading)
    }

}

final class OverviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(sender) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let workspaces = WorkspaceModel()
    let notifications = NotificationModel()
    let overviewState = OverviewState()
    private(set) var naturalHeight: CGFloat = 240
    var item: NSStatusItem!
    private(set) var workspaceItems: [String: NSStatusItem] = [:]
    private(set) var menuOrder: [String] = []
    let panel = OverviewPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var hosting: NSHostingController<Overview>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.sendAction(on: [.leftMouseDown])
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
            let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
            self?.dismissIfOutside(at: point)
            return event
        }
        hosting = NSHostingController(rootView:
            Overview(workspaces: workspaces, notifications: notifications,
                     close: { [weak self] in self?.panel.orderOut(nil) }, state: overviewState,
                     resized: { [weak self] height in self?.resizeOverview(to: height) }))
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
        if !CommandLine.arguments.contains("--menu-test") && !CommandLine.arguments.contains("--layout-test") {
            workspaces.start()
            notifications.start()
        }
    }

    func updateStatus() {
        let snapshot = workspaces.snapshot
        let spaces = snapshot.menuSpaces
        if spaces != menuOrder {
            for status in workspaceItems.values { NSStatusBar.system.removeStatusItem(status) }
            workspaceItems = [:]
            // New status items appear to the left of existing ones.
            for space in spaces.reversed() {
                let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                status.button?.target = self
                status.button?.action = #selector(workspaceClicked(_:))
                workspaceItems[space] = status
            }
            menuOrder = spaces
        }
        for space in spaces {
            guard let button = workspaceItems[space]?.button else { continue }
            let current = space == snapshot.current
            button.image = workspaceBadge(current && workspaces.error != nil ? "!" : space, selected: current)
            button.imagePosition = .imageLeft
            let bundles = snapshot.appBundles(in: space)
            button.attributedTitle = iconStrip(bundles)
            // Four points of outer padding instead of the default status-item margins.
            workspaceItems[space]?.length = button.image!.size.width + (bundles.isEmpty ? 0 : CGFloat(bundles.count * 21 + 4) + 2) + 4
            button.imageHugsTitle = true
            let names = snapshot.windows(in: space).map(\.app)
            button.toolTip = "Workspace \(space): \(Array(Set(names)).sorted().joined(separator: ", ")). Click to switch workspace."
            button.setAccessibilityLabel(button.toolTip)
        }
        let badge = notifications.badges.first
        let bell = NSImage(systemSymbolName: badge == nil ? "bell" : "bell.badge.fill", accessibilityDescription: "Workspace overview")!
        if badge != nil { item.button?.image = bell.withSymbolConfiguration(.init(paletteColors: [.systemOrange])) }
        else { bell.isTemplate = true; item.button?.image = bell }
        item.button?.imagePosition = .imageLeft
        item.button?.attributedTitle = NSAttributedString(string: "")
        item.length = 24
        item.button?.toolTip = badge.map { "Notifications: \($0.name). Click for overview." }
            ?? "Workspace Status: click for overview."
        item.button?.setAccessibilityLabel(item.button?.toolTip)
    }

    @objc func workspaceClicked(_ sender: NSStatusBarButton) {
        guard let space = workspaceItems.first(where: { $0.value.button === sender })?.key else { return }
        panel.orderOut(nil)
        if space != workspaces.snapshot.current {
            workspaces.perform(["workspace", space], completion: {})
        }
    }

    @objc func toggle() {
        guard let button = item.button else { return }
        showOverview(from: button)
    }

    func dismissIfOutside(at point: NSPoint) {
        guard panel.isVisible, !panel.frame.contains(point) else { return }
        if let button = item.button, let window = button.window,
           window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point) { return }
        panel.orderOut(nil)
    }

    private func showOverview(from button: NSStatusBarButton) {
        if panel.isVisible { panel.orderOut(nil); return }
        guard let window = button.window, let screen = window.screen else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        hosting.rootView.width = max(1, min(360, screen.visibleFrame.width - 28))
        fitOverview(visibleFrame: screen.visibleFrame, anchor: anchor)
        if !CommandLine.arguments.contains("--layout-test") { workspaces.refresh() }
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.contentView?.layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.10
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func resizeOverview(to height: CGFloat) {
        guard height > 0, abs(naturalHeight - height) > 0.5 else { return }
        naturalHeight = height
        guard panel.isVisible, let button = item.button, let window = button.window,
              let screen = window.screen else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        fitOverview(visibleFrame: screen.visibleFrame, anchor: anchor)
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
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
    }
}
