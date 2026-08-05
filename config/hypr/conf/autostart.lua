-- What starts with the session.
--
-- This fires on `hyprland.start` ONLY. `hyprctl reload` re-reads the config but
-- does not re-run this, so anything added here needs a fresh login before it
-- runs. Say so rather than letting it look broken.

hl.on("hyprland.start", function()
  -- Polkit agent. Without it, anything asking for privileges (mounting a disk,
  -- a GUI package manager) silently fails instead of prompting.
  hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

  -- Wallpaper daemon. The picker drives it live over `hyprctl hyprpaper`, but
  -- that lasts only as long as the process — what survives a logout is
  -- ~/.config/hypr/hyprpaper.conf, which install.sh rewrites on every
  -- wallpaper change and hyprpaper reads here. Without that file this starts
  -- bare, which is how the wallpaper used to be lost at every login.
  hl.exec_cmd("hyprpaper")

  -- Clipboard: cliphist stores history for the launcher, wl-clip-persist keeps
  -- content alive after the source window closes.
  hl.exec_cmd("wl-paste --type text  --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("wl-clip-persist --clipboard regular")

  -- Removable media automount.
  hl.exec_cmd("udiskie --no-automount --smart-tray")

  -- Night light. Runs as a daemon doing nothing until a profile or the
  -- control centre sets a temperature; the control centre drives it over
  -- `hyprctl hyprsunset`, which needs it already running.
  hl.exec_cmd("hyprsunset")

  -- Idle management: dim, lock, suspend.
  hl.exec_cmd("hypridle")

  -- The shell. Everything visible comes from this one process.
  hl.exec_cmd("uwsm app -- qs")
end)
