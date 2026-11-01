--[[
	Level — данные единственного уровня «Перевал».
	Всё в studs (1 stud ≈ 0.28 м). Ось Z — вниз по склону, к лесу.
	Маршрут задан опорными точками (waypoints) с высотой y.
	Отсюда же берут данные генератор мира (сервер), тесты и самотест.
]]

local RouteMath = require(script.Parent.RouteMath)

local Level = {}

-- Опорные точки маршрута. y — высота тропы в этой точке.
Level.Waypoints = {
	{ x = 0, z = 0, y = 400, tag = "tent" }, -- 1  палатка под перевалом
	{ x = 50, z = 150, y = 382 }, -- 2
	{ x = -40, z = 330, y = 352 }, -- 3
	{ x = 30, z = 510, y = 318 }, -- 4
	{ x = -30, z = 690, y = 284 }, -- 5
	{ x = 50, z = 850, y = 254 }, -- 6
	{ x = 80, z = 990, y = 228, tag = "cedar" }, -- 7  кедр на краю леса
	{ x = 200, z = 1100, y = 214 }, -- 8
	{ x = 380, z = 1150, y = 204 }, -- 9
	{ x = 540, z = 1250, y = 194, tag = "camp" }, -- 10 стоянка в лесу
	{ x = 640, z = 1400, y = 182 }, -- 11
	{ x = 700, z = 1520, y = 164 }, -- 12 спуск в овраг
	{ x = 760, z = 1680, y = 154 }, -- 13
	{ x = 730, z = 1850, y = 148, tag = "labaz" }, -- 14 лабаз в овраге
	{ x = 820, z = 2000, y = 142 }, -- 15
	{ x = 920, z = 2100, y = 152 }, -- 16 выход из оврага
	{ x = 990, z = 2280, y = 160 }, -- 17
	{ x = 1020, z = 2440, y = 162, tag = "hut" }, -- 18 изба
}

--[[
	Зоны. startWp — с какой опорной точки начинается зона.
	wind     — доля ветра (1 = открытый склон)
	halfWidth/wallRise/wallWidth — форма рельефа вокруг тропы
	noise    — амплитуда неровностей
	gust     — интервал порывов {min, max}, сек
	fog      — плотность метели (Atmosphere.Density) 0..1
	cold     — множитель холода
]]
Level.Zones = {
	{
		id = "slope",
		startWp = 1,
		wind = 1.0,
		cold = 1.0,
		halfWidth = 70,
		wallRise = 18,
		wallWidth = 60,
		noise = 7,
		gust = { 9, 15 },
		fog = 0.52,
	},
	{
		id = "forest",
		startWp = 7,
		wind = 0.35,
		cold = 0.9,
		halfWidth = 55,
		wallRise = 10,
		wallWidth = 80,
		noise = 5,
		gust = { 18, 30 },
		fog = 0.4,
	},
	{
		id = "ravine",
		startWp = 12,
		wind = 0.22,
		cold = 1.0,
		halfWidth = 14,
		wallRise = 30,
		wallWidth = 18,
		noise = 2,
		gust = { 25, 40 },
		fog = 0.36,
	},
	{
		id = "clearing",
		startWp = 16,
		wind = 0.9,
		cold = 1.1,
		halfWidth = 80,
		wallRise = 8,
		wallWidth = 70,
		noise = 4,
		gust = { 10, 16 },
		fog = 0.8,
	},
}

Level.ZoneBlend = 70 -- плавный переход параметров рельефа между зонами, studs

-- Чекпоинты-костры. offset — смещение от осевой (по нормали маршрута).
Level.Checkpoints = {
	{ id = "tent", wp = 1, offset = 0, fire = false },
	{ id = "cedar", wp = 7, offset = -12, fire = true, prelit = true },
	{ id = "camp", wp = 10, offset = 12, fire = true, prelit = false, stash = true },
	{ id = "labaz", wp = 14, offset = 7, fire = true, prelit = false, dryWood = true },
}

-- Каменные гряды на склоне — укрытия от ветра. s — расстояние по маршруту.
Level.Outcrops = {
	{ s = 70, offset = -26, size = 12 }, -- у палатки, рядом памятный знак
	{ s = 190, offset = 14, size = 10 },
	{ s = 330, offset = -15, size = 11 },
	{ s = 470, offset = 15, size = 12 },
	{ s = 600, offset = -14, size = 10 },
	{ s = 740, offset = 16, size = 11 },
	{ s = 870, offset = -15, size = 10 },
	{ s = 960, offset = 15, size = 9 },
}

-- Ручей в овраге: смещение от осевой = Amp * sin((s - start) / Period)
Level.Creek = {
	Amp = 9,
	Period = 55,
	Phase = -1.0, -- подобрано так, чтобы у лабаза ручей ушёл к дальней стене
	HalfWidth = 4,
	Depth = 3.2,
	Water = 1.8,
	StartPad = 30, -- ручей начинается через столько studs после входа в овраг
	EndPad = 30,
	IceStep = 8,
	ThinChance = 0.38,
}

