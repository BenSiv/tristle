-- tuning.lua
-- Acoustic design of the tristle (tri-whistle): chamber lengths, hole positions and
-- hole diameters, plus the chord/fingering table.
--
-- Model (open-open pipe, Benade/Flutomat tone-hole formulas):
--   acoustic length from the labium   L(f) = c / (2 f) - window_correction
--   physical length labium -> foot     x_end = L(root) - 0.6133 * r
--   open hole at x with spacing g to the next open thing below it sounds as
--   if the pipe ended at x + C, where
--     C = g/2 * (sqrt(1 + 4 * m * D^2 / g) - 1),   m = (t + 0.75 d) / d^2
--   (d hole diameter, t chimney height, D bore). Twin holes add in parallel:
--   1/m = 1/m_small + 1/m_large.
--
-- Run standalone for the report:  luam tuning.lua

here = string.match(debug.getinfo(1).source, "^@(.*[\\/])")
if here == nil then
    here = "./"
end
package.path = here .. "?.lua;" .. package.path
config = require("config")

tuning = {}

NOTE_INDEX = { C = 0, ["C#"] = 1, D = 2, ["D#"] = 3, E = 4, F = 5, ["F#"] = 6,
               G = 7, ["G#"] = 8, A = 9, ["A#"] = 10, B = 11 }
NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

-- Fingering per semitone offset, upper hole (h2) first: closed, half, open.
STATE_HOLES = { [0] = "●●", [1] = "●◐", [2] = "●○", [3] = "◐○", [4] = "○○" }

function tuning.midi(note)
    letter, octave = string.match(note, "^([A-G]#?)(%d)$")
    return 12 * (tonumber(octave) + 1) + NOTE_INDEX[letter]
end

function tuning.note_name(m)
    return NOTE_NAMES[m % 12 + 1] .. tostring(math.floor(m / 12) - 1)
end

function tuning.speed_of_sound(cfg)
    return (331.3 + 0.606 * cfg.temperature_c) * 1000 -- mm/s
end

-- Orifice estimate of the window end correction: the window is a short
-- neck of area Sw in a wall of thickness `wall`, seen from a bore of area Sb.
function tuning.window_correction(cfg)
    if cfg.window_correction != nil then
        return cfg.window_correction
    end
    sb = math.pi * (cfg.bore / 2) ^ 2
    sw = cfg.windway_width * cfg.window_length
    a = math.sqrt(sw / math.pi)
    return sb / sw * (cfg.wall + 1.7 * a)
end

function hole_m(d, t)
    return (t + 0.75 * d) / (d * d)
end

function hole_correction(g, m, bore)
    return g / 2 * (math.sqrt(1 + 4 * m * bore * bore / g) - 1)
end

-- Inverse of hole_correction: the m that yields correction c over spacing g.
function m_for_correction(c, g, bore)
    q = 2 * c / g + 1
    return g * (q * q - 1) / (4 * bore * bore)
end

-- Diameter whose m equals target (m falls monotonically with d).
function diameter_for_m(target, t)
    lo, hi = 0.2, 40.0
    for i = 1, 60 do
        mid = (lo + hi) / 2
        if hole_m(mid, t) > target then
            lo = mid
        else
            hi = mid
        end
    end
    return (lo + hi) / 2
end

-- Chimney height of a hole drilled straight through a flat front face at
-- lateral offset xo from the bore axis.
function chimney(cfg, xo)
    r = cfg.bore / 2
    return (r + cfg.wall) - math.sqrt(r * r - xo * xo)
end

-- Lateral offset of a hole cluster: inset toward the centre line, limited
-- so the cluster still lands fully on the bore.
function tuning.hole_offset(cfg, chamber, width)
    if chamber.x == 0 then
        return 0
    end
    limit = cfg.bore / 2 - 0.5 - width / 2
    xo = math.max(0, math.min(cfg.hole_inset, limit))
    if chamber.x > 0 then
        return -xo
    end
    return xo
end

