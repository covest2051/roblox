--[[
	Actions — запросы клиента: бег, фонарь, термос, конец интро, рестарт,
	а в Studio — отладочные команды (телепорт, бессмертие, вещи).
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Level = require(Shared.Level)
local Inventory = require(Shared.Inventory)
local Heightmap = require(Shared.Heightmap)
local Net = require(Shared.Net)

local World = require(script.Parent.World)
local PlayerService = require(script.Parent.PlayerService)

local Actions = {}

local debugCommands = {}

function debugCommands.cp(st, arg)
	local idx = tonumber(arg) or 1
	if idx >= #Level.Checkpoints + 1 then
		-- финиш: перед дверью избы
		local hf = Level.hutFrame()
		local x = hf.x + hf.dirX * (Level.Hut.size.z / 2 + 8)
		local z = hf.z + hf.dirZ * (Level.Hut.size.z / 2 + 8)
		PlayerService.teleport(st.player, Vector3.new(x, Heightmap.height(x, z) + 4, z))
		return
	end
	local cp = Level.Checkpoints[idx]
	if not cp then
		return
	end
	st.tentExited = true
	st.introDone = true
	st.checkpoint = math.max(st.checkpoint, idx)
	local pos = PlayerService.spawnPosition({ checkpoint = idx } :: any)
	if not pos then
		pos = World.tentExitPoint()
	end
	PlayerService.teleport(st.player, pos)
end

function debugCommands.god(st)
	st.god = not st.god
end

function debugCommands.items(st)
	for _, name in Level.Items do
		st.inv.items[name] = true
	end
	st.inv.taken = #Level.Items
	st.inv.matches += 5
	st.inv.sips += 2
	st.inv.battery = Config.Items.Flashlight.BatteryMax
	st.inv.wood = Config.Wood.Max
	PlayerService.ensureFlashlight(st)
end

function debugCommands.heat(st, arg)
	st.heat = tonumber(arg) or 10
end

function debugCommands.wet(st)
	st.wet = true
	st.wetUntil = workspace:GetServerTimeNow() + Config.Wet.Duration
end

function debugCommands.selftest(st)
	local SelfTest = require(script.Parent.SelfTest)
	task.spawn(function()
		local lines = SelfTest.run()
		PlayerService.send(st.player, { t = "selftest", lines = lines })
	end)
end

function debugCommands.restart(st)
	PlayerService.reset(st)
end

function debugCommands.s(st, arg)
	-- телепорт на точку маршрута по длине дуги
	local s = math.clamp(tonumber(arg) or 0, 0, Level.Route.length)
	local x, z = Level.placeAt(s, 0)
	st.tentExited = true
	st.introDone = true
	PlayerService.teleport(st.player, Vector3.new(x, Heightmap.height(x, z) + 4, z))
end

function Actions.start()
	Net.ClientAction.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then
			return
		end
		local st = PlayerService.get(player)
		if not st then
			return
		end
		local t = payload.t
		if t == "sprint" then
			st.sprintHeld = payload.on == true
		elseif t == "flashlight" then
			if not st.inv.items.Flashlight then
				PlayerService.toast(player, "ui.noFlashlight")
			elseif st.inv.battery <= 0 then
				PlayerService.toast(player, "ui.flashDead")
			else
				st.flashlightOn = not st.flashlightOn
				PlayerService.ensureFlashlight(st)
			end
		elseif t == "thermos" then
			if not st.inv.items.Thermos then
				PlayerService.toast(player, "ui.noThermos")
			else
				local gain = Inventory.sip(st.inv)
				if gain > 0 then
					st.heat = math.min(Config.Heat.Max, st.heat + gain)
					PlayerService.toast(player, "ui.sip")
				else
					PlayerService.toast(player, "ui.thermosEmpty")
				end
			end
		elseif t == "introDone" then
			PlayerService.startTentTimer(st)
		elseif t == "restart" then
			if st.finished then
				PlayerService.reset(st)
			end
		elseif t == "debug" then
			if not RunService:IsStudio() then
				return
			end
			local cmd = debugCommands[payload.cmd]
			if cmd then
				local ok, err = pcall(cmd, st, payload.arg)
				if not ok then
					warn("[Debug]", payload.cmd, err)
				end
			end
		end
	end)
end

return Actions
