-- layout.lua
-- Tube routing for the compact tristle. Each chamber is a filleted
-- polyline from its labium (z = 0) to an open end on the flat back face:
--
--   window -> down -> [E, C: a horizontal run across the free front space
--   above the rows] -> diagonally back to its drop column -> down to its
--   row -> forward to mid_y -> left to the row entry -> forward onto the
--   front -> right across both finger holes -> back to mid_y -> down by the
--   tail slack -> back to the back face
--
-- Two slack dimensions per chamber are solved. The lead slack sets the
-- length to the first finger hole: G's drop depth, E's and C's front-run
-- length (E runs left, C runs right, at their own levels). The tail drop
-- makes the tube end exactly on the back face at its acoustic length.
--
-- Run standalone for the routing report and clearance check:  luam layout.lua

here = string.match(debug.getinfo(1).source, "^@(.*[\\/])")
if here == nil then
    here = "./"
end
package.path = here .. "?.lua;" .. package.path
config = require("config")
tuning = require("tuning")
path = require("path")

layout = {}

-- Where each chamber's holes go if both are hole_target wide.
function targets(cfg, ctx, ch)
    hd = cfg.hole_target
    if ch.hole_d != nil then
        hd = ch.hole_d
    end
    d = tuning.design_chamber(cfg, ctx, { name = ch.name, root = ch.root, x = 0,
        h1 = { d = hd }, h2 = { d = hd } })
    return { length = d.length, h2 = d.h2.pos, h1 = d.h1.pos, gap = d.h1.pos - d.h2.pos }
end

function layout.frame(cfg)
    ctx = tuning.context(cfg)
    f = { r = cfg.bore / 2, rows = {}, targets = {} }
    f.r_out = f.r + cfg.wall
    margin = cfg.bend_radius + cfg.hole_target / 2 + 1.5 -- straight run around a hole
    for k, ch in ipairs(cfg.chambers) do
        t = targets(cfg, ctx, ch)
        t.z = cfg.bend_z - cfg.tube_gap - cfg.row_drop - (k - 1) * cfg.row_pitch
        t.hx = t.gap / 2               -- holes at x = -hx (h2), +hx (h1)
        t.entry = -t.hx - margin
        t.turn = t.hx + margin
        f.targets[k] = t
    end
    return f
end

DEEP = -400

-- Waypoints for chamber k with lead slack s and tail drop u.
function layout.waypoints(cfg, f, k, s, u)
    t = f.targets[k]
    wx = cfg.chambers[k].window_x
    xd = cfg.drop_x[k]
    bz, my, z = cfg.bend_z, cfg.mid_y, t.z
    pts = { { wx, 0, 0 } }
    yd = my - cfg.drop_depth
    if k == 1 then -- G: straight back to its drop, depth s
        yd = my - s
        table.insert(pts, { wx, 0, bz })
        table.insert(pts, { xd, yd, bz })
    else -- E runs left, C runs right, each one tube_gap lower than the last
        zf = bz - (k - 1) * cfg.tube_gap
        dir = -1
        if k == 3 then
            dir = 1
        end
        table.insert(pts, { wx, 0, zf })
        table.insert(pts, { wx + dir * s, 0, zf })
        table.insert(pts, { xd, yd, zf })
    end
    tail = {
        { xd, yd, z }, { xd, my, z }, { t.entry, my, z }, { t.entry, 0, z },
        { t.turn, 0, z }, { t.turn, my, z }, { t.turn, my, z - u }, { t.turn, cfg.back_y, z - u },
    }
    for _, p in ipairs(tail) do
        table.insert(pts, p)
    end
    return pts
end

function build(cfg, f, k, s, u)
    return path.build(layout.waypoints(cfg, f, k, s, u), cfg.bend_radius, 1.0)
end

function first_hole_s(cfg, f, k, s)
    p = build(cfg, f, k, s, 1)
    return path.s_of(p, { -f.targets[k].hx, 0, f.targets[k].z })
end

-- Bisection for x in [a, b] such that fn(x) = target (fn monotonic).
function solve(fn, a, b, target)
    fa, fb = fn(a), fn(b)
    if (fa - target) * (fb - target) > 0 then
        return nil, fa, fb
    end
    for i = 1, 50 do
        m = (a + b) / 2
        fm = fn(m)
        if (fm - target) * (fa - target) > 0 then
            a, fa = m, fm
        else
            b = m
        end
    end
    return (a + b) / 2, fa, fb
