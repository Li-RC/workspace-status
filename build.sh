#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
app_dir="$project_dir/dist/Workspace Status.app"
build_cache="$(mktemp -d "${TMPDIR:-/tmp/}workspace-status.XXXXXX")"
trap 'rm -rf "$build_cache"' EXIT
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/LICENSE" "$app_dir/Contents/Resources/LICENSE.txt"
xcrun actool "$project_dir/Design/AppIcon/WorkspaceStatus.icon" \
  --compile "$app_dir/Contents/Resources" --platform macosx --minimum-deployment-target 14.0 \
  --target-device mac --app-icon WorkspaceStatus --standalone-icon-behavior all \
  --output-partial-info-plist "$build_cache/icon-info.plist" --output-format human-readable-text
xcrun swiftc -swift-version 5 -O -module-cache-path "$build_cache" -target "$(uname -m)-apple-macosx14.0" \
  "$project_dir"/Sources/*.swift -o "$app_dir/Contents/MacOS/WorkspaceStatus"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.WorkspaceStatus</string>
  <key>CFBundleName</key><string>Workspace Status</string>
  <key>CFBundleDisplayName</key><string>Workspace Status</string>
  <key>CFBundleExecutable</key><string>WorkspaceStatus</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>CFBundleVersion</key><string>9</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAccessibilityUsageDescription</key><string>Read app unread indicators from Dock badges.</string>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Merge '$build_cache/icon-info.plist'" "$app_dir/Contents/Info.plist"
codesign --force --sign - --identifier local.WorkspaceStatus "$app_dir"
"$app_dir/Contents/MacOS/WorkspaceStatus" --self-test
printf 'Built %s\n' "$app_dir"
