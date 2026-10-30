-- config.lua
-- Single source of truth for the tristle (tri-whistle): acoustics + geometry.
-- All lengths in mm. z = 0 is the labium edge of every chamber, mouthpiece
-- up (+z). Finger holes and windows face +y (away from the player); the
-- player's left is -x.

config = {}

-- Acoustics ---------------------------------------------------------------
config.a4 = 440.0
config.temperature_c = 25.0 -- air in a played whistle is warm; raise to sharpen

-- Window (mouth) end correction in mm. This is the one number that theory
-- cannot pin down for a fipple; print the calibrate view, measure, put the
-- value it reports here. nil = use the orifice estimate in tuning.lua.
config.window_correction = nil

-- Bore ----------------------------------------------------------------------
config.bore = 11.0          -- bore diameter, same for all three chambers
config.wall = 1.6           -- outer wall (also the finger-hole chimney height)
config.tube_gap = 13.0      -- minimum centre-to-centre distance between tubes
config.bend_radius = 7.0    -- corner rounding of the tubes

-- Fipple (identical in every chamber) ----------------------------------------
config.windway_width = 4.8   -- narrow, so the three slits span ~19 mm at the lips
config.windway_height = 1.1
config.windway_straight = 12.0 -- straight run before the window (keep parallel)
config.window_length = 3.5     -- windway exit to labium edge
config.labium_angle = 16.0     -- ramp angle, degrees
config.beak_length = 24.0      -- mouthpiece taper; keeps its overhang < 45 deg
config.beak_web = 1.0          -- wall between windways at the lips
config.tip_width = 26.0        -- flat mouth end (the head prints standing on it)
config.tip_depth = 10.0

-- Jet speed per chamber. All three windways share one blowing pressure, but
-- a lower note wants a slower jet (as organ pipes on one wind chest do).
-- Each lower chamber gets a narrow inlet slit at the lips that opens
-- abruptly into its full-width windway; the expansion loses pressure, so
-- the jet leaves the windway slower. jet_match = 1 aims for jet speed in
-- proportion to pitch, 0 leaves every inlet full width. A chamber's own
-- inlet_width (mm) overrides the computed one. Head-only change: the body
-- and its tuning are unaffected.
config.jet_match = 1.0
config.inlet_length = 3.0      -- length of the narrow slit before it opens out

-- Finger grid -----------------------------------------------------------------
-- Two columns (left hand, right hand) x three rows (index, middle, ring),
-- one chamber per row, its tube running left -> right across the front:
-- left finger = h2 (+4), right finger = h1 (opened first, +2). Each row's
-- hole gap is the chamber's natural spacing for hole_target holes, so rows
-- widen going down (G top, C bottom).
config.hole_target = 5.0    -- design finger holes at this diameter (per-chamber hole_d overrides)
config.row_pitch = 18.0     -- vertical spacing between rows

-- Tube routing (see layout.lua) -------------------------------------------
config.bend_z = -32.0       -- tubes leave the vertical under the windows here
config.row_drop = 30.0      -- extra drop from bend_z to the top row
config.mid_y = -13.0        -- plane of the traverses between rows and drops
config.back_y = -32.0       -- flat back face; every tube end opens here
config.drop_x = { -24.5, -8.5, 4.5 } -- drop column per chamber (top row first)
config.drop_depth = 10.5    -- E and C drop this far behind mid_y (G's depth is solved)

-- Two-piece build. The joint crosses the three straight drops under the
-- windows and doubles as a tuning slide: pulling the head out flattens all
-- three chambers together. Both parts print upside down.
config.joint_z = -15.0        -- head/body split plane (below the labium ramps)
config.joint_length = 9.0     -- tenon length (must end above bend_z + bend_radius)
config.joint_wall = 1.6       -- tenon wall around each bore
config.joint_clearance = 0.15 -- radial; tune to your printer for a snug slip fit

-- Finger holes ----------------------------------------------------------------
config.hole_min = 3.5
config.hole_max = 8.5
config.hole_min_small = 2.5 -- semitone hole of a twin (recorders use ~2.5-3.5)
config.twin_holes = false   -- true: recorder-style double holes (exact semitones)
config.twin_web = 1.0       -- material between the two holes of a twin
config.hole_inset = 0.0     -- holes sit on the bore axis

-- Chambers, top row first. window_x places the window; hole positions are
-- filled in by layout.lua, tuning.lua then solves the diameters.
config.chambers = {
    { name = "G", root = "G5", window_x = -13, x = 0, hole_d = 4.0,
      h2 = { finger = "L index" }, h1 = { finger = "R index" } },
    { name = "E", root = "E5", window_x = 0, x = 0,
      h2 = { finger = "L middle" }, h1 = { finger = "R middle" } },
    { name = "C", root = "C5", window_x = 13, x = 0,
      h2 = { finger = "L ring" }, h1 = { finger = "R ring" } },
}

return config
