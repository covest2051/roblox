--[[
	Точка входа клиента: экран загрузки → интро → игра.
	Реагирует на события сервера (ServerEvent) и рисует HUD.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Level = require(Shared.Level)
local Net = require(Shared.Net)

local Ui = require(script.Ui)
local Hud = require(script.Hud)
local Atmosphere = require(script.Atmosphere)
local Controls = require(script.Controls)
local Gust = require(script.Gust)
local Prompts = require(script.Prompts)
local Cinematic = require(script.Cinematic)
local Details = require(script.Details)

local player = Players.LocalPlayer

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

Ui.screen()
Ui.watchViewport()
Hud.build()
Cinematic.build()
Atmosphere.build()
Gust.start()
Controls.start()
Details.start()

if RunService:IsStudio() and Config.Debug.ShowPanel then
	require(script.DebugPanel).build()
end

-- сюжетные субтитры по событиям
local stageLines = {
	slope = { "story.slope.1", "story.slope.2" },
	cedar = { "story.cedar.1", "story.cedar.2" },
	wood = { "story.wood.1" },
	fire = { "story.fire.1" },
	ravine = { "story.ravine.1", "story.ravine.2" },
	hut = { "story.hut.1", "story.hut.2" },
}

local lightsS = Level.zoneById("forest").startS + 230

Net.ServerEvent.OnClientEvent:Connect(function(ev)
	local t = ev.t
	if t == "toast" then
		Hud.toast(ev.key, ev.vars)
	elseif t == "stage" then
		local lines = stageLines[ev.stage]
		if lines then
			Hud.subtitles(lines)
		end
		Hud.setBellVisible(ev.stage == "hut")
		if ev.stage == "slope" then
			Details.playFriendsLights()
		end
	elseif t == "gustWarn" then
		Gust.warn(ev.at)
	elseif t == "gust" then
		Gust.hit(ev)
	elseif t == "faint" then
		Cinematic.faint()
	elseif t == "wake" then
		Cinematic.wake()
	elseif t == "finish" then
		Atmosphere.setOverride(0.2, 60)
		Cinematic.finish(ev)
	elseif t == "reset" then
		Cinematic.closeFinish()
		Atmosphere.resetEvents()
		Details.reset()
		Hud.setBellVisible(false)
		task.spawn(function()
			-- персонаж мог появиться раньше, чем пришло это событие
			local t0 = os.clock()
			repeat
				task.wait(0.2)
			until (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) or os.clock() - t0 > 10
			Cinematic.playIntro(function()
				Hud.subtitles({ "story.tent.1", "story.tent.2", "story.tent.3" })
			end)
		end)
	elseif t == "pickup" then
		Atmosphere.play("Pickup")
		if ev.item ~= "Wood" then
			Hud.toast("item." .. ev.item)
			Hud.subtitle("itemdesc." .. ev.item, 3.5)
		end
	elseif t == "fellIn" then
		Atmosphere.play("Splash")
		Hud.toast("ui.fellIn")
	elseif t == "iceCrack" then
		Hud.toast("ui.iceCrack")
	elseif t == "tentCut" then
		Atmosphere.play("TentTear")
	elseif t == "selftest" then
		for _, line in ev.lines do
			print(line)
		end
		Hud.toast(ev.lines[#ev.lines] or "selftest")
	end
end)

-- «огни в небе» — когда игрок углубился в лес
task.spawn(function()
	while true do
		task.wait(0.5)
		local s = player:GetAttribute("RouteS") or 0
		local stage = player:GetAttribute("Stage") or "tent"
		if s > lightsS and s < lightsS + 400 and stage ~= "tent" and stage ~= "slope" then
			Atmosphere.playLights(function(key)
				Hud.subtitle(key, 5)
			end)
		end
	end
end)

-- подсказка, когда впервые стало по-настоящему холодно
local coldTipShown = false
player:GetAttributeChangedSignal("Heat"):Connect(function()
	local h = player:GetAttribute("Heat") or 100
	if not coldTipShown and h < 35 then
		coldTipShown = true
		Hud.subtitle("story.firstFire", 4)
	elseif h > 80 then
		coldTipShown = false
	end
end)

-- закрыть окно чтения
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton1 then
		Hud.hideText()
	end
end)

-- старт
Cinematic.waitForWorld()
Prompts.start()
if not player.Character then
	player.CharacterAdded:Wait()
end
task.wait(0.5)
Cinematic.playIntro(function()
	Hud.subtitles({ "story.tent.1", "story.tent.2", "story.tent.3" })
end)
