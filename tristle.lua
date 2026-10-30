-- tristle.lua
-- Luametry model of the tristle (tri-whistle): three whistles (C5, E5, G5)
-- coiled into one compact two-piece body. Finger holes form two columns of
-- three (left hand, right hand); each row is one chamber. The tubes end
-- facing down inside an open skirt under the rows. Geometry comes from
-- config.lua, tube routes from layout.lua, hole sizes from tuning.lua.
--
--   luametry run tristle.lua             -> out/tristle.stl (print layout)
--   TRISTLE_VIEW=assembled luametry run tristle.lua -o out/assembled.stl
--   TRISTLE_VIEW=air       ...  just the air inside (bores, windways): shows the coil
--   TRISTLE_VIEW=calibrate ...  print layout without finger holes; measure
--                               the roots, then `luam tuning.lua calibrate`
--
-- Coordinates: z = 0 at the labium edges, mouthpiece +z, holes and windows
-- face +y (away from the player), player's left is -x.

const cad = require("cad")
here = string.match(debug.getinfo(1).source, "^@(.*[\\/])")
if here == nil then
    here = "./"
end
package.path = here .. "?.lua;" .. package.path
config = require("config")
tuning = require("tuning")
layout = require("layout")
path = require("path")

cfg = config
routes = layout.solve(cfg)
design = tuning.design(cfg)
frame = routes.frame

FN = 48
r = frame.r
r_out = frame.r_out
ww = cfg.windway_width
wh = cfg.windway_height
block_top = cfg.window_length + cfg.windway_straight -- end of straight windway
head_top = block_top + cfg.beak_length
ramp_len = (r_out + 1 - r) / math.tan(math.rad(cfg.labium_angle))
lip_pitch = ww + cfg.beak_web

joint_z = cfg.joint_z
joint_len = cfg.joint_length
tenon_r = r + cfg.joint_wall
socket_r = tenon_r + cfg.joint_clearance
collar_r = socket_r + 1.6

function box(x0, x1, y0, y1, z0, z1)
    return cad.translate(cad.cube({ size = { x1 - x0, y1 - y0, z1 - z0 } }), { x0, y0, z0 })
end

function rod(x, y, radius, z0, z1)
    c = cad.cylinder({ r = radius, h = z1 - z0, segments = FN })
    return cad.translate(c, { x, y, z0 })
end

function ball(p, radius)
    return cad.translate(cad.sphere({ r = radius, segments = 24 }), p)
end

