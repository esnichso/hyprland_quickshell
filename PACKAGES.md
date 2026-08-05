# Packages

What gets installed and why. Repo column matters: `extra` means it comes from
the Arch/CachyOS binary repos and updates like anything else; `AUR` means it
rebuilds locally and can break on a Qt or Hyprland bump.

**The headline:** both load-bearing new dependencies — `quickshell` and
`matugen` — are in `extra`. Exactly one AUR package is installed
(`zen-browser-bin`), and it is a browser, not part of the session.

Every name and repo below was verified against the live Arch and AUR APIs on
2026-08-03, not from memory. That check found two mislabels and one package
that does not exist at all — see `hyprpaper` below.

---

## Core session

| Package | Repo | Why |
| --- | --- | --- |
| `hyprland` | extra | The compositor. **Needs ≥ 0.55** for the Lua config (`hl.*`). Verify before anything else. |
| `uwsm` | extra | Universal Wayland session manager — puts each app in its own systemd scope so a crashing app can't take the session with it |
| `xdg-desktop-portal-hyprland` | extra | Screen sharing, screenshots, file pickers |
| `xdg-desktop-portal-gtk` | extra | The fallback portal — file dialogs for GTK apps |
| `qt6-wayland` | extra | Native Wayland for Qt apps, including QuickShell |
| `polkit` + `hyprpolkitagent` | extra | Privilege prompts. `Quickshell.Services.Polkit` could replace this in Phase 5. |
| `xorg-xwayland` | extra | For the X11 apps you still run |
| `pipewire` `pipewire-alsa` `pipewire-pulse` `pipewire-jack` `wireplumber` | extra | Audio. QuickShell talks to PipeWire directly for the audio panel. |
| `sddm` | extra | Login screen |
| `gnome-keyring` `libsecret` | extra | Secret storage — Chrome, VS Code and Signal all want it |
| `xdg-user-dirs` | extra | `~/Dokumente`, `~/Bilder` etc. — already German on your Ubuntu install |

## The shell

| Package | Repo | Why |
| --- | --- | --- |
| **`quickshell`** | **extra** | The whole desktop shell. 0.3.0. Ships native Networking, Bluetooth, Pipewire, UPower, Mpris, Notifications, SystemTray, DBusMenu, Pam and Polkit modules — which is why the control centre doesn't need CLI scraping. |
| `hyprlock` | extra | Lock screen. Stays out of QuickShell deliberately (FEATURES §9). |
| `hypridle` | extra | Idle ladder — dim, off, lock, suspend |
| `hyprshutdown` | extra | Graceful app exit before reboot/shutdown. **Not a menu** — the power menu calls it with `--post-cmd`. |
| `hyprpaper` | extra | Wallpaper daemon, driven over `hyprctl hyprpaper wallpaper '<mon>,<path>,<fit>'`. **`swww` was specified here first and does not exist** — it is in neither the official repos nor the AUR. Current hyprpaper no longer needs `preload`, which was the only reason to prefer swww. Cost: no transitions. |
| `hyprsunset` | extra | Night light, driven from the control centre |

**Deliberately not installed:** `waybar`, `rofi`, `swaync`, `dunst`, `mako`,
`swayosd`, `wofi`, `blueman`, `pavucontrol`, `network-manager-applet`.
QuickShell replaces all of them. Two notification daemons on the same D-Bus
name is a coin flip at login — `check.sh` fails if any of these are present.

## Theming

| Package | Repo | Why |
| --- | --- | --- |
| **`matugen`** | **extra** | Material 3 palette generation from an image or a seed colour, with a template engine. The whole colour pipeline (DESIGN §4). |
| `qt6ct` | extra | Applies the generated palette to Qt apps |
| `nwg-look` | extra | GTK settings GUI — only for one-off fixes, not in the pipeline |
| `papirus-icon-theme` | extra | Icon theme; recolourable to match |
| `gnome-themes-extra` | extra | Provides `/usr/share/themes/Adwaita-dark`, which `gtk-3.0/settings.ini` names. GTK3 has only plain **Adwaita** compiled in — without this, GTK silently falls back to it, still honours `prefer-dark`, and hands you a desktop that looks *almost* right. `check.sh`'s `desktop theming` section fails on it. |

