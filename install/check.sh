#!/usr/bin/env bash
# hypersetup2 checker.
#
# Validates the RUNNING SESSION, not the files on disk. That distinction is the
# whole point: a file-only checker mostly confirms that files exist, which they
# always do. What breaks is services not running, D-Bus names owned by the wrong
# process, layer namespaces that do not match, and colours that resolve to
# something unreadable.
#
# Run it inside the desktop, not over SSH.
#
#   ./install/check.sh          everything
#   ./install/check.sh --quiet  only failures

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

pass=0; fail=0; skip=0

c_ok=$'\e[32m'; c_no=$'\e[31m'; c_sk=$'\e[33m'; c_dim=$'\e[2m'; c_off=$'\e[0m'
# Counters use assignment, not ((n++)): post-increment evaluates to the OLD
# value, so ((pass++)) returns status 1 when pass is 0 — which silently makes
# any `ok ... && something` chain take the failure branch.
ok()   { (( QUIET )) || printf '%s ✓ %s %s\n' "$c_ok" "$c_off" "$*"; pass=$((pass+1)); }
no()   { printf '%s ✗ %s %s\n' "$c_no" "$c_off" "$*"; fail=$((fail+1)); }
sk()   { (( QUIET )) || printf '%s – %s %s %s(skipped)%s\n' "$c_sk" "$c_off" "$*" "$c_dim" "$c_off"; skip=$((skip+1)); }
sec()  { (( QUIET )) || printf '\n%s%s%s\n' "$c_dim" "$*" "$c_off"; }

# ------------------------------------------------------------------ session

sec "session"

if [[ "${XDG_CURRENT_DESKTOP:-}" == "Hyprland" ]]; then
    ok "XDG_CURRENT_DESKTOP=Hyprland"
else
    no "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-unset}' — portals will pick the wrong backend"
fi

if command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
    v="$(hyprctl version | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    maj="${v%%.*}"; min="$(echo "$v" | cut -d. -f2)"
    if (( maj > 0 || min >= 55 )); then
        ok "hyprland $v (Lua config supported)"
    else
        no "hyprland $v — too old for the Lua config, everything in config/hypr is the wrong syntax"
    fi

    # Did the Lua config actually load, or did it fall into emergency mode?
    # Emergency mode has almost no binds, so a low count is the tell.
    n="$(hyprctl binds -j 2>/dev/null | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
    if (( n > 40 )); then
        ok "$n keybinds loaded"
    else
        no "only $n keybinds — the Lua config probably failed to load (check: hyprctl rollinglog)"
    fi
else
    sk "hyprland not running — run this inside the session"
fi

# ------------------------------------------------------------------- shell

sec "shell"

if pgrep -x quickshell >/dev/null; then
    ok "quickshell running"
else
    no "quickshell not running — start it: uwsm app -- qs -c hypersetup2"
fi

# The layer namespaces the bar declares must match conf/rules.lua, or the blur
# rule silently applies to nothing. v1 lost an afternoon to exactly this.
if command -v hyprctl >/dev/null && hyprctl layers >/dev/null 2>&1; then
    layers="$(hyprctl layers)"
    for ns in hypersetup-bar; do
        if grep -q "$ns" <<<"$layers"; then
            ok "layer namespace '$ns' present"
        else
            no "layer namespace '$ns' NOT found — conf/rules.lua blur rule matches nothing"
        fi
    done
fi

# Exactly one notification daemon. Two owners of this name is a coin flip at
# login, and the loser fails in a way that looks like a shell bug.
if command -v busctl >/dev/null; then
    if busctl --user list 2>/dev/null | grep -q org.freedesktop.Notifications; then
        ok "a notification daemon owns org.freedesktop.Notifications"
    else
        sk "no notification daemon yet (Phase 2)"
    fi
fi

