# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Hyprland desktop for **CachyOS** on a **ThinkPad E16 Gen 3**, where the whole
shell layer — bar, notifications, OSD, launcher, control centre, power menu — is
a single **QuickShell** (QML) process.

**Current state: Phase 2e, partial.** Running in a CachyOS VM. Working there:
the compositor, the bar, the notch (clock, OSD, toasts, dashboard) and the
launcher — all six modes, keyboard-driven, one overlay.

The **control centre is written but has never been run**: Network, Bluetooth,
Audio and Display tabs, replacing nmtui, blueman and pavucontrol. Its
deviations from `FEATURES.md` §3 are listed there and in `ROADMAP.md`, each
because the Quickshell module does not expose what the feature needs.

The **power menu is written but has never been run** either: five actions, all
session-ending ones through `hyprshutdown` so apps are asked to exit.

The **system monitor** and the **wallpaper/theme picker** are written but have
never been run either. That is **all six panels of Phase 2e**; nothing in
`FEATURES.md` is unbuilt.

**Phase 2f is written too.** The wallpaper half of the theming pipeline is
proven in the VM — the user has applied wallpapers and settled on
`scheme-expressive`. The **role-override half has never run on a session**: no
theme carrying a `[roles]` table has been applied live, only against a
simulated matugen palette here. `ROADMAP.md` §2f lists the four things a VM run
has to confirm.

What remains is Phase 3, metal.

Every panel's deviations are listed in `FEATURES.md` beside the feature and in
`ROADMAP.md` §2e, each because a Quickshell module does not expose what the
feature needs — none were skipped for effort.

