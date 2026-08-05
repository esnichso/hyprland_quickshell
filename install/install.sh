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
#   ./install/install.sh --sddm       install the login screen (needs sudo)
#   ./install/install.sh --yes        never prompt (answers yes, not no)
#
# --sddm is separate from --theme because SDDM's theme lives in /usr/share and
# needs a password to update; --theme has to stay runnable from the picker,
# which has no terminal to type one into. Re-run --sddm after a theme change.

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

    # -Syu, NOT -S. This is Arch's documented way to install a package, and the
    # reason is not tidiness: `pacman -S` resolves against the LOCAL sync
    # database, and a mirror only keeps the current build of each package. Once
    # the db is a few days old, pacman asks for a filename that no longer exists
    # anywhere and every mirror answers 404 —
    #
    #   Fehler: Konnte Datei 'gexiv2-0.16.1-1.1-x86_64_v3.pkg.tar.zst' nicht
    #   von at.cachyos.org übertragen : The requested URL returned error: 404
    #
    # which reads like a broken mirror and is not one. (That is the real message
    # from a VM run; the mirror had 0.16.2-2.1.) Partial upgrades are unsupported
    # on Arch regardless, so there is no version of this that installs packages
    # without syncing first.
    #
    # Interactive by default. --noconfirm answers N to every question, including
    # "package X conflicts with Y, remove Y?" -- which turns a resolvable prompt
    # into "Nicht auflösbare Paketkonflikte gefunden" and aborts the whole
    # install. A conflict is a decision for you to make, not one to
    # auto-decline. Pass --yes if you want it unattended anyway.
    sudo pacman -Syu --needed $PACMAN_CONFIRM "${list[@]}"

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
            # -Syu here too, for the same reason: an AUR package's dependencies
            # come from the official repos and resolve against the same
            # database.
            "$helper" -Syu --needed $PACMAN_CONFIRM "${aur[@]}"
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

# ------------------------------------------------------- resident GTK apps

