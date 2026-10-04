import AppKit
import SwiftUI
import ApplicationServices

func scheduleLivePlacementTest(delegate: AppDelegate, args: [String]) {
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

func scheduleSmokeTest(delegate: AppDelegate) {
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
