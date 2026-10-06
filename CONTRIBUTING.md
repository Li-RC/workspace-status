# Contributing

Bug reports and pull requests are welcome. For a bug report, include your macOS version, AeroSpace version, and steps to reproduce the issue. For code changes, run the relevant checks below and verify affected interactions in the app.

## Development setup

Follow the [build instructions](README.md#build-from-source) to build the app locally. The build uses Xcode's asset compiler for the editable Icon Composer project, alongside the Swift compiler.

## Continuous integration

The **Build and test** GitHub Action runs on pushes to `main`, pull requests targeting `main`, and manual runs. It builds the app and its Icon Composer assets on `macos-26`, runs the self-tests included in `build.sh`, and verifies the app signature. CI explicitly uses ad-hoc signing and needs no signing certificate or secrets. It does not publish releases or upload app bundles.

Interactive UI, Accessibility permissions, AeroSpace integration and external-display behavior still require the local checks below.

## Developer checks and previews

Run checks from the repository root. Quit any running Workspace Status instance before the UI checks so duplicate menu bar items do not affect ordering:

Keep the test app visible in Bartender or any other menu bar manager. A hidden item can have a zero-height native window on macOS 27, causing click and dropdown checks to fail even when launched through Launch Services. If testing with the manager temporarily closed, reopen it afterward.

```sh
app_binary="dist/Workspace Status.app/Contents/MacOS/WorkspaceStatus"
"$app_binary" --diagnose
"$app_binary" --settings-test
"$app_binary" --menu-test
"$app_binary" --app-click-test
"$app_binary" --placement-test
"$app_binary" --layout-test
"$app_binary" --bell-click-test
"$app_binary" --popover-test
```

| Check | Coverage |
| --- | --- |
| `--self-test` | JSON decoding, workspace ordering/filtering, app deduplication, placement and sizing, streamed focus history, settings persistence, and injected login registration/approval/error states; also runs during the build |
| `--settings-test` | Single settings window, close/reopen and keyboard commands, bell-only context menus, compact mode and immediate preferences on native/positioned strips, and onscreen window recovery; uses an isolated defaults suite and does not register login items |
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

Use `--settings-test --render-settings-preview <file>` for a settings window preview, or add `--hold-settings-preview` to inspect the native controls interactively. Login registration tests use injected service responses; separately verify registration/removal and approval against an installed signed app. Do not enable login registration for a temporary test bundle.

## Project structure

| Path | Purpose |
| --- | --- |
| `Sources/main.swift` | Command dispatch, duplicate-instance guard and app startup |
| `Sources/App.swift` | App lifecycle, grouped menu bar item and click routing |
| `Sources/Settings/SettingsStore.swift` | Persisted menu placement and notification preferences |
| `Sources/Settings/SettingsView.swift` | Native General, Menu Bar, Notifications and About controls |
| `Sources/Settings/SettingsWindowController.swift` | Single settings window, activation and display fitting |
| `Sources/Settings/LoginItemModel.swift` | System login registration status, changes and errors |
| `Sources/Workspaces/WorkspaceData.swift` | Decoded workspace/window data and snapshot ordering |
| `Sources/Workspaces/AeroSpace.swift` | AeroSpace commands, event subscription and workspace state |
| `Sources/Workspaces/AeroSpaceStartup.swift` | Dependency detection and install/open prompts |
| `Sources/Notifications.swift` | Dock badge monitoring through Accessibility |
| `Sources/Accessibility.swift` | Shared Accessibility attribute and child lookup helpers |
| `Sources/AppIcons.swift` | Application icons, workspace badges and icon strips |
| `Sources/Overview/WorkspaceAppButton.swift` | Dropdown app buttons and single/double click handling |
| `Sources/Overview/Overview.swift` | SwiftUI dropdown, expansion state and native glass styling |
| `Sources/Overview/OverviewPanel.swift` | Dropdown panel sizing and appearance/dismissal animation |
| `Sources/MenuBar/MenuPlacement.swift` | Display-aware placement and positioned panel lifecycle |
| `Sources/MenuBar/MenuGeometry.swift` | System menu bar and status item geometry |
| `Sources/MenuBar/MenuStripView.swift` | Positioned strip drawing and input coordinates |
| `Tests/Verification/` | In-app checks, diagnostics, previews and shared fixtures |
| `Tests/MenuFixture.swift` | Native menu host for hardware placement checks |
| `Tests/check-placement-live.py` | Live check runner, log capture and restoration of installed apps |
| `build.sh` | Local compilation and signing |
| [`Design/AppIcon/`](Design/AppIcon/) | Editable Icon Composer project with embedded SVG layers, and appearance previews |

`build.sh` compiles `Sources/*.swift`, `Sources/*/*.swift` and `Tests/Verification/*.swift` into the app so the verification flags above remain available. `Tests/MenuFixture.swift` is a separate executable compiled by the live placement runner.
