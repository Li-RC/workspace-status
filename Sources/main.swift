import AppKit

let args = CommandLine.arguments
setbuf(stdout, nil)
if args.contains("--self-test") {
    try runSelfTests()
} else if args.contains("--settings-test") {
    runSettingsTest(args: args)
} else if args.contains("--app-click-test") {
    runAppClickTest()
} else if args.contains("--placement-test") {
    runPlacementTest()
} else if args.contains("--menu-test") {
    runMenuTest(args: args)
} else if args.contains("--layout-test") {
    runLayoutTest(args: args)
} else if args.contains("--bell-click-test") {
    runBellClickTest()
} else if args.contains("--popover-test") {
    runPopoverTest(args: args)
} else if args.contains("--diagnose") {
    diagnose()
} else if let index = args.firstIndex(of: "--render-preview"), args.count > index + 1 {
    try renderOverviewPreview(args: args, index: index)
} else {
    let application = NSApplication.shared
    // Launch Services normally prevents a second instance; also protect direct executable launches.
    let bundle = Bundle.main.bundleIdentifier ?? "local.WorkspaceStatus"
    if NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
        .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) { exit(0) }
    let delegate = AppDelegate()
    application.delegate = delegate
    if args.contains("--placement-live-test") {
        scheduleLivePlacementTest(delegate: delegate, args: args)
    }
    if args.contains("--smoke-test") {
        scheduleSmokeTest(delegate: delegate)
    }
    application.run()
}
