import AppKit
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var login: LoginItemModel
    @ObservedObject var notifications: NotificationModel

    var body: some View {
        TabView {
            Form {
                Section {
                    Toggle("Launch at login", isOn: Binding(get: { login.requested }, set: login.setEnabled))
                    Text(login.description).font(.caption).foregroundStyle(.secondary)
                    if login.status == .requiresApproval {
                        Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                    if let error = login.error {
                        Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                    }
                } header: { Text("Startup") }
                Section {
                    Text("Workspace Status runs in the menu bar. Closing Settings keeps it running.")
                        .foregroundStyle(.secondary)
                    Text("Appearance follows macOS, including accent color and accessibility preferences.")
                        .foregroundStyle(.secondary)
                } header: { Text("Behavior") }
            }.formStyle(.grouped).tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section {
                    Picker("Placement", selection: $settings.menuBarPosition) {
                        ForEach(MenuBarPosition.allCases) { position in Text(position.title).tag(position) }
                    }
                    Text(settings.menuBarPosition == .automatic
                         ? "On displays with a notch, keep the existing position. On other displays, center when possible or place after application menus. Accessibility access is required."
                         : "Use the normal macOS menu bar item. You can move it with Command-drag or manage it with Bartender.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }

            Form {
                Section {
                    Toggle("Show Dock badges", isOn: $settings.dockBadgesEnabled)
                    Text("Display app unread indicators from the Dock. Notification Center and notification content are never read.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("Notifications") }
                Section {
                    LabeledContent("Accessibility", value: notifications.authorized ? "Enabled" : "Not enabled")
                    Button("Open Accessibility Settings…") { notifications.enable() }
                    Text("Accessibility also enables automatic placement on displays without a notch.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("Permission") }
            }.formStyle(.grouped).tabItem { Label("Notifications", systemImage: "bell") }

            VStack(spacing: 12) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable().scaledToFit().frame(width: 88, height: 88)
                Text("Workspace Status").font(.title2.bold())
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                    .foregroundStyle(.secondary)
                Text("AeroSpace workspaces and app unread indicators in your macOS menu bar.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Link("GitHub Repository", destination: URL(string: "https://github.com/Li-RC/workspace-status")!)
                Button("MIT License") {
                    if let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") { NSWorkspace.shared.open(url) }
                }
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Label("About", systemImage: "info.circle") }
        }.padding(12).frame(width: 520, height: 360)
    }
}
