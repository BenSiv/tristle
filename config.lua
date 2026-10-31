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

-- Mouthpiece: one round inlet at the lips feeds all three chambers, so
-- they share exactly the same pressure. Below it a round channel per
-- chamber runs down to its window; the last few mm taper smoothly from
-- round to a flat jet slit aimed at the labium.
config.inlet_d = 8.0           -- mouth inlet (area > all three jets together)
config.inlet_length = 8.0      -- straight inlet channel before it branches
config.duct_d = 5.0            -- round channel to each chamber
config.duct_angle = 35.0       -- max tilt from vertical (prints without support)
config.tip_width = 20.0        -- flat mouth end around the inlet (the head
config.tip_depth = 12.0        -- prints standing on it)

-- Jet and labium (identical in every chamber)
config.windway_width = 7.0     -- jet / window width; wide = louder, prints cleaner
config.windway_height = 1.1    -- jet thickness
config.nozzle_taper = 5.0      -- round channel -> flat slit transition
config.windway_straight = 6.0  -- flat straight slit before the window
config.window_length = 2.0     -- jet exit to labium at the window's sides
config.labium_arc = 2.5        -- labium is an arc (like a quena notch) dipping
                               -- this far at its centre, so it prints as a
                               -- self-supporting arch instead of a flat bridge
config.labium_angle = 16.0     -- ramp angle, degrees

-- Jet speed per chamber. The pressure is shared, but a lower note wants a
-- slower jet (as organ pipes on one wind chest do). Each lower chamber's
-- channel starts with a short narrow orifice that opens abruptly into the
-- channel; the expansion loses pressure, so its jet comes out slower.
-- jet_match = 1 aims for jet speed in proportion to pitch, 0 leaves every
-- channel open. A chamber's own orifice_d (mm) overrides the computed one.
config.jet_match = 1.0
config.orifice_length = 3.0    -- length of the narrow part before it opens out

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
config.row_drop = 35.0      -- extra drop from bend_z to the top row
config.mid_y = -13.0        -- plane of the traverses between rows and drops
config.back_y = -32.0       -- flat back face; every tube end opens here
config.drop_x = { -24.5, -8.5, 4.5 } -- drop column per chamber (top row first)
config.drop_depth = 10.3    -- E and C drop this far behind mid_y (G's depth is solved)

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
