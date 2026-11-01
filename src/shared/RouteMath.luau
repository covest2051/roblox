--[[
	RouteMath — геометрия ломаной в плоскости XZ (без Roblox-типов,
	чтобы тестироваться в Lune). Точка — { x = number, z = number }.
]]

local RouteMath = {}

export type P2 = { x: number, z: number }

export type Polyline = {
	points: { P2 },
	cum: { number }, -- накопленная длина до точки i
	length: number,
}

function RouteMath.build(points: { P2 }): Polyline
	assert(#points >= 2, "polyline needs >= 2 points")
	local cum = { 0 }
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		cum[i] = cum[i - 1] + math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
	return { points = points, cum = cum, length = cum[#points] }
end

-- Ближайшая точка на ломаной: возвращает s (длина дуги), d (расстояние), px, pz, индекс сегмента
function RouteMath.nearest(line: Polyline, x: number, z: number): (number, number, number, number, number)
	local pts = line.points
	local bestD2, bestS, bestX, bestZ, bestI = math.huge, 0, pts[1].x, pts[1].z, 1
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local abx, abz = b.x - a.x, b.z - a.z
		local len2 = abx * abx + abz * abz
		local t = 0
		if len2 > 0 then
			t = math.clamp(((x - a.x) * abx + (z - a.z) * abz) / len2, 0, 1)
		end
		local px, pz = a.x + abx * t, a.z + abz * t
		local d2 = (x - px) ^ 2 + (z - pz) ^ 2
		if d2 < bestD2 then
			bestD2 = d2
			bestS = line.cum[i] + t * math.sqrt(len2)
			bestX, bestZ, bestI = px, pz, i
		end
	end
	return bestS, math.sqrt(bestD2), bestX, bestZ, bestI
end

-- Знаковое расстояние: >0 в сторону normalAt(), <0 в противоположную
function RouteMath.signedOffset(line: Polyline, x: number, z: number): number
	local _, d, px, pz, i = RouteMath.nearest(line, x, z)
	local a, b = line.points[i], line.points[i + 1]
	local cross = (b.x - a.x) * (z - pz) - (b.z - a.z) * (x - px)
	return if cross >= 0 then d else -d
end

local function segmentAt(line: Polyline, s: number): number
	local cum = line.cum
	if s <= 0 then
		return 1
	end
	for i = 1, #cum - 1 do
		if s <= cum[i + 1] then
			return i
		end
	end
	return #cum - 1
end

-- Точка на ломаной по длине дуги
function RouteMath.pointAt(line: Polyline, s: number): (number, number)
	s = math.clamp(s, 0, line.length)
	local i = segmentAt(line, s)
	local a, b = line.points[i], line.points[i + 1]
	local segLen = line.cum[i + 1] - line.cum[i]
	local t = if segLen > 0 then (s - line.cum[i]) / segLen else 0
	return a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
end

-- Единичный касательный вектор (сглаженный вблизи вершин)
function RouteMath.tangentAt(line: Polyline, s: number): (number, number)
	local h = 12
	local x1, z1 = RouteMath.pointAt(line, s - h)
	local x2, z2 = RouteMath.pointAt(line, s + h)
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-6 then
		local a, b = line.points[1], line.points[2]
		dx, dz = b.x - a.x, b.z - a.z
		len = math.sqrt(dx * dx + dz * dz)
	end
	return dx / len, dz / len
end

-- Нормаль к маршруту (та же сторона, что положительный signedOffset)
function RouteMath.normalAt(line: Polyline, s: number): (number, number)
	local tx, tz = RouteMath.tangentAt(line, s)
	return -tz, tx
end

-- Сглаженная ступенька 0..1
function RouteMath.smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

function RouteMath.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

return RouteMath