-- Path samples worth keeping: ends and every change of direction.
function keypoints(p)
    out = { p.pts[1] }
    for i = 2, #p.pts - 1 do
        d1 = path.unit(path.sub(p.pts[i], out[#out]))
        d2 = path.unit(path.sub(p.pts[i + 1], p.pts[i]))
        dot = d1[1] * d2[1] + d1[2] * d2[2] + d1[3] * d2[3]
        if dot < 0.9995 then
            table.insert(out, p.pts[i])
        end
    end
    table.insert(out, p.pts[#p.pts])
    return out
end

-- Swept tube: hull of spheres between consecutive keypoints.
function pipe(pts, radius)
    parts = {}
    for i = 2, #pts do
        table.insert(parts, cad.hull({ ball(pts[i - 1], radius), ball(pts[i], radius) }))
    end
    return cad.union(parts)
end

-- Footprint of all tubes (x/y extremes of their centrelines).
function footprint()
    x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
    for _, c in ipairs(routes.chambers) do
        for _, p in ipairs(c.path.pts) do
            x0 = math.min(x0, p[1])
            x1 = math.max(x1, p[1])
            y0 = math.min(y0, p[2])
            y1 = math.max(y1, p[2])
        end
    end
    return x0, x1, y0, y1
end

fx0, fx1, fy0, fy1 = footprint()
z_bot = math.huge
for _, c in ipairs(routes.chambers) do
    z_bot = math.min(z_bot, c.end_point[3])
end
z_bot = z_bot - 4

-- Solid outline: convex hull of every tube's outer surface, the beak tip,
-- and straight-walled corners down to the flat bottom of the skirt.
function outer_hull()
    parts = {}
    for _, c in ipairs(routes.chambers) do
        for _, p in ipairs(keypoints(c.path)) do
            table.insert(parts, ball(p, r_out))
        end
    end
    tip_w = 3 * ww + 2 * cfg.beak_web + 2 * cfg.beak_wall
    table.insert(parts, box(-tip_w / 2, tip_w / 2, r - wh / 2 - 2.0, r + wh / 2 + 1.2, head_top - 0.5, head_top))
    for _, x in ipairs({ fx0, fx1 }) do
        for _, y in ipairs({ fy0, fy1 }) do
            table.insert(parts, rod(x, y, r_out, z_bot, frame.skirt_z))
        end
    end
    return cad.hull(parts)
end

-- Open skirt under the rows; the tube ends hang into it as short stubs.
function skirt()
    m = r_out - 3
    return box(fx0 - m, fx1 + m, fy0 - m, fy1 + m, z_bot - 1, frame.skirt_z)
end

function stubs()
    parts = {}
    for _, c in ipairs(routes.chambers) do
        e = c.end_point
        table.insert(parts, rod(e[1], e[2], r_out, e[3], frame.skirt_z + 1))
    end
    return cad.union(parts)
end

-- Labium ramp: triangle in the (y, z) plane, extruded along x. Points must
-- run counter-clockwise or extrude yields an inside-out (negative) solid.
function ramp(x)
    tri = { { r, 0 }, { r_out + 1, -ramp_len }, { r_out + 1, 0 } }
    s = cad.extrude(tri, ww)
    s = cad.rotate(s, { 90, 0, 0 })
    s = cad.rotate(s, { 0, 0, 90 })
    return cad.translate(s, { x - ww / 2, 0, 0 })
end

function finger_holes()
    cuts = {}
    for k, c in ipairs(design.chambers) do
        z = frame.rows[k]
        for _, h in ipairs({ { -frame.hx, c.h2.d }, { frame.hx, c.h1.d } }) do
            d = cad.cylinder({ r = h[2] / 2, h = r_out + 2, segments = FN })
            d = cad.rotate(d, { -90, 0, 0 })
            table.insert(cuts, cad.translate(d, { h[1], 0, z }))
        end
    end
    return cuts
end

-- Everything air: bores, fipples, tube ends and (unless calibrating) holes.
function air(with_holes)
    cuts = {}
    for k, c in ipairs(routes.chambers) do
        x = cfg.chambers[k].window_x
        table.insert(cuts, pipe(keypoints(c.path), r))
        table.insert(cuts, rod(x, 0, r, -1, cfg.window_length))
        e = c.end_point
        table.insert(cuts, rod(e[1], e[2], r, e[3] - 1, e[3] + 2))
        -- flatten the bore roof under the window so the labium edge is straight
        table.insert(cuts, box(x - ww / 2, x + ww / 2, 0, r, -(ramp_len + 3), cfg.window_length))
        table.insert(cuts, box(x - ww / 2, x + ww / 2, 0, r_out + 1, 0, cfg.window_length))
        table.insert(cuts, ramp(x))
        -- windway: straight run, then converging to the narrow lip plate
        table.insert(cuts, box(x - ww / 2, x + ww / 2, r - wh / 2, r + wh / 2, cfg.window_length - 0.01, block_top))
        lip_x = 0
        if x < 0 then
            lip_x = -lip_pitch
        elseif x > 0 then
            lip_x = lip_pitch
        end
        table.insert(cuts, cad.hull({
            box(x - ww / 2, x + ww / 2, r - wh / 2, r + wh / 2, block_top - 0.01, block_top),
            box(lip_x - ww / 2, lip_x + ww / 2, r - wh / 2, r + wh / 2, head_top, head_top + 1),
        }))
    end
    if with_holes == true then
        for _, c in ipairs(finger_holes()) do
            table.insert(cuts, c)
        end
    end
    return cad.union(cuts)
end

-- Hull of one rod per window, clipped to [z0, z1] (tenon, socket, collar).
function bundle(radius, z0, z1)
    rods = {}
    for _, ch in ipairs(cfg.chambers) do
        table.insert(rods, rod(ch.window_x, 0, radius, z0, z1))
    end
    return cad.hull(rods)
end

function build(with_holes)
    shell = cad.union({ cad.difference({ outer_hull(), skirt() }), stubs() })
    holes = air(with_holes)
    far = 1000
    head = cad.union({
        cad.intersection({ shell, box(-far, far, -far, far, joint_z, far) }),
        bundle(tenon_r, joint_z - joint_len, joint_z + 0.01),
    })
    body = cad.union({
        cad.intersection({ shell, box(-far, far, -far, far, -far, joint_z) }),
        bundle(collar_r, joint_z - joint_len - 3, joint_z),
    })
    head = cad.difference({ head, holes })
    body = cad.difference({ body, bundle(socket_r, joint_z - joint_len - 0.5, joint_z + 1), holes })
    return head, body
end

view = os.getenv("TRISTLE_VIEW")
if view == "air" then
    return air(true)
end
head, body = build(view != "calibrate")

if view == "assembled" then
    return cad.union({ head, body })
end
-- Print layout (default and calibrate): head standing on its tenon, body
-- upside down on its joint face, skirt opening upward.
head_print = cad.translate(head, { 0, 0, -(joint_z - joint_len) })
body_print = cad.rotate(body, { 180, 0, 0 })
body_print = cad.translate(body_print, { 0, (fy1 - fy0) + 2 * collar_r + 15, joint_z })
return cad.union({ head_print, body_print })