**Qt theming has a hole, on purpose.** `qt6ct` covers plain Qt apps, but KDE
Frameworks apps build their palette from `KColorScheme`, which reads
`~/.config/kdeglobals` and bypasses the Qt platform theme entirely. There is no
kdeglobals matugen target, so a KDE app is unthemed. Nothing in this desktop is
a KDE app today; `check.sh` reports it as a **skip** with that reason rather
than a failure, because a check that can never pass is worthless. Adding it
means adding a template, never a second mechanism.

## Hardware — Intel Arrow Lake / ThinkPad E16 Gen 3

| Package | Repo | Why |
| --- | --- | --- |
| `mesa` `vulkan-intel` | extra | Graphics for the Arc iGPU |
| `intel-media-driver` | extra | VA-API hardware video decode — matters for battery on video calls |
| `libva-utils` | extra | `vainfo`, to verify the above actually works |
| `sof-firmware` | extra | Audio firmware. Without it there is no sound at all on this generation. |
| `brightnessctl` | extra | Screen and keyboard backlight setter |
| `power-profiles-daemon` | extra | Performance / balanced / saver, exposed in the control centre |
| `upower` | extra | Battery data for the shell |
| `networkmanager` | extra | Networking. QuickShell drives it over D-Bus. |
| `bluez` `bluez-utils` | extra | Bluetooth stack |
| `fprintd` | extra | Fingerprint reader. **Support on the E16 Gen 3 is unverified** — Phase 3 metal task. |
| `thermald` | extra | Intel thermal management |

## Utilities bound to keys

| Package | Repo | Bound to |
| --- | --- | --- |
| `grim` `slurp` | extra | Screenshot capture and region select |
| `satty` | extra | Screenshot annotation |
| `wl-clipboard` | extra | `wl-copy` / `wl-paste` |
| `cliphist` | extra | Clipboard history store, read by the launcher |
| `wl-clip-persist` | extra | Keeps clipboard contents after the source app closes |
| `unicode-emoji` | extra | `emoji-test.txt` — the launcher's `:` mode reads it directly rather than shipping a generated blob |
| `wf-recorder` | extra | Screen recording |
| `hyprpicker` | extra | Colour picker |
| `playerctl` | extra | Media keys |
| `wev` | extra | Find out what a key actually is — needed for German-layout debugging |

## Applications

| Package | Repo | Why |
| --- | --- | --- |
| `kitty` | extra | Terminal. Chosen for its control socket — the theme pipeline pushes a new palette to every running instance live. |
| `zen-browser-bin` | AUR | Browser, bound to `SUPER+B`. Firefox-based; the sidebar tab strip suits a tiling WM. The only AUR package here. |

### Why Zen from the AUR and not Flatpak

Zen is in neither `extra` nor the CachyOS repos — verified against the live API,
not assumed — so the real choice is `zen-browser-bin` (AUR) or
`app.zen_browser.zen` (Flathub). The AUR package wins here for reasons specific
to *this* repo, not general taste:

- **`-bin` does not build.** The usual AUR objection is rebuild time on every
  update; this package unpacks an official upstream tarball, so an update is a
  download, not a compile. The objection does not apply.
- **Flatpak cannot see the theme.** A sandboxed app does not read
  `~/.config/gtk-3.0`, and the GTK theme, the icon theme and the cursor theme
  all have to be re-provided inside the sandbox — as runtime extensions plus
  `flatpak override --filesystem=` lines. That is a **second theming mechanism**,
  which is the one structural rule this repo does not bend (CLAUDE.md,
  "Colour has exactly one code path"). Its cursor and font sizes would drift
  from the rest of the desktop and nothing would report it.
