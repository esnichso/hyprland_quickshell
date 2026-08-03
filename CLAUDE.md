# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Hyprland desktop for **CachyOS** on a **ThinkPad E16 Gen 3**, where the whole
shell layer — bar, notifications, OSD, launcher, control centre, power menu — is
a single **QuickShell** (QML) process.

**Current state: Phase 1 written, never executed.** `config/` and `install/`
exist; nothing in them has run. The dev host is Ubuntu, where Hyprland and
QuickShell cannot be installed, so the first CachyOS VM boot is the first time
any of this executes. Treat every file as unproven.

The documents below are the specification; `docs/hyprland/` is a wiki snapshot.

| Document | Read it before |
| --- | --- |
| `DESIGN.md` | Touching geometry, motion, or colour. Every number is a decision with a stated reason. |
| `FEATURES.md` | Building any panel. Specs each surface against a named QuickShell module. |
| `KEYBINDS.md` | Adding a bind. The German-layout constraints are hard constraints. |
| `PACKAGES.md` | Adding a dependency. Notes which repo each comes from. |
| `ROADMAP.md` | Planning work. Phased VM → metal, with a list of what a VM cannot test. |

Do not restate these files' content in new documents. Extend them.

## Relationship to v1

`../hypersetup` is a complete, working waybar/rofi/swaync setup for the same
machine. **This is a restart, not a fork.** No files are imported.

The user's explicit instruction: reuse is fine where you're confident, but *no
dead code*, and no time spent repairing carried-over imports or paths. Carry
**decisions**, not files. Keep entry points few — the verdict on v1's seven
scripts was "installer + checker is good", so `install.sh` takes flags rather
than spawning siblings.

## Hardware facts the configuration depends on

| | |
| --- | --- |
| CPU | Intel Core Ultra 7 255H (Arrow Lake-H) — **no AVX-512**, so CachyOS **v3** repos, never v4 |
| GPU | Intel Arc iGPU — no NVIDIA workarounds anywhere |
| Display | single `eDP-1`, **2560×1600** — see the open question below |
| Keyboard | German (`de`), **no Print key**, no numpad |
| Battery | `BAT0` + `AC` — absent in a VM, so battery UI only verifies on metal |

### Open question: display scale

`DESIGN.md` assumes **scale 1.25** → 2048×1280 logical, which is what the
machine reports under GNOME today and what every pixel value in that document
is expressed in.

**v1 chose scale 1.6** → 1600×1000 logical, on the reasoning that 2560/1.6 is a
whole number. So is 2560/1.25. Both are valid; they produce very different
apparent sizes for a 46px bar.

This has never been tested on the real panel and is the single decision most
likely to invalidate the geometry in `DESIGN.md`. Resolve it in Phase 3 by
looking at the display, then update `DESIGN.md`'s numbers if 1.6 wins. Do not
quietly assume either value.

## Workflow

The dev host is **Ubuntu 24.04 / GNOME**. Hyprland, QuickShell and the hypr\*
tools are not installed here and will not run. **You cannot test any of this
locally.** Verification is static here, live in a CachyOS VM, and finally on
metal.

```
edit here  →  static checks  →  user runs it in the VM  →  metal
```

Phase order is in `ROADMAP.md` and exists for a reason: the compositor is
proven before the shell is built on top of it, and the notch state machine is
built before any panel content, because it is the part most likely to need
redoing.

## Commands

These exist and are executable, but have never been run:

```bash
./install/install.sh              # packages → symlinks → services → theme
./install/install.sh --packages   # one concern at a time
./install/install.sh --link
./install/install.sh --theme      # regenerate the palette
./install/check.sh                # validate the RUNNING session, not the files
```

`check.sh` inspects the live session — services, D-Bus ownership, layer
namespaces, resolved colour contrast, named keybinds — rather than parsing
config files. A file-only checker mostly confirms that files exist, which they
always do.

