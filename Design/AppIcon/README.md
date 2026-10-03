# Workspace Status app icon

Open `WorkspaceStatus.icon` in Apple's Icon Composer. This is the editable construction document, with embedded SVG artwork and native Liquid Glass effects. The icon uses a four-workspace grid on a navy background; the blue tile has a window layout symbol to identify the selected workspace even in monochrome appearances.

## Construction

- `layers/01-workspaces.svg`: three neutral workspace tiles.
- `layers/02-selected-workspace.svg`: the blue selected tile.
- `layers/03-window-detail.svg`: the white window layout symbol.
- `WorkspaceStatus.icon/Assets/`: embedded copies of the original vector layers.
- `WorkspaceStatus.icon/icon.json`: background gradient, layer ordering, and native glass settings.

All artwork uses the same 1024 × 1024 canvas, with no baked shadows, blur, or highlights. Edit shapes in the SVG files and replace the corresponding layers in Icon Composer. Keep the files in `layers/` and the embedded copies in sync. Icon Composer groups are ordered front to back: the window detail sits above the workspace tiles.

## Previews

`preview.png` is the 1024-pixel default appearance. The other PNGs show Dark, TintedDark, and ClearLight at 512 pixels. All previews were rendered using Apple's native exporter with design generation 26. The `.icon` document retains editable layers; PNGs are flattened previews.

To export the default preview again with the installed Xcode:

```sh
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
  "$PWD/Design/AppIcon/WorkspaceStatus.icon" \
  --export-image --output-file "$PWD/Design/AppIcon/preview.png" \
  --platform macOS --rendition Default \
  --width 1024 --height 1024 --scale 1 --design-generation 26
```

Run the command from the repository root. These PNG exports are previews only. `build.sh` compiles the editable `.icon` document directly with Apple's `actool`, producing `Assets.car` for native appearance variants and `WorkspaceStatus.icns` for compatibility. Both are embedded in the app's Resources directory, and the compiler's icon metadata is merged into Info.plist before signing.

The artwork is original to Workspace Status and covered by the repository's MIT license.
