-- config.lua
-- Single source of truth for the tri-whistle: acoustics + geometry.
-- All lengths in mm. z = 0 is the labium edge of every chamber; the
-- instrument points down (-z), the mouthpiece is up (+z), finger holes
-- and windows face +y.

config = {}

-- Acoustics ---------------------------------------------------------------
config.a4 = 440.0
config.temperature_c = 25.0 -- air in a played whistle is warm; raise to sharpen

-- Window (mouth) end correction in mm. This is the one number that theory
-- cannot pin down for a fipple; print the calibrate view, measure, put the
-- value it reports here. nil = use the orifice estimate in tuning.lua.
config.window_correction = nil

-- Body ----------------------------------------------------------------------
config.bore = 13.0          -- bore diameter, same for all three chambers
config.wall = 2.0           -- outer wall (also the finger-hole chimney height)
config.septum = 2.0         -- wall between neighbouring bores
config.pitch = config.bore + config.septum -- bore centre spacing (x)

-- Fipple (identical in every chamber) ----------------------------------------
config.windway_width = 8.0   -- ~0.6 * bore
config.windway_height = 1.2
config.windway_straight = 14.0 -- straight run before the window (keep parallel)
config.window_length = 4.0     -- windway exit to labium edge
config.labium_angle = 16.0     -- ramp angle, degrees
config.beak_length = 22.0      -- converging part of the windways
config.beak_pitch = 11.0       -- windway spacing at the lips (< pitch)

-- Print split (most printers top out at 220-256 mm) --------------------------
config.joint_z = -80          -- head/body joint, below the labium ramps
config.joint_length = 15      -- tenon length
config.joint_wall = 1.2       -- tenon wall around each bore
config.joint_clearance = 0.15 -- radial; tune to your printer for a snug slip fit

-- Finger holes ----------------------------------------------------------------
config.hole_min = 4.0
config.hole_max = 9.5
config.hole_min_small = 2.5 -- semitone hole of a twin (recorders use ~2.5-3.5)
config.twin_holes = false  -- true: recorder-style double holes (exact semitones,
                           -- but wider finger spread; rerun optimize.lua)
config.twin_web = 1.2      -- material between the two holes of a twin
config.spacing_hand = 20.0  -- ideal hole spacing under one hand
config.spacing_break = 28.0 -- ideal gap between the hands (L ring -> R index)
config.hole_inset = 3.0    -- shift G/C holes toward the centre line (x)

-- Chambers, left to right when looking at the holes. Each chamber has two
-- holes: h1 (lower, opened first, +2 semitones) and h2 (upper, +4).
-- pos (mm from the labium) comes from optimize.lua; tuning.lua solves the
-- diameter. Set d instead of pos to fix the diameter and solve the position.
config.chambers = {
    {
        name = "G", root = "G5", x = -config.pitch,
        h2 = { pos = 121, finger = "L index" },
        h1 = { pos = 141, finger = "L middle" },
    },
    {
        name = "E", root = "E5", x = 0,
        h2 = { pos = 161, finger = "L ring" },
        h1 = { pos = 189, finger = "R index" },
    },
    {
        name = "C", root = "C5", x = config.pitch,
        h2 = { pos = 209, finger = "R middle" },
        h1 = { pos = 229, finger = "R ring" },
    },
}

return config
