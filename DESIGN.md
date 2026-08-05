# Design

The look, the feel, the motion, and where colour comes from. Every number here
is a decision, not a default — if you change one, this is the file to change it
in, and `config/quickshell/settings.json` is where it actually lives at runtime.

---

## 1. The idea in one paragraph

Three floating islands sit on the top edge of the screen. The left one shows
workspaces, the right one shows the four things you always want to know
(network, bluetooth/volume, battery), and the middle one — the **notch** — is a
clock that morphs. A notification arrives, the notch stretches into it and
shows the message, then collapses back to the clock. You press the volume key,
it widens into a volume bar without ever getting taller. You click it, it grows
downward into a full dashboard. Nothing pops in from off-screen; everything
comes out of, and returns to, that one object in the middle.

The islands never move. Only the notch changes shape.

---

## 2. Geometry

The panel is 2560×1600 at scale 1.25, so every number below is in **logical
pixels** — 2048×1280 of usable space. Hyprland and QuickShell both work in
logical pixels, so these are the numbers you type.

> **Unresolved: the scale itself.** 1.25 is what the machine reports under
> GNOME today, and every number below is expressed in it. **v1 chose 1.6**
> (1600×1000 logical) on the reasoning that 2560/1.6 is a whole number — so is
> 2560/1.25, so both are valid, but they make a 46px bar look very different.
> Neither has been looked at on the real panel. This is a Phase 3 decision;
> if 1.6 wins, every number in this section needs scaling by 0.78 and the
> font sizes need re-checking. Do not assume either value is settled.

### The bar surface

| Property | Value | Why |
| --- | --- | --- |
| Anchors | top, left, right | Full-width layer-shell surface |
| Height | `46` | 34 island + 6 above + 6 below |
| Exclusive zone | `46` | Windows start below it; nothing ever overlaps |
| Layer | `top` | Above windows, below fullscreen and the launcher overlay |
| Background | fully transparent | The islands are the only visible thing |

The surface is transparent and click-through everywhere except the islands
themselves. `mask` is set to the union of the three island rects so clicks on
the gaps between them reach the window underneath.

### The islands

| | Height | Radius | Side margin | Gap to edge |
| --- | --- | --- | --- | --- |
| All three | `34` | `14` | `10` | `6` top |

Radius 14 on a 34px-tall object is deliberately *not* a full pill (which would
be 17). A pill reads as a badge; 14 reads as a surface. It also matches the
window `rounding = 12` closely enough that the desktop looks like one system.

| Island | Width | Contents |
| --- | --- | --- |
| Left | content-sized, ~`120` | Workspace indicators |
| Centre (notch) | `168` at rest | Clock + date |
| Right | content-sized, ~`150` | Network · Bluetooth/volume · Battery |

Left and right are anchored to their screen edges (10px in). The notch is
centred on the **screen**, not between the islands — so it stays put when the
side islands change width.

### Notch states and their sizes

| State | Width | Height | Radius | Lifetime |
| --- | --- | --- | --- | --- |
| Rest | `168` | `34` | `14` | — |
| OSD (volume, brightness, kbd, mic, caps) | `240` | `34` | `14` | 1.6s after last input |
| Notification toast | `400` | `76` | `18` | 5s (critical: until dismissed) |
| Dashboard (clicked) | `440` | `560` | `20` | until Esc / click-away |

The OSD is the detail that makes this feel designed: **it never gets taller
than the bar**. Volume and brightness widen the notch in place, so the bar
silhouette is unbroken and nothing on your screen is covered. Only
notifications and panels grow downward.

---

## 3. Motion

Motion is the entire point of a notch. Get this wrong and it's just a bar with
a gap in it.

### Curves

| Transition | Duration | Easing |
| --- | --- | --- |
| Notch expanding | `260ms` | `cubic-bezier(0.22, 1.00, 0.36, 1.00)` (out-quint) |
| Notch collapsing | `180ms` | `cubic-bezier(0.64, 0.00, 0.78, 0.00)` (in-quint) |
| Content cross-fade | `120ms`, delayed `60ms` | linear |
| Island hover tint | `90ms` | out-cubic |
| Panel open | `220ms` | out-quint |

Expansion is slower than collapse. Things that arrive should be noticed;
things that leave should get out of the way.

### Rules

- **Width and height animate together, and content is clipped during the
  transition.** The old content fades out as geometry starts moving, the new
  content fades in 60ms later. This is what produces the "morph" rather than a
  "resize".
- **Never animate blur radius.** It's a full-surface GPU re-render each frame
  and it will drop frames on the Arc iGPU. Blur is set once and left alone.
- **Never animate the exclusive zone.** Windows would reflow on every
  notification. The bar surface is a fixed 46px forever; the notch overlays
  content when it grows.
- **Interrupting is normal.** If a second notification arrives mid-expansion,
  the geometry animation retargets from wherever it is — it does not queue or
  restart. Every animated property uses a `Behavior`, so this is free.
- **One thing at a time.** The notch has a single state machine with a
  priority order: `dashboard > critical notification > OSD > notification >
  media > clock`. A volume press during a toast wins, the toast returns
  afterwards with its remaining time.

