--[[
	Hazards — порывы ветра (по зонам) и тонкий лёд.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Level = require(Shared.Level)
local Storm = require(Shared.Storm)
local Heat = require(Shared.Heat)
local Heightmap = require(Shared.Heightmap)
local Rng = require(Shared.Rng)

local PlayerService = require(script.Parent.PlayerService)

local Hazards = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Порывы: у каждой зоны своё расписание
local function runGusts()
	local rng = Rng.new(Config.Seed + 99)
	local schedule = {}
	for _, z in Level.Zones do
		schedule[z.id] = { at = now() + Storm.nextGustDelay(z, rng), warned = false, zone = z }
	end
	while true do
		task.wait(0.1)
		local t = now()
		for id, g in schedule do
			if not g.warned and t >= g.at - Config.Storm.WarningSeconds then
				g.warned = true
				for _, st in PlayerService.states do
					if st.zone == id and st.tentExited and not st.finished then
						PlayerService.send(st.player, { t = "gustWarn", at = g.at })
					end
				end
			end
			if t >= g.at then
				local wx, wz = Storm.windDir(t)
				for _, st in PlayerService.states do
					if st.zone == id and st.tentExited and not st.finished and not st.fainting then
						local zp = Heightmap.zoneParams(st.s)
						local ctx = {
							cold = zp.cold,
							wind = zp.wind,
							storm = 1,
							exposed = st.exposed,
							wet = st.wet,
							jacket = st.inv.items.Jacket == true,
							boots = st.inv.items.Boots == true,
							sprinting = false,
							nearFire = st.nearFireId ~= nil,
							inHut = false,
							lost = false,
							frozen = st.god,
						}
						local penalty = Heat.gustPenalty(ctx)
						st.heat = math.max(0, st.heat - penalty)
						PlayerService.send(st.player, {
							t = "gust",
							exposed = penalty > 0,
							dx = wx,
							dz = wz,
							push = Config.Storm.GustPush * zp.wind,
							duration = Config.Storm.GustDuration,
						})
					end
				end
				g.at = t + Storm.nextGustDelay(g.zone, rng)
				g.warned = false
			end
		end
	end
end

-- Тонкий лёд: ломается через 0.45 с после того, как на него наступили
local breaking = {}
local function hookIce(part: BasePart)
	part.Touched:Connect(function(hit)
		if breaking[part] or part.Transparency >= 1 then
			return
		end
		local ch = hit:FindFirstAncestorOfClass("Model")
		local player = ch and Players:GetPlayerFromCharacter(ch)
		if not player then
			return
		end
		breaking[part] = true
		PlayerService.send(player, { t = "iceCrack" })
		local color = part.Color
		part.Color = Color3.fromRGB(40, 60, 75)
		task.delay(0.45, function()
			part.CanCollide = false
			part.Transparency = 1
			local snd = Config.Sounds.IceBreak
			if snd.Id ~= "" then
				local s = Instance.new("Sound")
				s.SoundId = snd.Id
				s.Volume = snd.Volume
				s.PlaybackSpeed = snd.Speed
				s.RollOffMaxDistance = 80
				s.Parent = part
				s:Play()
				task.delay(3, function()
					s:Destroy()
				end)
			end
			task.delay(25, function()
				part.CanCollide = true
				part.Transparency = 0.3
				part.Color = color
				breaking[part] = nil
			end)
		end)
	end)
end

function Hazards.start()
	task.spawn(runGusts)
	for _, p in CollectionService:GetTagged("ThinIce") do
		hookIce(p)
	end
	CollectionService:GetInstanceAddedSignal("ThinIce"):Connect(hookIce)
end

return Hazards
