-- Window, workspace and layer rules.

------------------------------------------------------------------ layer rules

-- The shell's own surfaces. Namespaces must match what shell.qml sets via
-- WlrLayershell.namespace, and you should confirm them against `hyprctl layers`
-- in a running session rather than trusting this comment — v1 shipped a layer
-- rule that matched nothing for exactly that reason, and the blur silently
-- never applied.
hl.layer_rule({ match = { namespace = "hypersetup-bar" },   blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "hypersetup-panel" }, blur = true, ignore_alpha = 0.1 })

----------------------------------------------------------------- window rules

-- Float dialogs and pickers rather than tiling them into the layout.
hl.window_rule({ match = { title = "^(Open|Save|Select) .*" },     float = true })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk)$" }, float = true })
hl.window_rule({ match = { class = "^(org.gnome.Calculator)$" },   float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" },        float = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" },   float = true })
hl.window_rule({ match = { class = "^(pavucontrol)$" },            float = true })

-- Picture-in-picture: floating, pinned above workspaces, no border.
-- `border_size = 0`, not `no_border` — that one is a WORKSPACE rule, not a
-- window rule.
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" },
                 float = true, pin = true, border_size = 0, size = { 480, 270 } })

-- Thunar's bulk-rename and progress dialogs — every thunar window whose title
-- is not the plain file manager.
--
-- Hyprland matches with Google's RE2, which has NO lookahead: the obvious
-- `^(?!Thunar$).*` is a syntax error, not a non-match. RE2 negation is a
-- `negative:` prefix on the whole pattern instead.
hl.window_rule({ match = { class = "^(thunar)$", title = "negative:^Thunar$" }, float = true })

-- Zen and Firefox open a sharing indicator that is 40px tall and would
-- otherwise take a tile.
hl.window_rule({ match = { title = ".*is sharing (your screen|a window)\\." },
                 float = true, no_focus = true })

-- No shadow on tiled windows: the gap is only 6px, so shadows from neighbours
-- overlap and muddy the gutter. Floating windows keep theirs.
hl.window_rule({ match = { float = false }, no_shadow = true })

-- Never idle-inhibit for a maximised video player by accident; do inhibit for
-- actual fullscreen playback.
hl.window_rule({ match = { fullscreen = true }, idle_inhibit = "fullscreen" })

-------------------------------------------------------------- workspace rules

-- Scratchpad gets no gaps so a terminal dropped into it fills the overlay.
hl.workspace_rule({ workspace = "special:scratchpad", gaps_in = 0, gaps_out = 12, on_created_empty = "kitty" })

-- NOTE: no "smart gaps". A single window on a workspace looks like any other
-- window, borders and all. v1 stripped the frame in that case and it was
-- disliked; the rules are deliberately absent rather than commented out.
