#!/usr/bin/env bash
# hypersetup2 installer.
#
# One script, flags instead of siblings. Idempotent: safe to re-run, and
# re-running is the normal way to pick up a new config directory after a pull.
#
#   ./install/install.sh              everything
#   ./install/install.sh --packages   packages only
#   ./install/install.sh --link       symlinks only
#   ./install/install.sh --services   enable system/user services
#   ./install/install.sh --theme      regenerate the palette
#   ./install/install.sh --theme <name|/path/to/wallpaper.jpg>
#   ./install/install.sh --wallpaper <path>   set it WITHOUT retheming
#   ./install/install.sh --yes        never prompt (answers yes, not no)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STAMP="$(date +%Y%m%d-%H%M%S)"
PACMAN_CONFIRM=""          # set to --noconfirm by --yes
BACKUP="$HOME/.config-backup-$STAMP"

c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_dim=$'\e[2m'; c_off=$'\e[0m'
ok()   { printf '%s  ok %s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s  !! %s %s\n' "$c_warn" "$c_off" "$*"; }
die()  { printf '%s  XX %s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }
step() { printf '\n%s== %s ==%s\n' "$c_dim" "$*" "$c_off"; }

# ---------------------------------------------------------------- preflight

preflight() {
    step "preflight"

    command -v pacman >/dev/null || die "no pacman — this is an Arch/CachyOS installer"

    # The one assumption that would invalidate the whole config/hypr tree.
    # Hyprland 0.55 replaced hyprlang with Lua; below that, nothing here loads.
    if command -v hyprctl >/dev/null; then
        local v
        v="$(hyprctl version 2>/dev/null | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
        if [[ -n "$v" ]]; then
            local maj min
            maj="${v%%.*}"; min="$(echo "$v" | cut -d. -f2)"
            if (( maj == 0 && min < 55 )); then
                die "hyprland $v is too old — the Lua config needs >= 0.55"
            fi
            ok "hyprland $v"
        fi
    fi

    # CachyOS ships repos per x86-64 microarchitecture level. v4 requires
    # AVX-512, which Arrow Lake does not have (Intel dropped it from consumer
    # P+E designs). Running v4 binaries without it is SIGILL on first use.
    #
    # Ask the dynamic loader what the CPU actually supports rather than
    # inferring from one flag — in a VM the answer depends on the QEMU CPU
    # model, and the default qemu64 model supports only x86-64-v1.
    # The loader prints, e.g.:
    #   x86-64-v4
    #   x86-64-v3 (supported, searched)
    # Note the marker is "(supported, searched)" — matching on "(supported)"
    # alone finds nothing and silently skips this whole check.
    local isa="" ld=""
    for c in /lib64/ld-linux-x86-64.so.2 /lib/ld-linux-x86-64.so.2 \
             /usr/lib/ld-linux-x86-64.so.2; do
        [[ -x "$c" ]] && { ld="$c"; break; }
    done
    if [[ -n "$ld" ]]; then
        isa="$("$ld" --help 2>/dev/null \
               | grep -oE 'x86-64-v[0-9] \(supported' \
               | grep -oE 'v[0-9]' | sort -u | tail -1)"
    fi
    [[ -n "$isa" ]] && ok "CPU supports up to x86-64-$isa"

    # Match every v4 section: [cachyos-v4], [cachyos-core-v4], [cachyos-extra-v4].
    local v4
    v4="$(grep -hoE '^\[cachyos[a-z-]*-v4\]' /etc/pacman.conf 2>/dev/null | tr -d '[]' | paste -sd' ' || true)"

    if [[ -n "$v4" ]] && [[ "$isa" != "v4" ]]; then
        die "v4 repos enabled ($v4) but this CPU tops out at x86-64-${isa:-?}.
     Fix:  curl -O https://mirror.cachyos.org/cachyos-repo.tar.xz
           tar xf cachyos-repo.tar.xz && cd cachyos-repo && sudo ./cachyos-repo.sh
           sudo pacman -Syyuu
     The script re-detects the ISA level and rewrites /etc/pacman.conf."
    elif [[ -n "$v4" ]]; then
        ok "v4 repos enabled and the CPU supports x86-64-v4"
    else
        ok "no v4 repos enabled"
    fi
}

# ---------------------------------------------------------------- packages

do_packages() {
    step "packages"

    local list=()
    while IFS= read -r line; do
        line="${line%%#*}"; line="${line// /}"
        [[ -n "$line" ]] && list+=("$line")
    done < "$REPO/install/packages.txt"

    ok "${#list[@]} packages from the official repos"

    # Interactive by default. --noconfirm answers N to every question,
    # including "package X conflicts with Y, remove Y?" -- which turns a
    # resolvable prompt into "Nicht auflösbare Paketkonflikte gefunden" and
    # aborts the whole install. A conflict is a decision for you to make, not
    # one to auto-decline. Pass --yes if you want it unattended anyway.
    sudo pacman -S --needed $PACMAN_CONFIRM "${list[@]}"

    # Anything QuickShell replaces must not be installed. Two daemons owning
    # org.freedesktop.Notifications is a coin flip at login, and a stray waybar
    # autostart is a confusing thing to debug.
    local conflicts=(waybar rofi rofi-wayland swaync dunst mako swayosd wofi blueman pavucontrol network-manager-applet)
    local found=()
    for p in "${conflicts[@]}"; do
        pacman -Qq "$p" &>/dev/null && found+=("$p")
    done
    if (( ${#found[@]} )); then
        warn "these are replaced by the shell and should be removed: ${found[*]}"
        warn "  sudo pacman -Rns ${found[*]}"
    fi

    # AUR. No helper is installed automatically — that is a choice the user
    # should make, not something an install script does behind their back.
    local aur=()
    while IFS= read -r line; do
        line="${line%%#*}"; line="${line// /}"
        [[ -n "$line" ]] && aur+=("$line")
    done < "$REPO/install/packages-aur.txt"

    if (( ${#aur[@]} )); then
        local helper=""
        for h in paru yay; do command -v "$h" >/dev/null && { helper="$h"; break; }; done
        if [[ -n "$helper" ]]; then
            "$helper" -S --needed $PACMAN_CONFIRM "${aur[@]}"
        else
            warn "no AUR helper (paru/yay) — install manually: ${aur[*]}"
        fi
    fi
}

# ---------------------------------------------------------------- symlinks

link_one() {
    local src="$1" dst="$2"

    # Already correct.
    [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]] && return 0

    if [[ -e "$dst" || -L "$dst" ]]; then
        mkdir -p "$BACKUP"
        mv "$dst" "$BACKUP/"
        warn "backed up $(basename "$dst") -> $BACKUP/"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "$(basename "$dst")"
}

do_link() {
    step "symlinks"

    mkdir -p "$CONFIG_HOME" "$STATE_HOME/quickshell" "$HOME/Bilder/screenshots" "$HOME/Bilder/walls"

    # Everything directly under config/ maps to ~/.config/<name>.
    for entry in "$REPO"/config/*; do
        link_one "$entry" "$CONFIG_HOME/$(basename "$entry")"
    done

    ok "re-run --link after any pull that adds a config directory"
}

# ---------------------------------------------------------------- services

do_services() {
    step "services"

    enable_system() {
        if sudo systemctl enable --now "$1" >/dev/null 2>&1; then ok "$1"
        else warn "could not enable $1"; fi
    }
    enable_system NetworkManager.service
    enable_system bluetooth.service
    enable_system power-profiles-daemon.service
    enable_system thermald.service

    # sddm is enabled but NOT started — starting it from inside a running
    # session kills the session you are typing in.
    if sudo systemctl enable sddm.service >/dev/null 2>&1; then ok "sddm (enabled, not started)"
    else warn "could not enable sddm"; fi

    if systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service >/dev/null 2>&1
    then ok "pipewire + wireplumber"
    else warn "could not enable pipewire user services"; fi

    # fish as the login shell, only if it is not already.
    if [[ "$SHELL" != *fish ]] && command -v fish >/dev/null; then
        warn "login shell is $SHELL; to switch:  chsh -s $(command -v fish)"
    fi
}

# ---------------------------------------------------------------- theme

do_theme() {
    step "theme"

    command -v matugen >/dev/null || die "matugen not installed"

    local arg="${1:-}"
    local mode scheme prefer
    mode="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme mode || echo wallpaper)"
    scheme="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme scheme || echo dark)"

    # matugen ABORTS on an image with several candidate source colours unless it
    # can ask, and it cannot ask when the shell launched it — "Multiple source
    # colors found, no preference was inputted, and a terminal was not
    # detected". Interactive from a terminal it prompts, so this only fails when
    # driven from the picker, which is the normal case.
    #
    # Valid values, from matugen's SelectionPreference enum: darkness,
    # lightness, saturation, less-saturation, value, closest-to-fallback.
    prefer="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme prefer || echo saturation)"

    # The two tuning knobs, both matugen CLI flags:
    #   --type      which scheme algorithm spreads the palette. The default,
    #               scheme-tonal-spot, is deliberately muted; scheme-vibrant
    #               and scheme-expressive separate the hues much further.
    #   --contrast  -1..1, 0 being the Material spec.
    # Built once into an array so image and hex generation cannot drift apart.
    local style contrast
    style="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme style || echo scheme-tonal-spot)"
    contrast="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme contrast || echo 0)"
    local tune=(--type "$style" --contrast "$contrast")

    local source_desc
    if [[ -n "$arg" && -f "$arg" ]]; then
        # An explicit image: switch to wallpaper mode and remember it.
        matugen image "$arg" --mode "$scheme" --prefer "$prefer" "${tune[@]}"
        echo "$arg" > "$STATE_HOME/quickshell/wallpaper"
        source_desc="wallpaper $(basename "$arg")"
        set_wallpaper "$arg"

    elif [[ -n "$arg" && -f "$REPO/themes/$arg.toml" ]]; then
        local seed
        seed="$(grep -oP '^seed\s*=\s*"\K[^"]+' "$REPO/themes/$arg.toml")"
        matugen color hex "$seed" --mode "$scheme" "${tune[@]}"
        source_desc="theme $arg (seed $seed)"

    elif [[ "$mode" == "manual" ]]; then
        local name seed
        name="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme manual || echo catppuccin-mocha)"
        [[ -f "$REPO/themes/$name.toml" ]] || die "no such theme: $name"
        seed="$(grep -oP '^seed\s*=\s*"\K[^"]+' "$REPO/themes/$name.toml")"
        matugen color hex "$seed" --mode "$scheme" "${tune[@]}"
        source_desc="theme $name (seed $seed)"

    else
        local wall
        wall="$(cat "$STATE_HOME/quickshell/wallpaper" 2>/dev/null || true)"
        if [[ -n "$wall" && -f "$wall" ]]; then
            matugen image "$wall" --mode "$scheme" --prefer "$prefer" "${tune[@]}"
            source_desc="wallpaper $(basename "$wall")"
            set_wallpaper "$wall"
        else
            # No wallpaper chosen yet. Fall back to the manual seed rather than
            # leaving the shell with no colors.json at all.
            local seed
            seed="$(grep -oP '^seed\s*=\s*"\K[^"]+' "$REPO/themes/catppuccin-mocha.toml")"
            matugen color hex "$seed" --mode "$scheme" "${tune[@]}"
            source_desc="fallback seed $seed (no wallpaper set)"
        fi
    fi

    ok "$source_desc, $scheme"

    # Push the new palette to every running kitty. Without this, open terminals
    # keep the old colours until they are restarted.
    if command -v kitty >/dev/null && [[ -e "$CONFIG_HOME/kitty/colors.conf" ]]; then
        kitty @ --to unix:@mykitty set-colors --all --configured \
            "$CONFIG_HOME/kitty/colors.conf" >/dev/null 2>&1 \
            && ok "pushed to running kitty" || true
    fi

    # Hyprland re-reads conf/colors.lua on reload; border gradients update live.
    command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 && ok "hyprctl reload"
}

set_wallpaper() {
    command -v hyprctl >/dev/null || return 0
    pgrep -x hyprpaper >/dev/null || return 0
    local fit
    fit="$(json_get "$CONFIG_HOME/quickshell/settings.json" wallpaper fit || echo cover)"
    # Empty monitor = fallback for every output.
    hyprctl hyprpaper wallpaper ",$1,$fit" >/dev/null 2>&1 || true
}

# Set the wallpaper and remember it, WITHOUT touching the palette.
#
# This is what "pick a theme" mode needs: in that mode changing wallpaper must
# not re-theme the desktop, which is the whole point of the setting. do_theme
# with an image argument always runs matugen, so it is the wrong entry point.
do_wallpaper() {
    step "wallpaper"
    local img="${1:-}"
    [[ -n "$img" ]] || die "--wallpaper needs a path"
    [[ -f "$img" ]] || die "no such file: $img"

    mkdir -p "$STATE_HOME/quickshell"
    printf '%s\n' "$img" > "$STATE_HOME/quickshell/wallpaper"
    set_wallpaper "$img"
    ok "$(basename "$img")"
}

# Minimal nested-key reader. python3 is a hard dependency of pacman, so it is
# always present; jq is not.
json_get() {
    python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    for k in sys.argv[2:]: d=d[k]
    print(d)
except Exception:
    sys.exit(1)
" "$@" 2>/dev/null
}

# ---------------------------------------------------------------- main

main() {
    local do_all=1 pkgs=0 link=0 svc=0 theme=0 theme_arg="" wall=0 wall_arg=""

    while (( $# )); do
        case "$1" in
            --packages) do_all=0; pkgs=1 ;;
            --link)     do_all=0; link=1 ;;
            --services) do_all=0; svc=1 ;;
            --theme)    do_all=0; theme=1
                        [[ ${2:-} && ${2:-} != --* ]] && { theme_arg="$2"; shift; } ;;
            --wallpaper) do_all=0
                        [[ ${2:-} && ${2:-} != --* ]] && { wall=1; wall_arg="$2"; shift; } \
                            || die "--wallpaper needs a path" ;;
            --yes|-y)   PACMAN_CONFIRM="--noconfirm" ;;
            -h|--help)  sed -n '2,13p' "$0"; exit 0 ;;
            *)          die "unknown flag: $1" ;;
        esac
        shift
    done

    preflight
    (( do_all || pkgs ))  && do_packages
    (( do_all || link ))  && do_link
    (( do_all || svc ))   && do_services
    (( wall ))            && do_wallpaper "$wall_arg"
    (( do_all || theme )) && do_theme "$theme_arg"

    step "done"
    if (( do_all )); then
        cat <<'EOF'
  Next:
    1. chsh -s /usr/bin/fish        if you want fish as the login shell
    2. log out, pick Hyprland in SDDM, log back in
    3. ./install/check.sh           validates the RUNNING session

  Autostart only fires on login. `hyprctl reload` will not start the shell.
EOF
    fi
}

main "$@"
