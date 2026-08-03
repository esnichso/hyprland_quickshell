# Packages

What gets installed and why. Repo column matters: `extra` means it comes from
the Arch/CachyOS binary repos and updates like anything else; `AUR` means it
rebuilds locally and can break on a Qt or Hyprland bump.

**The headline:** both load-bearing new dependencies — `quickshell` and
`matugen` — are in `extra`. Nothing in the critical path is an AUR package.
This is a materially different situation from a year ago.

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
| `swww` | extra | Wallpaper daemon with a socket and transitions. Chosen over `hyprpaper` because the picker grid needs to set arbitrary images without preloading each one into VRAM first. |
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
| `nwg-look` | AUR | GTK settings GUI — only for one-off fixes, not in the pipeline |
| `papirus-icon-theme` | extra | Icon theme; recolourable to match |

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
| `wl-clip-persist` | AUR | Keeps clipboard contents after the source app closes |
| `wf-recorder` | extra | Screen recording |
| `hyprpicker` | extra | Colour picker |
| `playerctl` | extra | Media keys |
| `wev` | extra | Find out what a key actually is — needed for German-layout debugging |

## Applications

| Package | Repo | Why |
| --- | --- | --- |
| `kitty` | extra | Terminal. Chosen for its control socket — the theme pipeline pushes a new palette to every running instance live. |
| `fish` | extra | Shell |
| `starship` | extra | Prompt, themed from the palette |
| `thunar` `thunar-volman` `tumbler` `ffmpegthumbnailer` `gvfs` | extra | File manager and thumbnails |
| `udiskie` | extra | Automount removable media |
| `btop` | extra | The real system monitor for when the panel isn't enough |
| `fastfetch` | extra | Because you will screenshot this |
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
pacman -Si quickshell matugen hyprland swww | grep -E '^(Name|Version|Repository)'
```

If `hyprland` is below 0.55, the Lua config will not load and the whole
`config/hypr/` tree needs the hyprlang syntax instead. Check this first — it
is the one assumption that would invalidate a lot of work.
