# Roadmap

VM first, metal second — the workflow you chose. The value of the VM is that
it catches structural mistakes cheaply; its limit is that a VM has no battery,
no real GPU, no keyboard backlight and no fingerprint reader. Both facts shape
the phases below.

Blur, animations and general shell behaviour **did** work acceptably in the VM
last time, so the design work genuinely can be validated there.

---

## Phase 0 — Verify the assumptions · ~30 min

Before writing a line of config. Any of these being false changes the plan.

- [ ] `pacman -Si hyprland` reports **≥ 0.55** — otherwise the entire
      `config/hypr/` tree needs hyprlang syntax, not Lua
- [ ] `pacman -Si quickshell` reports **0.3.0+** from `extra`
- [ ] `pacman -Si matugen hyprpaper` both resolve from `extra`
- [ ] Confirm the panel's real mode: `2560x1600@?Hz` and which scale looks
      right — 1.25 is what Ubuntu picked, but Hyprland's fractional scaling
      differs from GNOME's
- [ ] Back up from Ubuntu regardless of the disk decision: `~/.ssh`,
      `~/.gnupg`, `~/.config/{Code,Signal,Slack,discord,obsidian,JetBrains}`,
      browser profiles, `~/HPI`, `~/ctf`, `~/research`, Docker volumes,
      `~/.local/share/keyrings`

**Deliverable:** a short note in this file recording what was actually found.

---

## Phase 1 — Compositor and session, in the VM · ~1 day

A working Hyprland session with no shell at all. Prove the foundation before
building on it.

- `config/hypr/hyprland.lua` + `conf/{monitors,input,looks,binds,rules,autostart}.lua`
- uwsm session, SDDM entry, portals, PipeWire
- Every keybind from KEYBINDS.md **except** the shell ones
- Dwindle layout, gaps, borders, blur, animations tuned per DESIGN §2
- Placeholder: `foot` or `kitty` autostarted so you can see something

**Done when:** you can log in, open windows, tile them, switch workspaces, and
screenshot — with no bar and no launcher. `check.sh` passes its compositor
checks.

---

## Phase 2 — The shell, in the VM · ~3–4 days

The bulk of the work. Build in this order, because each step is testable and
each unblocks the next.

### 2a — Foundations
- `shell.qml`, the `Config` singleton reading `settings.json` with live reload
- The `Theme` singleton reading `colors.json`
- Shared widgets: `IslandSurface`, `Pill`, `Slider`, `Toggle`, `Tooltip`
- **Test:** edit `settings.json`, watch the bar change without a restart

### 2b — The bar
- Bar surface, exclusive zone, click mask
- Left island: workspaces (`Quickshell.Hyprland`)
- Right island: network, bluetooth, volume, battery, tray
- Notch: clock only

**Done when:** the bar looks like the mockup and the numbers in it are real.

### 2c — The notch state machine
The riskiest and most valuable part. Build the state machine and its
transitions before any panel content.
- Priority resolver (dashboard > critical > OSD > toast > media > clock)
- Geometry morph with clip + delayed cross-fade
- Interrupt handling — retarget, don't queue

**Test explicitly:** fire a notification while an OSD is showing, fire a
second notification mid-expansion, open the dashboard during a toast. This is
where a naive implementation falls apart, and it's much cheaper to get right
now than to retrofit.

### 2d — Notifications and OSD  ✅ built, untested
- `NotificationServer`, toasts, history, DND
- OSD for volume, mic, brightness, kbd backlight
- Dashboard: media (MPRIS), calendar, notification list
- `HyprlandFocusGrab` so clicking away closes the dashboard

Volume/mic OSDs are **reactive** — the shell watches PipeWire, so any change
shows feedback regardless of what caused it. Brightness is **pushed** by the
keybind over IPC, because sysfs change notification is unreliable enough that
watching it would work on some kernels and silently never fire on others.

Caps/Num Lock OSD is not built: it needs a keyboard-state source that is not
obviously available, and it is the least valuable of the five.

### 2e — Panels
In descending order of daily value:
1. ~~Launcher (apps → run → calc → clipboard → emoji → windows)~~ **built**
2. ~~Dashboard (media → notifications → calendar)~~ **built** (2d)
3. Control centre (audio → network → bluetooth → display)
4. Power menu
5. System monitor
6. Wallpaper + theme picker

**Ship-able checkpoint:** after the launcher and dashboard, the desktop is
already usable daily. Everything after that is improvement, not blocker.
**Both are now built** — this is the checkpoint, pending a VM run.

