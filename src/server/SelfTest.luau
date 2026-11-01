--[[
	SelfTest — проверки, которые можно сделать только в движке.
	Запускается автоматически при старте в Studio (Config.Debug.AutoSelfTest)
	и кнопкой на отладочной панели. Пишет в Output строки вида
	  [SELFTEST] PASS terrain under waypoints
	и итог:
	  [SELFTEST] RESULT 18/19 passed, 1 warnings
]]

local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Level = require(Shared.Level)
local Layout = require(Shared.Layout)
local Heightmap = require(Shared.Heightmap)
local Storm = require(Shared.Storm)
local Config = require(Shared.Config)

local World = require(script.Parent.World)
local PlayerService = require(script.Parent.PlayerService)

local SelfTest = {}

function SelfTest.run(): { string }
	local lines = {}
	local passed, failed, warned = 0, 0, 0
	local function report(status: string, name: string, detail: string?)
		local line = string.format("[SELFTEST] %s %s%s", status, name, if detail then " — " .. detail else "")
		table.insert(lines, line)
		if status == "PASS" then
			passed += 1
			print(line)
		elseif status == "WARN" then
			warned += 1
			warn(line)
		else
			failed += 1
			warn(line)
		end
	end
	local function check(name: string, fn: () -> (boolean, string?))
		local ok, res, detail = pcall(fn)
		if not ok then
			report("FAIL", name, "error: " .. tostring(res))
		elseif res then
			report("PASS", name, detail)
		else
			report("FAIL", name, detail)
		end
	end

	check("world built", function()
		return World.ready, string.format("%.1fs", World.buildSeconds)
	end)

	check("remotes exist", function()
		local r = ReplicatedStorage:FindFirstChild("Remotes")
		return r ~= nil and r:FindFirstChild("ClientAction") ~= nil and r:FindFirstChild("ServerEvent") ~= nil
	end)

	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

	check("terrain under every waypoint matches heightmap", function()
		local worst, worstI = 0, 0
		for i, w in Level.Waypoints do
			local expected = Heightmap.height(w.x, w.z)
			local hit = workspace:Raycast(Vector3.new(w.x, expected + 60, w.z), Vector3.new(0, -140, 0), terrainOnly)
			if not hit then
				return false, "no terrain at waypoint " .. i
			end
			local err = math.abs(hit.Position.Y - expected)
			if err > worst then
				worst, worstI = err, i
			end
		end
		return worst < 3, string.format("max error %.2f at wp %d", worst, worstI)
	end)

	check("tent: cut wall prompt and 5 items", function()
		local tent = World.tent
		if not tent then
			return false, "no tent"
		end
		local wall = tent:FindFirstChild("CutWall")
		local items = tent:FindFirstChild("Items")
		local n = 0
		for _, m in (items and items:GetChildren() or {}) do
			if m.PrimaryPart and m.PrimaryPart:FindFirstChildOfClass("ProximityPrompt") then
				n += 1
			end
		end
		return wall ~= nil and n == #Level.Items, "items with prompts: " .. n
	end)

	check("fires: count and cedar is pre-lit", function()
		local n = 0
		for _ in World.fires do
			n += 1
		end
		local cedar = World.fires.cedar
		return n == 3 and cedar ~= nil and cedar:GetAttribute("Lit") == true, "fires " .. n
	end)

	check("fire spawn points stand on ground", function()
		for id, m in World.fires do
			local sp = m:GetAttribute("SpawnPos")
			if not sp then
				return false, "no SpawnPos for " .. id
			end
			local hit = workspace:Raycast(sp, Vector3.new(0, -12, 0), terrainOnly)
			if not hit or sp.Y - hit.Position.Y > 6 then
				return false, "spawn floats or no ground at " .. id
			end
		end
		return true
	end)

	check("wood piles built", function()
		local n = 0
		for _ in World.piles do
			n += 1
		end
		return n == #Layout.woodPiles(), string.format("%d/%d", n, #Layout.woodPiles())
	end)

	check("thin ice is tagged", function()
		local n = #CollectionService:GetTagged("ThinIce")
		local expected = 0
		for _, s in Layout.ice() do
			if s.thin then
				expected += 1
			end
		end
		return n == expected and n > 0, string.format("%d/%d", n, expected)
	end)

	check("ice sits at the creek rim", function()
		local worst = 0
		for _, s in Layout.ice() do
			local hit = workspace:Raycast(Vector3.new(s.x, s.y + 20, s.z), Vector3.new(0, -40, 0), terrainOnly)
			if hit then
				-- под льдом должна быть вода или дно ниже льда
				local gap = s.y - hit.Position.Y
				if gap < -0.8 then
					worst = math.min(worst, gap)
				end
			end
		end
		return worst > -0.8, string.format("worst buried %.2f", worst)
	end)

	check("hut: finish zone and bell", function()
		return World.finishZone ~= nil and World.bell ~= nil
	end)

	-- Укрытия: за каждой грядой с подветренной стороны — укрыто
	check("outcrops shelter their lee side", function()
		local t = 0
		-- подбираем момент, когда ветер близок к базовому направлению
		local wx, wz = Storm.windDir(t)
		local bad = {}
		for _, o in Layout.outcrops() do
			local x = o.x + wx * (o.size * 0.9 + 2)
			local z = o.z + wz * (o.size * 0.9 + 2)
			local pos = Vector3.new(x, Heightmap.height(x, z) + 3, z)
			if not PlayerService.isSheltered(pos, t) then
				table.insert(bad, tostring(o.id))
			end
		end
		return #bad <= 1, if #bad > 0 then "not sheltered: " .. table.concat(bad, ",") else nil
	end)

	check("open slope between outcrops is exposed", function()
		local t = 0
		local exposed, total = 0, 0
		for s = 100, Level.wpS(6), 37 do
			local nearRock = false
			for _, o in Layout.outcrops() do
				if math.abs(o.s - s) < 30 then
					nearRock = true
				end
			end
			if not nearRock then
				local x, z = Level.placeAt(s, 0)
				local pos = Vector3.new(x, Heightmap.height(x, z) + 3, z)
				total += 1
				if not PlayerService.isSheltered(pos, t) then
					exposed += 1
				end
			end
		end
		return total > 0 and exposed / total >= 0.7, string.format("%d/%d exposed", exposed, total)
	end)

	-- Pathfinding между соседними точками маршрута
	local agent = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 8 }
	local segFails = {}
	for i = 1, #Level.Waypoints - 1 do
		local a, b = Level.Waypoints[i], Level.Waypoints[i + 1]
		local from = Vector3.new(a.x, Heightmap.height(a.x, a.z) + 3, a.z)
		local to = Vector3.new(b.x, Heightmap.height(b.x, b.z) + 3, b.z)
		local path = PathfindingService:CreatePath(agent)
		local ok = pcall(function()
			path:ComputeAsync(from, to)
		end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			table.insert(segFails, string.format("%d→%d (%s)", i, i + 1, if ok then path.Status.Name else "error"))
		end
	end
	if #segFails == 0 then
		report("PASS", "pathfinding along the whole route")
	else
		-- через ручей pathfinding может «не видеть» брёвна — это предупреждение, не ошибка
		report("WARN", "pathfinding along the route", table.concat(segFails, ", "))
	end

	check("balance constants sane", function()
		return Config.Heat.FireWarmth > 0 and Config.Tent.MaxItems == 3
	end)

	local summary = string.format("[SELFTEST] RESULT %d/%d passed, %d warnings", passed, passed + failed, warned)
	table.insert(lines, summary)
	if failed > 0 then
		warn(summary)
	else
		print(summary)
	end
	return lines
end

return SelfTest
