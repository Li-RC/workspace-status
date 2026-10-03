# Workspace Status

A standalone native macOS menu bar app for AeroSpace. Requires macOS 14 or later and a running AeroSpace installation. Liquid Glass sections and controls are available on macOS 26 and later, with a compatible appearance on earlier releases. Binaries are for Apple Silicon; `build.sh` also builds for Intel when run on an Intel Mac. No third-party packages or network services are used.

**Local development version: 1.1.0, unreleased.** The behavior below describes the current source. The latest published version is 1.0.2. Builds and releases are published only on explicit request.

[Download the latest published release](https://github.com/Li-RC/workspace-status/releases/latest)

## Run

Build from source or open the locally built **Workspace Status.app**. With a DMG, drag the app onto the Applications shortcut. It runs in the menu bar without a Dock icon.

- Every occupied workspace appears in natural numeric order, with an icon for every distinct open application, sorted by app name. The current workspace has a filled badge; other workspaces have outlined badges. Numbers follow the system's black/white menu bar contrast.
- The current workspace keeps its menu bar badge even if empty. Empty workspaces are excluded from the dropdown.
- Workspace Status's own popup and Notification Center windows are excluded from workspace application counts.
- Click a workspace indicator to select that workspace. Clicking the current workspace keeps it selected. Neither action opens the dropdown. There is no right-click dropdown shortcut.
- **Only the bell opens the dropdown; clicking it again closes it.** An orange bell indicates that an app has a Dock badge; hover to see its name.
- Menu bar app icons are part of the workspace button and select that workspace. They are not individual app buttons: splitting the existing native control would require custom hit testing or a different menu bar layout.
- The menu bar indicators use compact outer margins, including the bell.
- The dropdown is normally 360 points wide and has no scroll area. It grows downward as a workspace is added or its window list expands; Notifications and Quit move down with it. The top stays anchored below the bell. If the content exceeds the display height, the entire dropdown scales to fit the screen.
- The area around the glass blocks is fully transparent, with no extra background blur, border, or window shadow. All workspaces share one glass block, Notifications use another, and Quit is a small standalone glass button. On macOS 26+, native glass uses the system's appearance and Liquid Glass preferences, including accessibility transparency and contrast settings. The app applies no custom glass opacity, tint, or forced color scheme. Earlier macOS versions use compatible surfaces.
- The dropdown opens with a 100 ms fade and closes immediately. Reduce Motion disables the fade. Window disclosure changes animate over 120 ms.
- Click a workspace number in the dropdown to select it. Click an app icon to focus a window of that app in that workspace. Click the window count/chevron to expand the workspace, then click an individual window to focus it.
- All application icons remain available; larger groups wrap onto additional rows.
- Click a Notifications row to focus one of that app's windows or launch the app if no window is listed by AeroSpace.
- Quit is at the bottom of the dropdown.

The app uses AeroSpace's event subscription, with a 15-second reconciliation/reconnect interval. It never edits AeroSpace or SketchyBar configuration. It is built for AeroSpace workspaces; macOS Mission Control desktops are not supported.

macOS controls the available menu bar space and may hide status items when the bar is crowded. All occupied workspaces and applications remain available in the dropdown.

## Notifications and permission

**Notification Center is ignored.** The app does not observe Notification Center events, inspect banners or history, attribute notifications, or keep a recent notification list.

Workspace controls work without Accessibility permission. To read Dock badges, click **Enable Accessibility…**, then enable **Workspace Status** in System Settings → Privacy & Security → Accessibility. The app checks for permission changes automatically.

Dock badges are read from the Dock's Accessibility interface every five seconds and displayed under **Notifications**. They are app unread indicators, not proof of a new notification. Apps without exposed Dock badges will not appear. Only app names, icons, and badge values are displayed; no notification message content is accessed. Nothing is sent to a server or persisted.

The local build is ad-hoc signed and not notarized. Keep the app in a stable location before enabling Accessibility. Rebuilding or moving it may require re-enabling permission. To launch at login, add it in System Settings → General → Login Items.

## Rebuild and verify

Install Xcode or Apple's Command Line Tools with the macOS 26 SDK or newer, then run:

```bash
bash build.sh
"dist/Workspace Status.app/Contents/MacOS/WorkspaceStatus" --diagnose
```

The build runs targeted checks for JSON decoding (including quoted/newline titles), workspace ordering, occupied-workspace filtering, retaining an empty current workspace in the menu bar, app deduplication without truncation, and screen size limits. `--diagnose` reads live AeroSpace data without switching workspaces or prompting for permissions. It prints workspace/app names and permission state, excluding window titles.

`--smoke-test` briefly runs the real menu bar app for eight seconds, checks live workspace loading and menu bar image creation, reports Dock badge monitoring status, and exits. It does not switch workspaces or generate notifications.

`--popover-test` opens the real popup through the bell, changes the list, and checks that the window and its content stay within the display. It verifies the transparent background without an extra blur layer, completed fade, bell mouse-down handling, outside-click and Escape dismissal, and that clicking the current workspace does not open the popup. Add `--render-popup-preview /tmp/popup.png` to capture a stable dropdown, skipping the stress-list update. It exports the window and a `-composited.png` image of the dropdown region over the desktop; this requires screen capture access.

`--layout-test` verifies native panel growth when windows expand or a workspace is added, shrinking after collapse, a fixed top edge, and an 80-workspace list fitting the screen without a scroll view. It uses synthetic data and does not switch your workspaces. Add `--render-layout-preview /tmp/layout` to export collapsed and expanded examples.

`--bell-click-test` sends four mouse-down/up events through AppKit to the real bell button and verifies the sequence open → closed → open → closed. It does not move the pointer or switch workspaces.

`--menu-test` creates real menu bar indicators from a synthetic fixture. It checks ordering, native template badges, compact padding, uncut image bounds, and an eight-app workspace without truncation. It does not switch actual workspaces. Add `--render-menu-preview /tmp/workspaces.png` to export the fixture's controls, including the bell.

To render an offscreen layout preview from live workspace data:

```bash
"dist/Workspace Status.app/Contents/MacOS/WorkspaceStatus" --render-preview /tmp/workspace-status.png
```

Offscreen rendering does not reproduce WindowServer's native blur/glass composition. Use the popup window capture for appearance checks. Automated checks cover layout and the bell/current-workspace trigger paths; manual inactive-workspace switching and app focus still need validation in use.

Source is in `Sources/`: AeroSpace access and model, Dock Accessibility badge model, SwiftUI dropdown and menu bar controller, and the command-line verification entry point.

## License

MIT. See [LICENSE](LICENSE).

References: [Apple materials and system preferences](https://developer.apple.com/design/human-interface-guidelines/materials), [AeroSpace commands](https://nikitabobko.github.io/AeroSpace/commands), [Apple Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Apple NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview).
