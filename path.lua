-- path.lua
-- 3D tube centrelines: polylines with filleted corners, sampled by arc
-- length. Acoustic positions (holes, ends) are arc lengths along these.

path = {}

function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
function add(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
function mul(a, k) return { a[1] * k, a[2] * k, a[3] * k } end
function norm(a) return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) end
function unit(a)
    n = norm(a)
    return { a[1] / n, a[2] / n, a[3] / n }
end

path.sub, path.add, path.mul, path.norm, path.unit = sub, add, mul, norm, unit

-- Sample a polyline whose corners are rounded (quadratic Bezier between
-- the tangent points `radius` either side of each corner). Returns
-- { pts = {...}, s = {...}, length = L, straights = {{a, b, s0}, ...} }.
function path.build(points, radius, step)
    if step == nil then
        step = 1.0
    end
    n = #points
    -- tangent point distance per interior corner, limited by segment halves
    cut = {}
    for i = 2, n - 1 do
        lin = norm(sub(points[i], points[i - 1]))
        lout = norm(sub(points[i + 1], points[i]))
        cut[i] = math.min(radius, lin / 2, lout / 2)
    end
    out = { pts = {}, s = {}, straights = {} }
    s = 0
    last = nil
    push = function(p)
        if last != nil then
            s = s + norm(sub(p, last))
        end
        table.insert(out.pts, p)
        table.insert(out.s, s)
        last = p
    end
    seg_start = points[1]
    for i = 2, n do
        dir = unit(sub(points[i], points[i - 1]))
        seg_end = points[i]
        if i < n then
            seg_end = sub(points[i], mul(dir, cut[i]))
        end
        -- straight part
        len = norm(sub(seg_end, seg_start))
        k = math.max(1, math.ceil(len / step))
        if last == nil then
            push(seg_start)
        end
        table.insert(out.straights, { seg_start, seg_end, s })
        for j = 1, k do
            push(add(seg_start, mul(sub(seg_end, seg_start), j / k)))
        end
        -- corner
        if i < n then
            dir2 = unit(sub(points[i + 1], points[i]))
            p0 = seg_end
            p2 = add(points[i], mul(dir2, cut[i]))
            m = math.max(4, math.ceil(2 * cut[i] / step))
            for j = 1, m do
                t = j / m
                a = (1 - t) * (1 - t)
                b = 2 * (1 - t) * t
                c = t * t
                push(add(add(mul(p0, a), mul(points[i], b)), mul(p2, c)))
            end
            seg_start = p2
        end
    end
    out.length = s
    return out
end

-- Arc length of point q, which must lie on one of the straight parts.
function path.s_of(p, q)
    for _, st in ipairs(p.straights) do
        a, b, s0 = st[1], st[2], st[3]
        ab = sub(b, a)
        l = norm(ab)
        if l > 0 then
            t = ((q[1] - a[1]) * ab[1] + (q[2] - a[2]) * ab[2] + (q[3] - a[3]) * ab[3]) / (l * l)
            foot = add(a, mul(ab, t))
            if t >= -1e-6 and t <= 1 + 1e-6 and norm(sub(foot, q)) < 1e-6 then
                return s0 + t * l
            end
        end
    end
    return nil
end

-- Truncate a sampled path at arc length L (interpolating the last point).
function path.truncate(p, L)
    out = { pts = {}, s = {}, straights = p.straights, length = L }
    for i = 1, #p.pts do
        if p.s[i] <= L then
            table.insert(out.pts, p.pts[i])
            table.insert(out.s, p.s[i])
        else
            a, b = p.pts[i - 1], p.pts[i]
            t = (L - p.s[i - 1]) / (p.s[i] - p.s[i - 1])
            table.insert(out.pts, add(a, mul(sub(b, a), t)))
            table.insert(out.s, L)
            return out
        end
    end
    return out
end

-- Point and unit tangent at arc length s.
function path.at(p, s)
    for i = 2, #p.pts do
        if p.s[i] >= s then
            a, b = p.pts[i - 1], p.pts[i]
            t = (s - p.s[i - 1]) / (p.s[i] - p.s[i - 1])
            return add(a, mul(sub(b, a), t)), unit(sub(b, a))
        end
    end
    n = #p.pts
    return p.pts[n], unit(sub(p.pts[n], p.pts[n - 1]))
end

return path
