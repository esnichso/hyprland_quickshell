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

# Is shell.qml where quickshell will actually look? A config that exists on
# disk but not on quickshell's search path fails with "Could not find ... in
# any valid config path", which reads like a missing file rather than a
# misplaced one.
if [[ -f "$CONFIG_HOME/quickshell/shell.qml" ]]; then
    ok "shell.qml at the base of ~/.config/quickshell (loads as the default config)"
elif compgen -G "$CONFIG_HOME/quickshell/*/shell.qml" >/dev/null; then
    no "shell.qml is in a subdirectory — this setup expects it at the base, run install.sh --link"
else
    no "no shell.qml anywhere under ~/.config/quickshell — run install.sh --link"
fi

if command -v qs >/dev/null; then
    # `qs list` reports what quickshell can see, which is the only opinion
    # that matters.
    if qs list 2>/dev/null | grep -qi 'default'; then
        ok "quickshell sees a default config"
    else
        no "quickshell does not see a default config: $(qs list 2>&1 | head -2 | tr '\n' ' ')"
    fi
fi

if pgrep -x quickshell >/dev/null; then
    ok "quickshell running"
else
    no "quickshell not running — start it: uwsm app -- qs"
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

# ------------------------------------------------------------------ qml lint

sec "qml"

# A narrow lint for things that are hard load failures, not style.
#
# QML cannot be parsed on the dev host: /usr/bin/qmllint there is a qtchooser
# stub for a Qt5 binary that is not installed, and it fails identically on valid
# and invalid input, so its verdict is worthless. That leaves targeted checks
# for mistakes that have actually happened.
#
# The whole shell failed to load once because font.pixelSize was 10.5. It is an
# INT in Qt; a fractional value aborts the file, and every type that imports it
# then reports "Type X unavailable" — so the error surfaces five frames away
# from its cause.
#
# The second rule catches EMPTY GLYPH SLOTS. Nerd Font icons live in the Unicode
# private use area, terminals render them as nothing, and a tool that rewrites a
# file can drop them without a word — which is how the OSD, the notch, the
# dashboard and the toast all shipped with `text: ""` where an icon belonged.
# Reading the diff cannot find it: the character is invisible either way. A
# deliberate blank must be written as a named property (root.noGlyph), never as
# a bare "".

if python3 - "$REPO" <<'PYEOF'
import re, sys, pathlib
repo = pathlib.Path(sys.argv[1])
qml = sorted((repo / "config/quickshell").rglob("*.qml"))
if not qml:
    print("  no QML found — skipped"); sys.exit(0)

# QML properties typed int. A real assigned to any of these fails to load.
INT_PROPS = ["font.pixelSize", "font.weight", "maximumLineCount",
             "interval", "elideWidth", "cursorPosition"]

# An icon slot assigned a bare empty string, and a glyph map entry that is
# empty. Both mean a private-use character was lost, not that a blank was
# intended — intent is spelled root.noGlyph.
EMPTY_GLYPH = re.compile(r'^\s*(text|glyph)\s*:\s*""\s*,?\s*$')
EMPTY_TERNARY = re.compile(r'^\s*(text|glyph)\s*:.*\?\s*""\s*:\s*""')
GLYPH_MAP_OPEN = re.compile(r'\bproperty\s+var\s+\w*[Gg]lyphs?\s*:\s*\(\{')
MAP_ENTRY_EMPTY = re.compile(r'^\s*"[^"]+"\s*:\s*""\s*,?\s*$')

def strip_comment(line):
    """Drop a // comment, but not a // that is inside a string.

    A regex cannot do this: `"://"` in a URL and `` `file://${p}` `` both look
    like the start of a comment, and truncating there leaves an odd number of
    quotes — which the unbalanced-quote rule below then reports as broken code.
    That false positive fired on real, correct Media.qml.
    """
    out = []
    quote = None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                out.append(line[i:i + 2]); i += 2; continue
            if c == quote:
                quote = None
        elif c in "\"'`":
            quote = c
        elif c == "/" and line[i + 1:i + 2] == "/":
            break
        out.append(c)
        i += 1
    return "".join(out)

