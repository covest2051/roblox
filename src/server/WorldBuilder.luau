--!native
--[[
	WorldBuilder — генерирует Terrain по Heightmap через WriteVoxels.
	Чанки 64×64 studs; высота чанка — от min(h)-16 до max(h)+4.
	Крутые склоны получают материал Rock, русло ручья — воду.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Heightmap = require(Shared.Heightmap)
local Level = require(Shared.Level)

local WorldBuilder = {}

local VOX = 4
local CHUNK = 64
local N = CHUNK // VOX -- колонок на чанк по оси

local SNOW = Enum.Material.Snow
local ROCK = Enum.Material.Rock
local WATER = Enum.Material.Water
local AIR = Enum.Material.Air

local ROCK_SLOPE = 1.35 -- перепад высот на 4 studs, после которого — скала (~53°)

local function floorTo(v: number, step: number): number
	return math.floor(v / step) * step
end

local function ceilTo(v: number, step: number): number
	return math.ceil(v / step) * step
end

function WorldBuilder.buildTerrain(onProgress: ((number) -> ())?)
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(SNOW, Color3.fromRGB(226, 232, 242))
	terrain:SetMaterialColor(ROCK, Color3.fromRGB(78, 82, 92))
	terrain.WaterColor = Color3.fromRGB(20, 32, 40)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0
	terrain.WaterWaveSpeed = 0

	local minX, maxX, minZ, maxZ = Heightmap.bounds(360)
	minX, minZ = floorTo(minX, CHUNK), floorTo(minZ, CHUNK)
	maxX, maxZ = ceilTo(maxX, CHUNK), ceilTo(maxZ, CHUNK)

	local total = ((maxX - minX) // CHUNK) * ((maxZ - minZ) // CHUNK)
	local done = 0
	local lastYield = os.clock()

	for cx = minX, maxX - CHUNK, CHUNK do
		for cz = minZ, maxZ - CHUNK, CHUNK do
			-- высоты с «фартуком» в одну колонку для расчёта уклона
			local h = table.create(N + 2)
			local water = table.create(N)
			local lo, hi = math.huge, -math.huge
			for i = 0, N + 1 do
				local row = table.create(N + 2)
				h[i] = row
				local x = cx + (i - 0.5) * VOX
				for k = 0, N + 1 do
					local z = cz + (k - 0.5) * VOX
					local smp = Heightmap.sample(x, z)
					row[k] = smp.height
					if i >= 1 and i <= N and k >= 1 and k <= N then
						if smp.height < lo then
							lo = smp.height
						end
						if smp.height > hi then
							hi = smp.height
						end
						if smp.carve > 0.3 then
							local wl = Heightmap.waterLevel(smp.s)
							if wl and wl > smp.height then
								water[(i - 1) * N + k] = wl
								if wl > hi then
									hi = wl
								end
							end
						end
					end
				end
			end

			local y0 = floorTo(lo - 16, VOX)
			local y1 = ceilTo(hi + 4, VOX)
			local ny = (y1 - y0) // VOX

			local mats = table.create(N)
			local occ = table.create(N)
			for i = 1, N do
				local mi = table.create(ny)
				local oi = table.create(ny)
				mats[i] = mi
				occ[i] = oi
				for j = 1, ny do
					mi[j] = table.create(N, AIR)
					oi[j] = table.create(N, 0)
				end
				local rowP, row, rowN = h[i - 1], h[i], h[i + 1]
				for k = 1, N do
					local hh = row[k]
					local slope = math.max(
						math.abs(rowN[k] - rowP[k]),
						math.abs(row[k + 1] - row[k - 1])
					) / 2
					local surfaceMat = if slope > ROCK_SLOPE then ROCK else SNOW
					local wl = water[(i - 1) * N + k]
					for j = 1, ny do
						local yb = y0 + (j - 1) * VOX
						local g = (hh - yb) / VOX
						if g >= 1 then
							mi[j][k] = if hh - yb > 10 then ROCK else surfaceMat
							oi[j][k] = 1
						elseif g > 0 then
							mi[j][k] = surfaceMat
							oi[j][k] = math.max(g, 0.05)
						elseif wl and yb < wl then
							mi[j][k] = WATER
							oi[j][k] = math.clamp((wl - yb) / VOX, 0.1, 1)
						end
					end
				end
			end

			local region = Region3.new(Vector3.new(cx, y0, cz), Vector3.new(cx + CHUNK, y1, cz + CHUNK))
			terrain:WriteVoxels(region, VOX, mats, occ)

			done += 1
			if os.clock() - lastYield > 0.05 then
				if onProgress then
					onProgress(done / total)
				end
				task.wait()
				lastYield = os.clock()
			end
		end
	end
	if onProgress then
		onProgress(1)
	end
end

-- Каменные гряды-укрытия: несколько шаров Rock, вытянутых поперёк ветра
function WorldBuilder.buildOutcrops(outcrops, rng)
	local terrain = workspace.Terrain
	for _, o in outcrops do
		local n = 3 + (o.id % 3)
		for _ = 1, n do
			local ang = rng:range(0, math.pi * 2)
			local dist = rng:range(0, o.size * 0.7)
			local r = o.size * rng:range(0.45, 0.8)
			local x = o.x + math.cos(ang) * dist
			local z = o.z + math.sin(ang) * dist
			local y = Heightmap.height(x, z) + r * rng:range(0.15, 0.45)
			terrain:FillBall(Vector3.new(x, y, z), r, ROCK)
		end
	end
end

-- Сугроб, заваливший вход в палатку
function WorldBuilder.buryTentEntrance(pos: Vector3)
	workspace.Terrain:FillBall(pos, 6.5, SNOW)
end

WorldBuilder.Level = Level

return WorldBuilder
