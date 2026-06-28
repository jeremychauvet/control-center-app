# Control Center

A native macOS menu-bar utility that bundles several desktop conveniences:

- **Window snapping** — global hotkeys to snap the frontmost app's focused window
  to halves, maximize, center, or minimize, with cross-display chaining.
- **Presence** — keeps you "Available" in apps like Microsoft Teams by detecting
  idle time and injecting an invisible keystroke.
- **Keep Awake** — holds a power assertion so the display won't sleep.
- **System shortcuts** — global hotkeys to launch Activity Monitor and lock the
  screen.

It runs as a menu-bar item with no Dock icon (`LSUIElement`); configuration lives
in a settings window opened from the menu-bar menu.

## Requirements

- macOS 26.5 or later
- Xcode 26 or later to build

## Architecture

Each layer lives in its own file under `control-center-app/control-center-app/`
and exposes a clean Swift API so it can be tested in isolation.

| Layer | Responsibility |
|---|---|
| `HotkeyManager` | Registers global hotkeys via Carbon `RegisterEventHotKey`. Survives focus loss. Shared by every global-shortcut owner. |
| `AccessibilityService` | Checks/prompts `AXIsProcessTrusted`, opens the Accessibility pane, polls for grant. |
| `WindowController` | Reads/writes the focused window's frame via the AX API (resolves the frontmost app via `NSWorkspace` → focused window). |
| `ScreenLayout` | Pure functions that compute target frames for each region on a given `NSScreen.visibleFrame`, handling the NSScreen↔AX coordinate flip and multi-monitor neighbor selection. |
| `WindowAnimator` | Interpolates the window's frame to the target over a short ease-out curve, driven by a 60 fps timer. The AX API has no animation primitive so this is best-effort — some apps (Electron/Java/Qt) will step rather than glide. |
| `WindowManager` | Orchestrator that wires the snapping layers together, handles re-registration when shortcuts change, and implements cross-display chaining. |
| `SystemShortcutsService` | Registers fixed global shortcuts for system utilities: `⌃⇧⎋` → Activity Monitor, `⌘K` → lock screen. Shares the app-wide `HotkeyManager`. |
| `KeybindingStore` | `@Observable` persistence of window-snap bindings + animation settings in `UserDefaults`. |
| `PresenceService` | Idle detection + invisible F15 injection to keep you "Available". Requires Accessibility trust. |
| `KeepAwakeService` | Holds an `IOPMAssertion` to prevent display sleep. No special permission required. |
| `LaunchAtLoginService` | Wraps `SMAppService.mainApp` for the launch-at-login toggle. |
| `MenuBarController` | Owns the `NSStatusItem` whose menu opens the settings window. |
| `PresenceStatusItemController` | Optional dedicated menu-bar item that reflects and toggles Presence state. |
| `SettingsWindowController` | Owns the settings `NSWindow`; promotes the app to a regular (Dock-visible) app while open. |

## Window snapping

### Default keybindings

Plain `Cmd+←/→` are reserved by macOS for moving the text cursor to the
start/end of a line, so the horizontal halves use `Cmd+Shift+arrow`. All snap
bindings are remappable from the **Window Snapping** pane.

| Action | Default |
|---|---|
| Left half | `⌘⇧←` |
| Right half | `⌘⇧→` |
| Maximize | `⌘↑` |
| Minimize to Dock | `⌘↓` |
| Top half | `⌃⌥↑` |
| Bottom half | `⌃⌥↓` |
| Center | `⌃⌥C` |

### Cross-display chaining

Pressing a half-snap shortcut on a window that's already snapped to that half
hops it to the opposite half of the adjacent display (if one exists in that
physical direction). Maximize, Center, and Minimize don't chain.

### Margins

When the macOS "Tiled windows have margins" setting is enabled
(`com.apple.WindowManager`/`EnableTiledWindowMargins`), snapped windows are inset
to match the appearance of macOS's own tiling.

## System utilities

These shortcuts are **fixed, not remappable**, and registered globally.

| Action | Default |
|---|---|
| Launch Activity Monitor | `⌃⇧⎋` |
| Lock screen | `⌘K` |

`⌃⇧⎋` mirrors Windows' `Ctrl+Shift+Esc` (Task Manager); Activity Monitor is the
macOS equivalent. `⌘K` switches to the login window via `SACLockScreenImmediate`
from the private `login.framework` (resolved at runtime via `dlsym`; requires the
unsandboxed build). Carbon hotkeys can't distinguish left from right Shift, so
`⌃⇧⎋` fires for either Shift key.

Note that because `⌘K` is registered as a system-wide hotkey, it is consumed
before reaching the frontmost app.

## Presence and Keep Awake

**Presence** ("Keep me available") injects an invisible F15 key event once the
Mac has been idle past a configurable threshold, incrementing the idle timer apps
like Microsoft Teams read without resetting the timer used to detect real user
input. Injecting events requires Accessibility trust, so the loop only runs while
the feature is enabled *and* the process is trusted. An optional menu-bar item
reflects the live state and toggles the feature.

**Keep Awake** holds a `kIOPMAssertionTypePreventUserIdleDisplaySleep` assertion
while enabled, preventing the display from sleeping. It is independent of Presence
and needs no permission.

## Accessibility permission

Moving other apps' windows and injecting input requires the Accessibility
permission. On first launch the system prompt appears; if you dismiss it, the
**General** and **Presence** panes show a "permission needed" banner with a button
that re-issues the prompt and opens **System Settings → Privacy & Security →
Accessibility**. The app polls for the grant once per second, so once you approve
it everything starts working — no relaunch needed.

## Distribution

This app is built for **direct download with Developer ID notarization**, not the
Mac App Store. The App Sandbox is disabled (`ENABLE_APP_SANDBOX = NO`) because the
AX APIs needed to move other apps' windows — and the private lock-screen call —
are incompatible with sandboxing. The `LSUIElement` flag and sandbox setting are
configured in the project's build settings; no manual Xcode setup is required.

`Scripts/bump-version.sh` runs as a build phase: it bumps
`CURRENT_PROJECT_VERSION` on every build and the last component of
`MARKETING_VERSION` on archive.
