--[[
	Heightmap — высота рельефа в любой точке (x, z).
	Чистая функция: используется сервером для генерации Terrain
	и тестами в Lune для проверки проходимости маршрута.

	Рельеф = высота тропы (Level.trailY) + подъём по краям коридора
	+ горы за пределами + шум + русло ручья + выровненные площадки.
]]

local Level = require(script.Parent.Level)
local RouteMath = require(script.Parent.RouteMath)
local Config = require(script.Parent.Config)

local Heightmap = {}

local smoothstep = RouteMath.smoothstep
local lerp = RouteMath.lerp

local PARAMS = { "halfWidth", "wallRise", "wallWidth", "noise", "wind", "fog", "cold" }

-- Параметры зоны с плавным переходом на границах
function Heightmap.zoneParams(s: number)
	local zones = Level.Zones
	local i = Level.zoneIndexAt(s)
	local cur = zones[i]
	local out = {}
	for _, k in PARAMS do
		out[k] = cur[k]
	end
	local half = Level.ZoneBlend / 2
	-- переход к следующей зоне
	local nxt = zones[i + 1]
	if nxt and s > nxt.startS - half then
		local t = smoothstep(nxt.startS - half, nxt.startS + half, s)
		for _, k in PARAMS do
			out[k] = lerp(cur[k], nxt[k], t)
		end
	end
	-- переход от предыдущей зоны
	local prev = zones[i - 1]
	if prev and s < cur.startS + half then
		local t = smoothstep(cur.startS - half, cur.startS + half, s)
		for _, k in PARAMS do
			out[k] = lerp(prev[k], cur[k], t)
		end
	end
	return out
end

local seedA = (Config.Seed % 97) + 0.37
local seedB = (Config.Seed % 89) + 0.71

local pads = Level.pads()

-- Глубина русла в точке (0 — нет русла)
function Heightmap.creekCarve(s: number, signedOffset: number): number
	local co = Level.creekOffset(s)
	if not co then
		return 0
	end
	local cd = math.abs(signedOffset - co)
	local hw = Level.Creek.HalfWidth
	return Level.Creek.Depth * (1 - smoothstep(hw - 0.8, hw + 1.2, cd))
end

-- Полная информация о точке: высота и служебные величины
function Heightmap.sample(x: number, z: number)
	local route = Level.Route
	local s, d, px, pz, seg = RouteMath.nearest(route, x, z)
	local a, b = route.points[seg], route.points[seg + 1]
	local cross = (b.x - a.x) * (z - pz) - (b.z - a.z) * (x - px)
	local signed = if cross >= 0 then d else -d
	local p = Heightmap.zoneParams(s)
	local base = Level.trailY(s)

	-- стенки коридора и пологий подъём дальше
	local hw = p.halfWidth
	local rise = p.wallRise * smoothstep(hw, hw + p.wallWidth, d)
	rise += math.max(0, d - hw - p.wallWidth) * 0.18
	-- горы по краям карты
	rise += smoothstep(230, 340, d) * 140

	-- шум: у тропы слабее
	local amp = p.noise * (0.2 + 0.8 * smoothstep(4, math.max(hw, 8), d))
	local n = math.noise(x / 90, z / 90, seedA) * amp + math.noise(x / 31, z / 31, seedB) * amp * 0.35

	local h = base + rise + n

	-- русло ручья
	local carve = Heightmap.creekCarve(s, signed)
	h -= carve

	-- выровненные площадки
	for _, pad in pads do
		local pd = math.sqrt((x - pad.x) ^ 2 + (z - pad.z) ^ 2)
		if pd < pad.r then
			h = lerp(pad.y, h, smoothstep(pad.r * 0.55, pad.r, pd))
		end
	end

	return {
		height = h,
		s = s,
		d = d,
		offset = signed,
		carve = carve,
		zone = Level.zoneAt(s).id,
	}
end

function Heightmap.height(x: number, z: number): number
	return Heightmap.sample(x, z).height
end

-- Высота воды в ручье (nil вне ручья)
function Heightmap.waterLevel(s: number): number?
	if not Level.creekOffset(s) then
		return nil
	end
	return Level.trailY(s) - Level.Creek.Depth + Level.Creek.Water
end

-- Границы генерируемой области (studs), с запасом вокруг маршрута
function Heightmap.bounds(margin: number?): (number, number, number, number)
	local m = margin or 360
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, w in Level.Waypoints do
		minX = math.min(minX, w.x)
		maxX = math.max(maxX, w.x)
		minZ = math.min(minZ, w.z)
		maxZ = math.max(maxZ, w.z)
	end
	return minX - m, maxX + m, minZ - m, maxZ + m
end

return Heightmap
