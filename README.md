# hypersetup2

A hand-written Hyprland desktop for CachyOS on a ThinkPad E16 Gen 3, with the
entire shell layer written in QuickShell.

Three floating islands on the top edge. The middle one is a notch: a clock
that morphs into notifications, OSDs and panels, and collapses back. Colour
comes either from the wallpaper or from a theme you pick — your choice, at
runtime.

**Status: Phase 1 built, untested.** The compositor config, the install and
check scripts, the theming pipeline and a minimal bar exist. None of it has
ever run — it was written on an Ubuntu host where Hyprland and QuickShell
cannot be installed. The first CachyOS VM boot is the first execution.

What works on paper and needs proving: session starts, bar draws three islands,
clock ticks, workspaces respond, battery reads. What is deliberately absent:
the notch's OSD/toast/dashboard content, and every panel. Those are Phase 2.

---

## Where to start

| File | What it is |
| --- | --- |
| [DESIGN.md](DESIGN.md) | Look, feel, motion, colour, geometry. Every number is a decision. |
| [FEATURES.md](FEATURES.md) | Every surface the shell draws, spec'd against real QuickShell modules. |
| [KEYBINDS.md](KEYBINDS.md) | The full map, chosen for a German QWERTZ ThinkPad with no Print key. |
| [PACKAGES.md](PACKAGES.md) | What gets installed, why, and which repo it comes from. |
| [ROADMAP.md](ROADMAP.md) | Phases, VM → metal, and the list of things a VM cannot test. |
| `docs/hyprland/` | Snapshot of the official wiki, including the Lua config reference. |

---

## The decisions, in one place

| | |
| --- | --- |
| Distro | CachyOS |
| Compositor | Hyprland ≥ 0.55, configured in **Lua** (`hl.*` API) |
| Layout | Dwindle, with tabbed groups on `SUPER+G` |
| Shell | **QuickShell 0.3.0** — bar, notch, notifications, OSD, launcher, control centre, power menu, system monitor, wallpaper picker |
| Bar | Three floating islands; centre island is the notch |
| Interaction | Click to open, keybind for everything. Hover shows a tooltip only. |
| Colour | matugen, dual mode: **from wallpaper** or **pick a theme** |
| Config | `settings.json` with live reload — QML holds no magic numbers |
| Terminal / shell | kitty + fish + starship |
| Lock / idle | hyprlock + hypridle (deliberately *not* QuickShell) |
| Wallpaper | hyprpaper, driven from a QuickShell picker over `hyprctl` |
| Scripts | Exactly two: `install.sh`, `check.sh` |

---

## Relationship to v1

[`../hypersetup`](../hypersetup) is a complete, working Hyprland setup for the
same machine using waybar + rofi + swaync. **This is a restart, not a fork.**
Nothing is imported. v1 stays intact as a reference for decisions that were
already litigated there — the German-layout keybind problems, the kitty
opacity mistake, the smart-gaps removal, `hyprshutdown` not being a menu — and
those conclusions are folded into the documents here rather than rediscovered.

What v1 got right and is preserved as an *idea*, not as code:

- One palette source rendering every config, instead of hex literals in 13 files
- A checker that validates the running session rather than the files on disk
- Comments that explain why, so the config can be maintained rather than copied

What changes:

- One shell process instead of four programs that each need separate theming
- A real control centre instead of launching `nmtui` in a floating window
- Two scripts instead of seven

---

## Planned layout

```
hypersetup2/
├── config/
│   ├── hypr/
│   │   ├── hyprland.lua          entry point
│   │   ├── conf/                 monitors, input, looks, binds, rules, autostart
│   │   ├── hyprlock.conf         hyprlang — generated colours
│   │   └── hypridle.conf         hyprlang — the idle ladder
│   ├── quickshell/
│   │   ├── shell.qml             root
│   │   ├── settings.json         every tunable, live-reloaded
│   │   ├── Config.qml            singleton over settings.json
│   │   ├── Theme.qml             singleton over colors.json
│   │   ├── bar/                  Bar, WorkspaceIsland, Notch, StatusIsland
│   │   ├── panels/               Dashboard, ControlCenter, Launcher,
│   │   │                         PowerMenu, SysMon, WallpaperPicker
│   │   ├── services/             thin wrappers over the Quickshell modules
│   │   └── widgets/              IslandSurface, Pill, Slider, Toggle, Tooltip
│   ├── matugen/
│   │   ├── config.toml           the seven output targets
│   │   └── templates/            one per target
│   ├── kitty/  fish/  starship.toml
│   ├── gtk-3.0/  gtk-4.0/  qt6ct/
│   └── uwsm/env
├── themes/                       seed + role overrides, one TOML per theme
├── install/
│   ├── install.sh                packages → links → services → theme
│   └── check.sh                  validates the running session
└── docs/hyprland/                wiki snapshot
```

---

## Two things worth knowing before starting

**Hyprland 0.55 deprecated hyprlang in favour of Lua.** Everything in
`config/hypr/` is a real Lua file using the typed `hl` API — `hl.bind(...)`,
`hl.config{...}`, `hl.dsp.*`. Verify the packaged version is ≥ 0.55 before
writing any of it; below that, the syntax is entirely different.

**QuickShell 0.3.0 has native Networking and Bluetooth modules.** The control
centre binds to NetworkManager and BlueZ over D-Bus rather than polling
`nmcli` and parsing text. This is what makes a real control centre — with
password entry, per-app volume and device battery levels — a reasonable thing
to build rather than a heroic one.