-- Solve one hole. spec.pos fixed -> solve diameter(s); spec.d fixed -> solve
-- position. tail(x) is the acoustic spacing g from x to the next opening.
function solve_hole(cfg, chamber, spec, tail, l_full, l_semi)
    hole = { finger = spec.finger }
    width = 7
    xo = 0
    for iter = 1, 4 do
        t = chimney(cfg, xo)
        m_full = 0
        if spec.d != nil then
            m_full = hole_m(spec.d, t)
            lo, hi = 1.0, l_full -- a hole never sits below its own acoustic end
            for i = 1, 80 do
                x = (lo + hi) / 2
                if x + hole_correction(tail(x), m_full, cfg.bore) > l_full then
                    hi = x
                else
                    lo = x
                end
            end
            hole.pos = (lo + hi) / 2
        else
            hole.pos = spec.pos
            m_full = m_for_correction(l_full - hole.pos, tail(hole.pos), cfg.bore)
        end
        g = tail(hole.pos)
        hole.d = diameter_for_m(m_full, t)
        if cfg.twin_holes == true then
            m_semi = m_for_correction(l_semi - hole.pos, g, cfg.bore)
            hole.d_small = diameter_for_m(m_semi, t)
            inv = 1 / m_full - 1 / m_semi
            if inv > 0 then
                hole.d_large = diameter_for_m(1 / inv, t)
            else
                hole.d_large = 0
            end
            width = hole.d_small + cfg.twin_web + hole.d_large
        else
            width = hole.d
        end
        xo = tuning.hole_offset(cfg, chamber, width)
    end
    hole.offset = xo
    hole.chimney = chimney(cfg, xo)
    hole.width = width

    hole.warnings = {}
    sizes = { { hole.d, cfg.hole_min } }
    if cfg.twin_holes == true then
        sizes = { { hole.d_small, cfg.hole_min_small }, { hole.d_large, cfg.hole_min } }
    end
    for _, s in ipairs(sizes) do
        if s[1] < s[2] or s[1] > cfg.hole_max then
            table.insert(hole.warnings, string.format(
                "%.1f mm outside %.1f-%.1f: move the hole", s[1], s[2], cfg.hole_max))
        end
    end
    if width > cfg.bore - 1 then
        table.insert(hole.warnings, string.format(
            "hole cluster %.1f mm wider than bore allows", width))
    end
    return hole
end

function tuning.context(cfg)
    ctx = {
        c = tuning.speed_of_sound(cfg),
        window_correction = tuning.window_correction(cfg),
        end_correction = 0.6133 * cfg.bore / 2,
    }
    ctx.acoustic = function(m)
        return ctx.c / (2 * cfg.a4 * 2 ^ ((m - 69) / 12)) - ctx.window_correction
    end
    return ctx
end

function tuning.design_chamber(cfg, ctx, ch)
    acoustic = ctx.acoustic
    root = tuning.midi(ch.root)
    out = { name = ch.name, root = root, x = ch.x }
    out.length = acoustic(root) - ctx.end_correction
    foot = acoustic(root)
    out.h1 = solve_hole(cfg, ch, ch.h1, function(x) return foot - x end,
                        acoustic(root + 2), acoustic(root + 1))
    h1_pos = out.h1.pos
    out.h2 = solve_hole(cfg, ch, ch.h2, function(x) return h1_pos - x end,
                        acoustic(root + 4), acoustic(root + 3))
    return out
end

function tuning.design(cfg)
    result = tuning.context(cfg)
    result.chambers = {}
    for _, ch in ipairs(cfg.chambers) do
        table.insert(result.chambers, tuning.design_chamber(cfg, result, ch))
    end
    return result
end

-- Every chord whose three pitch classes can be voiced one per chamber.
function tuning.chords(design)
    qualities = {
        { "", { 0, 4, 7 } }, { "m", { 0, 3, 7 } },
        { "dim", { 0, 3, 6 } }, { "aug", { 0, 4, 8 } },
        { "sus4", { 0, 5, 7 } }, { "sus2", { 0, 2, 7 } },
    }
    roots = {}
    for _, ch in ipairs(design.chambers) do
        table.insert(roots, ch.root)
    end
    found = {}
    for pc = 0, 11 do
        for _, q in ipairs(qualities) do
            want = {}
            for _, iv in ipairs(q[2]) do
                want[(pc + iv) % 12] = true
            end
            best = nil
            for a = 0, 4 do
                for b = 0, 4 do
                    for k = 0, 4 do
                        offs = { a, b, k }
                        seen = {}
                        count = 0
                        ok = true
                        for i = 1, 3 do
                            p = (roots[i] + offs[i]) % 12
                            if want[p] != true then
                                ok = false
                            elseif seen[p] == nil then
                                seen[p] = true
                                count = count + 1
                            end
                        end
                        if ok == true and count == 3 then
                            halves = 0
                            for i = 1, 3 do
                                if offs[i] % 2 == 1 then
                                    halves = halves + 1
                                end
                            end
                            if best == nil or halves < best.halves then
                                best = { offs = offs, halves = halves }
                            end
                        end
                    end
                end
            end
            if best != nil then
                table.insert(found, { name = NOTE_NAMES[pc + 1] .. q[1], offs = best.offs,
                                      halves = best.halves, diatonic = false })
            end
        end
    end
    return found