bad = []
for f in qml:
    in_glyph_map = False
    for i, line in enumerate(f.read_text().splitlines(), 1):
        code = strip_comment(line)

        if GLYPH_MAP_OPEN.search(code):
            in_glyph_map = True
        elif in_glyph_map and "})" in code:
            in_glyph_map = False
        elif in_glyph_map and MAP_ENTRY_EMPTY.match(code):
            bad.append((f.relative_to(repo), i, "empty glyph in map", code.strip()))

        if EMPTY_GLYPH.search(code):
            bad.append((f.relative_to(repo), i, "empty glyph slot", code.strip()))
        elif EMPTY_TERNARY.search(code):
            bad.append((f.relative_to(repo), i, "both glyph branches empty", code.strip()))

        for prop in INT_PROPS:
            m = re.search(rf"\b{re.escape(prop)}\s*:\s*(-?[0-9]+\.[0-9]+)\s*$", code)
            if m:
                bad.append((f.relative_to(repo), i, f"{prop} (int expected)", m.group(1)))

        # Balanced-brace typos are caught by the parser, but an unclosed string
        # is not obvious in a diff.
        if code.count('"') % 2 == 1 and "\\\"" not in code:
            bad.append((f.relative_to(repo), i, "unbalanced quote", code.strip()[:40]))

if bad:
    for f, i, prop, val in bad:
        print(f"  \033[31m ✗ \033[0m {f}:{i}  {prop}: {val}")
    sys.exit(1)
print(f"  \033[32m ✓ \033[0m {len(qml)} QML files, no fractional int assignments"
      " and no empty glyph slots")
PYEOF
then pass=$((pass+1)); else fail=$((fail+1)); fi

# ----------------------------------------------------------- ansi palette

sec "ansi"

# Six of the sixteen terminal colours were once byte-identical duplicates —
# green and magenta both `tertiary`, yellow and cyan both `secondary`. No
# palette generator can make those distinguishable, and a diff cannot show it.
#
# Bright colours must also not be `*_container`: in a dark scheme that is a
# DARK tone meant to sit behind text, which is what made half the palette
# unreadable.

if python3 - "$REPO" <<'PYEOF'
import re, sys, pathlib
repo = pathlib.Path(sys.argv[1])
tpl = repo / "config/matugen/templates/kitty-colors.conf"
if not tpl.exists():
    print("  kitty template missing — skipped"); sys.exit(0)

roles = {}
for line in tpl.read_text().splitlines():
    m = re.match(r"^\s*color(\d+)\s+\{\{\s*colors\.([a-z_0-9]+)\.", line)
    if m:
        roles[int(m.group(1))] = m.group(2)

missing = [n for n in range(16) if n not in roles]
if missing:
    print(f"  \033[31m ✗ \033[0m kitty template defines no color{missing[0]}")
    sys.exit(1)

seen = {}
dupes = []
for n in range(16):
    seen.setdefault(roles[n], []).append(n)
for role, idx in seen.items():
    if len(idx) > 1:
        dupes.append(f"color{'/'.join(str(i) for i in idx)} all use {role}")

# 8-15 are the bright half. `X_container` is the dark tone; `on_X_container`
# is its LIGHT counterpart and is exactly what a bright colour should be, so
# the on_ prefix has to be excluded or this flags the correct mapping.
dark = [f"color{n} = {roles[n]}" for n in range(8, 16)
        if roles[n].endswith("_container") and not roles[n].startswith("on_")]

if dupes or dark:
    for d in dupes:
        print(f"  \033[31m ✗ \033[0m duplicate ANSI colour: {d}")
    for d in dark:
        print(f"  \033[31m ✗ \033[0m bright colour uses a container role (dark in a dark scheme): {d}")
    sys.exit(1)

