-- Keybindings. The authoritative map is KEYBINDS.md; this file and that
-- document must agree, and check.sh diffs them against `hyprctl binds`.
--
-- German QWERTZ. The constraints that shaped this map:
--   [ and ] are AltGr+8 / AltGr+9        -> never bound
--   ` and ´ are dead keys                -> never bound
--   Y and Z are swapped vs US            -> Y is bottom-left, adjacent to X
--   Ö Ä Ü and < are free and reachable
--   there is no Print key on this laptop

local mod = "SUPER"

-- Launch GUI apps through uwsm so each gets its own systemd scope. A crashing
-- app then cannot take the session with it, and `systemctl --user status`
-- shows you what is actually running.
local function app(cmd)
  return hl.dsp.exec_cmd("uwsm app -- " .. cmd)
end

-- Ask the shell to do something. One IPC path for every panel, so adding a
-- panel never means inventing a new mechanism.
--
-- No `-c`: this repo symlinks config/quickshell to ~/.config/quickshell, so
-- shell.qml sits at the base of that directory. Quickshell then registers it
-- as the DEFAULT config and ignores subdirectories entirely -- `-c <name>`
-- looks for ~/.config/quickshell/<name>/shell.qml, which does not exist.
local function shell(target)
  return hl.dsp.exec_cmd("qs ipc call panels toggle " .. target)
end

local terminal    = "kitty"
local fileManager = "thunar"
local browser     = "zen-browser"

--------------------------------------------------------------------- launching

hl.bind(mod .. " + Return", app(terminal))
hl.bind(mod .. " + E",      app(fileManager))
hl.bind(mod .. " + B",      app(browser))
-- Some ThinkPads have a star key. Harmless if this one does not.
hl.bind("XF86Favorites",    shell("launcher"))

------------------------------------------------------------------ shell panels

hl.bind(mod .. " + SPACE",         shell("launcher"))
hl.bind(mod .. " + N",             shell("dashboard"))
hl.bind(mod .. " + I",             shell("control"))
hl.bind(mod .. " + P",             shell("power"))
hl.bind(mod .. " + V",             shell("clipboard"))
hl.bind(mod .. " + period",        shell("emoji"))
hl.bind(mod .. " + SHIFT + M",     shell("sysmon"))
hl.bind(mod .. " + ALT + W",       shell("wallpaper"))
hl.bind(mod .. " + SHIFT + N",     shell("dnd"))

-- Lock is on Escape, not L: L is needed for focus-right, and lock belongs away
-- from anything you press by accident. Caps Lock is Escape, so this is a
-- comfortable one-handed chord.
hl.bind(mod .. " + Escape",        hl.dsp.exec_cmd("hyprlock"))

----------------------------------------------------------------------- windows

hl.bind(mod .. " + Q",             hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q",     hl.dsp.window.kill())
hl.bind(mod .. " + W",             hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F",             hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + SHIFT + F",     hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
hl.bind(mod .. " + C",             hl.dsp.window.center())
hl.bind(mod .. " + T",             hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + SHIFT + P",     hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind(mod .. " + O",             hl.dsp.window.pin({ action = "toggle" }))
hl.bind(mod .. " + Tab",           hl.dsp.window.cycle_next({ next = true }))
hl.bind(mod .. " + SHIFT + Tab",   hl.dsp.window.cycle_next({ next = false }))

------------------------------------------------------------ groups (tabbed)

hl.bind(mod .. " + G",             hl.dsp.group.toggle())
hl.bind(mod .. " + SHIFT + G",     hl.dsp.window.move({ out_of_group = true }))
-- Y and X are adjacent on QWERTZ (Y X C V B) and both free. This is the fix
-- for v1's [ and ] problem.
hl.bind(mod .. " + Y",             hl.dsp.group.prev())
hl.bind(mod .. " + X",             hl.dsp.group.next())

------------------------------------------------------- focus, move, resize

-- hjkl and arrows both. Use the arrows while hjkl sinks in, then delete the
-- arrow block below.
local dirs = { H = "left", J = "down", K = "up", L = "right" }
for key, dir in pairs(dirs) do
  hl.bind(mod .. " + " .. key,             hl.dsp.focus({ direction = dir }))
  hl.bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ direction = dir, group_aware = true }))
end

local arrows = { left = "left", down = "down", up = "up", right = "right" }
for key, dir in pairs(arrows) do
  hl.bind(mod .. " + " .. key,             hl.dsp.focus({ direction = dir }))
  hl.bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ direction = dir, group_aware = true }))
end

-- Resize in 40px steps.
local resize = {
  H = { -40, 0 }, J = { 0, 40 }, K = { 0, -40 }, L = { 40, 0 },
  left = { -40, 0 }, down = { 0, 40 }, up = { 0, -40 }, right = { 40, 0 },
}
for key, d in pairs(resize) do
  hl.bind(mod .. " + CTRL + " .. key,
          hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }))
end

-- Mouse. 272 is left button, 273 is right.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-------------------------------------------------------------------- workspaces

for i = 1, 10 do
  local key = i % 10  -- workspace 10 is on the 0 key
  hl.bind(mod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i, follow = true }))
end

hl.bind(mod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))
hl.bind(mod .. " + CTRL + left",  hl.dsp.focus({ workspace = "-1" }))
hl.bind(mod .. " + mouse_down",   hl.dsp.focus({ workspace = "+1" }))
hl.bind(mod .. " + mouse_up",     hl.dsp.focus({ workspace = "-1" }))

-- The key left of Y on a German keyboard. No US equivalent, so it is free.
hl.bind(mod .. " + less",         hl.dsp.focus({ urgent_or_last = true }))

-- Scratchpad. SUPER+S and SUPER+SHIFT+S are different bindings, so the
-- screenshot bind below does not collide with this.
hl.bind(mod .. " + S",            hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mod .. " + CTRL + S",     hl.dsp.window.move({ workspace = "special:scratchpad" }))

--------------------------------------------------- screenshots and recording

-- No Print key on this keyboard, so nothing depends on one. The Print binds
-- are here anyway for when an external keyboard is docked.
local shot_region = "grim -g \"$(slurp -d)\" - | satty --filename - --output-filename " ..
                    "\"$HOME/Bilder/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png\""
local shot_full   = "grim - | satty --filename - --output-filename " ..
                    "\"$HOME/Bilder/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png\""
local shot_clip   = "grim -g \"$(slurp -d)\" - | wl-copy"

hl.bind(mod .. " + SHIFT + S",  hl.dsp.exec_cmd(shot_region))
hl.bind(mod .. " + SHIFT + D",  hl.dsp.exec_cmd(shot_full))
hl.bind(mod .. " + SHIFT + C",  hl.dsp.exec_cmd(shot_clip))
hl.bind("Print",                hl.dsp.exec_cmd(shot_region))
hl.bind("SHIFT + Print",        hl.dsp.exec_cmd(shot_full))

hl.bind(mod .. " + SHIFT + X",  hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mod .. " + SHIFT + R",  hl.dsp.exec_cmd(
  "pkill -INT wf-recorder || wf-recorder -g \"$(slurp)\" " ..
  "-f \"$HOME/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4\""))

------------------------------------------------------------------ hardware keys

-- `locked` makes these work on the lock screen; `repeating` makes holding them
-- ramp. Both are what you want for volume and brightness.
local hw = { locked = true, repeating = true }

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), hw)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      hw)
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     hw)
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   hw)

-- Brightness tells the shell it changed. Volume does not need to: the shell
-- watches PipeWire directly and reacts to any change, whoever made it. sysfs
-- has no equivalent — its change notifications are unreliable enough that
-- watching them would work on some kernels and silently never fire on others.
local function osd(kind) return "qs ipc call osd show " .. kind end

hl.bind("XF86MonBrightnessUp",
        hl.dsp.exec_cmd("brightnessctl set 5%+ && " .. osd("brightness")), hw)
hl.bind("XF86MonBrightnessDown",
        hl.dsp.exec_cmd("brightnessctl set 5%- && " .. osd("brightness")), hw)

-- Keyboard backlight. METAL ONLY — a VM has no such LED, and whether these
-- keysyms are even emitted on the E16 Gen 3 is unverified. Check with `wev`.
hl.bind("XF86KbdBrightnessUp",
        hl.dsp.exec_cmd("brightnessctl -d '*kbd_backlight' set +1 && " .. osd("keyboard")), hw)
hl.bind("XF86KbdBrightnessDown",
        hl.dsp.exec_cmd("brightnessctl -d '*kbd_backlight' set 1- && " .. osd("keyboard")), hw)

hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), hw)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       hw)
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   hw)

-- Seek WITHIN the track, as opposed to changing it. This laptop has no
-- dedicated seek keys, so they hang off Shift with the same media keys —
-- next/previous is the track, shift+next/previous is ten seconds. `repeating`
-- from `hw` makes holding one scrub.
--
-- playerctl rather than the shell: seeking has to work whether or not the
-- dashboard is open, and `10+`/`10-` is playerctl's own relative syntax.
hl.bind("SHIFT + XF86AudioNext", hl.dsp.exec_cmd("playerctl position 10+"), hw)
hl.bind("SHIFT + XF86AudioPrev", hl.dsp.exec_cmd("playerctl position 10-"), hw)
hl.bind("XF86Search",     shell("launcher"))