### Reduced motion

`settings.json → motion.enabled: false` sets every duration to `0ms` and
skips the cross-fade. Nothing else changes. Useful when screen-recording, and
useful in the VM where animations are misleading anyway.

---

## 4. Colour

### Tuning how distinct the palette is

Two knobs in `settings.json`, both passed straight to matugen by
`install.sh --theme`. Change either and re-run `./install/install.sh --theme`.

| `theme.style` | What it does |
| --- | --- |
| `scheme-expressive` | **the one this desktop uses.** Pushes the secondary and tertiary hues away from the primary, so green, magenta and cyan read as separate colours rather than tints of the accent |
| `scheme-tonal-spot` | matugen's own default. Material's spec — deliberately muted, one hue with everything derived close to it |
| `scheme-vibrant` | same hue family as tonal-spot, much more chroma |
| `scheme-fruit-salad` | further still; hues clearly unrelated to each other |
| `scheme-content` `scheme-fidelity` | stay close to the wallpaper's actual colours |
| `scheme-rainbow` `scheme-neutral` `scheme-monochrome` | progressively less colour |

`theme.contrast` runs `-1` to `1`, `0` being the Material spec. It separates
foreground from background rather than hue from hue, so it is the one to reach
for when text is hard to read rather than when colours look alike.

`scheme-expressive` with contrast `0` was chosen after comparing them on the
real palette: it is the smallest step that changes the *hues* rather than just
saturating them, which is what "a bit more distinguishable, but not a lot"
asked for.

The ANSI mapping itself lives in `config/matugen/templates/kitty-colors.conf`,
one line per colour. That file is where to go to change *which role* a terminal
colour takes, as opposed to how the palette is generated.

Two modes, one pipeline, chosen at runtime. This is the switch you asked for.

```
                  ┌──────────────────────────────────┐
   mode:          │  "wallpaper"       │  "manual"   │
   wallpaper      │       ↓            │      ↓      │
   or manual      │  matugen image     │  themes/    │
                  │  <current.jpg>     │  <name>.toml│
                  └──────────┬─────────┴──────┬──────┘
                             │                │
                             └───────┬────────┘
                                     ↓
                         Material 3 role set (40 roles)
                                     ↓
                        matugen templates render:
      ┌──────────┬─────────┬──────────┬─────────┬──────────┬──────────┐
      ↓          ↓         ↓          ↓         ↓          ↓
  colors.json  kitty    gtk3/gtk4   qt6ct   hyprland   hyprlock
  (quickshell) (live)   (restart)  (restart) (live)     (next lock)
```

### Mode `wallpaper`

You change the wallpaper; the desktop changes colour. `hyprctl hyprpaper` sets it, and
the same action runs `matugen image <path>`, which regenerates every target
above. QuickShell watches `colors.json` and re-themes with no restart. Kitty
gets the new palette pushed over its socket to every running instance. GTK and
Qt apps pick it up when next launched.

### Mode `manual`

You pick a theme; the wallpaper no longer drives colour. Each theme is one
TOML in `themes/`:

```toml
name = "Catppuccin Mocha"
seed = "#cba6f7"          # generates the 35 roles, most of which nobody notices

[roles]                    # explicit overrides for the ones you do
background        = "#1e1e2e"
surface           = "#1e1e2e"
surface_container = "#313244"
on_surface        = "#cdd6f4"
on_surface_variant= "#a6adc8"
outline           = "#6c7086"
primary           = "#cba6f7"
error             = "#f38ba8"
```

The seed goes through matugen to fill the full role set, then `[roles]` is
merged on top. You get real Catppuccin where it matters and a coherent,
auto-derived palette everywhere else — without hand-writing 35 hex values per
theme, which is what made v1's theming a chore. Keys may be `snake_case` or
`camelCase`; an unknown one is a hard error, never a silent skip.

**Which roles a shipped theme pins, and which it leaves alone.** The neutrals
are what makes a theme recognisable — you know Mocha by `#1e1e2e`, not by its
tertiary container. So the three themes here pin the surfaces, the text, the
outlines, the accent and the error colour, and leave the tonal variants to
matugen. The mechanism is general: any of the 35 roles can be overridden.

The one visible consequence is in the terminal. ANSI green, yellow, cyan and
magenta come from `tertiary` and `secondary`, which are *not* pinned, so they
stay matugen's derivations from the seed rather than the theme's own green and
yellow. That is deliberate: Material 3 has four hue families and ANSI wants
six, so pinning two of the six would leave the other four visibly mismatched
against them. A coherent derived set reads better than a half-matched one.

**Both modes render through the same templates.** There is exactly one code
path from "a role set exists" to "every app is themed", which is the thing v1
got right and worth keeping.

**How the merge happens, given matugen renders the templates itself.** matugen
has no hook to change a role before it writes, so `install.sh --theme` lets it
render once, merges `[roles]` into `colors.json`, and — only if the theme
actually has overrides — re-renders the other seven targets from the merged map
itself. It reuses the same template files in the same syntax, so nothing about
*which role a target takes* is duplicated. A theme without `[roles]` never
reaches that renderer, so the common path is still matugen's alone.

