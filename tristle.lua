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
inlets = tuning.inlets(cfg)

FN = 48
r = cfg.bore / 2
r_out = r + cfg.wall
ww = cfg.windway_width
wh = cfg.windway_height
block_top = cfg.window_length + cfg.windway_straight -- end of straight windway
head_top = block_top + cfg.beak_length
ramp_len = (r_out + 1 - r) / math.tan(math.rad(cfg.labium_angle))
lip_pitch = ww + cfg.beak_web
tip_y = 3.0 -- mouth end centre (windways sit at y = r)

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
        -- flatten the bore roof under the window so the labium edge is straight
        table.insert(cuts, box(x - ww / 2, x + ww / 2, 0, r, -(ramp_len + 3), cfg.window_length))
        table.insert(cuts, box(x - ww / 2, x + ww / 2, 0, r_out + 1, 0, cfg.window_length))
        table.insert(cuts, ramp(x))
        -- windway: straight run, then converging to the narrow mouth end
        table.insert(cuts, box(x - ww / 2, x + ww / 2, r - wh / 2, r + wh / 2, cfg.window_length - 0.01, block_top))
        lip_x = 0
        if x < 0 then
            lip_x = -lip_pitch
        elseif x > 0 then
            lip_x = lip_pitch
        end
        inlet_top = head_top - cfg.inlet_length
        table.insert(cuts, cad.hull({
            box(x - ww / 2, x + ww / 2, r - wh / 2, r + wh / 2, block_top - 0.01, block_top),
            box(lip_x - ww / 2, lip_x + ww / 2, r - wh / 2, r + wh / 2, inlet_top - 0.01, inlet_top),
        }))
        -- narrow inlet slit at the lips: opens abruptly into the windway,
        -- slowing this chamber's jet (see config.jet_match)
        wi = inlets[k].width
        table.insert(cuts, box(lip_x - wi / 2, lip_x + wi / 2, r - wh / 2, r + wh / 2, inlet_top - 0.02, head_top + 1))
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
body_print = cad.translate(cad.rotate(body, { 180, 0, 0 }), { 0, 70, joint_z })
return cad.union({ head_print, body_print })
