--[[
	Details — мелочи для атмосферы, только у этого игрока:
	• фонари ребят, уходящих по склону к лесу (в начале склона);
	• следы на снегу, которые заметает ветер.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Level = require(Shared.Level)
local Heightmap = require(Shared.Heightmap)
local Make = require(Shared.Make)

local Details = {}

local player = Players.LocalPlayer

-------------------------------------------------------------------------------
-- Фонари ребят впереди
-------------------------------------------------------------------------------
local friendsPlayed = false
function Details.playFriendsLights()
	if friendsPlayed then
		return
	end
	friendsPlayed = true
	local cedarS = Level.wpS(Level.checkpointById("cedar").wp)
	local lights = {}
	local folder = Make("Folder", { Name = "FriendsLights", Parent = workspace.CurrentCamera })
	for i = 1, 4 do
		local p = Make("Part", {
			Name = "Lamp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.7, 0.7),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 236, 190),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = folder,
		})
		Make("PointLight", { Range = 14, Brightness = 2, Color = Color3.fromRGB(255, 236, 200), Parent = p })
		table.insert(lights, { part = p, s = 110 + i * 20, off = (i % 2 == 0) and 2.5 or -2.5, phase = i * 1.7 })
	end
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local alive = 0
		for _, l in lights do
			if l.part.Parent then
				l.s += 10 * dt
				local x, z = Level.placeAt(l.s, l.off + math.sin(os.clock() * 0.7 + l.phase) * 1.5)
				local y = Heightmap.height(x, z) + 3.6 + math.abs(math.sin(os.clock() * 4 + l.phase)) * 0.25
				l.part.CFrame = CFrame.new(x, y, z)
				if l.s > cedarS - 30 then
					l.part:Destroy()
				else
					alive += 1
				end
			end
		end
		if alive == 0 then
			conn:Disconnect()
			folder:Destroy()
		end
	end)
end

function Details.reset()
	friendsPlayed = false
end

-------------------------------------------------------------------------------
-- Следы
-------------------------------------------------------------------------------
local MAX_PRINTS = 70
local prints = {}
local lastPos: Vector3? = nil
local left = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }

local function stamp(pos: Vector3, dir: Vector3)
	local hit = workspace:Raycast(pos, Vector3.new(0, -6, 0), rayParams)
	if not hit or hit.Material ~= Enum.Material.Snow then
		return
	end
	local side = dir:Cross(Vector3.yAxis).Unit * (if left then 0.45 else -0.45)
	left = not left
	local at = hit.Position + side + hit.Normal * 0.03
	local p = Make("Part", {
		Name = "Footprint",
		Size = Vector3.new(0.55, 0.05, 1.0),
		CFrame = CFrame.lookAt(at, at + dir),
		Color = Color3.fromRGB(150, 160, 178),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace.CurrentCamera,
	})
	table.insert(prints, { part = p, born = os.clock() })
	if #prints > MAX_PRINTS then
		local old = table.remove(prints, 1)
		old.part:Destroy()
	end
end

function Details.start()
	RunService.Heartbeat:Connect(function()
		local ch = player.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		local pos = hrp.CFrame.Position
		if lastPos and (pos - lastPos).Magnitude > 2.4 then
			local d = pos - lastPos
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude > 0.5 and flat.Magnitude < 12 then
				stamp(pos, flat.Unit)
			end
			lastPos = pos
		elseif not lastPos then
			lastPos = pos
		end
		-- ветер заметает следы за ~25 секунд
		local now = os.clock()
		for i = #prints, 1, -1 do
			local pr = prints[i]
			local age = now - pr.born
			if age > 25 then
				pr.part:Destroy()
				table.remove(prints, i)
			else
				pr.part.Transparency = 0.35 + 0.65 * (age / 25)
			end
		end
	end)
end

return Details
