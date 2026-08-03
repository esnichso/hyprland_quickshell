# Features

Every surface the shell draws, what it does, and which QuickShell module
provides the data. Module names are from the Quickshell 0.3.0 type reference —
they exist, they're documented, and none of this needs shelling out to a CLI
and parsing text.

**Why that matters:** Quickshell 0.3.0 ships native `Quickshell.Networking`
and `Quickshell.Bluetooth`. A year ago a control centre meant scraping
`nmcli dev wifi list` on a timer and praying. Now it's a bindable model. This
is the single biggest reason this project is worth doing now.

---

## 0. The shell process

One QuickShell instance, started by Hyprland, drawing every surface below.

| | |
| --- | --- |
| Entry point | `config/quickshell/shell.qml` |
| Started by | `hl.on("hyprland.start", ...)` → `uwsm app -- quickshell` |
| Restart | `qs kill && qs` — or just save a QML file, it hot-reloads |
| Multi-monitor | `Variants` over `Quickshell.screens` — bar per screen, panels on the focused one |

If a QML file has an error, QuickShell logs it and keeps the last good scene
graph rather than dying. That's why the lock screen stays with hyprlock: a
shell crash costs you a bar, a lock-screen crash costs you the session.

---

## 1. The bar

### 1.1 Left island — workspaces

**Source:** `Quickshell.Hyprland` — `Hyprland.workspaces`, `Hyprland.focusedWorkspace`

Ten workspaces, but only the interesting ones are drawn: every workspace that
has windows, plus the focused one, plus workspace 1. Empty trailing
workspaces don't take up space.

| State | Appearance |
| --- | --- |
| Focused | Filled `primary` pill, widened to 22px |
| Has windows | Filled dot, `onSurfaceVariant` |
| Empty but shown | Hollow ring, `outline` |
| Urgent | `error`, pulsing 1.2s |

- **Click** a dot → switch to it
- **Scroll** anywhere on the island → previous/next *non-empty* workspace
- **Hover** → tooltip listing window classes on that workspace
- The focused pill slides between positions (`180ms` out-quint) rather than
  snapping. Workspace switching is the most frequent thing you do; it's worth
  the polish.

### 1.2 Centre island — the notch

State machine, priority order high to low:

| Priority | State | Trigger | See |
| --- | --- | --- | --- |
| 1 | Dashboard | click, or `SUPER+N` | §2 |
| 2 | Critical notification | urgency 2 | §1.2.2 |
| 3 | OSD | volume/brightness/mic/caps/kbd key | §1.2.3 |
| 4 | Notification toast | any notification | §1.2.2 |
| 5 | Media (optional) | `modules.notchMedia: true` | §1.2.4 |
| 6 | Clock | default | §1.2.1 |

#### 1.2.1 Clock (rest)

`14:32   Mon 3` — time in `tnum` figures, date in `onSurfaceVariant` at 11px.
Format from `settings.json` (`de_DE` gives you 24h and `Mo 3. Aug`).
Updates on the minute, not on a 1s timer — `SystemClock { precision: SystemClock.Minutes }`.

#### 1.2.2 Notification toast

**Source:** `Quickshell.Services.Notifications` — `NotificationServer`

The notch grows to 400×76 and shows app icon, app name, summary, and one
line of body (ellipsised).

- Auto-dismiss after 5s. Urgency `critical` stays until acted on.
- **Click** → invoke the notification's default action, then collapse
- **Middle-click / swipe up** → dismiss without acting
- **Actions** (e.g. "Reply", "Mark read") render as up to two buttons; more
  than two and it says "3 actions" and opens the dashboard on click
- Images (`image-data` hint, e.g. album art or an avatar) render as a 40px
  rounded square on the left
- Stacking: a second notification while one is showing replaces it and adds a
  `2` counter chip; they're all in history either way
- **Do Not Disturb** suppresses toasts entirely — everything still lands in
  history, and the notch shows a small crescent glyph next to the clock so you
  never forget it's on

Registering as the notification daemon means **swaync and dunst must not be
installed**. Two daemons on the same D-Bus name is a coin flip at login.

#### 1.2.3 OSD

**Sources:** `Quickshell.Services.Pipewire` (volume, mic), `sysfs` via
`Quickshell.Io` (backlight, kbd backlight), `Quickshell.Hyprland` (caps/num)

The notch widens to 240 and stays 34 tall — icon, a 120px bar, and the value.

