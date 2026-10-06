<div align="center">
  <img src="Design/AppIcon/preview.png" width="112" height="112" alt="Workspace Status, a native macOS menu bar app for AeroSpace workspace switching" />
  <h1>Workspace Status</h1>
  <p>A native macOS menu bar app for viewing and switching AeroSpace workspaces.</p>
  <p>
    <a href="LICENSE"><img src="https://img.shields.io/github/license/Li-RC/workspace-status?label=license&amp;color=blue" alt="License: MIT" /></a>
    <a href="#requirements"><img src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&amp;logoColor=white" alt="macOS 14 or later" /></a>
    <a href="#build-from-source"><img src="https://img.shields.io/badge/Built_with-Swift-F05138?logo=swift&amp;logoColor=white" alt="Built with Swift" /></a>
    <a href="https://github.com/Li-RC/workspace-status/releases/latest"><img src="https://img.shields.io/github/v/release/Li-RC/workspace-status?label=release" alt="Latest GitHub release" /></a>
    <a href="https://github.com/Li-RC/workspace-status/releases"><img src="https://img.shields.io/github/downloads/Li-RC/workspace-status/total?label=downloads" alt="Total release asset downloads" /></a>
    <a href="https://github.com/Li-RC/workspace-status/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/Li-RC/workspace-status/build.yml?branch=main&amp;label=build&amp;logo=github" alt="macOS build and self-test status on main" /></a>
  </p>
  <p>
    <a href="https://github.com/Li-RC/workspace-status/releases/latest">Download</a> ·
    <a href="#getting-started">Getting started</a> ·
    <a href="#build-from-source">Build from source</a> ·
    <a href="LICENSE">MIT license</a>
  </p>
</div>

Workspace Status is a **native macOS menu bar app for AeroSpace**, providing a **workspace indicator and workspace switcher** directly in your existing menu bar. See your active workspace, the applications open in each workspace, and unread app badges without opening Mission Control. Click a workspace to switch, click an app to focus its window, or open the bell dropdown for a window overview.

It is a standalone application that lives in Apple's native menu bar, not a separate status bar or menu bar replacement. It works alongside the [AeroSpace tiling window manager](https://nikitabobko.github.io/AeroSpace/) without requiring SketchyBar or a custom bar configuration.

Built with **Swift, SwiftUI and AppKit**, it brings **Liquid Glass** controls to macOS 26 and later, with a fallback interface on macOS 14 and 15.

## Features

- **Workspace overview.** See occupied workspaces and their open apps, with your current workspace highlighted.
- **Workspace and app switching.** Click anywhere in an inactive workspace group to switch there. Click an app in the current workspace to focus it, or double-click an app to focus it from any workspace.
- **Window browsing.** Expand a workspace in the dropdown to browse its open windows.
- **Native appearance.** Uses Liquid Glass on macOS 26 and later.
- **Display-aware placement.** Keeps the saved position on notched displays. On displays without a notch, centers the workspace indicators when space allows, with the bell beside them, or places the group immediately after the application menus.
- **Unread indicators.** An orange bell highlights apps with Dock badges. View those apps and their badge values under **Notifications**.
- **Native settings.** Configure login startup, menu bar placement and Dock badge monitoring in a dedicated settings window.
- **Local operation.** Runs without network services or changes to your AeroSpace configuration.

## Requirements

| Requirement | Details |
| --- | --- |
| macOS | 14 or later; native Liquid Glass requires macOS 26 or later |
| Window manager | AeroSpace must be installed and running |
| Architecture | Published binaries target Apple Silicon; source builds use the host architecture |
| Accessibility | Required for Dock badges and automatic placement on displays without a notch; workspace navigation works without it |

## Getting started