Nothing has run on metal. The dev host is Ubuntu, where Hyprland and QuickShell
cannot be installed, so anything untested in the VM is unproven.

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
./install/install.sh --sddm       # push theme + wallpaper to the login screen
./install/check.sh                # validate the RUNNING session, not the files
```

`check.sh` inspects the live session — services, D-Bus ownership, layer
namespaces, resolved colour contrast, named keybinds — rather than parsing
config files. A file-only checker mostly confirms that files exist, which they
always do.

**What can and cannot be verified on the Ubuntu dev host:** bash, JSON and TOML
parse locally. Lua parses via `luaparser` in a venv (`luac` is not installed).
**QML cannot be parsed at all** — `/usr/bin/qmllint` is a qtchooser stub pointing
at a Qt5 binary that does not exist, and it fails identically on valid and
invalid input, so its verdict means nothing.

`./install/check.sh` runs from the repo anywhere, and four of its sections are
pure static checks that need no session. Run it before every push:

- **config keys** — diffs every key in `config/hypr` against the 518 keys the
  wiki snapshot documents, and flags RE2 lookaheads in rules.
- **qml** — reals assigned to int-typed QML properties, unbalanced quotes, and
  empty glyph slots.
- **ansi** — duplicate terminal colours, and bright colours mapped to a dark
  container role.
- **templates** — the contract that lets `install.sh` re-render matugen's
  templates itself: placeholder forms it implements, roles that exist in
  `colors.json`, `[roles]` keys that resolve, and each theme's own contrast.

The first three exist because the corresponding mistake shipped once; the
fourth exists because the renderer it guards cannot be exercised here. None of
them replaces running the thing.

One more thing runs off a session:

```bash
node tests/launcher.js            # 75 assertions, ~1s
```

The launcher's pure logic — `services/Fuzzy.qml`, `Calc.qml`, `Emoji.qml`,
`Clip.qml` — is plain JavaScript with no QML types in it. `tests/launcher.js`
lifts every `function` and `property` literal straight out of the `.qml` source
and runs it in node, so it tests the **shipped text**, not a copy that can
drift. It caught a real precedence bug (`-2^2` answering `4`).

Do not try to grow this into a QML test runner. Everything else in the shell
needs a compositor, and `qmllint` here is a broken stub.

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
templates to all eight targets. When adding a themed target, add a matugen
template — never a second mechanism. `theme.mode` in `settings.json` selects
which source feeds it.

The one wrinkle: matugen offers no hook to change a role before it renders, so
a theme's `[roles]` table can only be merged *after*. `install.sh` lets matugen
render once, merges the overrides into `colors.json`, and re-renders the other
seven targets itself — reusing the same template files, so no target's role
mapping is duplicated. A theme without `[roles]` never reaches that path. Its
renderer implements exactly two placeholder forms; `check.sh`'s **templates**
section fails the build if a template ever uses a third. If you add a
placeholder form to a template, teach `apply_roles` in `install.sh` about it in
the same commit, or the check will tell you.

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

**The login screen is the one target `--theme` cannot update.** SDDM's theme
lives in `/usr/share`, root-owned, and `--theme` has to stay runnable from the
wallpaper picker — which has no terminal for a sudo prompt. So `--sddm` is a
separate flag that copies the already-rendered palette, the QML and the
wallpaper into place. `--theme` warns when the greeter has gone stale and
`check.sh`'s `login screen` section fails on it, because a wrong-coloured
greeter looks like a choice.

**hyprpaper remembers nothing.** `hyprctl hyprpaper wallpaper` lasts exactly as
long as the process, so the wallpaper was lost at every login. What survives is
`~/.config/hypr/hyprpaper.conf`, which `set_wallpaper()` rewrites on every
change and autostart's `hyprpaper` reads. The IPC call is what you see now; the
file is what logs in. Both, always.

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

## Mistakes made building this

Every one of these shipped, cost a round trip, and can recur. Grouped by where
they hide.

### Hyprland config

**Config keys move and get removed between releases, and an unknown key is a
startup error banner — not something ignored.** The first VM boot hit five at
once: `dwindle.pseudotile` (never existed — pseudotiling is per-window state),
`misc.vfr` (lives under `debug`), and `gestures.workspace_swipe` /
`workspace_swipe_fingers` (removed upstream in favour of `hl.gesture()`).
`check.sh` now diffs every key against the wiki snapshot. Run it before pushing
compositor changes, and refresh `docs/hyprland/` after a Hyprland update.

**`no_border` is a workspace rule, not a window rule.** Window rules use
`border_size = 0`. The rule name existing *somewhere* in the wiki is not
evidence it is valid where you are using it — check the right table.

**Hyprland matches with Google's RE2, which has no lookahead or lookbehind.**
`^(?!Thunar$).*` is a parse error, not a non-match. RE2 negates with a
`negative:` prefix on the whole pattern. `check.sh` greps for `(?=`, `(?!`,
`(?<`.

**Do not invent `hl.*` functions.** `hl.notify()` looked plausible and does not
exist. The full surface is discoverable:
`grep -rhoE "hl\.[a-z_]+\(" docs/hyprland/ | sort -u`.

### QuickShell and QML

**Read the LAST "caused by" line, not the first.** A single bad property aborts
its file, and every type that imports it then reports "Type X unavailable", so
the top of the error stack is five frames from the cause. One fractional
`font.pixelSize` presented as "Type Bar unavailable" in `shell.qml`.

**`font.pixelSize` is an int.** So are `font.weight`, `maximumLineCount` and
`Timer.interval`. A fractional value fails to load. Linted by `check.sh`.

**`exclusionMode` defaults to `Auto`, which ignores `exclusiveZone`.** Auto
derives the reserved space from the window's size and anchors "if exactly 3
anchors are connected" — which describes every edge-anchored bar. The explicit
`exclusiveZone` was silently unused and windows reflowed on every notch change.
**Always set `exclusionMode: ExclusionMode.Normal` explicitly.**

**Never let a layer surface change size.** The compositor animates layer resizes
(`hl.animation` leaf `layers`), and that animation lands on top of whatever the
shell is animating, reading as a bounce. Size the surface for its largest state
once and mask input instead.

**A MouseArea declared after its siblings stacks above them and swallows their
clicks.** The notch's open-dashboard handler sat after the panes and ate every
click on a notification toast — invisible for ordinary notifications because the
timer cleared them anyway, fatal for critical ones which have no timer. Declare
catch-all MouseAreas *before* content, and gate them with `enabled` so intent
survives a later edit.

**`qs`, not `qs -c <name>`.** `-c` resolves to
`<xdg>/quickshell/<name>/shell.qml`. This repo symlinks `config/quickshell` to
`~/.config/quickshell`, so `shell.qml` is at the base — which registers as the
*default* config and makes subdirectories invisible.

**`NotificationAction.invoke()` already destroys the notification** unless it is
resident. Calling `dismiss()` afterwards is a second close on a dead object.

**One tracker per resource.** `StatusIsland` grew its own `PwObjectTracker`
alongside the one in `Audio`. Two trackers on the same nodes is redundant work
and a way for two components to disagree about the volume. Services are
singletons for this reason — bind to them, do not re-instantiate.

**Do not name a component the same as one in a directory it imports.** A
`widgets/Bar.qml` would have shadowed `bar/Bar.qml`, which imports `root:/widgets`.

**`lastIpcObject` is a snapshot, not a live value.** It holds whatever
`hyprctl <thing>` last returned, and quickshell only re-runs that on events for
*that* thing — `Hyprland.workspaces` refreshes on workspace events, not on
window events. Reading `lastIpcObject.windows` to decide whether a workspace has
windows therefore answered with the state from before the window opened, and the
workspace island lagged one step behind reality. Prefer the typed live model
(`workspace.toplevels`, an ObjectModel) whenever the value has to react.

**`HyprlandFocusGrab` already gives its window the keyboard — do not add a
second surface to catch keys.** Read this before touching panel dismissal.
`Escape` on the dashboard took three attempts, and the first two each broke it
worse:

1. Added `PanelKeys`, a surface that takes `Exclusive` keyboard focus while a
   panel is open. The dashboard flashed open and closed instantly. Cause: the
   notch runs a `HyprlandFocusGrab` while the dashboard is up — that is what
   dismisses it on a click elsewhere — and a grab clears on a focus change to
   **any** surface outside its window list, including one of the shell's own.
2. Whitelisted `PanelKeys` in that grab and kept it permanently mapped to avoid
   racing the grab's surface-list commit. The dashboard then did not open at
   all. Root cause not established.

Both were reverted. What resolved it was one observation from the VM that no
amount of reading could replace: *the dashboard already captured the keyboard —
you could not type into the terminal behind it.* The grab was routing keys to
the bar the whole time. They were arriving and being **dropped**, because a QML
window delivers key events to whichever item holds active focus, and nothing in
the bar had ever asked for it. The fix is a zero-size `Item { focus: true }`
inside the bar window with a `Keys.onEscapePressed`, and `forceActiveFocus()`
when the panel opens. No new surface, nothing for the grab to fight.

Two lessons, both expensive:

- **Two mechanisms that both move focus will fight, and the symptom lands on the
  feature that was already working.** Neither failure was visible in review.
- **Getting the keyboard to a surface and getting it to an item are different
  problems.** I spent two attempts on the first while the second was the one
  that was broken. "It captures the keyboard but the key does nothing" is the
  symptom that separates them — ask for it before building anything.

**Nerd Font glyphs vanish in transit, and nothing complains.** They live in the
Unicode private use area. A terminal renders them as nothing, `cat` and the file
viewer show nothing, and a heredoc or a rewriting tool can drop them silently —
so `text: ""` and `text: ""` are indistinguishable everywhere except in the
running shell. The OSD, the notch, the dashboard and the toast all shipped with
**23 empty icon slots** this way, and reading the diff could not find it.

Three consequences, all load-bearing:

- **Write glyphs from their codepoint**, never by pasting the character:
  `new = old.replace('""', '"' + chr(0xf048) + '"')`. A pasted anchor matches
  zero times and the edit reports success.
- **Inspect with `repr`**, not by eye:
  `line.encode('unicode_escape')`. A scan that reads terminal output will call
  a correct file broken and a broken file correct — both happened here, in that
  order.
- **A deliberate blank is a named property** (`root.noGlyph`), so `check.sh`
  can tell intent from loss. The lint flags a bare `text: ""`, a ternary with
  two empty branches, and an empty entry in a `*Glyphs` map.

**When a fetched doc example contradicts working code, trust the code.** A
`PwObjectTracker` example returned `target:`; the real property is `objects:`,
and the shipped code was already right. Fetched prose is a summary and can
paraphrase wrongly — the dedicated type page is the authority.

### Theming

**A terminal palette can be generated correctly and still be unreadable.** Two
mistakes shipped together in `kitty-colors.conf`, and neither is visible in a
diff — only in a `fastfetch` palette strip:

- **Duplicates.** Six of the sixteen ANSI colours were byte-identical to three
  others: green and magenta both `tertiary`, yellow and cyan both `secondary`,
  red and bright red both `error`. No generator setting can separate colours
  that are the same value.
- **Bright colours on container roles.** In a dark scheme `X_container` is a
  *dark* tone meant to sit behind text. The light counterpart is
  `on_X_container`. Using the wrong one made the bright half of the palette
  read as mud.

Material 3 has only **four hue families** — primary, secondary, tertiary,
error — and ANSI wants six, so two of them must be tonal variants unless
`[config.custom_colors]` is used. `check.sh`'s **ansi** section now rejects both
shapes; note its container rule must exclude the `on_` prefix, or it flags the
correct mapping.

How distinct the palette is overall is `theme.style` (matugen `--type`) and
`theme.contrast`, both in `settings.json` — see DESIGN.md §4. This desktop uses
**`scheme-expressive`**, chosen by comparing them on the real palette. Matugen's
own default, `scheme-tonal-spot`, is deliberately muted; that is a Material
decision rather than a bug, so do not "fix" it by changing the template.

**Contrast against an opaque role is not the contrast you get.** Nothing in this
shell is opaque: the island is `surfaceContainer` at 0.72 and the panels are
`surfaceContainerLow` at 0.86, both composited over a blurred wallpaper. A
palette can clear 4.5:1 against the flat role and still be unreadable once a
third of the picture shows through. `check.sh`'s `colour` section now composites
over a black and a white wallpaper and gates the worse one at 3:1 — WCAG's
floor for large text, not 4.5, because a translucent surface cannot reach 4.5
against both extremes and a check that can never pass is worthless. It reads
the alphas out of `Theme.qml` rather than repeating them, so changing one in the
shell cannot leave the check testing the old number.

**Contrast is direction-blind, and that hid a whole bug class.** A *light*
palette rendered while `theme.scheme` says `dark` passes every contrast pair —
black on white is 21:1 — and produces black text on islands that are still
translucent over a dark wallpaper. The `colour` section now compares the
polarity it got against the one `settings.json` asked for, and rejects a value
that is not `#rrggbb` at all: an unsubstituted `{{colors.x.default.hex}}` is
valid JSON, survives every role-based check, and renders in QML as **black**,
because an invalid colour string does not warn.

**`matugen image` aborts when it cannot ask a question.** An image with several
candidate source colours makes it prompt — and when the shell launched it there
is no terminal, so it exits with *"Multiple source colors found, no preference
was inputted, and a terminal was not detected"*. Run by hand it works, which is
the worst version of this: it only fails from the picker, which is the only way
it is normally used. `--prefer` is mandatory for any non-interactive run. Its
values come from matugen's `SelectionPreference` enum — `darkness`, `lightness`,
`saturation`, `less-saturation`, `value`, `closest-to-fallback` — and live in
`settings.json` as `theme.prefer`. `matugen color hex` needs none of this: one
colour has nothing to choose between.

### Packages

**Verify names and repos against live APIs every time.** `swww` was specified
from memory and does not exist — not in the repos, not in the AUR. `nwg-look`
and `wl-clip-persist` were labelled AUR and are in `extra`. Check with
`pacman -Si <pkg>`, `archlinux.org/packages/search/json/?name=<pkg>`, or the AUR
RPC before writing a package list.

**Justify each package against this machine, not against a previous list.**
`pipewire-jack` was carried from v1, conflicts with the `jack2` CachyOS ships by
default, and is only needed for JACK pro-audio apps — none of which are
installed.

**`--noconfirm` answers N.** It declined pacman's offer to resolve a conflict and
then reported "unresolvable conflicts", which was false. Package installation is
interactive by default; `--yes` opts in. Auto-declining is the worst of the three
options because it produces a wrong diagnosis.

### Shell scripts

**`((n++))` evaluates to the OLD value, so it returns status 1 when `n` is 0.**
`ok() { ...; ((pass++)); }` therefore made `ok "x" && something` take the failure
branch, and `(( $? == 0 )) && ((pass++)) || ((fail++))` incremented *both*
counters. Use `n=$((n+1))`, which always returns 0.

**Derive the repo root, never hardcode it.** The fish aliases pointed at the dev
host's checkout and were broken on every other machine. Resolve it from the
symlink that placed the file: `~/.config/fish -> <repo>/config/fish`.

**`set -e` does not exit on a false `(( )) && cmd` list** — verified, so the
flag dispatch in `install.sh` is safe. Do not "fix" it.

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

Three more of the same shape, from this repo:

**A batch edit that finds nothing reports success.** Python's `str.replace` and
`sed` are silent on no-match. Five `Glyph` anchors were "fixed" by a replace that
matched zero times, and the claim was passed on as done. **Assert on every
edit** — that the old text was present, or that the resulting count is what you
expected. `install.sh`/`check.sh` patches in this repo all do.

**A check that has only ever returned green has not been tested.** Before
trusting any new check, inject the exact defect it exists to catch, confirm it
fails with a useful message, restore, and confirm it passes. Both of `check.sh`'s
static sections were verified this way — the config-key check against an injected
`dwindle.pseudotile` and a lookahead, the QML lint against the real
`font.pixelSize: 10.5` line that broke the shell.

**A scanner that reads its own documentation will flag it.** The RE2 lookahead
check fired on `rules.lua` because the comment there *quotes* a bad pattern to
explain the pitfall. Strip comments before scanning code for forbidden text.

**Bugs caused by an absent property are invisible in review.** Both of the
`Bar.qml` failures — `exclusionMode` defaulting to `Auto`, and a layer surface
that resizes — were about something not written down. Reading the diff cannot
find them. When a type has a default that changes behaviour (exclusion, focus,
stacking, sizing), set it explicitly even when the default happens to be right.

## Debugging what you cannot run

The workflow section says you cannot test any of this locally. That applies to
**diagnosis** as much as to building, and it is the harder half to remember: the
temptation is to substitute a protocol document for an observation. Fetched docs
describe what a mechanism is *for*. They do not tell you what your specific
composition of mechanisms is *doing*.

**The user at the VM is the instrument. Use them deliberately.**

Escape-closes-the-dashboard cost two broken builds and a revert because this
went wrong. Attempt 1 added a keyboard-catching surface; the dashboard flashed
open and closed. I inferred a cause and shipped attempt 2 without asking a
single question; the dashboard stopped opening at all. The reverting was right;
the guessing was not. What finally resolved it was one sentence the user
volunteered — *"the menu captures the keyboard, Escape just doesn't close it"* —
which said the keys were already reaching the surface and the bug was one layer
in. A question would have got that before attempt 1.

Four rules, in the order they would have helped:

**Inventory the mechanisms before adding one.** Grep the file you are about to
edit for whatever already touches the concern. `Notch.qml` held a
`HyprlandFocusGrab` doing the exact focus routing that was needed; it was found
*after* the replacement was already written and shipped. Ask "what already
handles this, and what is it already doing?" before "what should I add?".

**After ONE failed fix in the VM, stop shipping and ask.** Not "does it work
now" — a specific observation that discriminates between the hypotheses. The
second guess is not better informed than the first unless something was
measured in between.

**Ask for the symptom at the right granularity.** "Broken" is not a symptom.
These are all different bugs and they look identical in a bug report:

| Observation | What it rules out |
| --- | --- |
| Flashes open, then closes | It opened. Something *closed* it — look for a dismiss path, not a create path. |
| Never appears at all | Creation or visibility, not dismissal. |
| Appears, but a key does nothing | The surface has the input; routing *inside* the window is broken. |
| Appears, and the app behind still takes the key | The surface never got the input at all. |

The last two differ by one question — *can you still type into the window
behind it?* — and they have nothing in common as bugs.

**Never escalate complexity on an unverified hypothesis.** Attempt 2 was
strictly more elaborate than attempt 1 (always-mapped surface, grab whitelist,
a removed screen binding) and it was built on a cause nobody had confirmed. When
a fix fails, the next move is to *reduce and measure*, not to add. The fix that
worked was smaller than either attempt: no new surface at all.

**Revert to working first, then investigate.** Shipping the revert on its own,
with no speculative fix bundled in, was the one part of this that went right. A
broken desktop the user has to live with costs more than a round trip.

## User preferences

- **Flag guesses explicitly.** When something is inferred rather than verified,
  say so and say how to test it. This has been valued repeatedly.
- Wants the *mechanism*, not just the fix.
- Colour as signal, not decoration — the bar is neutral at rest and only
  colours what needs attention.
- No automatic wallpaper changes.
- Prefers official repos over AUR where there is a choice.
- Corrections plain and brief; no over-apologising, no re-litigating.
