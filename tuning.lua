-- tuning.lua
-- Acoustic design of the tristle (tri-whistle): chamber lengths, hole positions and
-- hole diameters, plus the chord/fingering table.
--
-- Model: each chamber is an open-open pipe. Its length comes from
--   acoustic length from the labium   L(f) = c / (2 f) - window_correction
--   physical length labium -> foot     L(root) - 0.6133 * r
-- Holes are placed with a lossless transfer-matrix model: bore segments as
-- plane-wave lines, each open hole as a shunt inertance of length
-- t + 0.75 d (t chimney, d diameter), the foot as an open end. The pitch of
-- a fingering is where the impedance at the virtual open end above the
-- window goes to zero. Twin holes are two shunts at the same spot.
--
-- Run standalone:  luam tuning.lua           report
--                  luam tuning.lua check     pitch of every fingering
--                  luam tuning.lua calibrate C=.. E=.. G=..

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

-- Window opening: a rectangle (jet exit to the labium's ends) plus the
-- circular segment the arched labium adds below it.
function tuning.window_area(cfg)
    w, sag = cfg.windway_width, cfg.labium_arc
    area = w * cfg.window_length
    if sag > 0 then
        rr = (w * w / 4 + sag * sag) / (2 * sag)
        area = area + rr * rr * math.acos((rr - sag) / rr) - (rr - sag) * math.sqrt(2 * rr * sag - sag * sag)
    end
    return area
end

-- Orifice estimate of the window end correction: the window is a short
-- neck of area Sw in a wall of thickness `wall`, seen from a bore of area Sb.
function tuning.window_correction(cfg)
    if cfg.window_correction != nil then
        return cfg.window_correction
    end
    sb = math.pi * (cfg.bore / 2) ^ 2
    sw = tuning.window_area(cfg)
    a = math.sqrt(sw / math.pi)
    return sb / sw * (cfg.wall + 1.7 * a)
end

-- Transfer-matrix pieces. Impedances are divided by rho*c and kept as
-- Z = j * N / D (lossless, so purely reactive) so poles stay finite.
function tm_pipe(st, k, len, zc)
    c, s = math.cos(k * len), math.sin(k * len)
    n = st[1] * c + st[2] * zc * s
    d = st[2] * c - st[1] * s / zc
    m = math.sqrt(n * n + d * d)
    return { n / m, d / m }
end

function tm_hole(st, k, d, t)
    xh = k * (t + 0.75 * d) / (math.pi * d * d / 4)
    return { st[1] * xh, st[2] * xh + st[1] }
end

-- Impedance state at the virtual open end above the window, for a chamber
-- of `length` with the given open holes ({pos, d, t}, any order).
function tm_state(cfg, ctx, length, shunts, f)
    k = 2 * math.pi * f / ctx.c
    zc = 1 / (math.pi * cfg.bore * cfg.bore / 4)
    sorted = {}
    for _, h in ipairs(shunts) do
        table.insert(sorted, h)
    end
    table.sort(sorted, function(a, b) return a[1] > b[1] end)
    st = tm_pipe({ 0, 1 }, k, ctx.end_correction, zc)
    x = length
    for _, h in ipairs(sorted) do
        st = tm_pipe(st, k, x - h[1], zc)
        st = tm_hole(st, k, h[2], h[3])
        x = h[1]
    end
    return tm_pipe(st, k, x + ctx.window_correction, zc)
end

-- Lowest resonance between 0.5 and 2 times `near` (nil if none).
function tuning.resonance(cfg, ctx, length, shunts, near)
    step = near / 400
    prev = tm_state(cfg, ctx, length, shunts, 0.5 * near)
    f = 0.5 * near + step
    while f < 2 * near do
        st = tm_state(cfg, ctx, length, shunts, f)
        if (prev[1] < 0) != (st[1] < 0) and math.abs(st[2]) > 0.5 then
            lo, hi = f - step, f
            sign = prev[1] < 0
            for i = 1, 40 do
                mid = (lo + hi) / 2
                if (tm_state(cfg, ctx, length, shunts, mid)[1] < 0) == sign then
                    lo = mid
                else
                    hi = mid
                end
            end
            return (lo + hi) / 2
        end
        prev = st
        f = f + step
    end
    return nil
end

-- Bisection for x in [a, b] with fn(x) = target, fn monotonic.
function bisect(fn, a, b, target)
    fa = fn(a)
    for i = 1, 50 do
        m = (a + b) / 2
        fm = fn(m)
        if (fm - target) * (fa - target) > 0 then
            a, fa = m, fm
        else
            b = m
        end
    end
    return (a + b) / 2
end

-- Open area over effective length: what twin holes add in parallel.
function admittance(d, t)
    return (math.pi * d * d / 4) / (t + 0.75 * d)
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
-- position. `below` are the shunts of the open hole(s) further down.
function solve_hole(cfg, ctx, chamber, spec, length, below, f_full, f_semi)
    hole = { finger = spec.finger }
    width = 7
    xo = 0
    pitch_with = function(pos, d, t)
        sh = { { pos, d, t } }
        for _, b in ipairs(below) do
            table.insert(sh, b)
        end
        f = tuning.resonance(cfg, ctx, length, sh, f_full)
        if f == nil then
            return 0
        end
        return f
    end
    lowest = length
    for _, b in ipairs(below) do
        lowest = math.min(lowest, b[1])
    end
    for iter = 1, 4 do
        t = chimney(cfg, xo)
        if spec.d != nil then
            hole.d = spec.d
            hole.pos = bisect(function(x) return pitch_with(x, spec.d, t) end, 0.5 * lowest, lowest - 1, f_full)
        else
            hole.pos = spec.pos
            hole.d = bisect(function(d) return pitch_with(spec.pos, d, t) end, 0.3, 2 * cfg.bore, f_full)
        end
        hole.shunts = { { hole.pos, hole.d, t } }
        if cfg.twin_holes == true then
            hole.d_small = bisect(function(d) return pitch_with(hole.pos, d, t) end, 0.3, hole.d, f_semi)
            rest = admittance(hole.d, t) - admittance(hole.d_small, t)
            hole.d_large = 0
            if rest > 0 then
                hole.d_large = bisect(function(d) return admittance(d, t) end, 0.3, hole.d, rest)
            end
            hole.shunts = { { hole.pos, hole.d_small, t }, { hole.pos, hole.d_large, t } }
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

function tuning.note_freq(cfg, m)
    return cfg.a4 * 2 ^ ((m - 69) / 12)
end

function tuning.design_chamber(cfg, ctx, ch)
    root = tuning.midi(ch.root)
    out = { name = ch.name, root = root, x = ch.x }
    out.length = ctx.acoustic(root) - ctx.end_correction
    hz = function(n) return tuning.note_freq(cfg, root + n) end
    out.h1 = solve_hole(cfg, ctx, ch, ch.h1, out.length, {}, hz(2), hz(1))
    out.h2 = solve_hole(cfg, ctx, ch, ch.h2, out.length, out.h1.shunts, hz(4), hz(3))
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

-- Orifice per chamber channel. Flow Q leaves the jet slit (area Ae) at
-- v_jet; upstream it passes an orifice (Ao) that opens abruptly into the
-- channel (Ad), losing the Borda-Carnot head (v_o - v_d)^2 / 2. With the
-- smooth nozzle lossless, p = rho/2 * v_jet^2 * (1 + (Ae/Ao - Ae/Ad)^2).
-- The highest chamber stays open; the others are narrowed toward speed
-- ratio (f / f_highest) ^ jet_match.
function tuning.orifices(cfg)
    ae = cfg.windway_width * cfg.windway_height
    ad = math.pi * cfg.duct_d * cfg.duct_d / 4
    f_top = 0
    for _, ch in ipairs(cfg.chambers) do
        f_top = math.max(f_top, tuning.note_freq(cfg, tuning.midi(ch.root)))
    end
    out = {}
    for _, ch in ipairs(cfg.chambers) do
        f = tuning.note_freq(cfg, tuning.midi(ch.root))
        ratio = (f / f_top) ^ cfg.jet_match
        ao = ae / (ae / ad + math.sqrt(1 / (ratio * ratio) - 1))
        d = math.min(cfg.duct_d, math.sqrt(4 * ao / math.pi))
        if ch.orifice_d != nil then
            d = ch.orifice_d
        end
        ao = math.pi * d * d / 4
        speed = 1 / math.sqrt(1 + (ae / ao - ae / ad) ^ 2)
        open = 1 / math.sqrt(1 + (ae / ad - ae / ad) ^ 2)
        table.insert(out, { name = ch.name, d = d, speed = speed / open })
    end
    return out
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
    parts = {}
    for _, o in ipairs(tuning.orifices(cfg)) do
        table.insert(parts, string.format("%s %.2f mm (jet %.0f %%)", o.name, o.d, 100 * o.speed))
    end
    add(string.format("Channel orifices (channel %.1f mm, jet_match %.2f): %s",
        cfg.duct_d, cfg.jet_match, table.concat(parts, "   ")))
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

-- Pitch of every full fingering (closed, h1 open, both open) from the
-- transfer-matrix model, as cents off target. After `design` this reads 0;
-- it is there to check hand-edited positions or sizes.
function tuning.check(cfg, design)
    lines = { "Transfer-matrix check (cents off target, 0 = exact):" }
    for _, c in ipairs(design.chambers) do
        parts = {}
        fingerings = { {}, c.h1.shunts, {} }
        for _, s in ipairs(c.h1.shunts) do
            table.insert(fingerings[3], s)
        end
        for _, s in ipairs(c.h2.shunts) do
            table.insert(fingerings[3], s)
        end
        for i, sh in ipairs(fingerings) do
            n = 2 * (i - 1)
            target = tuning.note_freq(cfg, c.root + n)
            f = tuning.resonance(cfg, design, c.length, sh, target)
            label = tuning.note_name(c.root + n)
            if f == nil then
                table.insert(parts, label .. " ?")
            else
                table.insert(parts, string.format("%s %+.1f", label, 1200 * math.log(f / target) / math.log(2)))
            end
        end
        table.insert(lines, string.format("  %s chamber: %s", c.name, table.concat(parts, "   ")))
    end
    return table.concat(lines, "\n")
end

if arg != nil and arg[0] != nil and string.match(arg[0], "tuning%.lua$") != nil then
    if arg[1] == "check" then
        package.loaded["tuning"] = tuning
        require("layout").solve(config)
        print(tuning.check(config, tuning.design(config)))
    elseif arg[1] == "calibrate" then
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
        require("layout").solve(config)
        print(tuning.report(tuning.design(config), config))
    end
end

return tuning