end

LEAD_RANGE = { 0.5, 60 } -- G: drop depth behind mid_y; E, C: front-run length
TAIL_RANGE = { 0.3, 60 } -- tail drop below the row

function layout.solve(cfg)
    f = layout.frame(cfg)
    result = { frame = f, chambers = {}, problems = {} }
    for k, ch in ipairs(cfg.chambers) do
        t = f.targets[k]
        s, lo, hi = solve(function(v) return first_hole_s(cfg, f, k, v) end,
            LEAD_RANGE[1], LEAD_RANGE[2], t.h2)
        if s == nil then
            table.insert(result.problems, string.format(
                "%s: first hole needs %.1f mm, lead reaches %.1f..%.1f", ch.name, t.h2, lo, hi))
            s = LEAD_RANGE[1]
        end
        u, lo, hi = solve(function(v) return build(cfg, f, k, s, v).length end,
            TAIL_RANGE[1], TAIL_RANGE[2], t.length)
        if u == nil then
            table.insert(result.problems, string.format(
                "%s: tube must be %.1f mm, tail gives %.1f..%.1f", ch.name, t.length, lo, hi))
            u = TAIL_RANGE[1]
        end
        p = build(cfg, f, k, s, u)
        -- a drop set too far back would break through the back face
        back = cfg.mid_y - cfg.drop_depth
        if k == 1 then
            back = cfg.mid_y - s
        end
        if back - f.r - cfg.print_roof - cfg.wall < cfg.back_y then
            table.insert(result.problems, string.format(
                "%s: drop at y = %.1f leaves less than %.1f mm of back wall; raise row_drop",
                ch.name, back, cfg.wall))
        end
        ch.h2.pos = path.s_of(p, { -t.hx, 0, t.z })
        ch.h1.pos = ch.h2.pos + t.gap
        result.chambers[k] = {
            name = ch.name, row = k, length = t.length, path = p, lead = s, tail = u,
            gap = t.gap, z = t.z, hx = t.hx, end_point = p.pts[#p.pts],
        }
    end
    return result
end

-- Closest approach between tube centrelines: different chambers anywhere,
-- the same chamber only between points far apart along the tube.
function layout.clearance(cfg, result)
    worst = { d = math.huge }
    samples = {}
    for _, c in ipairs(result.chambers) do
        for i = 1, #c.path.pts, 2 do
            table.insert(samples, { c.name, c.path.s[i], c.path.pts[i] })
        end
    end
    for i = 1, #samples do
        a = samples[i]
        for j = i + 1, #samples do
            b = samples[j]
            far = a[1] != b[1] or math.abs(a[2] - b[2]) > 3 * cfg.tube_gap
            if far == true then
                d = path.norm(path.sub(a[3], b[3]))
                if d < worst.d then
                    worst = { d = d, a = a, b = b }
                end
            end
        end
    end
    return worst
end

function fmt_pt(p)
    return string.format("(%.0f, %.0f, %.0f)", p[1], p[2], p[3])
end

function layout.report(cfg, result)
    lines = {}
    add = function(s) table.insert(lines, s) end
    for _, c in ipairs(result.chambers) do
        add(string.format("%s row %d z %.0f  hole gap %.1f  length %.1f  lead slack %.1f  tail drop %.1f  open end %s",
            c.name, c.row, c.z, c.gap, c.length, c.lead, c.tail, fmt_pt(c.end_point)))
    end
    w = layout.clearance(cfg, result)
    status = "OK"
    if w.d < cfg.tube_gap - 0.5 then
        status = "TOO CLOSE"
    end
    add(string.format("closest tubes %.1f mm (need %.1f) %s: %s s=%.0f %s  vs  %s s=%.0f %s",
        w.d, cfg.tube_gap, status, w.a[1], w.a[2], fmt_pt(w.a[3]), w.b[1], w.b[2], fmt_pt(w.b[3])))
    for _, p in ipairs(result.problems) do
        add("PROBLEM " .. p)
    end
    return table.concat(lines, "\n")
end

if arg != nil and arg[0] != nil and string.match(arg[0], "layout%.lua$") != nil then
    print(layout.report(config, layout.solve(config)))
end

return layout
