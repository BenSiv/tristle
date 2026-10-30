-- optimize.lua
-- Search hole positions (1 mm grid) for the layout closest to ideal finger
-- spacing, keeping every hole diameter printable and coverable.
-- Hole order down the instrument: G.h2 G.h1 | E.h2 E.h1 | C.h2 C.h1, with
-- the hand break between E.h2 (L ring) and E.h1 (R index).
--
-- Run:  luam optimize.lua      -> prints positions to paste into config.lua

here = string.match(debug.getinfo(1).source, "^@(.*[\\/])")
if here == nil then
    here = "./"
end
package.path = here .. "?.lua;" .. package.path
config = require("config")
tuning = require("tuning")

-- Prefer holes near the middle of the allowed range (easier to seal, less
-- sensitive to print error) -- small weight next to spacing.
function size_cost(cfg, design)
    cost = 0
    mid = (cfg.hole_min + cfg.hole_max) / 2
    for _, key in ipairs({ "h1", "h2" }) do
        cost = cost + 0.05 * (design[key].d - mid) ^ 2
    end
    return cost
end

-- All feasible (h2, h1) placements for one chamber.
function candidates(cfg, ctx, ch)
    list = {}
    probe = tuning.design_chamber(cfg, ctx, { name = ch.name, root = ch.root, x = ch.x,
                                              h1 = { d = 6 }, h2 = { d = 6 } })
    for p1 = math.floor(probe.h1.pos) - 25, math.floor(probe.h1.pos) + 25 do
        for p2 = p1 - 35, p1 - 12 do
            d = tuning.design_chamber(cfg, ctx, {
                name = ch.name, root = ch.root, x = ch.x,
                h1 = { pos = p1, finger = ch.h1.finger },
                h2 = { pos = p2, finger = ch.h2.finger },
            })
            if #d.h1.warnings == 0 and #d.h2.warnings == 0 then
                table.insert(list, { h2 = p2, h1 = p1, cost = size_cost(cfg, d) })
            end
        end
    end
    return list
end

function gap_cost(gap, ideal)
    return (gap - ideal) ^ 2
end

function optimize(cfg)
    ctx = tuning.context(cfg)
    g = candidates(cfg, ctx, cfg.chambers[1])
    e = candidates(cfg, ctx, cfg.chambers[2])
    c = candidates(cfg, ctx, cfg.chambers[3])
    best = nil
    for _, ep in ipairs(e) do
        base = ep.cost + gap_cost(ep.h1 - ep.h2, cfg.spacing_break)
        best_g = nil
        for _, gp in ipairs(g) do
            cost = gp.cost + gap_cost(gp.h1 - gp.h2, cfg.spacing_hand)
                   + gap_cost(ep.h2 - gp.h1, cfg.spacing_hand)
            if best_g == nil or cost < best_g.cost then
                best_g = { p = gp, cost = cost }
            end
        end
        best_c = nil
        for _, cp in ipairs(c) do
            cost = cp.cost + gap_cost(cp.h2 - ep.h1, cfg.spacing_hand)
                   + gap_cost(cp.h1 - cp.h2, cfg.spacing_hand)
            if best_c == nil or cost < best_c.cost then
                best_c = { p = cp, cost = cost }
            end
        end
        if best_g != nil and best_c != nil then
            total = base + best_g.cost + best_c.cost
            if best == nil or total < best.cost then
                best = { g = best_g.p, e = ep, c = best_c.p, cost = total }
            end
        end
    end
    return best, #g, #e, #c
end

best, ng, ne, nc = optimize(config)
print(string.format("feasible placements: G %d  E %d  C %d", ng, ne, nc))
if best == nil then
    print("no feasible layout -- widen hole_min/hole_max or spacing")
else
    print(string.format("cost %.1f", best.cost))
    print(string.format("G  h2 = %d  h1 = %d", best.g.h2, best.g.h1))
    print(string.format("E  h2 = %d  h1 = %d", best.e.h2, best.e.h1))
    print(string.format("C  h2 = %d  h1 = %d", best.c.h2, best.c.h1))
end
