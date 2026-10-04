import AppKit
import SwiftUI
import ApplicationServices

func diagnose() {
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
}

func renderOverviewPreview(args: [String], index: Int) throws {
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
}