# GTK reads gtk.css ONCE, at PROCESS START. That is not the same as "next time
# you open a window": GNOME apps are D-Bus activated and stay resident after
# their last window closes, so asking for a new window asks the SURVIVING
# process for one and it is still drawing the palette that was current when it
# first launched. The app therefore looks stale in a way that survives exactly
# the test you would use to check for staleness — a screenshot showed Nautilus
# on an orange palette (hue 28) while the shell and kitty were both on a blue
# one (hue 210), and the window had been opened after the theme change.
#
# This is the same problem `kitty @ set-colors` solves above, and it gets the
# same treatment: finish the job rather than leaving one target stale.
#
# ONLY QUITS APPS WITH NO OPEN WINDOWS. `nautilus --quit` closes every window it
# has, and silently closing a file manager someone is in the middle of using to
# fix a colour is a bad trade. With no windows open the quit is invisible and
# the next launch reads the new palette; with windows open, say so instead.
refresh_gtk_apps() {
    # "<binary>:<window class>" — the class is what `hyprctl clients` reports,
    # which is the app id, not the binary name.
    local apps=("nautilus:org.gnome.Nautilus")

    local entry bin cls
    for entry in "${apps[@]}"; do
        bin="${entry%%:*}"; cls="${entry##*:}"

        command -v "$bin" >/dev/null || continue
        # Not resident, so nothing is holding a stale stylesheet. Skipping also
        # avoids `--quit` D-Bus-activating the app just to shut it down again.
        pgrep -x "$bin" >/dev/null 2>&1 || continue

        # Cannot see the windows -> do not close anything. Being wrong in this
        # direction costs a stale titlebar; being wrong in the other costs
        # whatever the user had open.
        if ! command -v hyprctl >/dev/null || ! hyprctl clients -j >/dev/null 2>&1; then
            warn "$bin is running with the old palette — restart it, or run: $bin --quit"
            continue
        fi

        local open
        open="$(hyprctl clients -j 2>/dev/null \
                | python3 -c 'import json,sys; c=json.load(sys.stdin);
print(sum(1 for w in c if w.get("class") == sys.argv[1]))' "$cls" 2>/dev/null || echo 0)"

        if [[ "$open" == "0" ]]; then
            "$bin" --quit >/dev/null 2>&1 || true
            ok "$bin restarted on next launch (it was resident with the old palette)"
        else
            warn "$bin has $open window(s) open and keeps the old palette until it exits — $bin --quit"
        fi
    done
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
    #   --type      which scheme algorithm spreads the palette. Matugen's own
    #               default, scheme-tonal-spot, is deliberately muted; this
    #               desktop uses scheme-expressive, which moves the secondary
    #               and tertiary hues away from the primary.
    #   --contrast  -1..1, 0 being the Material spec.
    # Built once into an array so image and hex generation cannot drift apart.
    local style contrast
    style="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme style || echo scheme-expressive)"
    contrast="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme contrast || echo 0)"
    local tune=(--type "$style" --contrast "$contrast")

    # Set by every branch that generated from a THEME rather than an image.
    # Only a theme can carry [roles], so this is also the flag for whether the
    # override pass runs at all.
    local theme_toml=""

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
        theme_toml="$REPO/themes/$arg.toml"

    elif [[ "$mode" == "manual" ]]; then
        local name seed
        name="$(json_get "$CONFIG_HOME/quickshell/settings.json" theme manual || echo catppuccin-mocha)"
        [[ -f "$REPO/themes/$name.toml" ]] || die "no such theme: $name"
        seed="$(grep -oP '^seed\s*=\s*"\K[^"]+' "$REPO/themes/$name.toml")"
        matugen color hex "$seed" --mode "$scheme" "${tune[@]}"
        source_desc="theme $name (seed $seed)"
        theme_toml="$REPO/themes/$name.toml"

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
            theme_toml="$REPO/themes/catppuccin-mocha.toml"
        fi
    fi

    ok "$source_desc, $scheme"

    if [[ -n "$theme_toml" ]]; then
        apply_roles "$theme_toml"
    fi

    # Push the new palette to every running kitty. Without this, open terminals
    # keep the old colours until they are restarted.
    if command -v kitty >/dev/null && [[ -e "$CONFIG_HOME/kitty/colors.conf" ]]; then
        kitty @ --to unix:@mykitty set-colors --all --configured \
            "$CONFIG_HOME/kitty/colors.conf" >/dev/null 2>&1 \
            && ok "pushed to running kitty" || true
    fi

    # Hyprland re-reads conf/colors.lua on reload; border gradients update live.
    command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 && ok "hyprctl reload"

    refresh_gtk_apps

    # The login screen is the one target this cannot update: /usr/share is
    # root-owned and this function has to stay runnable from the picker, which
    # has no terminal for a sudo prompt. Say so rather than letting the greeter
    # silently keep last month's colours.
    if [[ -f "$SDDM_THEME_DIR/theme.conf" ]] \
       && ! diff -q <(grep -v '^background=' "$SDDM_THEME_DIR/theme.conf" 2>/dev/null) \
                    "$STATE_HOME/quickshell/sddm-theme.conf" >/dev/null 2>&1; then
        warn "login screen still has the old palette — ./install/install.sh --sddm"
    fi
}

# Merge a theme's [roles] table over the palette matugen just generated, then
# re-render every other target from the merged map (DESIGN.md §4, "Mode
# manual").
#
# WHY THERE IS A SECOND RENDER AT ALL. matugen derives all 35 roles from one
# seed, which gives a coherent palette but not literally Catppuccin — its base
# is a purple-tinted near-black, not #1e1e2e. matugen has no hook to override a
# role before it renders, so the only place to intervene is after. It renders
# once, we merge, and if anything changed we re-render the seven non-JSON targets
# ourselves.
#
# THIS IS STILL ONE CODE PATH. The templates are the same files matugen uses,
# in the same syntax; nothing here decides which role a target takes. A theme
# with no [roles] table never reaches the renderer at all, so the two cannot
# drift on the common case. `check.sh`'s `templates` section holds the contract
# that makes the uncommon case safe: every placeholder in every template is a
# form this renderer implements, and every role it names exists in colors.json.
apply_roles() {
    local rc=0 out=""
    out="$(python3 - "$1" "$CONFIG_HOME/matugen/config.toml" \
                        "$CONFIG_HOME/quickshell/colors.json" <<'PYEOF'
import json, os, pathlib, re, sys

try:
    import tomllib
except ModuleNotFoundError:
    sys.exit("[roles] overrides need python >= 3.11 (tomllib)")

theme_path, cfg_path, colors_path = sys.argv[1:4]

roles = tomllib.load(open(theme_path, "rb")).get("roles") or {}
if not roles:
    sys.exit(3)                      # no overrides — matugen's output stands

def write_atomic(path, text):
    # Write beside the target, then rename over it. `os.replace` is atomic on
    # the same filesystem, so a watcher never sees a truncated file — it sees
    # the old one and then the new one, with nothing in between.
    #
    # Theme.qml watches colors.json with inotify and reloads on change. A plain
    # `open(path, "w")` fires that watcher the moment the file is truncated,
    # and the reload reads a fragment. Matugen's own write has the same problem
    # and is not ours to fix, which is why Theme.qml also debounces and retries
    # — but everything THIS script writes can simply never be seen half-done.
    p = pathlib.Path(path)
    tmp = p.with_name(p.name + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, p)


palette = json.load(open(colors_path))
colors = palette["colors"]

# DESIGN.md §4 writes the example table in camelCase and matugen names roles in
# snake_case. Accept either rather than making one of them wrong.
index = {k.lower().replace("_", ""): k for k in colors}

bad, merged = [], {}
for key, value in roles.items():
    real = index.get(key.lower().replace("_", ""))
    if real is None:
        bad.append(f"unknown role {key!r}")
    elif not re.fullmatch(r"#[0-9a-fA-F]{6}", str(value)):
        bad.append(f"role {key!r}: {value!r} is not #rrggbb")
    else:
        merged[real] = "#" + str(value)[1:].lower()
# A typo in a theme must be loud. Silently ignoring it is how you get a theme
# that reports success and looks exactly like the one you were replacing.
if bad:
    sys.exit("theme " + pathlib.Path(theme_path).stem + ": " + "; ".join(bad))

colors.update(merged)
write_atomic(colors_path, json.dumps(palette, indent=2) + "\n")

# Re-render every target except the palette itself, which we just wrote.
placeholder = re.compile(r"\{\{colors\.([a-z_0-9]+)\.default\.(hex|hex_stripped)\}\}")
config = tomllib.load(open(cfg_path, "rb")).get("templates") or {}
rendered = 0

for name, spec in sorted(config.items()):
    src = pathlib.Path(os.path.expanduser(spec["input_path"]))
    dst = pathlib.Path(os.path.expanduser(spec["output_path"]))
    if dst.resolve() == pathlib.Path(colors_path).resolve():
        continue
    if not src.exists():
        sys.exit(f"template {name}: no such input {src}")

    unknown = set()

    def one(m):
        role, form = m.group(1), m.group(2)
        if role not in colors:
            unknown.add(role)
            return m.group(0)
        return colors[role] if form == "hex" else colors[role][1:]

    text, hits = placeholder.subn(one, src.read_text())
    if unknown:
        sys.exit(f"template {name}: role(s) not in colors.json: {', '.join(sorted(unknown))}")
    # Both of these mean the renderer silently produced a file that still has
    # template text in it — the exact failure shape this repo keeps hitting.
    if hits == 0:
        sys.exit(f"template {name}: no placeholders substituted")
    if "{{" in text:
        sys.exit(f"template {name}: unsupported placeholder survived: "
                 + re.search(r"\{\{[^}]*\}\}", text).group(0))

    dst.parent.mkdir(parents=True, exist_ok=True)
    write_atomic(dst, text)
    rendered += 1

print(f"{len(merged)} role overrides, {rendered} targets re-rendered")
PYEOF
)" || rc=$?

    case $rc in
        0) ok "$(basename "${1%.toml}"): $out" ;;
        3) : ;;                      # theme carries no [roles] table
        *) die "role overrides failed for $(basename "$1")" ;;
    esac
}

