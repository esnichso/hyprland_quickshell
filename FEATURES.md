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

Ten workspaces, but only the interesting ones are drawn: every workspace
Hyprland reports, plus the focused one, plus workspace 1. Empty trailing
workspaces don't take up space.

Hyprland only keeps a workspace alive while it holds windows or is focused, so
its list is *already* the interesting set — filtering it again by window count
is wrong, and was the bug that made a workspace invisible until you switched to
it. Occupancy for the filled-vs-hollow styling comes from
`HyprlandWorkspace.toplevels`, a live model, **never** from
`lastIpcObject.windows` — that is a snapshot of `hyprctl workspaces` refreshed
on workspace events, not on window events, so it is stale exactly when a window
has just opened.

| State | Appearance |
| --- | --- |
| Focused | Filled `primary` pill, widened to 22px |
| Has windows | Filled dot, `textOnSurfaceVariant` |
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

`14:32   Mon 3` — time in `tnum` figures, date in `textOnSurfaceVariant` at 11px.
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
| Volume | `Quickshell.Services.Pipewire` | Speaker glyph at one of three levels | **no** — always visible |
| Battery | `Quickshell.Services.UPower` | `87%` + glyph | no |

Battery detail:
- Charging shows a bolt; the percentage turns `primary`
- Below 20% the glyph turns `error`; below 10% it pulses
- Hover → `2h 14m remaining · 8.4 W · 94% health`
- On a desktop or in a VM with no battery, the item removes itself rather than
  showing `0%` — which is exactly the bug v1 hit in its VM round

Volume detail:
- **Always visible**, unlike the mic. The two are different kinds of thing: the
  mic is a mode you switch into and back out of, so "unmuted" is genuinely not
  worth a glyph — output volume is a level you want to read without opening
  anything, and a bar that only mentions audio when it is *wrong* makes you open
  the control centre to answer "how loud is this".
- Three glyph levels, because that is how many the classic Font Awesome speaker
  has: no waves (≤33%), one wave (≤66%), two waves (above). Muted reuses the
  no-wave glyph in `error` and is told apart by colour alone — the crossed-out
  speaker lives in a Nerd Fonts v3 block this repo cannot verify without a
  session.
- **No percentage.** The OSD already answers "how loud exactly" while you are
  changing it, which is the only moment the number matters. In the bar it is
  width spent on a value that is stale the rest of the time — glyph level is
  enough to answer "is this loud" at a glance, which is the question the bar is
  for.

**Clicks** open the relevant panel: network → control centre on the Network
tab, bluetooth → Bluetooth tab, battery → power/profiles. The volume glyph
itself toggles mute, which is the one action worth a single click.
**Scroll anywhere on the island** adjusts the default sink — not just over the
volume item.

### 1.4 System tray

**Source:** `Quickshell.Services.SystemTray` + `Quickshell.DBusMenu`

Tray icons sit at the **left end of the right island**, separated by a 1px
divider. You run Signal, Slack, Discord and Mullvad — all four are tray-only
when closed, so this isn't optional.

- **Left-click → activate.** Unless the item reports `onlyMenu`, which is the
  StatusNotifierItem way of saying activation is a no-op — those open the menu
  instead, because a click that "works" and does nothing is worse than a click
  that does the obvious thing.
- **Middle-click → secondary activate.**
- **Right-click → the app's own menu**, over DBusMenu. Quickshell hands out a
  `QsMenuHandle` and renders the platform menu itself through `QsMenuAnchor`,
  so there is nothing here to lay out. Anchored to `anchor.item` — the icon —
  rather than `anchor.window`: PopupAnchor treats the two as mutually exclusive,
  and anchoring to the icon is what puts the menu under the one you clicked.
- **Hover → a tooltip** with `tooltipTitle` (falling back to `title`) and
  `tooltipDescription`. Drawn by `Bar.qml`, **not** by the island: the island is
  34px tall, and a tooltip below it would either be clipped by the rounded rect
  or force the layer surface taller — and a layer surface must never change
  size (DESIGN §3). The bar window is already tall enough for the notch and is
  masked to the islands, so there is room below it that is drawn but not
  clickable, which is exactly what a tooltip wants.
