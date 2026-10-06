import AppKit
import SwiftUI
import ApplicationServices

func runSelfTests() throws {
    runSettingsStoreTests()
    runAeroSpaceStartupTests()
    let json = #"[{"window-id":42,"app-name":"Editor","app-bundle-id":"test.editor","window-title":"quote \" newline\n $(echo no)","workspace":"dev space"}]"#
    let windows = try JSONDecoder().decode([AppWindow].self, from: Data(json.utf8))
    precondition(windows[0].id == 42 && windows[0].workspace == "dev space")
    precondition(windows[0].title.contains("\n") && windows[0].title.contains("$(echo no)"))
    precondition(windows[0].isWorkspaceApplication)
    for bundle in ["local.WorkspaceStatus", "com.apple.notificationcenterui", "com.apple.UserNotificationCenter"] {
        precondition(!AppWindow(id: 0, app: "Utility", bundle: bundle, title: "Popup", workspace: "2").isWorkspaceApplication)
    }
    let snapshot = Snapshot(spaces: ["dev space", "empty"], current: "empty", windows: windows)
    precondition(snapshot.windows(in: "empty").isEmpty && snapshot.windows(in: "dev space").count == 1)
    let shortScreen = NSRect(x: 0, y: 40, width: 800, height: 500)
    let shortSize = overviewSize(visibleFrame: shortScreen, anchor: NSRect(x: 600, y: 540, width: 100, height: 24))
    precondition(shortSize.width + 28 <= shortScreen.width && shortSize.height + 28 <= shortScreen.height)
    precondition(shortSize.width + 2 * overviewShadowMargin <= shortScreen.width
        && shortSize.height + overviewTopMargin + overviewShadowMargin <= shortScreen.height,
        "Native shadow margins do not fit the screen")
    let secondaryScreen = NSRect(x: -500, y: -700, width: 400, height: 600)
    let secondarySize = overviewSize(visibleFrame: secondaryScreen, anchor: NSRect(x: -200, y: -100, width: 80, height: 24))
    precondition(secondarySize.width + 28 <= secondaryScreen.width && secondarySize.height + 28 <= secondaryScreen.height)
    let tallSize = overviewSize(visibleFrame: shortScreen, anchor: NSRect(x: 600, y: 540, width: 24, height: 24), contentHeight: 1800)
    precondition(tallSize.height + 28 <= shortScreen.height && tallSize.width < 360)
    let display = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let saved = NSRect(x: 1020, y: 876, width: 320, height: 24)
    func strip(_ screen: NSRect = display, notch: Bool = false, menus: CGFloat = 480,
               status: CGFloat = 1120, width: CGFloat = 320) -> NSRect? {
        menuStripFrame(screen: screen, hasNotch: notch, native: saved, menuEnd: menus,
                       statusStart: status, width: width, workspaceWidth: width - 24, height: 24)
    }
    precondition(strip(notch: true, menus: 1200) == saved, "Notched display lost its saved position")
    precondition(strip() == NSRect(x: 570, y: 876, width: 320, height: 24), "The workspace group was not centered independently of the bell")
    precondition(strip(width: 100)?.minX == 680, "A compact workspace group was not centered")
    precondition(strip(menus: 600)?.minX == 608, "Long app menus should place the strip just after them")
    precondition(strip(menus: 400, status: 850)?.minX == 408, "Right-side icons overlapped a centered strip")
    precondition(strip(menus: 400, status: 890)?.minX == 408, "Centering the workspaces left no room for the bell")
    precondition(strip(menus: 700, status: 900)?.width == 184, "A crowded bar overlapped other icons")
    precondition(strip(menus: 900, status: 900) == nil, "A strip was drawn without any available space")
    let offsetDisplay = NSRect(x: -1600, y: -400, width: 1600, height: 1000)
    precondition(strip(offsetDisplay, menus: -1200, status: -300)?.minX == -950,
                 "A secondary display was centered using primary-display coordinates")
    precondition(menuStripFrame(screen: display, hasNotch: true, native: nil, menuEnd: 0,
        statusStart: 1440, width: 320, workspaceWidth: 296, height: 24) == nil, "A missing native slot invented a notched position")
    print("PASS: saved notched position; non-notched centering, after-menus placement, crowded bars and display offsets.")
    let fixture = menuFixture()
    precondition(fixture.occupiedSpaces == ["1", "2", "10"])
    precondition(fixture.menuSpaces == ["1", "2", "3", "10"])
    precondition(fixture.appBundles(in: "1").count == 8)
    precondition(fixture.appBundles(in: "1").first == "com.apple.finder")
    precondition(fixture.appBundles(in: "3").isEmpty)
    let model = WorkspaceModel()
    model.snapshot = Snapshot(spaces: fixture.spaces, current: "1", windows: fixture.windows)
    precondition(model.navigationArguments(to: "2", appBundle: "com.apple.Preview") == ["workspace", "2"])
    precondition(model.navigationArguments(to: "2", appBundle: "com.apple.Preview", focusApp: true) == ["focus", "--window-id", "21"])
    precondition(model.navigationArguments(to: "2", appBundle: "missing.app", focusApp: true) == nil)
    precondition(model.navigationArguments(to: "1") == nil)
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "0"])
    model.consumeEvents(Data(#"{"_event":"focus-changed","windowId":20}"#.utf8))
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "0"],
                 "A partial event changed focus history")
    model.consumeEvents(Data("\n{\"_event\":\"mode-changed\",\"mode\":\"main\"}\n{\"_event\":\"focus-changed\",\"windowId\":21}\n".utf8))
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "20"])
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.Preview") == ["focus", "--window-id", "5"],
                 "App focus crossed into another workspace")
    model.consumeEvents(Data("invalid JSON\n{\"_event\":\"focus-changed\",\"windowId\":null}\n{\"_event\":\"focus-changed\",\"windowId\":0}\n".utf8))
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "0"])
    model.snapshot = Snapshot(spaces: fixture.spaces, current: "1", windows: fixture.windows.filter { $0.id != 0 })
    precondition(model.navigationArguments(to: "1", appBundle: "com.apple.finder") == ["focus", "--window-id", "20"],
                 "App focus selected a closed window")
    precondition(model.navigationArguments(to: "1", appBundle: "missing.app") == nil)
    print("PASS: inactive switching, current-app focus, streamed focus history and closed-window fallback.")
    print("PASS: JSON, screen sizing, workspace ordering/filtering and all-app deduplication.")
}