# ---------------------------------------------------------------- login screen

SDDM_THEME_DIR="/usr/share/sddm/themes/hypersetup"

# Install (or refresh) the SDDM theme.
#
# WHY THIS IS A SEPARATE FLAG rather than part of --theme. SDDM runs as the
# `sddm` user on its own VT before any user session exists: it never reads
# $HOME, `hyprctl reload` means nothing to it, and its theme directory is
# root-owned. So the theme has to be COPIED, and copying needs a password —
# which --theme cannot ask for, because the wallpaper picker runs it with no
# terminal attached. Rolling this into --theme would make every theme change
# from the picker hang on an invisible sudo prompt.
#
# It generates no colour. matugen has already rendered the palette to
# ~/.local/state; this moves that file, the QML and the wallpaper into place.
do_sddm() {
    step "login screen"

    local gen="$STATE_HOME/quickshell/sddm-theme.conf"
    [[ -f "$gen" ]] || die "no generated palette at $gen — run ./install/install.sh --theme first"
    [[ -f "$REPO/sddm/hypersetup/Main.qml" ]] || die "no theme in the repo at sddm/hypersetup"

    # Cheap, and it has already paid for itself once: an unversioned import is
    # Qt 6 syntax, and on the engine sddm actually launched it meant the theme
    # did not load at all. Refuse to install a greeter that cannot start.
    if grep -qE '^import [A-Za-z.]+\s*$' "$REPO"/sddm/hypersetup/*.qml; then
        die "unversioned import in the sddm theme — sddm's QML engine rejects it:
     $(grep -nE '^import [A-Za-z.]+\s*$' "$REPO"/sddm/hypersetup/*.qml | head -3)"
    fi

    sudo install -d -m 755 "$SDDM_THEME_DIR"
    # Every .qml, not a named list: the theme grew IconButton.qml and
    # PillButton.qml when the inline components had to become separate files,
    # and a named list would have installed a Main.qml referring to types that
    # were not there — which fails exactly like a syntax error.
    local n=0
    for f in "$REPO"/sddm/hypersetup/*.qml; do
        sudo install -m 644 "$f" "$SDDM_THEME_DIR/"
        n=$((n+1))
    done
    (( n > 0 )) || die "no QML in $REPO/sddm/hypersetup"
    sudo install -m 644 "$REPO/sddm/hypersetup/metadata.desktop" "$SDDM_THEME_DIR/"
    sudo install -m 644 "$gen" "$SDDM_THEME_DIR/theme.conf"
    ok "$n QML files + palette in $SDDM_THEME_DIR"

    # The wallpaper, if one has been chosen. The extension is preserved rather
    # than forced to .jpg: QML's image loader picks its decoder by extension
    # first, and a PNG named .jpg is a blank background with no error.
    local wall ext
    wall="$(cat "$STATE_HOME/quickshell/wallpaper" 2>/dev/null || true)"
    if [[ -n "$wall" && -f "$wall" ]]; then
        ext="${wall##*.}"
        # Drop any earlier one first, or a format change leaves two files and
        # theme.conf pointing at the stale one.
        sudo rm -f "$SDDM_THEME_DIR"/background.*
        sudo install -m 644 "$wall" "$SDDM_THEME_DIR/background.$ext"
        # [General] is the only section in the template, so appending stays
        # inside it. Main.qml treats a missing key as "no wallpaper".
        printf 'background=background.%s\n' "$ext" \
            | sudo tee -a "$SDDM_THEME_DIR/theme.conf" >/dev/null
        ok "background.$ext ($(basename "$wall"))"
    else
        warn "no wallpaper set — the login screen will use the flat background colour"
    fi

    # Root-owned, in /etc: a symlink into ~ would be invisible to the sddm user.
    sudo install -d -m 755 /etc/sddm.conf.d
    printf '[Theme]\nCurrent=hypersetup\n' \
        | sudo tee /etc/sddm.conf.d/10-hypersetup.conf >/dev/null
    ok "/etc/sddm.conf.d/10-hypersetup.conf"

    # A greeter that fails to draw locks you out of your own machine, so the
    # way back is printed here rather than left in a comment you cannot reach.
    printf '\n%s  preview it before you trust it:%s\n' "$c_dim" "$c_off"
    printf '    sddm-greeter-qt6 --test-mode --theme %s\n' "$SDDM_THEME_DIR"
    printf '\n%s  if the login screen is ever blank: Ctrl+Alt+F2, log in, then%s\n' "$c_dim" "$c_off"
    printf '    sudo rm /etc/sddm.conf.d/10-hypersetup.conf && sudo systemctl restart sddm\n'
}

# Set the wallpaper on the running session AND make it survive a logout.
#
# hyprpaper remembers NOTHING. `hyprctl hyprpaper wallpaper` lasts exactly as
# long as the process, and autostart starts a fresh one with no config, so the
# desktop came back bare after every login. The config file is the only thing
# hyprpaper reads at startup, so the choice is written there as well as pushed
# over IPC — the file is what logs in, the IPC call is what you see now.
#
# It is generated, so it is gitignored alongside the matugen output: ~/.config
# is a symlink into the checkout and a runtime write would otherwise leave the
# tree permanently dirty.
set_wallpaper() {
    local img="$1" fit
    fit="$(json_get "$CONFIG_HOME/quickshell/settings.json" wallpaper fit || echo cover)"

    # hyprpaper is hyprlang, not Lua — `wallpaper` is a nested block here, and
    # fit_mode is one of contain|cover|tile|fill. An empty monitor is the
    # fallback for every output, which is what a single-display machine wants.
    mkdir -p "$CONFIG_HOME/hypr"
    cat > "$CONFIG_HOME/hypr/hyprpaper.conf" <<EOF
# Generated by install.sh. Change wallpaper.fit in settings.json, not this.
splash = false
ipc = true

wallpaper {
    monitor =
    path = $img
    fit_mode = $fit
}
EOF
    ok "hyprpaper.conf -> $(basename "$img")"

    # Live update on top of that, when there is a session to update.
    command -v hyprctl >/dev/null || return 0
    pgrep -x hyprpaper >/dev/null || return 0
    hyprctl hyprpaper wallpaper ",$img,$fit" >/dev/null 2>&1 || true
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
    local do_all=1 pkgs=0 link=0 svc=0 theme=0 theme_arg="" wall=0 wall_arg="" sddm=0

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
            --sddm)     do_all=0; sddm=1 ;;
            --yes|-y)   PACMAN_CONFIRM="--noconfirm" ;;
            -h|--help)  sed -n '2,19p' "$0"; exit 0 ;;
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
    # After --theme, never before: it copies the palette --theme just rendered.
    (( do_all || sddm ))  && do_sddm

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