- **Overflow past `bar.trayVisible` (3) collapses behind an ellipsis**, which
  toggles to a chevron when expanded. Hidden items take zero width, not just
  `visible: false` — an invisible item that still occupies 14px leaves the
  island padded for icons nobody can see. The set collapses again by itself
  when an app quits and the count drops back under the limit.

---

## 2. Dashboard — click the notch, or `SUPER+N`

440×560, grows down out of the notch. Three stacked sections, scrollable as
one.

### Media

**Source:** `Quickshell.Services.Mpris`

- Album art at 96px, rounded 12, faded in when it loads. What players put in
  `mpris:artUrl` varies: a local `file://`, a bare filesystem path with no
  scheme, an `https://` cover or YouTube poster frame from a browser tab, or a
  `data:` URI. `Media.artUrl` gives the bare path a scheme — that one case
  renders as an empty square otherwise — and passes the rest through. The
  placeholder shows whenever there is no art **on screen**, which includes a
  URL that failed to fetch, not only a missing one.
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

**Built** (Phase 2e). Four tabs; five details fall short of this spec and are
called out inline below, each with a line in ROADMAP.md.

400 wide, height driven by content, anchored under the right island. Tabs
across the top: **Network · Bluetooth · Audio · Display**.

The window copies the launcher's pattern exactly — full-screen transparent
overlay, exclusive keyboard focus, click outside to close, Escape to close —
because that pattern is known to work. It deliberately does **not** use
`HyprlandFocusGrab`: the notch uses a grab, and a grab plus a second
focus-taking surface is what broke the dashboard twice. One focus mechanism per
surface.

Only the visible tab is `active`. Wifi scanning, bluetooth discovery and
binding every PipeWire node all cost power or work, so each tab starts its own
expense when it appears and stops it when it does not.

### Network

**Source:** `Quickshell.Networking`

- Wifi toggle, then a live list of visible networks sorted by signal
- Each row: SSID, signal arc, a lock glyph if secured, `✓` if it's the active one
- Click an unknown network → an inline password field appears in the row
  (not a separate dialog), Enter connects, errors render in the row in `error`
- Known networks connect on click
- Right-click → forget
- Ethernet appears as a pinned row at the top when a cable is in
- Signal strength is drawn as four bars of **geometry, not a font glyph**.
  Nerd Fonts puts graded wifi icons in the Material Design range, which v3
  moved to Unicode plane 1 — codepoints this repo cannot verify without a
  session, and an invented one renders as a replacement box.

**Deviations.** `Quickshell.Networking` exposes no addressing information and no
VPN model, so the **IP / gateway / link-speed footer** and the **VPN section**
are not built — reaching them means shelling out to `nmcli`, which is the thing
this tab exists to stop doing. **Enterprise (802.1X) networks** say so and point
at `nmtui` rather than offering a password box that cannot work.

**This replaces `nmtui`**, which v1 launched tiled and which swallowed the
whole screen. No terminal UI in a floating window pretending to be a GUI.

### Bluetooth

**Source:** `Quickshell.Bluetooth`

- Adapter toggle and a discovery toggle
- Paired devices first with battery level where the device reports it
  (headphones and mice mostly do), then discovered devices
- Click → connect/disconnect. Right-click → forget.

**Deviation.** Pairing that needs a **PIN confirmation** is not handled: BlueZ
asks for that through an `org.bluez.Agent1` registration, which Quickshell 0.3.0
does not expose. Devices that pair without confirmation work; anything that puts
a number on a screen needs `bluetoothctl`.

**Replaces `blueman`.**

### Audio

**Source:** `Quickshell.Services.Pipewire`

- Output device list with a radio selection and a per-device volume slider
- Input device list, same

  **Deviation:** the live input-level meter is not built. Reading a node's peak
  level means attaching a monitor stream, which Quickshell 0.3.0 does not
  expose.
- **Per-application volume** — every PipeWire stream with its app icon and its
  own slider. This is the pavucontrol replacement and the reason to bother.
- Mute buttons everywhere; muted sliders grey out but keep their value

**Replaces `pavucontrol`.**

### Display

- Screen brightness slider (`sysfs`, with `brightnessctl` as the setter)
- Keyboard backlight: off / low / high segmented control
- Night light toggle and temperature slider, driving `hyprsunset` over
  `hyprctl hyprsunset temperature|identity` — the commands in
  `docs/hyprland/Hypr_Ecosystem_hyprsunset.md`, not invented. The daemon is
  started in `conf/autostart.lua`; without it the tab says so rather than
  silently doing nothing.

  **Deviation:** the state shown is what you last set, not a readback.
  `hyprctl hyprsunset profile` prints the active profile but its output format
  is undocumented, so the parser is best-effort and is not allowed to move the
  UI when it fails.
