--[[
	Layout — где стоят объекты мира: вешки, деревья, хворост, лёд, брёвна,
	камни. Детерминированно (Config.Seed), без Roblox-API — проверяется тестами.
	Сервер (Props) только превращает эти данные в Parts.
]]

local Config = require(script.Parent.Config)
local Level = require(script.Parent.Level)
local Heightmap = require(script.Parent.Heightmap)
local RouteMath = require(script.Parent.RouteMath)
local Rng = require(script.Parent.Rng)

local Layout = {}

local cache = {}
local function memo(name: string, fn: () -> any)
	return function()
		if cache[name] == nil then
			cache[name] = fn()
		end
		return cache[name]
	end
end

local function zoneStart(id: string): number
	return Level.zoneById(id).startS
end

local function cedarS(): number
	return Level.wpS(Level.checkpointById("cedar").wp)
end

-- Вешки на склоне: шест с полосатыми лентами каждые ~32 studs
Layout.poles = memo("poles", function()
	local out = {}
	local rng = Rng.new(Config.Seed + 11)
	local endS = cedarS() - 40
	local side = 1
	local s = 32
	while s < endS do
		local off = side * rng:range(4.5, 6.5)
		local x, z = Level.placeAt(s, off)
		table.insert(out, {
			x = x,
			z = z,
			y = Heightmap.height(x, z),
			toppled = rng:next() < 0.22,
			tilt = rng:range(-12, 12),
			yaw = rng:range(0, 360),
			s = s,
		})
		side = -side
		s += 32
	end
	return out
end)

-- Камни-укрытия
Layout.outcrops = memo("outcrops", function()
	local out = {}
	for i, o in Level.Outcrops do
		local x, z = Level.placeAt(o.s, o.offset)
		table.insert(out, { x = x, z = z, y = Heightmap.height(x, z), size = o.size, s = o.s, id = i })
	end
	return out
end)

-- Костры-чекпоинты
Layout.fires = memo("fires", function()
	local out = {}
	for i, cp in Level.Checkpoints do
		if cp.fire then
			local x, z = Level.checkpointXZ(cp)
			table.insert(out, {
				id = cp.id,
				index = i,
				x = x,
				z = z,
				y = Heightmap.height(x, z),
				prelit = cp.prelit == true,
				stash = cp.stash == true,
				dryWood = cp.dryWood == true,
			})
		end
	end
	return out
end)

-- Кедр стоит за костром, дальше от тропы
Layout.cedar = memo("cedar", function()
	local cp = Level.checkpointById("cedar")
	local s = Level.wpS(cp.wp)
	local off = cp.offset + (if cp.offset < 0 then -8 else 8)
	local x, z = Level.placeAt(s, off)
	return { x = x, z = z, y = Heightmap.height(x, z) }
end)

-- Ручей: точки осевой линии русла
local function creekPoint(s: number): (number, number)
	local co = Level.creekOffset(s) or 0
	return Level.placeAt(s, co)
end

local function creekDir(s: number): (number, number)
	local x1, z1 = creekPoint(s - 1)
	local x2, z2 = creekPoint(s + 1)
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	return dx / len, dz / len
end

local function rimY(s: number): number
	local co = Level.creekOffset(s) or 0
	local w = Level.Creek.HalfWidth + 1.8
	local x1, z1 = Level.placeAt(s, co - w)
	local x2, z2 = Level.placeAt(s, co + w)
	return (Heightmap.height(x1, z1) + Heightmap.height(x2, z2)) / 2
end

-- Места, где ручей пересекает осевую тропы
Layout.creekCrossings = memo("creekCrossings", function()
	local a, b = Level.creekRange()
	local out = {}
	local prev = Level.creekOffset(a + 1) or 0
	local s = a + 2
	while s < b do
		local co = Level.creekOffset(s) or 0
		if (prev < 0 and co >= 0) or (prev > 0 and co <= 0) then
			table.insert(out, s)
		end
		prev = co
		s += 1
	end
	return out
end)

-- Лёд поверх ручья; часть — тонкий (проламывается)
Layout.ice = memo("ice", function()
	local a, b = Level.creekRange()
	local C = Level.Creek
	local out = {}
	local s = a + C.IceStep / 2
	local i = 0
	while s < b do
		i += 1
		local x, z = creekPoint(s)
		local dx, dz = creekDir(s)
		local thin = Rng.hash2(i, 7, Config.Seed) < C.ThinChance
		table.insert(out, {
			id = i,
			x = x,
			z = z,
			y = rimY(s) - 0.35,
			dirX = dx,
			dirZ = dz,
			len = C.IceStep + 0.6,
			width = C.HalfWidth * 2 + 2.5,
			thin = thin,
			s = s,
		})
		s += C.IceStep
	end
	return out
end)

-- Брёвна-мостики у каждого пересечения ручья с тропой
Layout.logs = memo("logs", function()
	local out = {}
	for i, sc in Layout.creekCrossings() do
		local s = sc + (if i % 2 == 0 then 9 else -9)
		local x, z = creekPoint(s)
		local dx, dz = creekDir(s)
		table.insert(out, {
			x = x,
			z = z,
			y = rimY(s) + 0.5,
			-- поперёк ручья
			dirX = -dz,
			dirZ = dx,
			len = Level.Creek.HalfWidth * 2 + 8,
			s = s,
		})
	end
	return out
end)