| Trigger | Shows |
| --- | --- |
| `XF86AudioRaiseVolume` / `Lower` / `Mute` | Speaker icon + level, crossed out when muted |
| `XF86AudioMicMute` | Mic icon + muted/live |
| `XF86MonBrightnessUp` / `Down` | Sun icon + level |
| `XF86KbdBrightnessUp` / `Down` | Keyboard icon + off/low/high |
| Caps Lock, Num Lock | Glyph + on/off |

Dismisses 1.6s after the last keypress — holding the key down keeps it open,
which is the behaviour you want when ramping volume.

Volume is read from PipeWire's **default sink**, not a fixed device, so it
follows when you plug in headphones. Above 100% the bar turns `error`.

#### 1.2.4 Media in the notch (optional, off by default)

**Source:** `Quickshell.Services.Mpris`

You said media should be a panel rather than the resting state, so this is
off. If you turn it on later, the notch shows a 20px album-art thumbnail,
scrolling title, and a 6-bar visualiser when something is playing, and falls
back to the clock when nothing is. The code path exists either way because the
dashboard needs the same data.

### 1.3 Right island — status

Fixed order, left to right. Items marked *conditional* only render when
they're not in the boring state, so the island stays short.

| Item | Source | Shows | Conditional? |
| --- | --- | --- | --- |
| VPN | `Quickshell.Networking` | Shield glyph in `primary` when a tunnel is up | yes |
| Network | `Quickshell.Networking` | Wifi arc by signal strength, or ethernet glyph, or a crossed wifi when down | no |
| Bluetooth | `Quickshell.Bluetooth` | Glyph; filled when a device is connected | yes — hidden when the adapter is off |
| Mic | `Quickshell.Services.Pipewire` | Crossed mic | yes — only when muted |
| Volume | `Quickshell.Services.Pipewire` | Speaker glyph | yes — only when muted or >100% |
| Battery | `Quickshell.Services.UPower` | `87%` + glyph | no |

Battery detail:
- Charging shows a bolt; the percentage turns `primary`
- Below 20% the glyph turns `error`; below 10% it pulses
- Hover → `2h 14m remaining · 8.4 W · 94% health`
- On a desktop or in a VM with no battery, the item removes itself rather than
  showing `0%` — which is exactly the bug v1 hit in its VM round

**Clicks** open the relevant panel: network → control centre on the Network
tab, bluetooth → Bluetooth tab, volume → Audio tab, battery → power/profiles.
**Scroll** on the volume area adjusts the default sink even when the icon is
hidden.

### 1.4 System tray

**Source:** `Quickshell.Services.SystemTray` + `Quickshell.DBusMenu`

Tray icons sit at the **left end of the right island**, separated by a 1px
divider. You run Signal, Slack, Discord and Mullvad — all four are tray-only
when closed, so this isn't optional.

- Left-click → activate
- Right-click → the app's real menu, rendered by us from DBusMenu with our
  palette (this is why `Quickshell.DBusMenu` matters — no GTK menu popping up
  in a completely different theme)
- Overflow past 5 icons collapses into a `»` chip

---

## 2. Dashboard — click the notch, or `SUPER+N`

440×560, grows down out of the notch. Three stacked sections, scrollable as
one.

### Media

**Source:** `Quickshell.Services.Mpris`

- Album art at 96px, rounded 12. Falls back to the app icon.
- Title / artist, both marquee-scrolling only on hover
- Previous / play-pause / next, 32px targets
- Seek bar with elapsed and total, draggable, only when the player reports
  `canSeek`
- **Player switcher** when more than one is active — a row of small app icons;
  Spotify, a browser tab and mpv can all be playing and you pick which one the
  controls drive
- Per-player volume via the PipeWire node bound to that app

### Calendar