That small renderer implements exactly two placeholder forms,
`{{colors.<role>.default.hex}}` and `.hex_stripped`. `check.sh`'s `templates`
section is the contract that keeps it safe: it fails if any template uses a
form the renderer does not implement, if any template names a role that is not
in `colors.json`, if any theme names a role that does not exist, or if a
theme's own pinned colours miss the contrast floor below.

### Light and dark

`theme.scheme` is `dark`, `light`, or `auto`. `auto` follows `hyprsunset`'s
schedule — light during the day, dark after sunset — and re-renders on the
transition. matugen produces both schemes from the same seed, so switching is
a template re-render, not a regeneration.

### Roles the shell actually uses

Everything in the shell references a role, never a hex value:

| Shell element | Role | Alpha |
| --- | --- | --- |
| Island background | `surfaceContainer` | `0.72` |
| Island border (1px, inset) | `outline` | `0.18` |
| Panel background | `surfaceContainerLow` | `0.86` |
| Primary text | `textOnSurface` | `1.0` |
| Secondary text, icons at rest | `textOnSurfaceVariant` | `1.0` |
| Active workspace, sliders, focus ring | `primary` | `1.0` |
| Critical notification, battery < 15% | `error` | `1.0` |
| Hyprland active border | `primary` → `tertiary` gradient, 45° | — |
| Hyprland inactive border | `outline` | `0.35` |

### Contrast floor

Any text role over its background must clear **4.5:1**. matugen's tone mapping
gets this right for generated palettes; `check.sh` verifies it anyway and
fails loudly, because the one real risk of wallpaper-driven colour is a
beautiful wallpaper that produces an unreadable terminal.

### Blur

Islands and panels sit at 0.72–0.86 alpha over a Hyprland layer blur:

```lua
blur = { enabled = true, size = 6, passes = 3, noise = 0.02,
         contrast = 1.0, brightness = 0.9, xray = false }
```

`passes = 3` at `size = 6` is the quality/cost sweet spot on Arc integrated
graphics. `xray = false` because with it on, blur samples the wallpaper
instead of the windows underneath, which looks wrong the moment a window is
behind the bar.

Kitty uses `background_opacity 0.88` — its *own* setting, so the background is
translucent and the glyphs stay fully opaque. This is the distinction v1 got
wrong by using a window-rule opacity, which faded the text too.

---

## 5. Typography

| Use | Font | Size | Weight |
| --- | --- | --- | --- |
| Bar, panels, all UI | Inter | `13` | 500 |
| Secondary / labels | Inter | `11` | 400 |
| Clock, percentages, all numerics | Inter, `tnum` on | `13` | 500 |
| Panel headings | Inter | `15` | 600 |
| Terminal, code, system monitor | JetBrains Mono Nerd | `11` | 400 |
| Icons | Nerd Font Symbols | `14` | — |

**Tabular figures are not optional on the clock.** Without `tnum`, Inter's
proportional digits make `14:11` narrower than `14:00`, and a centred clock
that jitters by two pixels every minute is the kind of thing you can't unsee.
In QML: `font.features: ({ "tnum": 1 })`.

---

## 6. What the design deliberately does not do

- **No hover-to-expand.** The top edge of the screen is where your cursor
  goes to reach browser tabs and window controls. An island that expands
  because you passed over it becomes an irritation within a day. Hover shows
  a small tooltip; that's all.
- **No screen dim behind panels.** Dimming implies modality. These panels are
  glanceable, and you should be able to read the window behind them.
- **No auto-hiding bar.** You asked for battery and network always visible;
  auto-hide is the direct opposite of that.
- **No window titles in the bar.** They change constantly and would make the
  one calm object on screen the busiest.
- **No smart gaps.** v1 stripped borders when a workspace held one window and
  you disliked it. One window looks like any other window.

---

## 7. Where the numbers live

Nothing above is hardcoded in QML. `config/quickshell/settings.json`:

```json
{
  "bar":    { "height": 46, "islandHeight": 34, "radius": 14,
              "sideMargin": 10, "topMargin": 6 },
  "notch":  { "restWidth": 168, "osdWidth": 240,
              "toastWidth": 400, "toastHeight": 76,
              "panelWidth": 440, "panelHeight": 560,
              "toastMs": 5000, "osdMs": 1600 },
  "motion": { "enabled": true, "expandMs": 260, "collapseMs": 180 },
  "theme":  { "mode": "wallpaper", "manual": "catppuccin-mocha",
              "scheme": "dark" },
  "wallpaper": { "dir": "~/Bilder/walls", "transition": "grow" },
  "modules": { "workspaces": true, "bluetooth": true,
               "volume": "when-changed", "cpu": false }
}
```

QuickShell watches this file and re-renders on save. A `Config` singleton
reads it; every component binds to `Config.notch.restWidth` and friends. QML
contains no magic numbers, and the theme pipeline and the settings panel can
both write to it safely.
