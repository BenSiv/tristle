-- tristle.lua
-- Luametry model of the tristle (tri-whistle): three whistles (C5, E5, G5)
-- coiled into one compact two-piece body. Finger holes form two columns
-- of three rows, one chamber per row, rows widening going down (G, E, C).
-- Every tube opens on the flat back face. Geometry comes from config.lua,
-- tube routes from layout.lua, hole sizes from tuning.lua.
--
-- Built to print upside down without support: vertical tubes are round,
-- every other tube run has a pointed (teardrop) roof facing the foot,
-- which is "up" on the printer.
--
--   ./export.sh                          -> out/head.stl, out/body.stl, ... (one file per part)
--   luametry run tristle.lua             -> out/tristle.stl (both parts, print layout)
--   TRISTLE_PART=head|body ...           one part only, in print orientation
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
orifices = tuning.orifices(cfg)

FN = 48
r = cfg.bore / 2
r_out = r + cfg.wall
ww = cfg.windway_width
wh = cfg.windway_height
ramp_len = (r_out + 1 - r) / math.tan(math.rad(cfg.labium_angle))
sag = cfg.labium_arc

-- Mouthpiece air path, bottom up: window, flat jet slit, round-to-flat
-- taper, round channel, branch point inside the inlet channel, inlet.
slit_top = cfg.window_length + cfg.windway_straight
duct_end = slit_top + cfg.nozzle_taper
duct_r = cfg.duct_d / 2
inlet_r = cfg.inlet_d / 2
duct_y = r + wh / 2 - duct_r - 0.6  -- channel tucked behind the jet slit
side_x = 0
for _, ch in ipairs(cfg.chambers) do
    side_x = math.max(side_x, math.abs(ch.window_x))
end
branch_x = inlet_r - duct_r + 0.5  -- side channels start inside the inlet
branch_z = duct_end + (side_x - branch_x) / math.tan(math.rad(cfg.duct_angle))
head_top = branch_z + cfg.inlet_length
inlet_y = duct_y - 1.5 -- a little further back than the channels: keeps the front wall
tip_y = inlet_y

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

-- Sphere with a 45-degree point below it: swept horizontally it gives a
-- teardrop channel whose roof prints without support when inverted.
function tear(p, radius)
    tipp = { p[1], p[2], p[3] - radius * math.sqrt(2) }
    return { ball(p, radius), ball(tipp, 0.2) }
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

-- Swept bore: hull of teardrops between consecutive keypoints.
function bore_pipe(pts)
    parts = {}
    for i = 2, #pts do
        a = tear(pts[i - 1], r)
        b = tear(pts[i], r)
        table.insert(parts, cad.hull({ a[1], a[2], b[1], b[2] }))
    end
    return cad.union(parts)
end

-- Solid outline: convex hull of every tube's outer surface and its mirror
-- image (so the outside is symmetric) plus the mouth end, cut flat at the
-- back face where the tubes open. The outer surface is teardrop-shaped
-- like the bores, so their pointed roofs stay covered.
function outer()
    parts = {}
    for _, c in ipairs(routes.chambers) do
        for _, p in ipairs(keypoints(c.path)) do
            for _, q in ipairs({ p, { -p[1], p[2], p[3] } }) do
                for _, piece in ipairs(tear(q, r_out)) do
                    table.insert(parts, piece)
                end
            end
        end
    end
    half = (cfg.tip_width - cfg.tip_depth) / 2
    table.insert(parts, rod(-half, tip_y, cfg.tip_depth / 2, head_top - 0.01, head_top))
    table.insert(parts, rod(half, tip_y, cfg.tip_depth / 2, head_top - 0.01, head_top))
    return cad.intersection({ cad.hull(parts), box(-500, 500, cfg.back_y, 500, -500, 500) })
end

-- Labium edge height across the window: a circular arc through the
-- window's corners (z = 0) dipping `sag` at the centre.
function labium_z(dx)
    if sag <= 0 then
        return 0
    end
    rr = (ww * ww / 4 + sag * sag) / (2 * sag)
    return (rr - sag) - math.sqrt(rr * rr - dx * dx)
end

-- Thin slice of the labium ramp at edge height ze: triangle in the (y, z)
-- plane, extruded along x. Points must run counter-clockwise or extrude
-- yields an inside-out (negative) solid.
function ramp_slice(x, ze)
    tri = { { r, 0 }, { r_out + 1, -ramp_len }, { r_out + 1, 0 } }
    s = cad.extrude(tri, 0.01)
    s = cad.rotate(s, { 90, 0, 0 })
    s = cad.rotate(s, { 0, 0, 90 })
    return cad.translate(s, { x - 0.005, 0, ze })