- Scale selector for the internal panel — 1.0 / 1.25 / 1.5, applied via
  `hyprctl keyword monitor`. **Metal-only: cannot be verified in the VM.**
- Power profile: Saver / Balanced / Performance, via `power-profiles-daemon`,
  with the current one highlighted and a note showing which one auto-switching
  picked

---

## 4. Launcher — `SUPER+SPACE`

**Built** (Phase 2e). All six modes work; two details fall short of this spec
and are called out below.

Centred overlay, 640 wide and at most 420 tall, layer `overlay`, keyboard
grabbed (`WlrKeyboardFocus.Exclusive`). Background is *not* dimmed (see DESIGN
§6); the box uses the shared `Theme.panelBg` role rather than its own alpha, so
it restyles with everything else.

The layer surface is full-screen and fixed; the box inside it is what resizes,
growing downward from a fixed top edge so the input never moves as you type.
Clicking outside the box closes the launcher.

**Source:** `Quickshell` (`DesktopEntries`), `Quickshell.Hyprland`,
`Quickshell.Io` (`Process`, `FileView`)

One input field. What you type is matched across modes; a prefix forces one.

| Prefix | Mode | Example |
| --- | --- | --- |
| *(none)* | Apps — fuzzy over name, generic name, keywords, exec | `fire` → Firefox |
| `>` | Run a command | `>systemctl --user restart foo` |
| `=` | Calculator | `=45*1.19` → `53.55`, Enter copies |
| `:` | Emoji | `:shrug` → ¯\\_(ツ)_/¯ |
| `;` | Clipboard history | `;` then type to filter |
| `/` | Window switcher | `/nvim` jumps to that window |

`SUPER+V` and `SUPER+.` are not separate surfaces — they open this one with
`;` or `:` already typed. Pressing one while the launcher is open *switches*
mode rather than closing it; pressing the same bind twice closes.

- Results are keyboard-driven: `↑`/`↓`, `Ctrl+K`/`Ctrl+J` or `Ctrl+P`/`Ctrl+N`,
  Enter runs, Esc closes. Selection wraps at both ends.
- App results show icon, name, and generic name; recently-used sort first,
  frecency stored in `~/.local/state/quickshell/frecency.json` as a use count
  with a 30-day half-life, decayed again at query time. It breaks ties and
  orders the bare launcher; it never outranks a clear text match.
- Apps launch through `uwsm app --` so they land in their own systemd scope
  and don't die with the launcher. `Terminal=true` entries get the terminal
  prepended, because `DesktopEntry.execute()` ignores that flag.
- **Clipboard** reads `cliphist`. Selecting copies and closes; `Ctrl+Delete`
  (or middle/right click) removes an entry. Every `cliphist` call passes the id
  or the list line as a **positional argument** to `sh -c`, never interpolated
  into the script text.
  Image entries show a **thumbnail**. cliphist only hands out bytes on stdout
  and an `Image` needs a URL, so the bytes are decoded to a file under
  `Quickshell.cachePath("clip")` on demand — one `cliphist decode` at a time
  from a queue, because a clipboard holding forty screenshots would otherwise
  fork forty processes in the frame you press `;`. Results are cached by
  cliphist id, failures cached as empty so a decode that cannot work is not
  retried on every keystroke, and the whole directory is dropped on refresh
  since a rotated-out entry never comes back. Only `png/jpg/jpeg/gif/webp/bmp`
  are decoded — an arbitrary binary blob is work with no payoff.

  The row label is rewritten too: `png · 800×600 · 41 KiB` rather than
  `[[ binary data 41 KiB png 800x600 ]]`. Search reads **both** the label and
  the raw marker and takes the better score, or an image would be un-findable
  by typing either what the row says or what cliphist stored.

  **Old deviation, now closed:** image entries used to show cliphist's
  `[[ binary data … ]]` descriptor with a picture glyph and no thumbnail. The
  stated reason was that rendering one means decoding each visible row to a
  temp file, a process per row. That is still what it does — the fix was the
  queue and the id cache, which make "a process per row" bounded rather than
  unbounded.