-- Предметы в палатке
Level.Items = { "Boots", "Jacket", "Flashlight", "Matches", "Thermos" }

-- Изба (финиш)
Level.Hut = {
	wp = 18,
	size = { x = 26, y = 11, z = 20 },
	padRadius = 30,
}

Level.TentPadRadius = 20
Level.FirePadRadius = 8

-------------------------------------------------------------------------------
-- Производные данные
-------------------------------------------------------------------------------

local pts = {}
for i, w in Level.Waypoints do
	pts[i] = { x = w.x, z = w.z }
end
Level.Route = RouteMath.build(pts)

function Level.wpS(i: number): number
	return Level.Route.cum[i]
end

for _, zone in Level.Zones do
	zone.startS = Level.wpS(zone.startWp)
end

function Level.zoneIndexAt(s: number): number
	local idx = 1
	for i, zone in Level.Zones do
		if s >= zone.startS then
			idx = i
		end
	end
	return idx
end

function Level.zoneAt(s: number)
	return Level.Zones[Level.zoneIndexAt(s)]
end

function Level.zoneById(id: string)
	for _, zone in Level.Zones do
		if zone.id == id then
			return zone
		end
	end
	return nil
end

-- Зона «Овраг»: границы по s
function Level.ravineRange(): (number, number)
	local r = Level.zoneById("ravine")
	local c = Level.zoneById("clearing")
	return r.startS, c.startS
end

-- Высота тропы по длине дуги: smoothstep между опорными точками (ровно у точек)
function Level.trailY(s: number): number
	local cum = Level.Route.cum
	local W = Level.Waypoints
	if s <= 0 then
		return W[1].y
	end
	for i = 1, #cum - 1 do
		if s <= cum[i + 1] then
			local t = RouteMath.smoothstep(cum[i], cum[i + 1], s)
			return RouteMath.lerp(W[i].y, W[i + 1].y, t)
		end
	end
	return W[#W].y
end

-- Положение точки «s по маршруту + смещение по нормали»
function Level.placeAt(s: number, offset: number): (number, number)
	local x, z = RouteMath.pointAt(Level.Route, s)
	local nx, nz = RouteMath.normalAt(Level.Route, s)
	return x + nx * offset, z + nz * offset
end

function Level.checkpointXZ(cp): (number, number)
	return Level.placeAt(Level.wpS(cp.wp), cp.offset)
end

function Level.checkpointById(id: string)
	for i, cp in Level.Checkpoints do
		if cp.id == id then
			return cp, i
		end
	end
	return nil, nil
end

-- Смещение ручья от осевой (nil вне оврага)
function Level.creekOffset(s: number): number?
	local r0, r1 = Level.ravineRange()
	local a, b = r0 + Level.Creek.StartPad, r1 - Level.Creek.EndPad
	if s < a or s > b then
		return nil
	end
	-- плавно «выходит» из нуля у краёв, чтобы ручей не обрывался ступенькой
	local fade = RouteMath.smoothstep(a, a + 25, s) * (1 - RouteMath.smoothstep(b - 25, b, s))
	return Level.Creek.Amp * math.sin((s - a) / Level.Creek.Period + Level.Creek.Phase) * fade
end

function Level.creekRange(): (number, number)
	local r0, r1 = Level.ravineRange()
	return r0 + Level.Creek.StartPad, r1 - Level.Creek.EndPad
end

-- Площадки, которые выравниваются (палатка, костры, изба, кедр)
function Level.pads()
	local list = {}
	local tx, tz = Level.Waypoints[1].x, Level.Waypoints[1].z
	table.insert(list, { x = tx, z = tz, r = Level.TentPadRadius, y = Level.Waypoints[1].y, id = "tent" })
	for _, cp in Level.Checkpoints do
		if cp.fire then
			local x, z = Level.checkpointXZ(cp)
			table.insert(list, { x = x, z = z, r = Level.FirePadRadius, y = Level.trailY(Level.wpS(cp.wp)), id = cp.id })
		end
	end
	local hf = Level.hutFrame()
	table.insert(list, { x = hf.x, z = hf.z, r = Level.Hut.padRadius, y = hf.y, id = "hut" })
	return list
end

-- Изба: центр (за концом тропы) и направление двери (к игроку)
function Level.hutFrame()
	local wp = Level.Waypoints[Level.Hut.wp]
	local bx, bz = Level.placeAt(Level.Route.length - 40, 0)
	local dx, dz = bx - wp.x, bz - wp.z
	local l = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / l, dz / l
	local back = Level.Hut.size.z / 2 + 2
	return { x = wp.x - dx * back, z = wp.z - dz * back, y = wp.y, dirX = dx, dirZ = dz }
end

return Level
