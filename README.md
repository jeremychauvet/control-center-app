# Control Center

A native macOS window-management app. v1 implements global-hotkey window snapping
(halves, maximize, center) for the frontmost app's focused window. It runs as a
menu-bar item with no Dock icon; configuration lives in a popover.

## Requirements

- macOS 26.5 or later
- Xcode 26 or later to build

## Architecture

Each layer lives in its own file under `control-center-app/control-center-app/`
and exposes a clean Swift API so it can be tested in isolation.

| Layer | Responsibility |
|---|---|
| `HotkeyManager` | Registers global hotkeys via Carbon `RegisterEventHotKey`. Survives focus loss. |
| `AccessibilityService` | Checks/prompts `AXIsProcessTrusted`, opens the Accessibility pane, polls for grant. |
| `WindowController` | Reads/writes the focused window's frame via the AX API (`AXUIElementCreateSystemWide` → focused app → focused window). |
| `ScreenLayout` | Pure functions that compute target frames for each region on a given `NSScreen.visibleFrame`, handling the NSScreen↔AX coordinate flip and multi-monitor space. |
| `WindowAnimator` | Interpolates the window's frame to the target over ~180ms with an ease-out curve, driven by a 60 fps timer. The AX API has no animation primitive so this is best-effort — some apps (Electron/Java/Qt) will step rather than glide. |
| `WindowManager` | Orchestrator that wires the layers together and handles re-registration when shortcuts change. |
| `SystemShortcutsService` | Registers global shortcuts for system utilities (e.g. `⌃⇧⎋` → Activity Monitor). Shares the app-wide `HotkeyManager`. |
| `KeybindingStore` | `@Observable` persistence of bindings + animation settings in `UserDefaults`. |
| `MenuBarController` | `NSStatusItem` + `NSPopover` hosting the SwiftUI settings UI. |

## Default keybindings

Halves use `Cmd+arrow`. These intercept system text-navigation, browser
back/forward, and Finder shortcuts globally — that's deliberate. All bindings
are remappable from the popover.

| Action | Default |
|---|---|
| Left half | `⌘←` |
| Right half | `⌘→` |
| Maximize | `⌘↑` |
| Bottom half | `⌘↓` |
| Top half | `⌃⌥↑` |
| Center | `⌃⌥C` |

### System utilities

| Action | Default |
|---|---|
| Launch Activity Monitor | `⌃⇧⎋` |

`⌃⇧⎋` mirrors Windows' `Ctrl+Shift+Esc` (Task Manager); Activity Monitor is the
macOS equivalent. Carbon hotkeys can't distinguish left from right Shift, so this
fires for either Shift key. This shortcut is fixed, not remappable.

## Accessibility permission

Moving other apps' windows requires the Accessibility permission. On first launch
the system prompt appears; if you dismiss it, the popover shows a "permission
needed" banner with a button that re-issues the prompt and opens
**System Settings → Privacy & Security → Accessibility**. The app polls for the
grant once per second, so once you approve it everything starts working — no
relaunch needed.

## Distribution

This app is built for **direct download with Developer ID notarization**, not the
Mac App Store. The App Sandbox is disabled because the AX APIs needed to move
other apps' windows are incompatible with sandboxing.

## Project setup notes

A few project-level settings must be configured in Xcode (build settings, not
source):

1. **Disable App Sandbox** — Target → Signing & Capabilities → remove
   *App Sandbox*. Required because the AX APIs that move other apps' windows
   are incompatible with sandboxing.
2. **Set `LSUIElement = YES`** — Target → Info → add row
   *"Application is agent (UIElement)" = YES*. Hides the Dock icon.