- **Emoji** parses `/usr/share/unicode/emoji/emoji-test.txt` from the
  `unicode-emoji` package, lazily on the first `:` and only the
  `fully-qualified` sequences, plus a small built-in kaomoji and symbol list —
  `:shrug` is a text face, not a Unicode character. Enter copies.
  Text faces are flagged `face: true` and get a wider, clipped leading slot and
  the UI font; pictographs get 24px and the colour emoji font. Without the
  distinction a ten-character kaomoji renders centred in a 24px box and draws
  over its own label on one side and out of the row on the other.
  **Without the `unicode-emoji` package installed this mode shows only the
  kaomoji** and logs one warning naming the package.
- **Calculator** evaluates as you type with a hand-written recursive-descent
  parser: `+ - * / % ^`, parentheses, unary sign, `sqrt abs floor ceil round ln
  log exp sin cos tan asin acos atan`, and `pi e tau`. `^` is right-associative
  and unary minus binds looser than it, so `-2^2` is `-4`. Not `eval()` — a
  process that owns the notification daemon and the tray must not run a string
  the user is halfway through typing.
  **Deviation:** no unit conversion, and `=` alone shows nothing rather than the
  last result. Both are in ROADMAP.md.

The pure logic — fuzzy scoring, the parser, the emoji and cliphist line
parsers — is the one part of the shell that can be tested off a session:
`node tests/launcher.js` runs it extracted verbatim from the QML.

**Replaces rofi, rofi-calc, rofimoji, and the cliphist rofi glue** — four
things v1 wired together, now one surface with one theme.

---

## 5. Power menu — `SUPER+P`

**Built** (Phase 2e).

Centred, 360 wide. Five rows: **Lock · Log out · Suspend · Restart · Shut
down**, each with an icon and a one-letter accelerator.

- Navigable with `j`/`k` and the arrows, Enter runs, Esc closes. The letter
  shown on each row (`L O S R P`) runs it directly.
- Restart and Shut down ask first; the others don't. A confirmation on Lock is
  a second keystroke you press every day and resent by the third.
- Confirmation is a **state of the panel**, not a second window. A dialog would
  be another surface taking focus, which this repo has already paid for twice.
  Escape backs out of a pending confirmation before it closes the menu, and
  moving off the row cancels it — the pending action is always the one under
  the cursor.
- Every session-ending action runs `hyprshutdown -t '…' --post-cmd '…'` so apps
  are asked to exit rather than killed. Flags are from
  `docs/hyprland/Hypr_Ecosystem_hyprshutdown.md`. **`hyprshutdown` is not a
  menu** — its name says otherwise and v1 lost a round trip binding it directly.
  No `--vt`: that flag is for NVIDIA + SDDM, and this machine is Intel.
- Suspend does *not* go through hyprshutdown — it does not end the session —
  and uses `systemctl suspend` so it runs through polkit without a password.
- Lock invokes `hyprlock`
- A footer shows uptime, and names whatever is holding a sleep lock. A suspend
  that silently does nothing looks like a broken button; this is the one place
  that says why.

  `systemd-inhibit --list`'s columns have moved between systemd releases, so the
  parser counts lines mentioning a sleep, idle or shutdown lock rather than
  reading by position. A miscount shows the wrong number; a positional parser
  would show nonsense.

---

## 6. System monitor — `SUPER+SHIFT+M`

420×520. Not a bar module — you asked for a calm bar, and per-core graphs in
the bar is the opposite of that. It's one keypress away instead.

**Built** (Phase 2e).

**Source:** `/proc` and `/sys` via `Quickshell.Io` `FileView`, polled at 1s
while visible and **not polled at all when hidden** — `Sys.active` follows the
window's visibility, and the previous samples are dropped on open so the first
delta is never measured against counters from the last time you looked.

- CPU: per-core bars plus a 60s history sparkline, package temperature
- Memory: used / cached / free stacked bar, swap below it
- Disk: per-mount usage bars, plus read/write throughput
- Network: up/down throughput sparkline
- Battery: draw in watts, time to full/empty, health percentage
- Top processes: 8 rows by CPU, each with a kill button (SIGTERM, not SIGKILL —
  the same courtesy `hyprshutdown` pays applications at logout)

