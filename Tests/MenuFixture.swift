import AppKit

// A separate regular app exposes real menu geometry to the placement check's AX client.
let application = NSApplication.shared
let commandURL = URL(fileURLWithPath: CommandLine.arguments[1])

final class MenuFixtureDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer?
    var phase = ""
    let window = NSWindow(contentRect: NSRect(x: 40, y: 100, width: 280, height: 90),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = "Workspace Status Placement Test"
        window.level = .floating
        let label = NSTextField(labelWithString: "Checking menu placement on both displays…")
        label.frame = NSRect(x: 14, y: 30, width: 260, height: 24)
        window.contentView?.addSubview(label)
        update()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.update() }
    }

    func update() {
        guard let next = try? String(contentsOf: commandURL, encoding: .utf8), next != phase else { return }
        phase = next
        if phase == "quit" { NSApp.terminate(nil); return }
        let bar = NSMenu()
        let appItem = NSMenuItem(title: "Menu Fixture", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "Menu Fixture")
        appMenu.addItem(withTitle: "Quit Menu Fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        bar.addItem(appItem)
        for title in phase == "long" ? ["File", "Edit", "View", "Window", "Help", "Tools", "Bookmarks"] : ["File"] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            menu.addItem(withTitle: "Test Action", action: nil, keyEquivalent: "")
            item.submenu = menu
            bar.addItem(item)
        }
        NSApp.mainMenu = bar
    }
}

application.setActivationPolicy(.regular)
let delegate = MenuFixtureDelegate()
application.delegate = delegate
application.run()
