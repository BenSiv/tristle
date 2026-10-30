-- layout.lua
-- Tube routing for the coiled tristle. Each chamber is a filleted polyline
-- from its labium (z = 0) down to an open end hanging into the skirt under
-- the rows. One slack dimension per chamber is solved so that the arc
-- length to its first finger hole matches what tuning needs:
--   C (top row)    U-curl width behind the rows (curls down over E toward G;
--                  depth fixed just above the skirt)
--   E (middle row) dip depth of its traverse
--   G (bottom row) how far left its drop sits
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

DEEP = -400 -- tails are routed far down, then truncated at the chamber length

function layout.frame(cfg)
    f = {}
    f.r = cfg.bore / 2
    f.r_out = f.r + cfg.wall
    f.hx = cfg.column_gap / 2              -- holes at x = -hx (h2), +hx (h1)
    f.turn_x = f.hx + 6                    -- rows turn into their tails here
    f.rows = {}
    for k = 1, 3 do
        f.rows[k] = cfg.bend_z - cfg.tube_gap - (k - 1) * cfg.row_pitch
    end
    f.skirt_z = f.rows[3] - f.r_out - 2   -- ceiling of the open skirt
    return f
end

-- Waypoints for chamber k with slack value `s`, plus the point where its
-- tail crosses the skirt ceiling.
function layout.waypoints(cfg, f, k, s)
    bz, by, my = cfg.bend_z, cfg.back_y, cfg.mid_y
    ex = cfg.row_entry_x
    wx = cfg.chambers[k].window_x
    z = f.rows[k]
    tx = f.turn_x
    if k == 1 then -- C: drop behind, U-curl over E toward G, back up at x = -s
        u = f.skirt_z + f.r_out + 2
        tail = { tx, my, f.skirt_z }
        return {
            { wx, 0, 0 }, { wx, 0, bz }, { wx, by, bz }, { wx, by, u },
            { -s, by, u }, { -s, by, z }, { -s, my, z }, { ex, my, z }, { ex, 0, z },
            { tx, 0, z }, { tx, my, z - cfg.tube_gap }, { tx, my, DEEP },
        }, tail
    elseif k == 2 then -- E: drop behind, forward, dipped traverse, row
        ex2 = tx + cfg.tube_gap
        tail = { ex2, 0, f.skirt_z }
        return {
            { wx, 0, 0 }, { wx, 0, bz }, { wx, by, bz }, { wx, by, z }, { wx, my, z },
            { (wx + ex) / 2, my, z - s }, { ex, my, z }, { ex, 0, z },
            { ex2, 0, z }, { ex2, 0, DEEP },
        }, tail
    end
    -- G: jog left in front of everything, drop outside the rows, row
    tail = { tx, 0, f.skirt_z }
    return {
        { wx, 0, 0 }, { wx, 0, bz }, { -s, 0, bz }, { -s, 0, z },
        { tx, 0, z }, { tx, 0, DEEP },
    }, tail
end

SLACK_RANGE = {
    { 13, 45 },    -- C: x of the U's return leg (as a distance to the left)
    { 0, 40 },     -- E: dip depth
    { 30, 70 },    -- G: drop x (as a positive distance to the left)
}

function first_hole_s(cfg, f, k, s)
    pts = layout.waypoints(cfg, f, k, s)
    p = path.build(pts, cfg.bend_radius, 1.0)
    return path.s_of(p, { -f.hx, 0, f.rows[k] }), p
end

-- Range of first-hole positions whose diameters stay printable.
function hole_window(cfg, ctx, ch)
    lo, hi = nil, nil
    for p2 = 60, 300 do
        d = tuning.design_chamber(cfg, ctx, { name = ch.name, root = ch.root, x = 0,
            h1 = { pos = p2 + cfg.column_gap }, h2 = { pos = p2 } })
        if #d.h1.warnings == 0 and #d.h2.warnings == 0 and d.h1.pos < d.length then
            if lo == nil then
                lo = p2
            end
            hi = p2
        end
    end
    return lo, hi
end

function layout.solve(cfg)
    ctx = tuning.context(cfg)
    f = layout.frame(cfg)
    result = { frame = f, chambers = {}, problems = {} }
    for k, ch in ipairs(cfg.chambers) do
        root = tuning.midi(ch.root)
        L = ctx.acoustic(root) - ctx.end_correction
        lo, hi = hole_window(cfg, ctx, ch)
        -- tail must reach the skirt plus a stub; that caps the first hole
        rng = SLACK_RANGE[k]
        s_probe, p_probe = first_hole_s(cfg, f, k, rng[1])
        pts, tail_pt = layout.waypoints(cfg, f, k, rng[1])
        tail_min = path.s_of(p_probe, tail_pt) - s_probe - cfg.column_gap + cfg.tail_stub
        cap = L - cfg.column_gap - tail_min
        -- prefer short tails (shallower skirt), but keep holes off their limits
        target = math.min(hi - 1, cap)
        if target < lo then
            table.insert(result.problems, string.format(
                "%s: tail needs %.0f mm but tuning allows at most %.0f", ch.name, tail_min, L - cfg.column_gap - lo))
        end
        -- bisection on slack
        a, b = rng[1], rng[2]
        sa = first_hole_s(cfg, f, k, a)
        sb = first_hole_s(cfg, f, k, b)
        if (target - sa) * (target - sb) > 0 then
            table.insert(result.problems, string.format(
                "%s: first hole target %.1f outside slack range (%.1f..%.1f)", ch.name, target, sa, sb))
        end
        for i = 1, 50 do
            m = (a + b) / 2
            sm = first_hole_s(cfg, f, k, m)
            if (sm - target) * (sa - target) > 0 then
                a, sa = m, sm
            else
                b = m
            end
        end
        slack = (a + b) / 2
        s_h2, p = first_hole_s(cfg, f, k, slack)
        p = path.truncate(p, L)
        ch.h2.pos = s_h2
        ch.h1.pos = s_h2 + cfg.column_gap
        table.insert(result.chambers, {
            name = ch.name, row = k, length = L, slack = slack, path = p,
            window = { lo, hi }, h2 = s_h2, h1 = s_h2 + cfg.column_gap,
            end_point = p.pts[#p.pts],
        })
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
    f = result.frame
    add(string.format("rows z: %.0f %.0f %.0f   skirt ceiling z %.0f",
        f.rows[1], f.rows[2], f.rows[3], f.skirt_z))
    for _, c in ipairs(result.chambers) do
        add(string.format("%s row %d  length %.1f  first hole %.1f (ok %d..%d)  slack %.1f  open end %s",
            c.name, c.row, c.length, c.h2, c.window[1], c.window[2], c.slack, fmt_pt(c.end_point)))
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
