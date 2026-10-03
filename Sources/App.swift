import AppKit
import SwiftUI
import CoreText

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

func workspaceBadge(_ label: String) -> NSImage {
    let font = NSFont.systemFont(ofSize: 12, weight: .bold)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: label,
        attributes: [.font: font, .foregroundColor: NSColor.black]))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let width = max(22, ceil(bounds.width) + 10)
    let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { _ in
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 2, width: width, height: 18), xRadius: 5, yRadius: 5).fill()
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: width / 2 - bounds.midX, y: 11 - bounds.midY)
        // Cut the centered number out of the template's solid badge.
        context.setBlendMode(.destinationOut)
        CTLineDraw(line, context)
        context.restoreGState()
        return true
    }
    image.isTemplate = true
    return image
}

func overviewSize(visibleFrame: NSRect, anchor: NSRect) -> NSSize {
    // Leave space for the popover's border/arrow inside the screen's usable area.
    let height = min(anchor.minY, visibleFrame.maxY) - visibleFrame.minY - 28
    return NSSize(width: max(1, min(430, visibleFrame.width - 28)),
                  height: max(1, min(650, height)))
}

struct Overview: View {
    @ObservedObject var workspaces: WorkspaceModel
    @ObservedObject var notifications: NotificationModel
    let close: () -> Void
    var size = NSSize(width: 430, height: 650)
    @State private var expanded: Set<String> = []

