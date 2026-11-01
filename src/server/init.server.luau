--[[
	Точка входа сервера: строим мир, затем запускаем сервисы.
	Пока мир строится, игроки видят экран загрузки (атрибут WorldReady).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local World = require(script.World)
local PlayerService = require(script.PlayerService)
local Interactions = require(script.Interactions)
local Hazards = require(script.Hazards)
local Actions = require(script.Actions)

-- персонажей не создаём, пока нет земли под ногами
Players.CharacterAutoLoads = false
workspace:SetAttribute("WorldReady", false)

pcall(function()
	local Lighting = game:GetService("Lighting")
	Lighting.LightingStyle = Enum.LightingStyle.Realistic
	Lighting.PrioritizeLightingQuality = true
end)

World.build(function(stage, p)
	workspace:SetAttribute("BuildStage", stage)
	workspace:SetAttribute("BuildProgress", p)
end)
print(string.format("[Pereval] world built in %.1fs", World.buildSeconds))

PlayerService.start()
Interactions.start()
Hazards.start()
Actions.start()

Players.CharacterAutoLoads = true
for _, p in Players:GetPlayers() do
	if not p.Character then
		p:LoadCharacter()
	end
end

if RunService:IsStudio() and Config.Debug.AutoSelfTest then
	task.delay(3, function()
		require(script.SelfTest).run()
	end)
end