print(f"  \033[32m ✓ \033[0m 16 ANSI colours, all distinct roles")
PYEOF
then pass=$((pass+1)); else fail=$((fail+1)); fi

# ------------------------------------------------------------- config keys

sec "config keys"

# Validate every key in config/hypr against the wiki snapshot in docs/.
#
# This is the one check that runs equally well off a live session, and it earns
# its place: Hyprland removes and relocates config keys between releases, and an
# unknown key is not ignored — it is a startup error banner. The first VM boot
# hit five of them at once (dwindle.pseudotile, misc.vfr, two removed gesture
# keys, and a window rule using a lookahead RE2 cannot parse).
#
# Refresh docs/hyprland/ after a Hyprland update, then re-run this.

if python3 - "$REPO" <<'PYEOF'
import re, sys, glob, pathlib
repo = pathlib.Path(sys.argv[1])
docs = repo / "docs/hyprland"
var  = docs / "Configuring_Basics_Variables.md"
if not var.exists():
    print("  wiki snapshot missing — skipped"); sys.exit(0)

valid = set()
def add(cat, block):
    for line in block.splitlines():
        m = re.match(r'^\|\s*([a-z_][a-z0-9_.]*)\s*\|', line)
        if m: valid.add(f"{cat}.{m.group(1)}" if cat else m.group(1))

txt = var.read_text()
parts = re.split(r'_Subcategory `([a-z:._]+)`_', txt)
add('general', parts[0])
for i in range(1, len(parts), 2):
    add(parts[i].rstrip('.').replace(':', '.'), parts[i+1])
for h, c in [('### General','general'), ('### Decoration','decoration'),
             ('### Input','input'), ('### Animations','animations')]:
    m = re.search(re.escape(h) + r'(.*?)(?=\n### |\Z)', txt, re.S)
    if m: add(c, m.group(1))
for f, c in [('Configuring_Layouts_Dwindle-Layout.md','dwindle'),
             ('Configuring_Layouts_Master-Layout.md','master')]:
    fp = docs / f
    if fp.exists(): add(c, fp.read_text())

used, bad = [], []
for f in glob.glob(str(repo / 'config/hypr/conf/*.lua')):
    src = open(f).read()
    for m in re.finditer(r'hl\.config\(\{(.*?)\n\}\)', src, re.S):
        stack = []
        for line in m.group(1).splitlines():
            s = line.strip()
            if not s or s.startswith('--'): continue
            ind = len(line) - len(line.lstrip())
            while stack and stack[-1][1] >= ind: stack.pop()
            k = re.match(r'([a-z_][a-z0-9_]*)\s*=\s*\{', s)
            v = re.match(r'([a-z_][a-z0-9_]*)\s*=\s*[^{]', s)
            if k: stack.append((k.group(1), ind))
            elif v:
                path = '.'.join(x[0] for x in stack + [(v.group(1), 0)])
                used.append(path)
                if path not in valid: bad.append((pathlib.Path(f).name, path))

# RE2 has no lookahead/lookbehind; using one is a parse error, not a non-match.
# Comments are stripped first — the config documents this pitfall by quoting a
# bad pattern, and scanning raw text flags the explanation as the offence.
for f in glob.glob(str(repo / 'config/hypr/conf/*.lua')):
    code = '\n'.join(re.sub(r'--.*$', '', ln) for ln in open(f).read().splitlines())
    if re.search(r'\(\?[=!<]', code):
        bad.append((pathlib.Path(f).name, 'RE2 lookahead/lookbehind in a rule'))

if bad:
    for f, k in bad:
        print(f"  \033[31m ✗ \033[0m {k}  ({f})")
    sys.exit(1)
print(f"  \033[32m ✓ \033[0m {len(used)} config keys, all known to the wiki")
PYEOF
then pass=$((pass+1)); else fail=$((fail+1)); fi

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
