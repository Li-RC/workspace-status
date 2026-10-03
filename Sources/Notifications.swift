import AppKit
import ApplicationServices

struct AppNotice: Identifiable {
    let bundle: String
    let name: String
    var date: Date
    var count: Int
    var id: String { bundle }
}

struct DockBadge: Identifiable {
    let name: String
    let bundle: String
    let value: String
    var id: String { bundle }
}

// Conservative attribution: a notification source must match an application name exactly.
// Body text is never saved, and a window with several distinct sources is not attributed.
func notificationSource(_ labels: [String], apps: [String: String]) -> String? {
    let matches = Set(labels.compactMap { apps[$0.trimmingCharacters(in: .whitespacesAndNewlines)] })
    return matches.count == 1 ? matches.first : nil
}

func axValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
    return result
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    axValue(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

final class NotificationModel: ObservableObject {
    @Published var authorized = false
    @Published var notices: [AppNotice] = []
    @Published var badges: [DockBadge] = []
    @Published var monitorStatus = "Enable Accessibility to identify notification apps."
    var changed: (() -> Void)?
    private var observers: [pid_t: AXObserver] = [:]
    private var roots: [pid_t: AXUIElement] = [:]
    private var seen: Set<String> = []
    private var timer: Timer?
    private var scanScheduled = false
    private let queue = DispatchQueue(label: "WorkspaceStatus.accessibility", qos: .utility)
    private var scanning = false

    func start() {
        checkPermission()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }

    func enable() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func checkPermission() {
        authorized = AXIsProcessTrusted()
        guard authorized else {
            monitorStatus = "Enable Accessibility to identify notification apps."
            badges = []
            changed?()
            return
        }
        let apps = NSWorkspace.shared.runningApplications.filter {
            ["com.apple.notificationcenterui", "com.apple.UserNotificationCenter"].contains($0.bundleIdentifier ?? "")
        }
        let running = Set(apps.map(\.processIdentifier))
        for pid in Array(observers.keys) where !running.contains(pid) {
            if let observer = observers.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
            roots.removeValue(forKey: pid)
        }
        for app in apps where observers[app.processIdentifier] == nil {
            let root = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.25)
            roots[app.processIdentifier] = root
            var observer: AXObserver?
            let callback: AXObserverCallback = { _, _, _, context in
                guard let context else { return }
                let model = Unmanaged<NotificationModel>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async { model.scheduleScan() }
            }
            guard AXObserverCreate(app.processIdentifier, callback, &observer) == .success,
                  let observer else { continue }
            var supported = false
            for event in [kAXWindowCreatedNotification, kAXCreatedNotification, kAXLayoutChangedNotification] {
                let result = AXObserverAddNotification(observer, root, event as CFString,
                    Unmanaged.passUnretained(self).toOpaque())
                supported = supported || result == .success
            }
            if supported {
                observers[app.processIdentifier] = observer
                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
        }
        monitorStatus = observers.isEmpty ? "Accessibility enabled · periodic banner checks" : "Accessibility enabled · observing visible banners"
        scan()
    }

    private func scheduleScan() {
        guard !scanScheduled else { return }
        scanScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.scanScheduled = false
            self?.scan()
        }
    }

    private func scan() {
        guard authorized, !scanning else { return }
        scanning = true
        let applications = NSWorkspace.shared.runningApplications
        var names: [String: String] = [:]
        for app in applications {
            if let name = app.localizedName, let bundle = app.bundleIdentifier { names[name] = bundle }
        }
        let roots = Array(self.roots.values)
        let dock = applications.first { $0.bundleIdentifier == "com.apple.dock" }
        queue.async {
            var visible: [String: (String, String)] = [:]
            for root in roots {
                let windows = axValue(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
                for window in windows {
                    // Only actual banners, not the history panel or widgets. Unknown structures are skipped.
                    let subrole = axValue(window, kAXSubroleAttribute) as? String ?? ""
                    let identifier = axValue(window, kAXIdentifierAttribute) as? String ?? ""
                    guard subrole.localizedCaseInsensitiveContains("notification") ||
                          identifier.localizedCaseInsensitiveContains("banner") || subrole == "AXSystemDialog" else { continue }
                    var labels: [String] = [], visited = 0
                    self.walk(window, depth: 0, visited: &visited) { element in
                        for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                            if let value = axValue(element, key) as? String { labels.append(value) }
                        }
                    }
                    if let bundle = notificationSource(labels, apps: names),
                       let name = names.first(where: { $0.value == bundle })?.key {
                        // Deduplication lives only in memory while the banner is visible.
                        let signature = bundle + "\u{1f}" + labels.joined(separator: "\u{1f}")
                        visible[signature] = (bundle, name)
                    }
                }
            }
            var badges: [DockBadge] = []
            if let dock {
                let root = AXUIElementCreateApplication(dock.processIdentifier)
                AXUIElementSetMessagingTimeout(root, 0.25)
                var visited = 0
                self.walk(root, depth: 0, visited: &visited) { element in
                    guard let badge = axValue(element, "AXStatusLabel") as? String, !badge.isEmpty,
                          let name = axValue(element, kAXTitleAttribute) as? String,
                          let bundle = names[name] else { return }
                    badges.append(DockBadge(name: name, bundle: bundle, value: badge))
                }
            }
            DispatchQueue.main.async {
                self.scanning = false
                guard self.authorized else { return }
                for (signature, source) in visible where !self.seen.contains(signature) {
                    if let index = self.notices.firstIndex(where: { $0.bundle == source.0 }) {
                        self.notices[index].date = Date(); self.notices[index].count += 1
                    } else {
                        self.notices.append(AppNotice(bundle: source.0, name: source.1, date: Date(), count: 1))
                    }
                }
                self.seen = Set(visible.keys)
                self.notices.sort { $0.date > $1.date }
                self.notices = Array(self.notices.prefix(20))
                self.badges = badges.sorted { $0.name < $1.name }
                self.changed?()
            }
        }
    }

    private func walk(_ element: AXUIElement, depth: Int, visited: inout Int, body: (AXUIElement) -> Void) {
        guard depth < 12, visited < 400 else { return }
        visited += 1
        body(element)
        for child in axChildren(element) { walk(child, depth: depth + 1, visited: &visited, body: body) }
    }

    func clear() { notices = []; changed?() }
    func stop() {
        timer?.invalidate()
        for observer in observers.values {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observers = [:]
    }
}
