# Keybindings

Every binding in the desktop, chosen for a **German QWERTZ layout** on a
ThinkPad E16 Gen 3 with no Print key and no numpad.

`SUPER` is the Windows key. **Caps Lock is Escape** — the real Escape still
works.

Syntax throughout is Hyprland 0.55+ Lua: `hl.bind("SUPER + Q", hl.dsp.window.close())`.

---

## German layout — the rules this map follows

v1 got bitten here, so these are constraints, not preferences:

| Reality on `de` | Consequence |
| --- | --- |
| `[` `]` are `AltGr+8` / `AltGr+9` | **Never bind them.** Three-finger contortion. |
| `` ` `` and `´` are dead keys | **Never bind them.** They swallow the next keystroke. |
| `Y` and `Z` are swapped vs US | `Y` is bottom-left, next to `X` — an easy adjacent pair |
| `Ö Ä Ü` sit where `; ' [` do on US | Free, reachable, and unused by anything |
| `<` `>` key exists left of `Y` | Reachable with the left pinky, keysym `less` |
| `-` is right of `.`, `+` is right of `Ü` | Fine for zoom-style pairs |

Anything bound below is reachable **one-handed on the left** (for
window management, so your right hand stays on the mouse) or **one-handed
where it makes sense**.

---

## Launching

| Keys | Action |
| --- | --- |
| `SUPER` + `Return` | Terminal — kitty |
| `SUPER` + `Space` | **Launcher** (apps, run, calc, emoji, clipboard, windows) |
| `SUPER` + `E` | File manager — nautilus |
| `SUPER` + `B` | Browser |
| `XF86Favorites` | Launcher — the star key on ThinkPad keyboards |

---

## Shell surfaces

The whole point of the shell being one process is that every panel has a key.

| Keys | Action |
| --- | --- |
| `SUPER` + `N` | Dashboard — media, calendar, notification history |
| `SUPER` + `I` | Control centre — network, bluetooth, audio, display |
| `SUPER` + `P` | Power menu |
| `SUPER` + `V` | Clipboard history (launcher, `;` mode) |
| `SUPER` + `.` | Emoji picker (launcher, `:` mode) — matches the GNOME/Slack convention |
| `SUPER` + `SHIFT` + `M` | System monitor |
| `SUPER` + `ALT` + `W` | Wallpaper + theme picker |
| `SUPER` + `SHIFT` + `N` | Toggle Do Not Disturb |
| `SUPER` + `Escape` | Lock the screen — hyprlock |
| `Escape` | Close whatever shell surface is open |

`Escape` is **not** a compositor bind — it could not be, or it would be
swallowed before every application that needs it.

The launcher handles it directly; it holds its own exclusive keyboard focus.
The dashboard gets it from `HyprlandFocusGrab`, which already routes the
keyboard to the bar while a panel is open — that is why you cannot type into the
window behind an open dashboard. The handler is therefore a zero-size focused
`Item` **inside the bar window**, not a surface of its own: the grab dismisses
on focus leaving its window list, so a second focus-taking surface closes the
panel it was meant to serve. Two attempts learned that the hard way; see
CLAUDE.md.

`SUPER+Escape` for lock rather than `SUPER+L`: `L` is needed for focus-right
in the hjkl row, and lock is something you want *away* from anything you hit
by accident.

---

## Windows

| Keys | Action |
| --- | --- |
| `SUPER` + `Q` | Close window |
| `SUPER` + `SHIFT` + `Q` | Force kill (`hl.dsp.kill()`) — for a hung app |
| `SUPER` + `W` | Toggle floating |
| `SUPER` + `F` | Fullscreen |
| `SUPER` + `SHIFT` + `F` | Maximise — keeps the bar and the gaps |
| `SUPER` + `C` | Centre a floating window |
| `SUPER` + `T` | Toggle split direction (dwindle) |
| `SUPER` + `SHIFT` + `P` | Pseudotile |
| `SUPER` + `O` | Pin above all workspaces |
| `SUPER` + `Tab` | Next window on this workspace |
| `SUPER` + `SHIFT` + `Tab` | Previous window |

`W` for float, not `V` — `V` is worth more as clipboard, which you'll press
twenty times a day, than as a float toggle you'll press twice.

## Groups (tabbed containers)

| Keys | Action |
| --- | --- |
| `SUPER` + `G` | Group / ungroup |
| `SUPER` + `SHIFT` + `G` | Move window out of the group |
| `SUPER` + `Y` | Previous tab |
| `SUPER` + `X` | Next tab |

`Y`/`X` are adjacent on QWERTZ (`Y X C V B`) and both are free. This is the
fix for v1's `[`/`]` problem.

## Focus, move, resize

Directional actions are on **hjkl and the arrow keys**. Use the arrows while
hjkl sinks in, then delete the arrow lines from `config/hypr/conf/binds.lua`.

| Keys | Action |
| --- | --- |
| `SUPER` + `H` `J` `K` `L` | Move focus left / down / up / right |
| `SUPER` + `SHIFT` + `H` `J` `K` `L` | Move the window |
| `SUPER` + `CTRL` + `H` `J` `K` `L` | Resize by 40px |
| `SUPER` + `←` `↓` `↑` `→` | Focus (same, with arrows) |
| `SUPER` + `SHIFT` + arrows | Move |
| `SUPER` + `CTRL` + arrows | Resize |
| `SUPER` + drag LMB | Move a window |
| `SUPER` + drag RMB | Resize a window |

## Workspaces