end

function tuning.report(design, cfg)
    lines = {}
    add = function(s) table.insert(lines, s) end
    add(string.format("speed of sound %.1f m/s (%.0f C)   window corr %.1f mm   end corr %.1f mm",
        design.c / 1000, cfg.temperature_c, design.window_correction, design.end_correction))
    if cfg.window_correction == nil then
        add("window correction is an ESTIMATE -- print TRISTLE_VIEW=calibrate and measure (README)")
    end
    add("")
    add("Lengths are along the tube centreline from the labium edge (window edge).")
    add("")
    add("chamber  notes (closed..open)        length  hole  finger     along tube  to end  dia (twin: small+large)")
    for _, ch in ipairs(design.chambers) do
        notes = {}
        for k = 0, 4 do
            table.insert(notes, tuning.note_name(ch.root + k))
        end
        first = true
        for _, key in ipairs({ "h2", "h1" }) do
            h = ch[key]
            dia = string.format("%.2f", h.d)
            if cfg.twin_holes == true then
                dia = string.format("%.2f  (%.2f + %.2f)", h.d, h.d_small, h.d_large)
            end
            head = ""
            if first == true then
                head = string.format("%-8s %-27s %6.1f", ch.name, table.concat(notes, " "), ch.length)
            else
                head = string.format("%-8s %-27s %6s", "", "", "")
            end
            add(string.format("%s  %-4s  %-9s %7.1f  %7.1f   %s",
                head, key, h.finger, h.pos, ch.length - h.pos, dia))
            for _, w in ipairs(h.warnings) do
                add("         WARNING " .. key .. ": " .. w)
            end
            first = false
        end
    end
    add("")
    add("Fingering per chamber (upper hole first): ●● root  ●◐ +1  ●○ +2  ◐○ +3  ○○ +4")
    add("")
    add("Triads in C major (one note per chamber, fewest half-holes):")
    scale = { [0] = true, [2] = true, [4] = true, [5] = true, [7] = true, [9] = true, [11] = true }
    others = {}
    for _, chord in ipairs(tuning.chords(design)) do
        names = {}
        holes = {}
        in_key = true
        for i, ch in ipairs(design.chambers) do
            m = ch.root + chord.offs[i]
            table.insert(names, tuning.note_name(m))
            table.insert(holes, ch.name .. " " .. STATE_HOLES[chord.offs[i]])
            if scale[m % 12] != true then
                in_key = false
            end
        end
        if in_key == true then
            add(string.format("  %-6s %-14s %s", chord.name, table.concat(names, " "), table.concat(holes, "   ")))
        else
            table.insert(others, chord.name)
        end
    end
    add("")
    add(string.format("Also playable (%d more): %s", #others, table.concat(others, " ")))
    return table.concat(lines, "\n")
end

-- Window correction from measured root notes of a hole-less print:
-- each chamber's physical length is known, so c/(2f) - length - end corr
-- is what the window adds. Measure warmed up, at playing breath pressure.
function tuning.calibrate(cfg, measured)
    package.loaded["tuning"] = tuning
    require("layout").solve(cfg)
    design = tuning.design(cfg)
    lines = {}
    sum, n = 0, 0
    for _, ch in ipairs(design.chambers) do
        f = measured[ch.name]
        if f != nil then
            cw = design.c / (2 * f) - ch.length - design.end_correction
            cents = 1200 * math.log(f / (cfg.a4 * 2 ^ ((ch.root - 69) / 12))) / math.log(2)
            table.insert(lines, string.format("%s: %.1f Hz (%+.0f cents vs %s) -> window correction %.1f mm",
                ch.name, f, cents, tuning.note_name(ch.root), cw))
            sum = sum + cw
            n = n + 1
        end
    end
    if n == 0 then
        return "usage: luam tuning.lua calibrate C=523.1 E=659.0 G=784.2"
    end
    table.insert(lines, string.format("\nset config.window_correction = %.1f  (was %.1f), then rerun", sum / n, design.window_correction))
    return table.concat(lines, "\n")
end

if arg != nil and arg[0] != nil and string.match(arg[0], "tuning%.lua$") != nil then
    if arg[1] == "calibrate" then
        measured = {}
        for i = 2, #arg do
            name, hz = string.match(arg[i], "^(%a)=([%d%.]+)$")
            if name != nil then
                measured[name] = tonumber(hz)
            end
        end
        print(tuning.calibrate(config, measured))
    else
        -- hole positions come from the tube routing
        package.loaded["tuning"] = tuning
        layout = require("layout")
        layout.solve(config)
        print(tuning.report(tuning.design(config), config))
    end
end

return tuning
