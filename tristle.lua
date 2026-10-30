-- tristle.lua
-- Luametry model of the tristle (tri-whistle): three whistles (C5, E5, G5) side by
-- side in one flat body, one mouthpiece with three windways, two finger
-- holes per chamber. Geometry comes from config.lua, hole positions and
-- diameters from tuning.lua.
--
--   luametry run tristle.lua             -> out/tristle.stl (print layout)
--   TRISTLE_VIEW=assembled luametry run tristle.lua -o out/assembled.stl
--   TRISTLE_VIEW=section   ...  head cut through the E chamber (inspection)
--   TRISTLE_VIEW=calibrate ...  print layout without finger holes; measure
--                                   the roots, then `luam tuning.lua calibrate`
--
-- Coordinates: z = 0 at the labium edges, mouthpiece +z, foot -z, holes and
-- windows face +y, chambers G E C from -x to +x.

const cad = require("cad")
here = string.match(debug.getinfo(1).source, "^@(.*[\\/])")
if here == nil then
    here = "./"
end
package.path = here .. "?.lua;" .. package.path
config = require("config")
tuning = require("tuning")

cfg = config
design = tuning.design(cfg)

FN = 64
r = cfg.bore / 2
r_out = r + cfg.wall
ww = cfg.windway_width
wh = cfg.windway_height
block_top = cfg.window_length + cfg.windway_straight -- end of straight windway
head_top = block_top + cfg.beak_length
ramp_len = (r_out + 1 - r) / math.tan(math.rad(cfg.labium_angle))

joint_z = cfg.joint_z
joint_len = cfg.joint_length
tenon_r = r + cfg.joint_wall
joint_clearance = cfg.joint_clearance
collar_r = tenon_r + joint_clearance + 1.6

function box(x0, x1, y0, y1, z0, z1)
    return cad.translate(cad.cube({ size = { x1 - x0, y1 - y0, z1 - z0 } }), { x0, y0, z0 })
end

function rod(x, radius, z0, z1)
    c = cad.cylinder({ r = radius, h = z1 - z0, segments = FN })
    return cad.translate(c, { x, 0, z0 })
end

-- Hull of one rod per chamber, each clipped to [z0, z1].
function bundle(chambers, radius, z0, z1)
    rods = {}
    for _, ch in ipairs(chambers) do
        table.insert(rods, rod(ch.x, radius, z0, z1))
    end
    return cad.hull(rods)
end

-- Outer shell: stepped flat body, each adjacent pair hulled over the
-- shorter one's length, plus the converging beak.
function outer_shell()
    chs = design.chambers
    parts = {}
    for i = 1, #chs do
        table.insert(parts, rod(chs[i].x, r_out, -chs[i].length, block_top))
        if i < #chs then
            z0 = -math.min(chs[i].length, chs[i + 1].length)
            table.insert(parts, bundle({ chs[i], chs[i + 1] }, r_out, z0, block_top))
        end
    end
    tip_w = 2 * cfg.beak_pitch + ww + 6
    tip = box(-tip_w / 2, tip_w / 2, r - wh / 2 - 2.2, r + wh / 2 + 1.4, head_top - 0.5, head_top)
    table.insert(parts, cad.hull({ bundle(chs, r_out, block_top - 0.5, block_top), tip }))
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

-- Finger hole (or twin hole) drilled straight in from the front face.
function finger_hole(ch, h)
    hx = ch.x + h.offset
    drills = {}
    if cfg.twin_holes == true then
        span = h.d_small + cfg.twin_web + h.d_large
        table.insert(drills, { hx - span / 2 + h.d_large / 2, h.d_large })
        table.insert(drills, { hx + span / 2 - h.d_small / 2, h.d_small })
    else
        table.insert(drills, { hx, h.d })
    end
    cuts = {}
    for _, dr in ipairs(drills) do
        c = cad.cylinder({ r = dr[2] / 2, h = r_out + 2, segments = 48 })
        c = cad.rotate(c, { -90, 0, 0 })
        table.insert(cuts, cad.translate(c, { dr[1], 0, -h.pos }))
    end
    return cuts
end

-- Everything air: bores, fipples and (unless calibrating) finger holes.
function air(with_holes)
    cuts = {}
    for _, ch in ipairs(design.chambers) do
        x = ch.x
        table.insert(cuts, rod(x, r, -ch.length - 1, cfg.window_length))
        -- flatten the bore roof under the window so the labium edge is straight
        table.insert(cuts, box(x - ww / 2, x + ww / 2, 0, r, -(ramp_len + 4), cfg.window_length))
        table.insert(cuts, box(x - ww / 2, x + ww / 2, 0, r_out + 1, 0, cfg.window_length))
        table.insert(cuts, ramp(x))
        -- windway: straight run, then converging to the lips
        table.insert(cuts, box(x - ww / 2, x + ww / 2, r - wh / 2, r + wh / 2, cfg.window_length - 0.01, block_top))
        lip_x = x * cfg.beak_pitch / cfg.pitch
        table.insert(cuts, cad.hull({
            box(x - ww / 2, x + ww / 2, r - wh / 2, r + wh / 2, block_top - 0.01, block_top),
            box(lip_x - ww / 2, lip_x + ww / 2, r - wh / 2, r + wh / 2, head_top, head_top + 1),
        }))
        if with_holes == true then
            for _, key in ipairs({ "h1", "h2" }) do
                for _, c in ipairs(finger_hole(ch, ch[key])) do
                    table.insert(cuts, c)
                end
            end
        end
    end
    return cad.union(cuts)
end

function build(with_holes)
    shell = outer_shell()
    holes = air(with_holes)
    far = 1000
    head = cad.union({
        cad.intersection({ shell, box(-far, far, -far, far, joint_z, far) }),
        bundle(design.chambers, tenon_r, joint_z - joint_len, joint_z + 0.01),
    })
    socket = bundle(design.chambers, tenon_r + joint_clearance, joint_z - joint_len - 0.5, joint_z + 1)
    body = cad.union({
        cad.intersection({ shell, box(-far, far, -far, far, -far, joint_z) }),
        bundle(design.chambers, collar_r, joint_z - joint_len - 3, joint_z),
    })
    head = cad.difference({ head, holes })
    body = cad.difference({ body, socket, holes })
    return head, body
end

view = os.getenv("TRISTLE_VIEW")
head, body = build(view != "calibrate")

if view == "assembled" then
    return cad.union({ head, body })
end
if view == "section" then -- head region cut through the E chamber axis
    return cad.intersection({ cad.union({ head, body }), box(-1000, 0, -1000, 1000, -40, 1000) })
end
-- Print layout (default and calibrate): head standing on its tenon, body upside down on its
-- socket end, side by side.
head_print = cad.translate(head, { 0, 0, -(joint_z - joint_len) })
body_print = cad.rotate(body, { 180, 0, 0 })
body_print = cad.translate(body_print, { 0, 40, joint_z })
return cad.union({ head_print, body_print })