| Keys | Action |
| --- | --- |
| `SUPER` + `1`…`0` | Go to workspace 1–10 |
| `SUPER` + `SHIFT` + `1`…`0` | Move window to workspace 1–10 |
| `SUPER` + `CTRL` + `←` / `→` | Previous / next workspace |
| `SUPER` + scroll | Previous / next workspace |
| `SUPER` + `S` | Toggle scratchpad |
| `SUPER` + `CTRL` + `S` | Move window to the scratchpad |
| `SUPER` + `<` | Back to the last workspace |

`SUPER+<` uses the `less` keysym on the key left of `Y` — a German-layout key
with no US equivalent, and free.

---

## Screenshots and recording

There is **no Print key on this keyboard**, so nothing depends on one. The
`Print` binds exist anyway, harmlessly, for when you dock an external board.

| Keys | Action |
| --- | --- |
| `SUPER` + `SHIFT` + `S` | Region → annotate in satty |
| `SUPER` + `SHIFT` + `D` | Whole screen → annotate |
| `SUPER` + `SHIFT` + `C` | Region → straight to clipboard, no editor |
| `SUPER` + `SHIFT` + `R` | Start / stop screen recording |
| `SUPER` + `SHIFT` + `X` | Colour picker — hyprpicker, copies the hex |
| `Print` | Region → annotate |
| `SHIFT` + `Print` | Whole screen → annotate |

`SUPER+SHIFT+S` is Windows/Snipping-Tool muscle memory and worth honouring.
Note it doesn't collide with `SUPER+S` (scratchpad) — different bindings.

---

## Hardware keys

All bound with `{ locked = true, repeating = true }` so they work on the lock
screen and while held.

| Key | Action |
| --- | --- |
| `XF86AudioRaiseVolume` / `LowerVolume` | Volume ±5% on the default sink, capped at 100% |
| `XF86AudioMute` | Mute toggle |
| `XF86AudioMicMute` | Microphone mute toggle |
| `XF86MonBrightnessUp` / `Down` | Screen brightness ±5% |
| `XF86KbdBrightnessUp` / `Down` | Keyboard backlight — off / low / high |
| `XF86AudioPlay` `Next` `Prev` | Media control via playerctl |
| `Shift` + `XF86AudioNext` / `Prev` | Seek ±10s **within** the track |
| `XF86Search` | Launcher |

The laptop has no dedicated seek keys, so seeking shares the track keys with a
`Shift`: unshifted changes the track, shifted moves inside it. Holding either
scrubs, because they carry the same `repeating` flag as volume.

Every one of these shows an OSD in the notch (DESIGN §1.2.3) rather than a
floating popup — that's what makes them feel integrated instead of bolted on.

**Metal-only:** the keyboard backlight keys cannot be tested in the VM. They
carry an explicit line in the metal checklist (ROADMAP §Phase 3).

---

## Wallpaper / theme picker — `SUPER` + `ALT` + `W`

| Key | Does |
| --- | --- |
| `←` `→` | Previous / next item |
| `↑` `↓` | A whole row on the wallpaper grid; one step on the theme tab |
| `Enter` / `Space` | Apply the focused item |
| `Tab` | Switch between Wallpapers and Theme |
| `Home` / `End` | First / last |
| `Escape` | Close |

The focus ring is an **outline**; the filled row is the one currently applied.
They are different facts and both can be true at once.

---

## Touchpad gestures

Declared with `hl.gesture()` in `conf/input.lua`, not with the old
`gestures.workspace_swipe` booleans — those were **removed upstream** and are a
startup error now, not an ignored key.

| Gesture | Does |
| --- | --- |
| 3 fingers, horizontal | Switch workspace, 1:1 with the swipe |
| 4 fingers, up | Toggle the scratchpad — the same special workspace as `SUPER` + `S` |

Two deliberate absences:

- **Three-finger vertical is unbound.** A swipe that starts diagonally would
  otherwise be a coin flip between switching workspace and opening the
  scratchpad, and the loser is whichever one you did not mean.
- **Nothing calls into the shell.** A gesture bound to a lua lambda running
  `qs ipc call …` would silently do nothing whenever quickshell is restarting.
  Compositor actions keep working regardless.

The swipe's feel — how far, when it commits, when it snaps back — is the
`workspace_swipe_*` block in `conf/input.lua`. Those keys still exist; only the
on/off switch was replaced.

---

## Terminal — kitty

| Keys | Action |
| --- | --- |
| `CTRL` + `SHIFT` + `C` / `V` | Copy / paste |
| `CTRL` + `SHIFT` + `Enter` | New window |
| `CTRL` + `SHIFT` + `T` | New tab |
| `CTRL` + `SHIFT` + `←` / `→` | Previous / next tab |
| `CTRL` + `+` / `-` | Font size |
| `CTRL` + `SHIFT` + `F6` | Dump the running config — the source of truth |

---

## Shell — fish

| Keys | Action |
| --- | --- |
| `→` or `CTRL` + `F` | Accept the autosuggestion |
| `ALT` + `→` | Accept one word of it |
| `CTRL` + `R` | History search (fzf) |
| `CTRL` + `T` | File search (fzf) |
| `ALT` + `C` | cd into a directory (fzf) |
| `ALT` + `←` / `→` | Previous / next directory |

---

## Live lists

When this file and reality disagree, reality wins:

| Layer | Command |
| --- | --- |
| Hyprland | `hyprctl binds` |
| QuickShell | `SUPER+SPACE` → type `keys` |
| kitty | `CTRL+SHIFT+F6` |
| fish | `bind` |

`check.sh` diffs `hyprctl binds` against this document and reports anything
bound but undocumented, or documented but unbound.
