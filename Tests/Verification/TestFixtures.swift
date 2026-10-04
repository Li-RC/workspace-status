import Foundation

func menuFixture() -> Snapshot {
    let bundles = ["com.apple.finder", "com.apple.Safari", "com.apple.iCal", "com.apple.mail",
                   "com.apple.Notes", "com.apple.Preview", "com.apple.Music", "com.apple.TextEdit"]
    var windows = bundles.enumerated().map {
        AppWindow(id: $0.offset, app: "App \($0.offset)", bundle: $0.element, title: "Test window", workspace: "1")
    }
    windows.append(AppWindow(id: 20, app: "App 0", bundle: bundles[0], title: "Second window", workspace: "1"))
    windows.append(AppWindow(id: 21, app: "Preview", bundle: bundles[5], title: "Test window", workspace: "2"))
    windows.append(AppWindow(id: 22, app: "Calendar", bundle: bundles[2], title: "Test window", workspace: "10"))
    return Snapshot(spaces: ["10", "3", "2", "1", "9"], current: "3", windows: windows)
}
