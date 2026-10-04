<div align="center">
  <img src="Design/AppIcon/preview.png" width="112" height="112" alt="Workspace Status app icon" />
  <h1>Workspace Status</h1>
  <p>Your AeroSpace workspaces, applications, and unread indicators — at a glance.</p>
  <p>
    <a href="https://github.com/Li-RC/workspace-status/releases/latest">Download</a> ·
    <a href="#getting-started">Getting started</a> ·
    <a href="#build-from-source">Build from source</a> ·
    <a href="LICENSE">MIT license</a>
  </p>
</div>

Workspace Status is a native macOS menu bar app for [AeroSpace](https://nikitabobko.github.io/AeroSpace/). See which apps are open across your workspaces, switch between them, and focus a window from a compact dropdown.

## Features

- **Workspace overview.** See occupied workspaces and their open apps, with your current workspace highlighted.
- **Direct navigation.** Switch workspaces from the menu bar, or use the dropdown to select an app or a specific window.
- **Window browsing.** Expand a workspace in the dropdown to browse its open windows.
- **Native appearance.** Uses Liquid Glass on macOS 26 and later.
- **Unread indicators.** The bell highlights apps with Dock badges using your macOS accent color. View those apps and their badge values under **Notifications**.
- **Local operation.** Runs without network services or changes to your AeroSpace configuration.

## Requirements

| Requirement | Details |
| --- | --- |
| macOS | 14 or later; native Liquid Glass requires macOS 26 or later |
| Window manager | AeroSpace must be installed and running |
| Architecture | Published binaries target Apple Silicon; source builds use the host architecture |
| Accessibility | Optional; required only to read Dock badges |

## Getting started

1. Download a DMG or ZIP from [GitHub Releases](https://github.com/Li-RC/workspace-status/releases/latest).
2. For a DMG, drag **Workspace Status.app** into **Applications**. For a ZIP, extract it and move the app into **Applications**.
3. Start AeroSpace, then open **Workspace Status**.

The app runs in the menu bar without a Dock icon. To start it at login, add it in **System Settings → General → Login Items**.

## Using Workspace Status

| Control | Action |
| --- | --- |
| Workspace number or app icons in the menu bar | Switch to that workspace |
| Bell | Toggle the dropdown open or closed |
| Workspace number in the dropdown | Switch to that workspace |
| App icon in the dropdown | Focus a window of that app in that workspace |
| Window count / chevron | Expand or collapse the workspace's window list |
| Window in an expanded list | Focus that window |
| App under Notifications | Focus one of its windows, or open the app |
| Refresh | Reload workspace information |
| Quit | Exit Workspace Status |

Each menu bar app icon selects its workspace. Individual app selection is available inside the dropdown. The current workspace keeps its menu bar indicator even when empty.

Click outside the dropdown or press **Escape** to close it. The dropdown fits your display and respects **Reduce Motion**.

## Notifications and privacy

The **Notifications** section displays unread indicators from app badges in the Dock. To enable it:

1. Open the dropdown and click **Enable Accessibility…**.
2. Enable **Workspace Status** in **System Settings → Privacy & Security → Accessibility**.
3. Leave the app running; it checks permission changes automatically.

Workspace navigation works without this permission. Dock badges update automatically and show app names, icons, and badge values. Notification Center, notification banners, history, and message content are not read. Badge information is neither persisted nor sent to a server.

Keep the app in a stable location before granting Accessibility access. Moving or rebuilding it may require granting permission again.

## Limitations

- Workspace navigation supports **AeroSpace workspaces**. macOS Mission Control desktops are not supported.
- Dock badges represent app unread counts or status; they do not confirm a new notification. Apps without an exposed Dock badge will not appear under Notifications.
- macOS may hide indicators when the menu bar is crowded. Occupied workspaces and their applications remain available in the dropdown.
- Bartender manages all workspace indicators and the bell as a single group; individual workspaces cannot be moved or hidden separately.

## Build from source

Install **Xcode with the macOS 26 SDK or newer** and select it as the active developer directory. Then run:

```sh
git clone https://github.com/Li-RC/workspace-status.git
cd workspace-status
bash build.sh
open "dist/Workspace Status.app"
```

The script builds for your Mac's architecture and runs self-tests. The app bundle is written to `dist/Workspace Status.app`. Local builds are ad-hoc signed and are not notarized.

## Contributing

Bug reports and pull requests are welcome. For a bug report, include your macOS version, AeroSpace version, and steps to reproduce the issue. See the [contributor guide](CONTRIBUTING.md) for development setup, checks, previews, and project structure.

## License

Workspace Status is open source under the [MIT license](LICENSE), including its original icon artwork.