**What can and cannot be verified on the Ubuntu dev host:** bash, JSON and TOML
parse locally. Lua parses via `luaparser` in a venv (`luac` is not installed).
**QML cannot be checked at all** — `/usr/bin/qmllint` is a qtchooser stub
pointing at a Qt5 binary that does not exist, and it fails identically on valid
and invalid input, so its verdict means nothing. This is the exact trap
described under "Verify your own work" below. QML correctness is established by
running it in the VM, and nowhere else.

**Available on a real session:**

```bash
qs                                # run the shell; QML edits hot-reload
qs list                           # what configs quickshell can actually see
qs kill                           # ...when they don't
hyprctl binds                     # the authoritative bind list
hyprctl layers                    # real layer namespaces — do not write these from memory
hyprctl monitors                  # actual mode and scale
wev                               # what a key really emits (essential on `de`)
matugen image <path>              # regenerate the palette
pacman -Si quickshell matugen hyprland hyprpaper
```

There is no test suite, no linter config, and no build step. QML is validated by
running it.

**`qs`, not `qs -c <name>`.** `config/quickshell` is symlinked to
`~/.config/quickshell`, putting `shell.qml` at the base of that directory.
Quickshell then registers it as the *default* config and ignores subdirectories
entirely, so `-c` has nothing to select. Moving to a named config would mean
relocating the symlink, the matugen output paths, and the paths in `Config.qml`
and `Theme.qml` — not worth it for one machine.

## Architecture

### One process, many surfaces

`config/quickshell/shell.qml` is the only entry point. Every surface — bar,
notch, all six panels — is drawn by that one process, which is the entire
reason for the rewrite: one theme source, one config file, one thing to restart.

Two singletons carry all shared state:

- **`Config.qml`** wraps `settings.json` via `FileView` + `JsonAdapter`.
  Every tunable lives there and hot-reloads on save.
- **`Theme.qml`** wraps `colors.json`, which matugen generates.

**QML contains no magic numbers and no hex literals.** Components bind to
`Config.notch.restWidth` and `Theme.primary`. This is what lets the theme
pipeline and a future settings panel both write state safely, and it is the
single most important structural rule in the repo.

### The notch is a state machine

The centre island resolves one state from a fixed priority order —
`dashboard > critical > OSD > toast > media > clock` — and animates its
geometry between them. It does not queue: a new event **retargets** the running
animation from wherever it is. Every animated property uses a `Behavior`, which
makes that free; anything hand-driving an animation is a bug.

Three rules that are not negotiable, all with stated causes in `DESIGN.md` §3:
the exclusive zone never animates (windows would reflow on every notification),
blur radius never animates (full-surface GPU re-render per frame on an iGPU),
and an OSD never grows taller than the bar.

### Colour has exactly one code path

`themes/*.toml` (seed + role overrides) and `matugen image <wallpaper>` both
produce the same Material 3 role set, which then renders through the same
templates to all seven targets. When adding a themed target, add a matugen
template — never a second mechanism. `theme.mode` in `settings.json` selects
which source feeds it.

### What deliberately stays outside QuickShell

hyprlock, hypridle, hyprpolkitagent, SDDM, and the screenshot tools. Reasons are
in `FEATURES.md` §9; the load-bearing one is that a QML error costs you a bar,
but a QML error on a *lock screen* costs you the session.

## Gotchas that still apply

**Hyprland 0.55+ is Lua-only.** hyprlang configs are dead, and essentially every
tutorial or dotfile repo older than May 2026 uses a syntax this version cannot
read. `docs/hyprland/` is a local wiki snapshot — check syntax there before
writing it. (Fetch updates from
`raw.githubusercontent.com/hyprwm/hyprland-wiki/main/content/…`; the rendered
site is JavaScript and unfetchable.)

**But the other hypr\* tools are still hyprlang.** `hyprlock.conf` and
`hypridle.conf` are not Lua. Do not convert them.

