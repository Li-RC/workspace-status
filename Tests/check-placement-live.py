"""Run the built app against real menus on a connected display without a notch."""
from pathlib import Path
import platform
import plistlib
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
folder = Path(tempfile.mkdtemp(prefix="workspace-status-live-check-"))
app = folder / "Menu Fixture.app"
executable = app / "Contents/MacOS/MenuFixture"
executable.parent.mkdir(parents=True)
info = {
    "CFBundleIdentifier": "local.WorkspaceStatus.MenuFixture",
    "CFBundleName": "Menu Fixture",
    "CFBundleDisplayName": "Menu Fixture",
    "CFBundleExecutable": "MenuFixture",
    "CFBundlePackageType": "APPL",
    "CFBundleVersion": "1",
    "LSMinimumSystemVersion": "14.0",
    "NSHighResolutionCapable": True,
}
with (app / "Contents/Info.plist").open("wb") as stream:
    plistlib.dump(info, stream)
subprocess.run([
    "xcrun", "swiftc", "-swift-version", "5", "-O",
    "-module-cache-path", str(folder / "module-cache"),
    "-target", f"{platform.machine()}-apple-macosx14.0",
    str(project / "Tests/MenuFixture.swift"), "-o", str(executable),
], check=True)
subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
command = folder / "menu-command.txt"
command.write_text("short")
print("Logs and fixture:", folder, flush=True)
was_running = subprocess.run(["pgrep", "-x", "WorkspaceStatus"], capture_output=True).returncode == 0
had_bartender = subprocess.run(["pgrep", "-x", "Bartender 7 Setapp"], capture_output=True).returncode == 0
if was_running:
    subprocess.run(["pkill", "-x", "WorkspaceStatus"], check=True)
if had_bartender:
    subprocess.run(["pkill", "-x", "Bartender 7 Setapp"], check=True)
try:
    subprocess.run([
        "open", "-n", "-o", str(folder / "host.log"), "--stderr", str(folder / "host-error.log"),
        str(app), "--args", str(command),
    ], check=True)
    result = subprocess.run([
        str(project / "dist/Workspace Status.app/Contents/MacOS/WorkspaceStatus"),
        "--placement-live-test", "--menu-command", str(command),
    ], capture_output=True, text=True, timeout=25)
    (folder / "live.log").write_text(result.stdout)
    (folder / "live-error.log").write_text(result.stderr)
    print(result.stdout)
    print(result.stderr)
    if result.returncode != 0 or "per-display bell dropdowns: PASS" not in result.stdout:
        raise SystemExit("Live placement check failed; inspect the logs above.")
finally:
    command.write_text("quit")
    subprocess.run(["pkill", "-x", "WorkspaceStatus"], capture_output=True)
    if had_bartender:
        subprocess.run(["open", "/Applications/Setapp/Bartender.app"], check=True)
    if was_running:
        subprocess.run(["open", "/Applications/Workspace Status.app"], check=True)
