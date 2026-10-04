# Contributing

Bug reports and pull requests are welcome. For a bug report, include your macOS version, AeroSpace version, and steps to reproduce the issue. For code changes, run the relevant checks below and verify affected interactions in the app.

## Development setup

Follow the [build instructions](README.md#build-from-source) to build the app locally. The build uses Xcode's asset compiler for the editable Icon Composer project, alongside the Swift compiler.

## Developer checks and previews

Run checks from the repository root. Quit any running Workspace Status instance before the UI checks so duplicate menu bar items do not affect ordering:

```sh
app_binary="dist/Workspace Status.app/Contents/MacOS/WorkspaceStatus"
"$app_binary" --diagnose
"$app_binary" --menu-test
"$app_binary" --layout-test
"$app_binary" --bell-click-test
"$app_binary" --popover-test
```

| Check | Coverage |
| --- | --- |
| `--self-test` | JSON decoding, workspace ordering and filtering, app deduplication, and display size limits; also runs during the build |
| `--diagnose` | Live workspace and application data plus Accessibility state, excluding window titles |
| `--smoke-test` | Eight-second run checking live workspace loading and menu bar image creation; quit any existing instance first |
| `--menu-test` | Native menu bar ordering, complete app icons, compact spacing, current-workspace clicks, and a persistent grouped item through workspace insertion and removal |
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
| `Sources/main.swift` | App entry point and verification commands |
| `build.sh` | Local compilation and signing |
| [`Design/AppIcon/`](Design/AppIcon/) | Editable Icon Composer project, SVG layers, and appearance previews |
