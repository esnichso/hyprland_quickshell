-- Monitors.
--
-- The VM and the ThinkPad are deliberately configured to the same LOGICAL
-- resolution, so what you see in the VM is the size things will actually be on
-- metal:
--
--   VM        2048x1280 @ scale 1     -> 2048x1280 logical
--   ThinkPad  2560x1600 @ scale 1.25  -> 2048x1280 logical
--
-- Every pixel value in DESIGN.md is expressed in those logical pixels.
--
-- OPEN QUESTION (see CLAUDE.md): v1 used scale 1.6 on this panel, giving
-- 1600x1000. Both divide cleanly. Neither has been looked at on the real
-- display. If 1.6 wins in Phase 3, the numbers in DESIGN.md need rescaling.

-- Fallback for anything not matched below — the VM, an external display, or a
-- panel we have not seen yet. `preferred` takes the display's native mode.
hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = 1,
})

-- The ThinkPad's internal panel. Commented out until the scale question is
-- settled on metal; until then the fallback above drives it at scale 1, which
-- is readable but small.
--
-- hl.monitor({
--   output   = "eDP-1",
--   mode     = "2560x1600@60",
--   position = "auto",
--   scale    = 1.25,
-- })