end

-- Window and labium for the chamber whose window is centred at x: slices
-- across the width, each pair hulled, so the arched edge and its ramp are
-- smooth ruled surfaces.
function window_cuts(x)
    n = 16
    cols, ramps = {}, {}
    for i = 0, n do
        dx = -ww / 2 + ww * i / n
        ze = labium_z(dx)
        table.insert(cols, box(x + dx - 0.005, x + dx + 0.005, 0, r_out + 1, ze, cfg.window_length))
        table.insert(ramps, ramp_slice(x + dx, ze))
    end
    parts = {}
    for i = 2, #cols do
        table.insert(parts, cad.hull({ cols[i - 1], cols[i] }))
        table.insert(parts, cad.hull({ ramps[i - 1], ramps[i] }))
    end
    return parts
end

function capsule(a, b, radius)
    return cad.hull({ ball(a, radius), ball(b, radius) })
end

-- Air path from the shared inlet to chamber k's jet slit: round channel
-- (starting with this chamber's orifice), smooth taper to the flat slit.
function mouth_air(k, x)
    cuts = {}
    start = { 0, inlet_y, branch_z }
    if x != 0 then
        start = { x / math.abs(x) * branch_x, inlet_y, branch_z }
    end
    stop = { x, duct_y, duct_end }
    dir = path.unit(path.sub(stop, start))
    od = orifices[k].d
    -- the orifice runs from inside the inlet to orifice_length past its wall
    o_end = path.add(start, path.mul(dir, inlet_r + cfg.orifice_length))
    table.insert(cuts, capsule(start, o_end, od / 2))
    table.insert(cuts, capsule(o_end, stop, duct_r))
    table.insert(cuts, cad.hull({
        ball(stop, duct_r),
        box(x - ww / 2, x + ww / 2, r - wh / 2, r + wh / 2, slit_top - 0.01, slit_top),
    }))
    table.insert(cuts, box(x - ww / 2, x + ww / 2, r - wh / 2, r + wh / 2, cfg.window_length - 0.01, slit_top))
    return cuts
end

function finger_holes()
    cuts = {}
    for k, c in ipairs(design.chambers) do
        rt = routes.chambers[k]
        for _, h in ipairs({ { -rt.hx, c.h2.d }, { rt.hx, c.h1.d } }) do
            d = cad.cylinder({ r = h[2] / 2, h = r_out + 2, segments = FN })
            d = cad.rotate(d, { -90, 0, 0 })
            table.insert(cuts, cad.translate(d, { h[1], 0, rt.z }))
        end
    end
    return cuts
end

-- Everything air: bores, fipples and (unless calibrating) finger holes.
function air(with_holes)
    cuts = {}
    for k, c in ipairs(routes.chambers) do
        x = cfg.chambers[k].window_x
        table.insert(cuts, bore_pipe(keypoints(c.path)))
        table.insert(cuts, rod(x, 0, r, -1, cfg.window_length))
        -- flatten the bore roof under the window so the labium edge is sharp
        table.insert(cuts, box(x - ww / 2, x + ww / 2, 0, r, -(sag + ramp_len + 2), cfg.window_length))
        for _, w in ipairs(window_cuts(x)) do
            table.insert(cuts, w)
        end
        for _, m in ipairs(mouth_air(k, x)) do
            table.insert(cuts, m)
        end
    end
    -- the one shared inlet, round-bottomed so it prints as a dome
    table.insert(cuts, rod(0, inlet_y, inlet_r, branch_z, head_top + 1))
    table.insert(cuts, ball({ 0, inlet_y, branch_z }, inlet_r))
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
    shell = outer()
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
-- Print layout (default and calibrate): both parts upside down. The head
-- stands on its flat mouth end, the body on its joint face (collar on the
-- bed); every non-vertical channel then has its pointed roof on top.
head_print = cad.translate(cad.rotate(head, { 180, 0, 0 }), { 0, 0, head_top })
body_print = cad.translate(cad.rotate(body, { 180, 0, 0 }), { 0, 0, joint_z })
part = os.getenv("TRISTLE_PART")
if part == "head" then
    return head_print
elseif part == "body" then
    return body_print
end
return cad.union({ head_print, cad.translate(body_print, { 0, 70, 0 }) })