Everything is a **delta between two samples**, because /proc counters are
monotonic totals since boot. Three details that are wrong if guessed:
`MemAvailable` is the only honest "used" figure (`total - free` double-counts
cache and reports 90% used on an idle machine); `/proc/diskstats` sectors are
always 512 bytes regardless of the device's block size, and partitions must be
excluded or every figure doubles; the CPU hwmon is found by **name** each tick
because its numbering is not stable across boots.

**Deviations.** No **charge cycle count** — `UPowerDevice` does not expose one.
No **sort-by-memory toggle**; the list is CPU-ordered and shows both figures.
Network throughput is **summed across interfaces** rather than one sparkline
per interface, with `lo` and the docker/libvirt bridges excluded so nothing is
counted twice.

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

**Keyboard.** Arrows move, `Enter` (or `Space`) applies, `Tab` switches tab,
`Home`/`End` jump, `Escape` closes. On the grid, up/down move a whole row and
left/right one tile; on the theme tab every arrow is one step, because it has
one column.

Navigation is an **index into a list of string keys**, not per-item focus. The
two tabs have nothing structurally in common — one is a `Grid` of images, the
other a `Column` mixing radio rows with a segmented control — so `KeyNavigation`
between real items would mean wiring every element to its four neighbours and
rewiring them whenever the theme list changes length. The key list is rebuilt
from the data instead (`"w:<path>"`, `"theme:<id>"`, `"scheme:dark"`, …) and
each element only answers "is my key the current one".

Three consequences worth stating, because each is a bug that shape avoids:

- Theme rows are **not reachable** while the palette follows the wallpaper,
  because they are not drawn — a focus ring on an invisible row is a cursor
  that has vanished.
- The index **clamps rather than wraps**. Wrapping from the last wallpaper back
  to the first reads as the selection jumping somewhere random when you are
  holding an arrow key.
- Focus is drawn as an **outline**, never as a fill: the fill already means
  "applied", and one property carrying two meanings leaves you unable to tell
  which row is selected from which one the keyboard is on.

Scroll-into-view is implemented for the wallpaper grid only. Its rows are a
fixed height computed on the spot, so the focused row's position is arithmetic;
the theme tab mixes 16px headings, 40px rows and a 22px control, which would
mean measuring real items — and it is short enough not to need it.

Selecting **From wallpaper** re-runs matugen against the current wallpaper
immediately. Selecting a named theme stops wallpaper changes from touching
colour — you can then change wallpaper freely without the desktop re-theming.
Both write `theme.mode` to `settings.json`, so the state survives a restart
and `check.sh` can report which mode you're in.

**Built** (Phase 2e), and with one rule that matters more than the panel:

**The picker does not generate colour.** It shells out to
`install/install.sh --theme <name|path>` — the same command you would type. It
never runs matugen, never writes `colors.json` and does not know what a
template is. A second mechanism here would be a second thing to keep in sync
with the eight matugen targets, and it would drift. `install.sh` gained a
`--wallpaper <path>` flag for the one case the existing flags could not cover:
changing the picture in "pick a theme" mode, where re-theming is exactly what
must not happen.

The repo path is **derived, not hardcoded** — `~/.config/quickshell` is a
symlink into the checkout, so the wrapper resolves it and goes up two levels.
v1's fish aliases hardcoded the dev host's path and were broken everywhere else.

`Config.save()` now blocks until the write lands, because the picker writes
`theme.mode`/`theme.scheme` and then immediately runs an installer that reads
that file back. A queued write would let it render the scheme you just changed
away from.

`theme.prefer` in `settings.json` decides which candidate matugen takes when a
wallpaper yields several. It is required, not tuning: without it matugen tries
to prompt, finds no terminal, and fails — but only when the picker launched it,
never when you run the same command by hand.

**Deviations.** Each theme row previews its **seed** colour, not the resolved
`primary`/`surface`/`onSurface` — those do not exist until matugen has run, and
running it per row to draw a swatch is three processes to preview three
squares. Scheme is **Dark / Light**; there is no Auto, which would need
time-of-day switching that nothing else in the shell has. Thumbnails are
decoded at `sourceSize.width: 320` and cached by Qt in memory rather than
written to `~/.cache/quickshell/wallthumbs/` — a disk cache needs an external
resizer, and the decode-time downsample already stops a 4000px photo becoming a
4000px texture.

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
| Login screen | `sddm` | Runs before `$HOME` is readable. Wears a hand-written QML theme in `sddm/hypersetup/`, installed by `install.sh --sddm` (see below). |
| Screenshots | `grim` + `slurp` + `satty` | Annotation is a real app's job |
| Screen recording | `wf-recorder` | Same |
| Colour picker | `hyprpicker` | Same |
| File manager | `nautilus` | Same |