**Wiki tables use path notation, not file syntax.** The hyprlock wiki lists
`pam:enabled`; in the file that is a nested block. Writing it flat defines an
option that does not exist, hyprlock exits, and the session is left locked with
no lock screen — recoverable only from a TTY.

**Names do not describe behaviour.** `hyprshutdown` is not a menu; it is a
graceful-exit tool, and binding it directly logs you straight out. v1 lost a
round trip to that assumption.

**Layer namespaces must be read from the running session.** v1 wrote a
`layerrule` matching `^swaync-(control-center|notification-window)$` from
memory; it matched nothing and the blur silently never applied. Use
`hyprctl layers`.

**Transparency has two independent layers.** A Hyprland window-rule `opacity`
fades text along with the background; a terminal's own `background_opacity`
fades only the background. Use the latter for kitty. And `blur.xray = true`
composites floating windows against the *wallpaper* rather than the window
behind them — it is off deliberately.

**GTK CSS is not web CSS**, and one unknown pseudo-class makes GTK reject the
entire stylesheet, yielding a completely unstyled surface with no error.
Validate with GTK's own parser (`load_from_path`, so `@import` resolves), never
by eye.

**qt6ct does not reach KDE applications.** KDE Frameworks apps build their
palette from `KColorScheme`, which reads `~/.config/kdeglobals` and bypasses the
Qt platform theme. Its colours are `r,g,b` **decimals** — a hex string parses as
`0,0,0`.

**A missing GTK theme fails silently and convincingly**: GTK falls back to
Adwaita, still honours the dark preference, and hands you a desktop that looks
*almost* right.

**SDDM never reads `$HOME`.** It runs as the `sddm` user on its own VT before
any user session exists, so no symlink into `~/.config` is visible to it and
`hyprctl reload` means nothing. Its config is root-owned in `/etc/sddm.conf.d/`,
themes in `/usr/share/sddm/themes/`, and installing a theme means **copying**,
not symlinking. Preview with `sddm-greeter-qt6 --test-mode --theme <dir>`.

**Verify package names against live APIs, not memory.** Real corrections found
this way in v1: `rofi-wayland` no longer exists, `hyprland-qtutils` →
`hyprland-guiutils`, `ttf-font-awesome` → `otf-font-awesome`. Also check what an
AUR package drags in — `bibata-cursor-theme` pulls Pillow, numpy and BLAS.

**Two notification daemons is a coin flip at login.** QuickShell owns
`org.freedesktop.Notifications`. swaync, dunst and mako must not be installed;
`check.sh` fails if they are.

## Verify your own work

The two most costly bugs in v1's history were the same mistake — trusting an
operation's report of itself instead of the state it left behind:

- An edit script whose regex was `^`-anchored without `re.M` matched nothing,
  and printed "rewrote launcher.rasi" regardless. That false claim was reported
  to the user as fact.
- `set-theme.py --check` *wrote* every file it claimed to inspect, so drift
  detection could never fail twice. A `--check` flag that mutates is worse than
  no check, because it manufactures the green result it is asked for.

A third, one layer out: **a tool on `$PATH` is not a tool that works.** A
`qmllint` step passed a file it had never parsed, because the binary was a
qtchooser stub that exited non-zero without printing the `error:` line the check
grepped for. Any linter must accept known-good input **and** reject known-bad
input before its verdict is trusted — otherwise skip loudly.

Check the file, not the script's success message. Re-read regions you edited:
v1 twice ended up with duplicated CSS rules, which are valid, warning-free, and
visually identical.

## User preferences

- **Flag guesses explicitly.** When something is inferred rather than verified,
  say so and say how to test it. This has been valued repeatedly.
- Wants the *mechanism*, not just the fix.
- Colour as signal, not decoration — the bar is neutral at rest and only
  colours what needs attention.
- No automatic wallpaper changes.
- Prefers official repos over AUR where there is a choice.
- Corrections plain and brief; no over-apologising, no re-litigating.