Deliberately deferred out of the launcher, each a bounded addition rather than
a rework:

| Deferred | Why |
| --- | --- |
| Clipboard image thumbnails | Needs `cliphist decode` per visible row into a cache file. A process per row, and no way to verify the result without a session. |
| Unit conversion in `=` | A units-aware parser is a project, not a feature. The arithmetic parser it would extend is tested. |
| `=` recalling the last result | Needs a result history, which is state nothing else wants yet. |
| Per-app frecency decay tuning | The 30-day half-life is a guess. It needs weeks of real use before it means anything. |
| Tray right-click menus (`Quickshell.DBusMenu`) | Left over from 2b; unrelated to the launcher but the same "panel content" bucket. |

### 2f — Theming pipeline
- matugen config + templates for all seven targets
- `themes/*.toml` with seed + role overrides
- Mode switch wired to the picker
- Contrast validation in `check.sh`

---

## Phase 3 — Metal · ~1 day

Only now does the disk get touched. Everything below **cannot be verified in a
VM** — this is the list you carry over.

### Cannot be tested until now
- [ ] **Fractional scaling** at 1.25 — check for blurry XWayland apps, and
      whether `GDK_SCALE`/`QT_SCALE_FACTOR` need overriding
- [ ] **Keyboard backlight** — do `XF86KbdBrightnessUp/Down` emit? Use `wev`.
      Is `/sys/class/leds/*::kbd_backlight/brightness` writable without root?
- [ ] **Battery** — that the right island renders it at all, that percentage,
      rate and time-to-empty are correct, and that the <20% and <10% states
      trigger. v1's VM round couldn't test this and it shipped broken.
- [ ] **Screen brightness** — correct sysfs device among several candidates
- [ ] **Suspend and resume** — lid close, wake, and whether the shell survives
      it (Wayland outputs get destroyed and recreated on some resumes)
- [ ] **Fingerprint** — `fprintd-enroll`, then hyprlock and sudo integration.
      May simply not be supported on this hardware.
- [ ] **Touchpad** — gestures, palm rejection, natural scroll
- [ ] **Hardware video decode** — `vainfo`, then a 4K video in mpv with
      `btop` open to confirm the CPU isn't doing the work
- [ ] **Real GPU performance** — blur at `size 6, passes 3` under load, and
      whether animations hold 60fps with a browser and an editor open
- [ ] **Wifi and bluetooth** against real hardware — the control centre's
      whole point, and a VM has neither
- [ ] **Thermals and fan** under sustained load
- [ ] **German layout** end to end — umlauts, AltGr, dead keys, and every
      binding in KEYBINDS.md actually pressed once

### Disk decision
Deferred to the end of Phase 2 by design: once the environment exists and
you've used it in a VM, you'll know whether you want to wipe Ubuntu or dual
boot. Both paths are viable; the backup from Phase 0 covers either.

---

## Phase 4 — Live on it · ~2 weeks

No new features. Use it as the daily driver and fix what annoys you. Keep a
running list at the bottom of this file — that's what v1's PLAN.md was for and
it was the most useful document in the repo.

Expect to spend this phase on: notification timing that's slightly wrong,
one panel that's 40px too small, a keybind that turns out to be awkward, and
one performance problem that only appears with 30 browser tabs open.

---

## Phase 5 — Optional, only if wanted

Deliberately after two weeks of real use, so these get judged on whether you
actually want them:

- In-shell settings panel with sliders (the GUI over `settings.json`)
- Lock screen in QuickShell via `Quickshell.Services.Pam` — needs a tested TTY
  escape hatch and hyprlock kept installed as a fallback
- Polkit agent via `Quickshell.Services.Polkit`, dropping `hyprpolkitagent`
- SDDM theme regenerated from the palette
- Media in the notch's resting state, if you find you miss it
- Multi-monitor design, when you dock something

---

## Time

| Phase | Estimate |
| --- | --- |
| 0 — Verify | 30 min |
| 1 — Compositor | 1 day |
| 2 — Shell | 3–4 days |
| 3 — Metal | 1 day |
| **To a daily-drivable desktop** | **~1 week of focused work** |
| 4 — Settle | 2 weeks, part time |

The single largest risk to that estimate is Phase 2c. A notch is a state
machine with animated geometry, and the failure mode is a shell that looks
right in screenshots and feels wrong in use. Budget for redoing it once.

---

## Running fix list

_Populated during Phases 3 and 4. Issue, cause, whether it needs a decision._

| | Issue | Cause | Needs you? |
| --- | --- | --- | --- |
| | | | |
