import Foundation

struct AppWindow: Decodable, Identifiable {
    let id: Int
    let app: String
    let bundle: String
    let title: String
    let workspace: String
    var isWorkspaceApplication: Bool {
        !["local.WorkspaceStatus", "com.apple.notificationcenterui", "com.apple.UserNotificationCenter"].contains(bundle)
    }
    enum CodingKeys: String, CodingKey {
        case id = "window-id", app = "app-name", bundle = "app-bundle-id"
        case title = "window-title", workspace
    }
}

struct Space: Decodable { let workspace: String }
struct FocusEvent: Decodable {
    let _event: String
    let windowId: Int?
}
struct Snapshot {
    let spaces: [String]
    let current: String
    let windows: [AppWindow]
    func windows(in space: String) -> [AppWindow] { windows.filter { $0.workspace == space } }
    var occupiedSpaces: [String] {
        Set(windows.map(\.workspace)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    var menuSpaces: [String] {
        Set(occupiedSpaces + [current]).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    func appBundles(in space: String) -> [String] {
        let names = Dictionary(windows(in: space).map { ($0.bundle, $0.app) }, uniquingKeysWith: { first, _ in first })
        return names.keys.sorted { left, right in
            let order = names[left]!.localizedStandardCompare(names[right]!)
            return order == .orderedSame ? left < right : order == .orderedAscending
        }
    }
}
