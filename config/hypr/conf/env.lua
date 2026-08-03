-- Environment variables.
--
-- Session-wide variables belong in config/uwsm/env instead — those are set
-- before the compositor starts, which some toolkits require. What is here is
-- only what Hyprland itself needs to export to its children.

-- Cursor. Size must match the GTK/Qt setting or you get two different cursors
-- depending on which surface you are over.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Qt: use the Wayland backend, and let qt6ct apply the generated palette.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Firefox-family (Zen) on Wayland natively rather than through XWayland.
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron apps: Wayland with hardware acceleration.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Intel Arc / Arrow Lake. VA-API through the iHD driver; without this,
-- hardware video decode silently falls back to software and the fans spin up
-- on every video call. Verify with `vainfo`.
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Tell toolkits this is a Hyprland session so portals resolve correctly.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