- Month grid, week starts Monday, ISO week numbers down the left (German
  convention, and you'll want them)
- Today is a filled `primary` circle
- Click a day → nothing, this is a reference calendar not an organiser
- `<` `>` to page months, click the header to snap back to today

Deliberately not integrated with any calendar service. Adding CalDAV means
credentials, sync, and an auth flow — real work with no relation to this
project. If you want it later it's a bounded addition.

### Notification history

**Source:** the same `NotificationServer`, retained in a `ListModel`

- Newest first, grouped by app with a count chip
- Each entry: icon, app, summary, body, relative time (`3m`, `2h`)
- **Swipe or middle-click** an entry to drop it
- **Per-app mute** from the entry's context menu, persisted to `settings.json`
- **Clear all** button in the section header
- **Do Not Disturb** toggle, also in the header
- History is capped at 100 and **not persisted across reboots** — deliberately.
  Persisting means writing every notification you receive to disk, which
  includes message previews.

---

## 3. Control centre — `SUPER+I`, or click any status item

400 wide, height driven by content, anchored under the right island. Tabs
across the top: **Network · Bluetooth · Audio · Display**.

### Network

**Source:** `Quickshell.Networking`

- Wifi toggle, then a live list of visible networks sorted by signal
- Each row: SSID, signal arc, a lock glyph if secured, `✓` if it's the active one
- Click an unknown network → an inline password field appears in the row
  (not a separate dialog), Enter connects, errors render in the row in `error`
- Known networks connect on click
- Right-click → forget
- Active connection shows IP, gateway, and link speed in a footer
- Ethernet appears as a pinned row at the top when a cable is in
- VPN section listing configured tunnels with toggles — Mullvad manages its
  own connections, so its entry just activates the tray icon

**This replaces `nmtui`**, which v1 launched tiled and which swallowed the
whole screen. No terminal UI in a floating window pretending to be a GUI.

### Bluetooth

**Source:** `Quickshell.Bluetooth`

- Adapter toggle and a discovery toggle
- Paired devices first with battery level where the device reports it
  (headphones and mice mostly do), then discovered devices
- Click → connect/disconnect. Right-click → forget.
- Pairing with a PIN renders the confirmation inline

**Replaces `blueman`.**

### Audio

**Source:** `Quickshell.Services.Pipewire`

- Output device list with a radio selection and a per-device volume slider
- Input device list, same, plus a live input-level meter so you can see the
  mic is actually picking you up before a call
- **Per-application volume** — every PipeWire stream with its app icon and its
  own slider. This is the pavucontrol replacement and the reason to bother.
- Mute buttons everywhere; muted sliders grey out but keep their value

**Replaces `pavucontrol`.**

### Display

- Screen brightness slider (`sysfs`, with `brightnessctl` as the setter)
- Keyboard backlight: off / low / high segmented control
- Night light toggle and temperature slider, driving `hyprsunset`
- Scale selector for the internal panel — 1.0 / 1.25 / 1.5, applied via
  `hyprctl keyword monitor`. **Metal-only: cannot be verified in the VM.**
- Power profile: Saver / Balanced / Performance, via `power-profiles-daemon`,
  with the current one highlighted and a note showing which one auto-switching
  picked

---

## 4. Launcher — `SUPER+SPACE`

Centred overlay, 640×420, layer `overlay`, keyboard-grabbed. Background is
*not* dimmed (see DESIGN §6) but the launcher itself sits at 0.94 alpha
because you need to read it.

**Source:** `Quickshell.Io` (`DesktopEntries`), `Quickshell.Hyprland`, `Process`

One input field. What you type is matched across modes; a prefix forces one.

| Prefix | Mode | Example |
| --- | --- | --- |
| *(none)* | Apps — fuzzy over name, generic name, keywords, exec | `fire` → Firefox |
| `>` | Run a command | `>systemctl --user restart foo` |
| `=` | Calculator | `=45*1.19` → `53.55`, Enter copies |
| `:` | Emoji | `:shrug` → ¯\\_(ツ)_/¯ |
| `;` | Clipboard history | `;` then type to filter |
| `/` | Window switcher | `/nvim` jumps to that window |

- Results are keyboard-driven: `↑`/`↓` or `Ctrl+K`/`Ctrl+J`, Enter runs, Esc closes
- App results show icon, name, and generic name; recently-used sort first,
  frecency stored in `~/.local/state/quickshell/frecency.json`
- Apps launch through `uwsm app --` so they land in their own systemd scope
  and don't die with the launcher
- **Clipboard** reads `cliphist`; text entries preview inline, images render
  as thumbnails. Selecting copies and closes. `Ctrl+Delete` removes an entry
  from history.
- **Calculator** evaluates as you type with a units-aware expression parser;
  `=` alone shows the last result

**Replaces rofi, rofi-calc, rofimoji, and the cliphist rofi glue** — four
things v1 wired together, now one surface with one theme.

---

## 5. Power menu — `SUPER+P`

Centred, 360 wide. Five rows: **Lock · Logout · Suspend · Reboot · Shutdown**,
each with an icon and its keybind hint.

- Navigable with `hjkl`/arrows, Enter confirms, Esc closes
- Reboot and Shutdown ask for confirmation; the others don't
- Every destructive action runs `hyprshutdown --post-cmd '...'` so apps get
  asked to exit gracefully rather than being killed. v1 learned this the hard
  way — `hyprshutdown` is not a menu, it's the graceful-exit mechanism, and
  this is the right way to use it.
- Lock invokes `hyprlock`
- A footer shows uptime and whether any app is inhibiting sleep

---

## 6. System monitor — `SUPER+SHIFT+M`

420×520. Not a bar module — you asked for a calm bar, and per-core graphs in
the bar is the opposite of that. It's one keypress away instead.

**Source:** `/proc` and `/sys` via `Quickshell.Io` `FileView`, polled at 1s
while visible and **not polled at all when hidden**.

- CPU: per-core bars plus a 60s history sparkline, package temperature
- Memory: used / cached / free stacked bar, swap below it
- Disk: per-mount usage bars, plus read/write throughput
- Network: up/down throughput sparkline per interface
- Battery: draw in watts, charge cycles, health percentage
- Top processes: 8 rows by CPU, toggleable to sort by memory, each with a kill
  button

`btop` stays installed for when you need the real thing.

---

## 7. Wallpaper and theme picker — `SUPER+ALT+W`

560×480. Two tabs.

**Wallpapers:** a thumbnail grid of `settings.wallpaper.dir`. Click to apply,
which runs `hyprctl hyprpaper wallpaper "<monitor>,<path>,cover"`. Thumbnails
are cached to `~/.cache/quickshell/wallthumbs/`. There is no transition —
hyprpaper does not do them (see §8).

**Theme:** the mode switch you asked for.

```
  Colour source     ( • ) From wallpaper    (   ) Pick a theme
  Scheme            [ Dark ] [ Light ] [ Auto ]

  ── when "Pick a theme" is selected ──────────────────
  ( • ) catppuccin-mocha    (   ) gruvbox-dark
  (   ) tokyo-night         (   ) everforest
```

Selecting **From wallpaper** re-runs matugen against the current wallpaper
immediately. Selecting a named theme stops wallpaper changes from touching
colour — you can then change wallpaper freely without the desktop re-theming.
Both write `theme.mode` to `settings.json`, so the state survives a restart
and `check.sh` can report which mode you're in.

Each swatch row previews the theme's actual `primary`, `surface` and
`onSurface`, so you're picking by colour rather than by name.

---

## 8. Wallpaper daemon

`hyprpaper`. You wanted the wallpaper to live outside QuickShell but be driven
from it, and hyprpaper is a daemon with IPC, so the picker just runs one
command:

```sh
hyprctl hyprpaper wallpaper "eDP-1,/path/to/wall.jpg,cover"
```

**This spec originally said `swww`, which was wrong twice over.** `swww` is in
neither the official repos nor the AUR — it no longer exists as a package. And
the reason given for preferring it, that hyprpaper needs every image preloaded
into VRAM first, is no longer true: current hyprpaper takes a path directly,
and the wiki notes `preload`/`unload` may not exist in your installed version
at all. Check `hyprctl hyprpaper --help` before writing IPC against it.

What is genuinely lost: hyprpaper has no transitions. A wallpaper change is a
hard cut. If that turns out to matter, the fallback is drawing the wallpaper on
a QuickShell background layer and cross-fading there — but that moves the
wallpaper back inside the shell, which you explicitly didn't want.

---

## 9. What stays an external program

| Thing | Program | Why not QuickShell |
| --- | --- | --- |
| Lock screen | `hyprlock` | A QML error on the lock surface can trap you in a session. `Quickshell.Services.Pam` exists and this is revisitable in Phase 5, behind a tested TTY escape. |
| Idle management | `hypridle` | Solved problem, no UI, nothing to gain |
| Polkit agent | `hyprpolkitagent` | `Quickshell.Services.Polkit` exists; swapping is a Phase 5 nicety, not worth blocking on |
| Login screen | `sddm` | Runs before `$HOME` is readable. Gets a hand-written QML theme reading a palette written to `/usr/share` at theme-apply time. |
| Screenshots | `grim` + `slurp` + `satty` | Annotation is a real app's job |
| Screen recording | `wf-recorder` | Same |
| Colour picker | `hyprpicker` | Same |
| File manager | `thunar` | Same |

---

## 10. Explicitly out of scope

Named here so they don't creep in:

- Calendar/email/CalDAV integration
- A weather module (needs an API key, a network failure mode, and a location)
- Per-app theming beyond GTK/Qt/kitty
- Widgets on the desktop layer
- A greeter written in QuickShell (`Quickshell.Services.Greetd` exists, SDDM works)
- Multi-monitor beyond "bar on each screen, panels on the focused one" — you
  have one display; this gets designed properly when you dock something
