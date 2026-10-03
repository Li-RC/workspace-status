# Workspace Status

A standalone native macOS menu bar app for AeroSpace. Requires macOS 14 or later and a running AeroSpace installation. Release binaries are for Apple Silicon; `build.sh` also builds for Intel when run on an Intel Mac. No third-party packages or network services are used.

[Download the latest release](https://github.com/Li-RC/workspace-status/releases/latest)

## Run

Build from source or download the ZIP from GitHub Releases, extract it, and open **Workspace Status.app**. It runs in the menu bar without a Dock icon. Click its workspace number and app icons to open the overview.

- The menu bar shows the focused workspace, up to three app icons, and a bell. The centered number badge follows the system's black/white menu bar contrast; additional apps appear in the overview.
- The overview lists every AeroSpace workspace, including empty workspaces. The current one is highlighted.
- The popup fits the available space below the menu bar on the display where it opens; its contents scroll when necessary.
- Click a workspace row to switch. Click its window count/chevron to expand it; click a window to focus it.
- The bell shows the most recently detected notification app, or an app with a Dock badge when no banner has been detected. Hover for the source label.
- Click a notification app or badge to focus one of its windows or launch the app.
- Clear dismisses this app's in-memory notification list; it does not dismiss macOS notifications.
- Quit is at the bottom of the popup.

The app uses AeroSpace's event subscription, with a 15-second reconciliation/reconnect interval. It never edits AeroSpace or SketchyBar configuration. It is built for AeroSpace workspaces; macOS Mission Control desktops are not supported by this version.

## Notification permission and limitations

Workspace controls work without granting this app Accessibility. To enable notification sources, click **Enable Accessibility…**, then enable **Workspace Status** in System Settings → Privacy & Security → Accessibility. The app checks for permission changes automatically.

macOS does not provide a supported public API to retrieve every other app's notifications. This app conservatively watches Accessibility events from Notification Center and User Notification Center, and scans exposed banner windows. A source must match a running application's name exactly. Unknown or ambiguous sources are skipped. This feature depends on the AX structure exposed by your macOS version and is best effort; it cannot guarantee detection, especially with Focus, suppressed banners, already-delivered history, quit apps, or unexposed banner structures. Notification observation needs live validation after permission is granted.

Dock badges are read separately every five seconds and labeled **Dock badges**; they are unread indicators, not proof of a new notification. Banners are also checked on that interval as a fallback if AX events are unavailable. Some brief banners can be missed. Only application names, observation times, and detection counts appear in the UI. Nothing is sent to a server or persisted. Banner labels are read transiently to attribute sources and deduplicate visible banners; message text is not displayed or written to disk.

The local build is ad-hoc signed, not notarized. Keep the app in a stable location before enabling Accessibility. Rebuilding or moving it may require re-enabling permission. If you want it to launch at login, add it in System Settings → General → Login Items.

## Rebuild and verify

Install Xcode or Apple's Command Line Tools, then run:

```bash
bash build.sh
"dist/Workspace Status.app/Contents/MacOS/WorkspaceStatus" --diagnose
```

The build runs targeted checks for JSON decoding (including quoted/newline titles), named and empty workspaces, and ambiguous notification attribution. `--diagnose` reads live AeroSpace data without switching workspaces or prompting for permissions. It prints workspace/app names and permission state, but excludes window titles and notification bodies.

`--smoke-test` briefly runs the real menu bar app for eight seconds, checks live workspace loading and menu bar image creation, reports the Accessibility monitor status, and exits. It does not switch workspaces or generate notifications. This build passed those checks on the development machine. Actual banner attribution and manual click interactions remain to be validated in use.

`--popover-test` briefly opens the real popup, updates its list, and checks that its window stays within the display and its content within the usable screen area. It exits after reporting the result. The build also checks size limits for compact screens and displays with negative coordinate origins.

To render an offscreen preview from live workspace data:

```bash
"dist/Workspace Status.app/Contents/MacOS/WorkspaceStatus" --render-preview /tmp/workspace-status.png
```

Source is in `Sources/`: AeroSpace access and model, Accessibility notification model, SwiftUI popup and menu bar controller, and the command-line verification entry point.

## License

MIT. See [LICENSE](LICENSE).

References: [AeroSpace commands](https://nikitabobko.github.io/AeroSpace/commands), [Apple UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter), [Apple AXObserverAddNotification](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification).
