# BarManager

BarManager is a menu bar utility for macOS. It hides and groups the status
icons in the menu bar, in the style of Hidden Bar and Ice. It is written in
Swift with AppKit. It has no dependencies.

## Groups

Two separators divide the menu bar into three zones:

```
┄  [always hidden]  ┊  [hidden]  |  [visible]  ‹  🕐
```

- **Visible**: the icons on the right side of the solid separator `|`. These
  icons always show.
- **Hidden**: the icons between the two separators. These icons hide when you
  collapse the bar.
- **Always hidden**: the icons on the left side of the dotted separator `┊`.
  These icons show only in the "show all" mode.

To move an icon to a different group, hold the Command key and drag the icon
to the other side of a separator. This drag function is a standard macOS
feature.

## Operation

The chevron icon shows the state:

| Icon | State | Click action |
|---|---|---|
| `‹` (monochrome) | Collapsed. The hidden icons do not show | Expand |
| `›` (red circle) | Expanded. The hidden group shows | Collapse |
| 👁 (orange circle) | All groups show, also the always-hidden group | Back to expanded |

| Action | Result |
|---|---|
| Click the chevron | Hides or shows the hidden group |
| Option + click | Shows or hides the always-hidden group |
| Right click | Opens the menu: show all, group options, auto-hide, open at login, quit |
| CLI | `BarManager toggle` or `BarManager reveal`. The command goes to the app that operates in the menu bar |

The always-hidden group is off by default. Use the right-click menu item
"Grupo «siempre ocultos»" to set it to on.

### Group backgrounds

When you expand the bar, a colored shape shows behind each group. The hidden
group has a blue background. The visible group has a gray background. A
transparent window draws the shapes below the status icons (window level 24,
status icons at level 25). The app reads the icon positions with
`CGWindowListCopyWindowInfo`. This function does not need permissions. Use the
menu item "Fondos de grupos" to set the backgrounds to off.

## Build and run

For a quick test without an app bundle:

```sh
swift run
```

To build the app bundle (ad-hoc signature, no Dock icon):

```sh
./Scripts/build-app.sh
open build/BarManager.app
```

> The menu shows "open at login" only when the app operates from an `.app`
> bundle.

## Release on Homebrew

1. Make the release file (universal binary for arm64 and x86_64):

   ```sh
   ./Scripts/release.sh 1.0.0
   ```

   The script shows the zip path and the sha256 value. The workflow
   `.github/workflows/release.yml` does the same operation when you push a tag
   `v1.0.0`. The workflow makes the GitHub release and attaches the zip file.

2. Copy `packaging/barmanager.rb` to the tap repository
   `github.com/cristiandley/homebrew-tap` as `Casks/barmanager.rb`. Set the
   correct `sha256` value.

3. Install:

   ```sh
   brew install cristiandley/tap/barmanager
   ```

   The app has an ad-hoc signature and is not notarized. Because of this, the
   cask removes the quarantine attribute in a postflight step. When you sign
   the app with a Developer ID and notarize it, remove the postflight step.
   Notarization is also necessary for the official `homebrew/cask` repository.
   That repository also has a popularity requirement (approximately 75 GitHub
   stars).

## How it operates

macOS has no public API that hides the icons of other applications. Each
separator is an `NSStatusItem`. To collapse a group, the app sets the length
of the separator to approximately 10000 points. The wide separator pushes all
icons on its left side off the screen. To expand the group, the app sets the
length of the separator back to the normal value. Hidden Bar and Ice use the
same technique.

## Known limitations

- On a Mac with a notch, the pushed icons can move below the notch. macOS
  hides the icons that do not have space. The function operates correctly,
  but the usable space is smaller.
- At the first start, macOS puts the separators together on the left side of
  the clock. Move them with Command + drag. macOS keeps the positions for the
  next sessions.
