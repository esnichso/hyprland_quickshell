-- Keyboard, pointer, touchpad, gestures.

hl.config({
  input = {
    kb_layout = "de",
    -- Caps Lock becomes Escape. The real Escape keeps working. This is the
    -- single highest-value remap on a laptop keyboard and every keybind in
    -- KEYBINDS.md assumes it.
    kb_options = "caps:escape",

    follow_mouse = 1,
    -- Moving the mouse over a window focuses it, but does NOT raise or warp
    -- focus while you are typing into a floating window.
    mouse_refocus = false,

    sensitivity = 0,

    touchpad = {
      natural_scroll         = true,
      disable_while_typing   = true,
      tap_to_click           = true,
      drag_lock              = true,
      -- Two-finger scroll speed. The default is slow enough to be annoying on
      -- a 16" panel.
      scroll_factor          = 1.1,
      clickfinger_behavior   = true,
    },
  },

  gestures = {
    -- NOTE: `workspace_swipe` and `workspace_swipe_fingers` no longer exist.
    -- They were removed in favour of the hl.gesture() system below; what stays
    -- here is only the tuning for the swipe once a gesture triggers it.
    workspace_swipe_distance         = 300,
    workspace_swipe_cancel_ratio     = 0.4,
    workspace_swipe_min_speed_to_force = 20,
    -- Do not wrap from workspace 10 back to 1 — overshooting a swipe should
    -- stop, not teleport across the whole set.
    workspace_swipe_create_new       = false,
  },

  cursor = {
    -- Hide the pointer while typing; it reappears on the next mouse movement.
    hide_on_key_press = true,
    -- Do not warp the cursor to a newly focused window. Keyboard focus moving
    -- should not move the mouse out from under your hand.
    no_warps          = true,
  },
})

-- Gestures are declared, not configured. The old `gestures.workspace_swipe`
-- boolean was replaced by this system, which can bind any gesture to any
-- action rather than hardcoding workspace switching.
hl.gesture({
  fingers   = 3,
  direction = "horizontal",
  action    = "workspace",
})
