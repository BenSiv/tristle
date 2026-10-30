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
config.bend_radius = 7.0    -- corner rounding of the coiled tubes

-- Fipple (identical in every chamber) ----------------------------------------
config.windway_width = 4.8   -- narrow, so the beak stays ~19 mm wide
config.windway_height = 1.1
config.windway_straight = 12.0 -- straight run before the window (keep parallel)
config.window_length = 3.5     -- windway exit to labium edge
config.labium_angle = 16.0     -- ramp angle, degrees
config.beak_length = 18.0      -- converging part of the windways
config.beak_web = 1.0          -- wall between windways at the lips
config.beak_wall = 1.2         -- outer beak wall beside the windways

-- Layout --------------------------------------------------------------------
-- Finger grid: two columns (left hand, right hand) x three rows (index,
-- middle, ring). Each row is one chamber, its tube running left -> right
-- across the front: left finger = h2 (upper, +4), right finger = h1
-- (lower, opened first, +2).
config.column_gap = 22.0    -- hole spacing across a row
config.row_pitch = 18.0     -- vertical spacing between rows
config.window_pitch = 13.0  -- window spacing (x) at the labia
config.bend_z = -32.0       -- where the drop tubes leave the vertical under the windows
config.back_y = -26.0       -- plane of the drop tubes behind the rows
config.mid_y = -13.0        -- plane of the traverses between rows and drops
config.row_entry_x = -22.0  -- where rows 1-2 turn onto the front
config.pillar_x = 35.0      -- G's drop down the left side (x = -pillar_x)
config.curl_y = -31.0       -- plane of C's U-curl, behind the skirt
config.skirt_back_y = -20.5 -- back wall of the open skirt (in front of the curl)
config.tail_stub = 3.0      -- minimum tail protrusion into the open skirt

-- Two-piece build: the joint crosses the three straight drops under the
-- windows. Pulling the head out flattens all three chambers together.
config.joint_z = -15.0        -- head/body split plane (below the labium ramps)
config.joint_length = 9.0     -- tenon length (must end above bend_z + bend_radius)
config.joint_wall = 1.2       -- tenon wall around each bore
config.joint_clearance = 0.15 -- radial; tune to your printer for a snug slip fit

-- Finger holes ----------------------------------------------------------------
config.hole_min = 3.5
config.hole_max = 8.5
config.hole_min_small = 2.5 -- semitone hole of a twin (recorders use ~2.5-3.5)
config.twin_holes = false   -- true: recorder-style double holes (exact semitones)
config.twin_web = 1.0       -- material between the two holes of a twin
config.hole_inset = 0.0     -- holes sit on the bore axis

-- Chambers, top row first. window_x places the window; pos fields are filled
-- in by layout.lua from the tube paths, tuning.lua then solves diameters.
config.chambers = {
    { name = "C", root = "C5", window_x = 13, x = 0,
      h2 = { finger = "L index" }, h1 = { finger = "R index" } },
    { name = "E", root = "E5", window_x = 0, x = 0,
      h2 = { finger = "L middle" }, h1 = { finger = "R middle" } },
    { name = "G", root = "G5", window_x = -13, x = 0,
      h2 = { finger = "L ring" }, h1 = { finger = "R ring" } },
}

return config