1. Download a DMG or ZIP from [GitHub Releases](https://github.com/Li-RC/workspace-status/releases/latest).
2. For a DMG, drag **Workspace Status.app** into **Applications**. For a ZIP, extract it and move the app into **Applications**.
3. Start AeroSpace, then open **Workspace Status**.

Workspace Status checks for AeroSpace when launched or reopened. If it is missing, **Install AeroSpace…** opens the [official installation guide](https://nikitabobko.github.io/AeroSpace/guide#installation). If it is installed but not running, **Open AeroSpace** starts it and refreshes the workspaces. **Not Now** leaves Workspace Status running so you can set up AeroSpace later.

The app runs in the menu bar without a Dock icon. To start it at login, enable **Launch at login** in the app's Settings. If macOS requires approval, Settings provides a button to open Login Items.

This README describes the current source on `main`. Check the release notes for features included in a downloaded version.

## Using Workspace Status

| Control | Action |
| --- | --- |
| Workspace number | Switch to that workspace; clicking the current number leaves focus unchanged |
| App icon in an inactive workspace | Switch to that workspace, preserving its existing focus |
| App icon in the current workspace | Focus that app's most recently used window in the current workspace |
| Double-click any workspace app icon | Switch to its workspace and focus that app's most recently used window there |
| Bell | Toggle the dropdown open or closed |
| Window count / chevron | Expand or collapse the workspace's window list |
| Window in an expanded list | Focus that window |
| App under Notifications | Focus one of its windows, or open the app |
| Refresh | Reload workspace information |
| Settings gear | Open the settings window |
| Right-click the bell | Open a menu with Settings and Quit |
| Quit | Exit Workspace Status |

The whole inactive workspace group is clickable in the menu bar. Workspace numbers and app icons behave the same in the menu bar and dropdown. Window focus history is kept only while the app runs; if no history exists for an app, its first available window is focused. The current workspace keeps its menu bar indicator even when empty.

Click outside the dropdown or press **Escape** to close it. The dropdown fits your display and respects **Reduce Motion**.

Menu bar single clicks respond immediately. Dropdown app icons wait for the system double-click interval before acting, so the dropdown stays open long enough to receive a second click. Keyboard activation responds immediately.

### Settings

Open the bell dropdown and click the gear beside Refresh, or right-click the bell and choose **Settings…**. Reopening the running app through Finder or Spotlight also opens Settings. **⌘,** opens Settings while Workspace Status has keyboard focus; it is not a global shortcut.

| Section | Options |
| --- | --- |
| General | Launch at login and its macOS registration/approval status |
| Menu Bar | Compact view, automatic display-aware placement or the normal system position |
| Notifications | Show Dock badges, Accessibility status and access to permission settings |
| About | App version/build, repository and MIT license |

Preferences take effect immediately and persist across restarts. Automatic placement and Dock badge monitoring are enabled by default. Choose **System position** to let macOS or a menu bar manager handle placement. Disabling Dock badges stops badge monitoring without affecting workspace navigation or permission for automatic placement.

Enable **Compact view** under **Menu Bar** to show workspace numbers without application icons in the menu bar. Workspace switching and the bell remain available, and the dropdown still shows all applications and windows. Compact view is off by default.

Settings follows system appearance. Closing its window or pressing **⌘W** keeps the menu bar app running. Startup at login does not open Settings.

### Placement on multiple displays

On a display **with a notch**, the strip stays at its existing menu bar position. On a display **without a notch**, it centers the workspace indicators, including application icons, while keeping the bell beside them. The bell is excluded from the centering calculation, but space for the whole group is still reserved between application menus and status icons. When the centered group cannot fit, it appears just after the application menus, shrinking to fit the available gap when necessary. The dropdown opens beneath the bell on the display you clicked.

Automatic placement requires Accessibility access to read menu bar positions. Without permission, or while those positions are unavailable, the normal macOS status item remains usable. If there is no gap at all, the positioned strip is hidden on that display until space becomes available. It follows menu bar visibility, including auto-hide and full-screen apps.

Workspace Status implements positioning using transparent AppKit panels because macOS does not provide a public API to center a status item independently on each display. When notched and non-notched displays are connected together, a transparent slot preserves the original position on the notched display. When every connected display has a notch, the original native status item is used directly.

## Notifications and privacy

The **Notifications** section displays unread indicators from app badges in the Dock. To enable it:

1. Open the dropdown and click **Enable Accessibility…**.
2. Enable **Workspace Status** in **System Settings → Privacy & Security → Accessibility**.
3. Leave the app running; it checks permission changes automatically.

Workspace navigation works without this permission. Accessibility is also used to read menu bar geometry for placement on displays without a notch. Dock badges update automatically and show app names, icons, and badge values. Notification Center, notification banners, history, and message content are not read. Badge information is neither persisted nor sent to a server.

Keep the app in a stable location before granting Accessibility access. Moving or rebuilding it may require granting permission again.

## Limitations

- Workspace navigation supports **AeroSpace workspaces**. macOS Mission Control desktops are not supported.
- Dock badges represent app unread counts or status; they do not confirm a new notification. Apps without an exposed Dock badge will not appear under Notifications.
- macOS may hide indicators when the menu bar is crowded. Occupied workspaces and their applications remain available in the dropdown.
- With only notched displays, Bartender manages all workspace indicators and the bell as a single native group. When a display without a notch is connected, the positioned panels are outside Bartender's control; the reserved native slot remains grouped. Individual workspaces cannot be moved or hidden separately.

## Build from source

Install **Xcode with the macOS 26 SDK or newer** and select it as the active developer directory. Then run:

```sh
git clone https://github.com/Li-RC/workspace-status.git
cd workspace-status
bash build.sh
open "dist/Workspace Status.app"
```

The script builds for your Mac's architecture and runs self-tests. The app bundle is written to `dist/Workspace Status.app`. Builds use ad-hoc signing unless a certificate is configured, and are not notarized.

To use a persistent signing certificate from your Keychain, save its name or fingerprint in the ignored local configuration file:

```sh
printf '%s\n' 'Workspace Status Local' > .signing-identity
bash build.sh
```

You can override the local configuration with `WORKSPACE_STATUS_SIGNING_IDENTITY`. A configured certificate must be available; the build does not silently fall back to ad-hoc signing. Keep the same certificate, bundle identifier and installation path across updates to preserve the app's identity. Switching from ad-hoc signing may require granting Accessibility permission once more; subsequent permission retention should be verified on your Mac. Local self-signed certificates are for development; public releases should use Developer ID signing and notarization.

## Frequently asked questions

### Is this a separate bar or a native menu bar app?

Workspace Status is a native macOS menu bar application. Its workspace indicators, app icons and dropdown live in the existing system menu bar. It does not replace the macOS menu bar or add a separate bar to your desktop.

### Do I need SketchyBar?

No. Workspace Status is a standalone macOS menu bar app. It displays AeroSpace workspace numbers and application icons directly in the menu bar, without installing or configuring a separate status bar.

### Does it support macOS Spaces or Mission Control desktops?

Workspace switching uses AeroSpace workspaces. It does not switch macOS Spaces or Mission Control desktops. AeroSpace must be running to load workspaces and focus windows.

## Contributing

Bug reports and pull requests are welcome. For a bug report, include your macOS version, AeroSpace version, and steps to reproduce the issue. See the [contributor guide](CONTRIBUTING.md) for development setup, checks, previews, and project structure.

## License

Workspace Status is open source under the [MIT license](LICENSE), including its original icon artwork.
