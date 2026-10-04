# Contributing

Bug reports and pull requests are welcome. For a bug report, include your macOS version, AeroSpace version, and steps to reproduce the issue. For code changes, run the relevant checks below and verify affected interactions in the app.

## Development setup

Follow the [build instructions](README.md#build-from-source) to build the app locally. The build uses Xcode's asset compiler for the editable Icon Composer project, alongside the Swift compiler.

## Developer checks and previews

Run checks from the repository root. Quit any running Workspace Status instance before the UI checks so duplicate menu bar items do not affect ordering:

Keep the test app visible in Bartender or any other menu bar manager. A hidden item can have a zero-height native window on macOS 27, causing click and dropdown checks to fail even when launched through Launch Services. If testing with the manager temporarily closed, reopen it afterward.

```sh
app_binary="dist/Workspace Status.app/Contents/MacOS/WorkspaceStatus"
"$app_binary" --diagnose
"$app_binary" --menu-test
"$app_binary" --app-click-test
"$app_binary" --placement-test
"$app_binary" --layout-test
"$app_binary" --bell-click-test
"$app_binary" --popover-test
```

| Check | Coverage |
| --- | --- |
| `--self-test` | JSON decoding, workspace ordering and filtering, app deduplication, display size limits, placement around menus/status icons and across display coordinates, streamed focus history, and workspace-specific app selection; also runs during the build |
| `--diagnose` | Live workspace and application data, Accessibility state, and menu geometry counts when permission is available; excludes window titles |
| `--smoke-test` | Eight-second run checking live workspace loading and menu bar image creation; quit any existing instance first |
| `--menu-test` | Native menu bar ordering, complete app icons, compact spacing, single/double click routing, preserved app targets after rearrangement, and a persistent grouped item through workspace insertion and removal |
| `--app-click-test` | Dropdown app single/double clicks, cancellation of pending single clicks, and immediate keyboard activation |
| `--placement-test` | Transparent positioned strip, scaled click routing, active-app focus, double clicks, bell toggling, dropdown anchoring, mixed-display slot reservation and native restoration; uses fixture geometry on the connected display |
| `--layout-test` | Expansion, added workspaces, collapse, a fixed top edge, and a tall list fitting without scrolling |
| `--bell-click-test` | Four native bell clicks verifying open → closed → open → closed |
| `--popover-test` | Popup containment, transparent background, completed fade, and dismissal behavior |

On macOS 27, launch UI checks through Launch Services. Direct executable launches can report a zero-height menu bar window. Use `open` with the check's arguments and inspect both logs for failures; `open` does not report the app's test exit status:

```sh
open -n -W -o /tmp/workspace-status-check.log --stderr /tmp/workspace-status-check-error.log \
  "dist/Workspace Status.app" --args --menu-test
cat /tmp/workspace-status-check.log /tmp/workspace-status-check-error.log
```

The checks do not switch your workspaces or generate notifications. Menu and layout tests use synthetic data. Inactive-workspace switching and individual app focus still require manual validation.

Native menu/popup checks retain their original placement so they can be compared with the stable version. Before shipping adaptive placement, also connect a display without a notch and check both centering and placement after long application menus, display reconnects, menu bar auto-hide, full-screen apps, and Bartender visibility. The placement fixture checks input and rendering without requiring an external display; it does not verify the system's multi-display Accessibility geometry.

With the desktop unlocked and an external display connected, run `python3 Tests/check-placement-live.py`. It builds a temporary regular app with short and long menus, checks available space and dropdown anchors on both displays, then closes the helper. It temporarily stops running Workspace Status and Bartender 7 Setapp instances and reopens the installed copies afterward. Run it from an Accessibility-enabled terminal. Whether centering fits depends on the display width and visible status icons; fixture tests separately cover a clear center. Logs and the helper bundle are kept in the printed temporary directory.

To capture the native dropdown over the desktop:

```sh
"$app_binary" --popover-test --render-popup-preview /tmp/workspace-status.png
```

This requires screen capture access and exports both the window image and a `-composited.png` preview. Other preview options are `--render-menu-preview <file>` with `--menu-test`, `--render-layout-preview <prefix>` with `--layout-test`, and `--render-preview <file>` for an offscreen layout. Offscreen previews do not reproduce native glass composition.

## Project structure

| Path | Purpose |
| --- | --- |
| `Sources/AeroSpace.swift` | AeroSpace integration and workspace state |
| `Sources/Notifications.swift` | Dock badge monitoring through Accessibility |
| `Sources/App.swift` | Menu bar controls and the SwiftUI dropdown |
| `Sources/MenuPlacement.swift` | Display-aware strip placement, menu geometry and transparent positioned panels |
| `Sources/main.swift` | App entry point and verification commands |
| `Tests/MenuFixture.swift` | Native menu host for hardware placement checks |
| `Tests/check-placement-live.py` | Live check runner, log capture and restoration of installed apps |
| `build.sh` | Local compilation and signing |
| [`Design/AppIcon/`](Design/AppIcon/) | Editable Icon Composer project, SVG layers, and appearance previews |