    func select(_ space: String) {
        workspaces.perform(["workspace", space], completion: close)
    }
    func focus(_ window: AppWindow) {
        workspaces.perform(["focus", "--window-id", String(window.id)], completion: close)
    }
    func openApp(_ bundle: String) {
        if let window = workspaces.snapshot.windows.first(where: { $0.bundle == bundle }) {
            focus(window)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
            close()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workspace Status").font(.headline)
                    Text("AeroSpace · workspace \(workspaces.snapshot.current)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { workspaces.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("Refresh workspaces")
            }.padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let error = workspaces.error {
                        Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                        Text("Start AeroSpace, then refresh. The last successful view may be out of date.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("WORKSPACES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(workspaces.snapshot.spaces, id: \.self) { space in
                        let windows = workspaces.snapshot.windows(in: space)
                        let bundles = Array(Set(windows.map(\.bundle))).sorted()
                        let current = space == workspaces.snapshot.current
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Button { select(space) } label: {
                                    HStack(spacing: 10) {
                                        Text(space).font(.system(.body, design: .rounded).weight(.bold))
                                            .frame(minWidth: 24, minHeight: 24)
                                            .background(current ? Color.blue : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                            .foregroundStyle(current ? Color.white : Color.primary)
                                        if bundles.isEmpty {
                                            Text("Empty workspace").font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            ForEach(bundles.prefix(7), id: \.self) { bundle in
                                                AppIcon(bundle: bundle).help(windows.first { $0.bundle == bundle }?.app ?? bundle)
                                            }
                                            if bundles.count > 7 { Text("+\(bundles.count - 7)").font(.caption) }
                                        }
                                        Spacer(minLength: 0)
                                        if current { Text("CURRENT").font(.system(size: 9, weight: .bold)).foregroundStyle(.blue) }
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).help("Switch to workspace \(space)")
                                if !windows.isEmpty {
                                    Button {
                                        if expanded.contains(space) { expanded.remove(space) } else { expanded.insert(space) }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text("\(windows.count)").monospacedDigit()
                                            Image(systemName: expanded.contains(space) ? "chevron.up" : "chevron.down")
                                        }.font(.caption).foregroundStyle(.secondary)
                                    }.buttonStyle(.borderless).help("Show windows in workspace \(space)")
                                }
                            }
                            if expanded.contains(space) {
                                ForEach(windows) { window in
                                    Button { focus(window) } label: {
                                        HStack(spacing: 8) {
                                            AppIcon(bundle: window.bundle)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(window.app).font(.caption.weight(.medium))
                                                Text(window.title.isEmpty ? "Untitled window" : window.title)
                                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                                        }.padding(5).contentShape(Rectangle())
                                    }.buttonStyle(.plain).help("Focus \(window.title)")
                                }
                            }
                        }.padding(10)
                            .background(current ? Color.blue.opacity(0.08) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    }
                    Divider().padding(.vertical, 4)
                    HStack {
                        Text("RECENT NOTIFICATION APPS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        if !notifications.notices.isEmpty {
                            Button("Clear") { notifications.clear() }.buttonStyle(.borderless).font(.caption)
                        }
                    }
                    if !notifications.authorized {
                        Text("Allow Accessibility to watch visible notification banners and read app badges.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Enable Accessibility…") { notifications.enable() }
                    } else {
                        Text(notifications.monitorStatus).font(.caption).foregroundStyle(.secondary)
                        if notifications.notices.isEmpty {
                            Text("No notification sources detected since launch.").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(notifications.notices) { notice in
                            Button { openApp(notice.bundle) } label: {
                                HStack {
                                    AppIcon(bundle: notice.bundle)
                                    Text(notice.name).font(.callout)
                                    Spacer()
                                    Text(notice.date, style: .time).font(.caption).foregroundStyle(.secondary)
                                    Text("\(notice.count)").font(.caption).monospacedDigit()
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                        if !notifications.badges.isEmpty {
                            Text("DOCK BADGES").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 6)
                            ForEach(notifications.badges) { badge in
                                Button { openApp(badge.bundle) } label: {
                                    HStack {
                                        AppIcon(bundle: badge.bundle)
                                        Text(badge.name).font(.callout)
                                        Spacer()
                                        Text(badge.value).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Visible banners only; Focus and macOS changes can hide sources. Dock badges are app unread indicators.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }.padding(16)
            }
            Divider()
            HStack {
                Text("Click a workspace to switch · expand to focus a window")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless).font(.caption)
            }.padding(12)
        }.frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let workspaces = WorkspaceModel()
    let notifications = NotificationModel()
    var item: NSStatusItem!
    let popover = NSPopover()
    private var hosting: NSHostingController<Overview>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggle)
        popover.behavior = .transient
        hosting = NSHostingController(rootView:
            Overview(workspaces: workspaces, notifications: notifications, close: { [weak self] in self?.popover.close() }))
        hosting.sizingOptions = []
        popover.contentViewController = hosting
        workspaces.changed = { [weak self] in self?.updateStatus() }
        notifications.changed = { [weak self] in self?.updateStatus() }
        updateStatus()
        workspaces.start()
        notifications.start()
    }

    func updateStatus() {
        let current = workspaces.snapshot.current
        let windows = workspaces.snapshot.windows(in: current)
        let bundles = Array(Set(windows.map(\.bundle))).sorted()
        let latest = notifications.notices.first
        let badges = notifications.badges
        let label = workspaces.error == nil ? current : "!"
        let visible = Array(bundles.prefix(3))
        let width = CGFloat(visible.count * 21) + 25 + (latest != nil || !badges.isEmpty ? 21 : 0)
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { rect in
            var x: CGFloat = 4
            for bundle in visible {
                appIcon(bundle).draw(in: NSRect(x: x, y: 3, width: 16, height: 16)); x += 21
            }
            let symbol = latest != nil || !badges.isEmpty ? "bell.badge.fill" : "bell"
            let bell = NSImage(systemSymbolName: symbol, accessibilityDescription: "Notifications")!
                .withSymbolConfiguration(.init(paletteColors: [latest != nil || !badges.isEmpty ? .systemOrange : .labelColor]))!
            bell.draw(in: NSRect(x: x + 3, y: 4, width: 14, height: 14))
            if let bundle = latest?.bundle ?? badges.first?.bundle {
                appIcon(bundle).draw(in: NSRect(x: x + 23, y: 3, width: 16, height: 16))
            }
            return true
        }
        // Keep the badge native/template-tinted without recoloring the app icons.
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: (NSFont.systemFont(ofSize: 12).capHeight - 22) / 2, width: width, height: 22)
        item.button?.image = workspaceBadge(label)
        item.button?.imagePosition = .imageLeft
        item.button?.attributedTitle = NSAttributedString(attachment: attachment)
        let source = latest.map { "Latest notification: \($0.name)." } ?? badges.first.map { "Dock badge: \($0.name)." } ?? ""
        item.button?.toolTip = "Workspace \(current): \(Array(Set(windows.map(\.app))).sorted().joined(separator: ", ")). \(source) Click to view all workspaces."
        item.button?.setAccessibilityLabel("Workspace Status. \(item.button?.toolTip ?? "")")
    }

    @objc func toggle() {
        if popover.isShown { popover.close(); return }
        guard let button = item.button, let window = button.window, let screen = window.screen else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let size = overviewSize(visibleFrame: screen.visibleFrame, anchor: anchor)
        hosting.rootView.size = size
        hosting.view.setFrameSize(size)
        hosting.preferredContentSize = size
        popover.contentSize = size
        workspaces.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: button.isFlipped ? .maxY : .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        workspaces.stop(); notifications.stop()
    }
}