### 9.1 The login screen

`sddm/hypersetup/` — `Main.qml` plus `metadata.desktop`, the eighth matugen
target, and the only one that is **copied** rather than symlinked. SDDM runs as
its own user on its own VT before any user session exists: it cannot read
`$HOME`, so a symlink into the checkout is a theme it never sees.

| Surface | Behaviour |
| --- | --- |
| Background | The current wallpaper, copied in beside the theme, dimmed 55% toward `background` so text stays readable over a picture nobody checked for contrast. Falls back to the flat colour when no wallpaper is set. |
| Clock | Time and date, same position as the notch's, one `Timer` driving one property |
| Card | Avatar initial, user name, password field, error line |
| Session | Bottom-left pill, click to cycle. Names come from a `Repeater` over `sessionModel`, resolved by role **name** — SDDM has reordered its role indices between releases |
| Keyboard | Bottom-left pill showing the layout, visible only when there is more than one. A greeter silently typing on `us` is the classic "my password stopped working" |
| Power | Bottom-right: suspend, restart, shut down — each hidden unless `sddm.can*` says it is available |

**The syntax is deliberately conservative — Qt 5 and Qt 6 both accept all of
it.** Which QML engine sddm launches is not something this repo can determine,
and the cost of guessing wrong is a login screen you cannot get past. So:

| Avoided | Because |
| --- | --- |
| `import QtQuick` with no version | Qt 6 only. This is what actually broke it: sddm reported *"Library import requires a version"*, the theme did not load at all, and the greeter fell back to breeze. `install.sh --sddm` now refuses to install a theme containing one, and `check.sh` flags it. |
| Inline `component X: Y {}` | Needs Qt 5.15. `IconButton.qml` and `PillButton.qml` are separate files instead. |
| `required property` in delegates | Needs Qt 5.15. The Repeaters use the implicit `index` / `model`. |
| `Connections { function onX() }` | Needs Qt 5.15, and the older `onX:` form is deprecated in Qt 6. Signals are connected with `signal.connect()`, which both engines have always accepted, inside a `try` so a signal one version lacks cannot abort the rest of the block. |
| `QtQuick.Controls` | Resolves a style at load, and a style not installed for the `sddm` user is a greeter that does not draw. |

**`sddm-greeter-qt6 --test-mode` can never log in.** Test mode runs the greeter
with no sddm daemon behind it, so `login()` has nothing to talk to and the
watchdog below always fires. Use it to check that the theme *draws*; a real
login can only be tested by logging out.

**Nothing fails silently.** An empty username, an empty password, and an
exception out of `login()` each put a sentence on the card, and a 5s watchdog
reports `no answer from sddm — normal under --test-mode (user '…', session N)`
if neither `loginSucceeded` nor `loginFailed` arrives — naming the two values being passed, because those
are the two that can be wrong. Without the watchdog, `busy` stuck `true` on any
silent failure and left the password field permanently disabled.

That matters because of how this failed the first time: `userModel.lastUser`
came back empty, `sddm.login("", …)` returned without a word, and the only
visible symptom was a card with no name on it.

The palette arrives through the normal pipeline —
`config/matugen/templates/sddm-theme.conf` renders to `~/.local/state`, and
`--sddm` copies that file, the QML and the wallpaper into
`/usr/share/sddm/themes/hypersetup`. **`--sddm` is separate from `--theme`
on purpose:** the copy needs a password, and `--theme` has to stay runnable
from the wallpaper picker, which has no terminal to type one into. `--theme`
prints a warning when the greeter's palette has gone stale, and `check.sh` has
a `login screen` section that fails on the same condition.

**If the greeter ever fails to draw you cannot log in.** The way back is a TTY:
`Ctrl+Alt+F2`, log in, then
`sudo rm /etc/sddm.conf.d/10-hypersetup.conf && sudo systemctl restart sddm`.
`--sddm` prints that, because the moment you need it is the moment you cannot
read this file. Preview before trusting it:
`sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/hypersetup`.

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