-- Кучи хвороста
Layout.woodPiles = memo("woodPiles", function()
	local out = {}
	local rng = Rng.new(Config.Seed + 23)
	local fStart, rStart = zoneStart("forest"), zoneStart("ravine")
	local rEnd = zoneStart("clearing")
	local campS = Level.wpS(Level.checkpointById("camp").wp)
	local campOff = Level.checkpointById("camp").offset

	local function add(s: number, off: number)
		local x, z = Level.placeAt(s, off)
		table.insert(out, { id = #out + 1, x = x, z = z, y = Heightmap.height(x, z), s = s })
	end

	-- лес: вдоль тропы
	local s = fStart + 40
	while s < rStart - 30 do
		if math.abs(s - campS) > 30 then
			local side = if rng:next() < 0.5 then -1 else 1
			add(s, side * rng:range(9, 22))
		end
		s += rng:range(30, 42)
	end
	-- гарантированно рядом со стоянкой (с другой стороны тропы от костра)
	local opp = if campOff > 0 then -1 else 1
	add(campS - 18, opp * 9)
	add(campS + 6, opp * 12)
	add(campS + 24, opp * 8)

	-- овраг: на сухой стороне дна
	s = rStart + 60
	while s < rEnd - 40 do
		local co = Level.creekOffset(s) or 0
		local off = if co > 0 then -8 else 8
		if math.abs(off - co) > Level.Creek.HalfWidth + 2.5 then
			add(s, off)
		end
		s += 95
	end
	return out
end)

-- Деревья (ели) и затесы-метки на стволах вдоль тропы
Layout.trees = memo("trees", function()
	local out = {}
	local route = Level.Route
	local minX, maxX, minZ, maxZ = Heightmap.bounds(170)
	local step = 15
	local fStart = zoneStart("forest")
	local pads = Level.pads()
	local piles = Layout.woodPiles()
	local fires = Layout.fires()
	local cedar = Layout.cedar()

	local function blocked(x: number, z: number, clearance: number): boolean
		for _, p in pads do
			if (x - p.x) ^ 2 + (z - p.z) ^ 2 < (p.r + clearance) ^ 2 then
				return true
			end
		end
		for _, p in piles do
			if (x - p.x) ^ 2 + (z - p.z) ^ 2 < 5 ^ 2 then
				return true
			end
		end
		for _, f in fires do
			if (x - f.x) ^ 2 + (z - f.z) ^ 2 < 14 ^ 2 then
				return true
			end
		end
		if (x - cedar.x) ^ 2 + (z - cedar.z) ^ 2 < 16 ^ 2 then
			return true
		end
		return false
	end

	-- затесы: принудительные деревья у тропы в лесу
	local blazeS = fStart + 25
	local side = 1
	local rStart = zoneStart("ravine")
	while blazeS < rStart - 10 do
		local x, z = Level.placeAt(blazeS, side * 8.5)
		if not blocked(x, z, 0) then
			local px, pz = RouteMath.pointAt(route, blazeS)
			table.insert(out, {
				x = x,
				z = z,
				y = Heightmap.height(x, z),
				scale = 1.0,
				blaze = true,
				faceX = px - x,
				faceZ = pz - z,
			})
		end
		side = -side
		blazeS += 34
	end

	local gx = math.floor(minX / step)
	while gx * step < maxX do
		local gz = math.floor(minZ / step)
		while gz * step < maxZ do
			local r1 = Rng.hash2(gx, gz, Config.Seed)
			local r2 = Rng.hash2(gx + 101, gz - 37, Config.Seed)
			local r3 = Rng.hash2(gx - 59, gz + 211, Config.Seed)
			local x = gx * step + (r2 - 0.5) * step * 0.8
			local z = gz * step + (r3 - 0.5) * step * 0.8
			local s, d = RouteMath.nearest(route, x, z)
			local zone = Level.zoneAt(s).id
			local density = 0
			if zone == "forest" then
				if d > 11 and d < 150 then
					density = if d < 20 then 0.22 else 0.5
				end
			elseif zone == "ravine" then
				if d > 36 and d < 150 then
					density = 0.45
				end
			elseif zone == "clearing" then
				if d > 58 and d < 150 then
					density = 0.32
				end
			elseif zone == "slope" then
				if s > fStart - 140 and d > 22 and d < 150 then
					density = 0.12
				end
			end
			if density > 0 and r1 < density and not blocked(x, z, 3) then
				table.insert(out, {
					x = x,
					z = z,
					y = Heightmap.height(x, z),
					scale = 0.7 + Rng.hash2(gx, gz, Config.Seed + 5) * 0.7,
					blaze = false,
				})
			end
			gz += 1
		end
		gx += 1
	end
	return out
end)

-- Лагерь: табличка и памятный знак
Layout.camp = memo("camp", function()
	local tx, tz = Level.Waypoints[1].x, Level.Waypoints[1].z
	local nx, nz = RouteMath.normalAt(Level.Route, 0)
	local tanX, tanZ = RouteMath.tangentAt(Level.Route, 0)
	local signX, signZ = tx + nx * 13 - tanX * 4, tz + nz * 13 - tanZ * 4
	local first = Layout.outcrops()[1]
	-- памятный знак — на ближайшей к тропе стороне первой гряды
	local px, pz = RouteMath.pointAt(Level.Route, Level.Outcrops[1].s)
	local vx, vz = px - first.x, pz - first.z
	local vl = math.sqrt(vx * vx + vz * vz)
	local mx, mz = first.x + vx / vl * (first.size * 0.75), first.z + vz / vl * (first.size * 0.75)
	return {
		tent = { x = tx, z = tz, y = Level.Waypoints[1].y, nx = nx, nz = nz, tx = tanX, tz = tanZ },
		sign = { x = signX, z = signZ, y = Heightmap.height(signX, signZ) },
		memorial = { x = mx, z = mz, y = Heightmap.height(mx, mz), faceX = vx / vl, faceZ = vz / vl },
	}
end)

return Layout