- **The env vars in `conf/env.lua` do not reach it.** `MOZ_ENABLE_WAYLAND=1` and
  `LIBVA_DRIVER_NAME=iHD` are exported by Hyprland to its children; a Flatpak
  gets the runtime's environment instead. On this machine that specifically
  costs Intel Arc hardware video decode, which `env.lua` calls out as a battery
  issue on video calls.
- **Native messaging and file access** go through portals, so KeePassXC-style
  integrations and "open with" need per-app overrides.

Flatpak is the better answer when the app is not packaged, needs a different
runtime than the system, or you want it sandboxed on purpose. None of those is
true here.
| `fish` | extra | Shell |
| `starship` | extra | Prompt, themed from the palette |
| `nautilus` `ffmpegthumbnailer` `gvfs` | extra | File manager and thumbnails. **Nautilus rather than Thunar** because it is GTK4/libadwaita and `gtk-colors.css` defines libadwaita's named colours — so it takes the generated palette directly, where a GTK3 file manager only gets whatever the GTK3 sheet carries. `tumbler` and `thunar-volman` left with Thunar: XFCE services Nautilus does not use. |
| `udiskie` | extra | Automount removable media |
| `btop` | extra | The real system monitor for when the panel isn't enough |
| `fastfetch` | extra | Because you will screenshot this. Configured in `config/fastfetch/config.jsonc`; it takes its colours from the **terminal's ANSI palette**, which the kitty template already generates, so it needs no matugen target of its own. Its `theme` / `icons` / `font` / `cursor` modules read the live GTK settings, which makes it a one-command answer to "did GTK theming apply?". |
| `mpv` `imv` | extra | Video and image viewers |

## Shell tooling

Each replaces something already installed with a better version. `config.fish`
wires them up and degrades gracefully if any are missing.

| Package | Repo | Replaces |
| --- | --- | --- |
| `fzf` | extra | `Ctrl+R` history search |
| `zoxide` | extra | `cd` |
| `eza` | extra | `ls` |
| `bat` | extra | `cat` |
| `fd` | extra | `find` |
| `ripgrep` | extra | `grep` |

## Fonts

| Package | Repo | Used for |
| --- | --- | --- |
| `inter-font` | extra | All UI text (DESIGN §5) |
| `ttf-jetbrains-mono-nerd` | extra | Terminal, code, system monitor |
| `ttf-nerd-fonts-symbols` | extra | Icon glyphs in the bar |
| `noto-fonts` `noto-fonts-cjk` `noto-fonts-emoji` | extra | Coverage and emoji |

---

## Install shape

Two scripts. Not ten.

```
install/
  install.sh    packages → symlinks → services → theme → done
  check.sh      is this system actually correct?
```

`install.sh` is idempotent and takes flags rather than spawning siblings:

```bash
./install/install.sh              # everything
./install/install.sh --packages   # packages only
./install/install.sh --link       # symlinks only
./install/install.sh --theme      # regenerate the palette
```

`check.sh` validates the **running system**, not the files — the distinction
that made v1's `doctor.sh` worth having:

- Hyprland version ≥ 0.55 and the Lua config actually loaded
- Exactly one notification daemon owns `org.freedesktop.Notifications`
- None of the replaced packages are installed
- QuickShell is running and its log has no QML errors
- Every keybind in KEYBINDS.md exists in `hyprctl binds`, and vice versa
- Every colour role resolves and clears 4.5:1 contrast
- Portals respond; `vainfo` reports hardware decode
- Battery, backlight and kbd-backlight sysfs paths exist and are writable

---

## Verify before trusting this list

Package names and versions drift. Before Phase 1:

```bash
pacman -Si quickshell matugen hyprland hyprpaper | grep -E '^(Name|Version|Repository)'
```

If `hyprland` is below 0.55, the Lua config will not load and the whole
`config/hypr/` tree needs the hyprlang syntax instead. Check this first — it
is the one assumption that would invalidate a lot of work.