# Packages the shell replaces must not be installed.
conflicts=(waybar rofi rofi-wayland swaync dunst mako swayosd wofi blueman pavucontrol network-manager-applet)
found=()
for p in "${conflicts[@]}"; do pacman -Qq "$p" &>/dev/null && found+=("$p"); done
if (( ${#found[@]} )); then
    no "replaced packages still installed: ${found[*]}"
else
    ok "no replaced packages installed"
fi

# ------------------------------------------------------------------- links

sec "symlinks"

for d in hypr quickshell matugen kitty fish gtk-3.0 gtk-4.0 qt6ct uwsm; do
    t="$CONFIG_HOME/$d"
    if [[ -L "$t" && "$(readlink -f "$t")" == "$REPO/config/$d" ]]; then
        ok "$d"
    elif [[ -e "$t" ]]; then
        no "$d exists but is not a link into this repo — run install.sh --link"
    else
        no "$d missing — run install.sh --link"
    fi
done

# ------------------------------------------------------------------ colours

sec "colour"

colors="$CONFIG_HOME/quickshell/colors.json"
if [[ -f "$colors" ]]; then
    ok "colors.json generated"

    # Contrast. The one real risk of wallpaper-driven colour is a beautiful
    # wallpaper that produces an unreadable terminal, so this is a hard gate.
    python3 - "$colors" <<'PY'
import json, sys

def lum(h):
    h = h.lstrip('#')
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

d = json.load(open(sys.argv[1]))["colors"]
pairs = [
    ("on_surface", "surface"),
    ("on_surface_variant", "surface"),
    ("on_surface", "surface_container"),
    ("on_primary", "primary"),
]
worst, bad = 99, []
for fg, bg in pairs:
    if fg not in d or bg not in d:
        continue
    r = ratio(d[fg], d[bg])
    worst = min(worst, r)
    if r < 4.5:
        bad.append(f"{fg} on {bg} = {r:.1f}:1")

if bad:
    print(f"\033[31m ✗ \033[0m contrast below 4.5:1 — " + "; ".join(bad))
    sys.exit(1)
print(f"\033[32m ✓ \033[0m contrast floor met (worst {worst:.1f}:1)")
PY
    if (( $? == 0 )); then pass=$((pass+1)); else fail=$((fail+1)); fi
else
    no "colors.json missing — run install.sh --theme"
fi

for f in kitty/colors.conf hypr/conf/colors.lua gtk-3.0/colors.css qt6ct/colors/hypersetup.conf; do
    [[ -f "$CONFIG_HOME/$f" ]] && ok "generated: $f" || no "missing: $f — run install.sh --theme"
done

# ------------------------------------------------------------------- binds

sec "keybinds"

if command -v hyprctl >/dev/null && hyprctl binds -j >/dev/null 2>&1; then
    # Check that specific, named binds exist — not a count.
    #
    # An earlier version compared "how many SUPER chords KEYBINDS.md mentions"
    # against "how many SUPER binds are live". That number was garbage: the
    # markdown extraction produced fragments like "." and an arrow glyph, so
    # the comparison would have passed or failed for reasons unrelated to
    # anything real. A check that manufactures a verdict is worse than no
    # check. These assertions are boring and true.
    binds_json="$(hyprctl binds -j)"

    check_bind() {  # $1 = keysym, $2 = what it should do
        if python3 -c '
import json,sys
key=sys.argv[1].lower()
b=json.load(open("/dev/stdin"))
# modmask 64 = SUPER exactly. Not a bitwise test: SUPER+SHIFT is 65, and
# "SUPER+L is bound" must not be satisfied by SUPER+SHIFT+L existing.
sys.exit(0 if any(x.get("key","").lower()==key and x.get("modmask",0)==64 for x in b) else 1)
' "$1" <<<"$binds_json" 2>/dev/null; then
            ok "SUPER+$1 bound ($2)"
        else
            no "SUPER+$1 NOT bound — expected: $2"
        fi
    }

    check_bind Return "terminal"
    check_bind space  "launcher"
    check_bind Q      "close window"
    check_bind Escape "lock"
    check_bind N      "dashboard"
    check_bind I      "control centre"
    check_bind L      "focus right"

    total="$(python3 -c '
import json,sys; print(len(json.load(open("/dev/stdin"))))' <<<"$binds_json" 2>/dev/null || echo 0)"
    ok "$total binds total"
fi

# ---------------------------------------------------------------- hardware

sec "hardware"

if [[ -d /sys/class/power_supply/BAT0 ]]; then
    ok "battery BAT0 present"
else
    sk "no battery — VM. The battery item removes itself; verify on metal."
fi

if ls /sys/class/backlight/*/brightness >/dev/null 2>&1; then
    ok "screen backlight controllable"
else
    sk "no backlight device — VM. Verify brightness keys on metal."
fi

if ls /sys/class/leds/*kbd_backlight*/brightness >/dev/null 2>&1; then
    ok "keyboard backlight present"
else
    sk "no keyboard backlight — VM. METAL-ONLY test, see ROADMAP Phase 3."
fi

if command -v vainfo >/dev/null; then
    if vainfo 2>/dev/null | grep -q VAProfile; then
        ok "VA-API hardware decode available"
    else
        no "vainfo reports no profiles — hardware video decode is not working"
    fi
else
    sk "libva-utils not installed"
fi

if command -v glxinfo >/dev/null; then
    r="$(glxinfo -B 2>/dev/null | grep -oP 'OpenGL renderer string: \K.*' || true)"
    if [[ "$r" == *llvmpipe* ]]; then
        no "GPU is llvmpipe (software) — enable 3D acceleration in the VM, blur will crawl"
    elif [[ -n "$r" ]]; then
        ok "GPU: $r"
    fi
fi

# ------------------------------------------------------------------ summary

printf '\n%s──%s %d passed, %d failed, %d skipped\n' "$c_dim" "$c_off" "$pass" "$fail" "$skip"
(( fail == 0 )) || exit 1
