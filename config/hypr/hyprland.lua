-- hypersetup2 — Hyprland entry point
--
-- Hyprland 0.55+ is Lua. hyprlang is deprecated and this file will not load on
-- anything older; check `hyprctl version` before debugging anything else.
--
-- Every require is wrapped in pcall. This is not defensive habit — it is a
-- specific fix. Hyprland reloads the instant a file in this tree changes, and
-- `git pull` rewrites files one at a time, so a reload can land while a module
-- is momentarily missing. Without the guard that drops the session into
-- emergency mode with no keybinds at all. require's own error isolation does
-- not cover module lookup failure.

local modules = {
  "conf.env",       -- environment, before anything launches
  "conf.monitors",  -- outputs and scaling
  "conf.looks",     -- gaps, borders, blur, animations
  "conf.input",     -- keyboard, touchpad, gestures
  "conf.rules",     -- window and workspace rules
  "conf.binds",     -- keybindings
  "conf.autostart", -- what starts with the session
}

local failed = {}

for _, m in ipairs(modules) do
  local ok, err = pcall(require, m)
  if not ok then
    failed[#failed + 1] = m
    -- Goes to the Hyprland log: `hyprctl rollinglog` or the journal.
    print("hypersetup2: " .. m .. " FAILED: " .. tostring(err))
  end
end

-- Surface it visually too, once a notification daemon exists. This runs
-- through sh, so it is harmless if notify-send is missing or nothing is
-- listening yet — but when the shell is up, a broken module is impossible to
-- miss instead of being a silently absent keybind.
if #failed > 0 then
  hl.on("hyprland.start", function()
    hl.exec_cmd(string.format(
      "sleep 3; command -v notify-send >/dev/null && " ..
      "notify-send -u critical 'hypersetup2' 'Config modules failed: %s'",
      table.concat(failed, ", ")))
  end)
end
