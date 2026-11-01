--[[
	Прогон сервера на заглушке движка: сборка мира, бот проходит уровень.
	Запуск (после rojo build): lune run tests/engine/server_sim.luau
]]

local process = require("@lune/process")
local Sim = require("./Sim")
local task = require("@lune/task")

local failures = {}
local function check(cond, msg)
	if cond then
		print("  ✓ " .. msg)
	else
		print("  ✗ " .. msg)
		table.insert(failures, msg)
	end
end

local function waitUntil(fn, timeout)
	local t0 = os.clock()
	while not fn() do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.05)
	end
	return true
end

local game = Sim.loadPlace(process.args[1] or "build/game.rbxl")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS.Shared
local Heightmap = Sim.require(Shared.Heightmap)
local Level = Sim.require(Shared.Level)
local Layout = Sim.require(Shared.Layout)
Sim.heightAt = Heightmap.height

local player = Sim.addPlayer("Tester")
local server = game:GetService("ServerScriptService").Server
local ws = game:GetService("Workspace")

print("== boot")
local t0 = os.clock()
Sim.runScript(server)
check(waitUntil(function()
	return ws:GetAttribute("WorldReady") == true
end, 240), "world builds")
if not ws:GetAttribute("WorldReady") then
	process.exit(1)
end
print(string.format("  world build %.1fs, %d WriteVoxels, %.1fM voxels, %d balls", os.clock() - t0, Sim.terrain.writes, Sim.terrain.voxels / 1e6, #Sim.terrain.balls))
check(#Sim.terrain.errors == 0, "WriteVoxels arguments valid" .. (if #Sim.terrain.errors > 0 then ": " .. Sim.terrain.errors[1] else ""))
check(waitUntil(function()
	return player.Character ~= nil
end, 5), "character spawned")

local PS = Sim.require(server.PlayerService)
local World = Sim.require(server.World)
local remotes = RS.Remotes
local function action(payload)
	Sim.signalOf(remotes.ClientAction, "OnServerEvent"):Fire(player, payload)
	task.wait(0.05)
end
local function trigger(prompt)
	Sim.signalOf(game:GetService("ProximityPromptService"), "PromptTriggered"):Fire(prompt, player)
	task.wait(0.05)
end
local function sentOf(kind)
	local out = {}
	for _, s in Sim.sent do
		if s.payload and s.payload.t == kind then
			table.insert(out, s.payload)
		end
	end
	return out
end
local function lastToast()
	local t = sentOf("toast")
	return t[#t] and t[#t].key
end
local function root()
	return player.Character.HumanoidRootPart
end
local function moveTo(x, z, dy)
	root().CFrame = Sim.game and require("@lune/roblox").CFrame.new(x, Heightmap.height(x, z) + (dy or 3), z)
end

local st = PS.get(player)
check(st ~= nil, "player state exists")

print("== tent")
action({ t = "introDone" })
check(st.tentDeadline < math.huge, "tent timer started after intro")
local items = World.tent.Items
for _, name in { "Boots", "Jacket", "Matches" } do
	trigger(items[name].PrimaryPart:FindFirstChildOfClass("ProximityPrompt"))
end
check(st.inv.taken == 3 and st.inv.items.Boots and st.inv.matches == 3, "took 3 items")
trigger(items.Thermos.PrimaryPart:FindFirstChildOfClass("ProximityPrompt"))
check(lastToast() == "ui.full" and not st.inv.items.Thermos, "4th item refused")
trigger(World.tent.CutWall:FindFirstChildOfClass("ProximityPrompt"))
check(World.tent:GetAttribute("Cut") == true, "tent wall cut")
local exitP = World.tentExitPoint()
moveTo(exitP.X, exitP.Z)
task.wait(0.5)
check(st.tentExited and st.progress.stage == "slope", "left the tent → stage slope (got " .. st.progress.stage .. ")")

print("== walk the route")
local piles = Layout.woodPiles()
local usedPiles = {}
local campLit = false
local stages = {}
local heatSeen = 100
local s = 0
local L = Level.Route.length
while s < L - 5 do
	local x, z = Level.placeAt(s, 0)
	moveTo(x, z)
	task.wait(0.03)
	heatSeen = math.min(heatSeen, st.heat)
	stages[st.progress.stage] = true
	-- собираем хворост рядом
	for _, p in piles do
		if not usedPiles[p.id] and (p.x - x) ^ 2 + (p.z - z) ^ 2 < 30 ^ 2 and st.inv.wood < 4 then
			usedPiles[p.id] = true
			moveTo(p.x, p.z)
			task.wait(0.03)
			trigger(World.piles[p.id].PrimaryPart:FindFirstChildOfClass("ProximityPrompt"))
		end
	end
	-- разжигаем костёр на стоянке
	if not campLit and st.progress.stage == "fire" then
		local camp = World.fires.camp
		local pit = camp.Pit
		local fx, fz = pit.CFrame.Position.X, pit.CFrame.Position.Z
		if (fx - x) ^ 2 + (fz - z) ^ 2 < 40 ^ 2 then
			moveTo(fx + 3, fz)
			trigger(pit:FindFirstChildOfClass("ProximityPrompt"))
			campLit = camp:GetAttribute("Lit") == true
			task.wait(0.5)
		end
	end
	s += 9
end
check(stages.cedar, "passed stage cedar")
check(stages.wood or stages.fire, "passed stage wood/fire")
check(campLit, "lit the camp fire (wood " .. st.inv.wood .. ", matches " .. st.inv.matches .. ")")
check(st.checkpoint >= 3, "checkpoint advanced to camp or further (" .. st.checkpoint .. ")")
check(stages.ravine and stages.hut, "reached ravine and hut stages")

print("== creek")
local thin
for _, p in World.folder.Ice:GetChildren() do
	if p.Name == "ThinIce" then
		thin = p
		break
	end
end
Sim.signalOf(thin, "Touched"):Fire(root())
task.wait(0.7)
check(thin.CanCollide == false, "thin ice breaks when stepped on")
-- в воду
local smpS
for _, seg in Layout.ice() do
	smpS = seg
	break
end
local wl = Heightmap.waterLevel(smpS.s)
root().CFrame = require("@lune/roblox").CFrame.new(smpS.x, wl + 1.5, smpS.z)
task.wait(0.4)
check(st.wet, "falling into the creek makes clothes wet")

print("== hut")
local fz = World.finishZone
root().CFrame = fz.CFrame
task.wait(0.5)
check(st.finished, "entering the hut finishes the run")
local fin = sentOf("finish")[1]
check(fin ~= nil and fin.time > 0, "finish event sent with time")

print("== thermos/flashlight/faint")
action({ t = "thermos" })
check(lastToast() == "ui.noThermos", "no thermos toast")
action({ t = "flashlight" })
check(lastToast() == "ui.noFlashlight", "no flashlight toast")

print("== restart")
action({ t = "restart" })
task.wait(0.3)
local st2 = PS.get(player)
check(st2 ~= st and st2.progress.stage == "tent" and st2.inv.taken == 0, "restart resets the run")

print("== faint")
action({ t = "introDone" })
-- подальше от костров, на открытом склоне
action({ t = "debug", cmd = "s", arg = 500 })
action({ t = "debug", cmd = "heat", arg = 0.01 })
task.wait(1.0)
check(st2.faints == 1, "freezing to 0 makes you faint")
task.wait(3)
check(not st2.fainting and st2.heat > 50, "wake up at checkpoint with heat")

print("== selftest")
action({ t = "debug", cmd = "selftest" })
check(waitUntil(function()
	return #sentOf("selftest") > 0
end, 20), "selftest finished")
local stl = sentOf("selftest")[1]
if stl then
	for _, line in stl.lines do
		print("    " .. line)
	end
end

print("== warnings")
local tickErrors = 0
for _, w in Sim.warnings or {} do
	if string.find(w, "tick error", 1, true) or string.find(w, "[Interactions]", 1, true) or string.find(w, "[Debug]", 1, true) then
		tickErrors += 1
		print("    " .. w)
	end
end
check(tickErrors == 0, "no runtime errors in server tick/interactions")

print(string.format("\n%d failures", #failures))
process.exit(if #failures > 0 then 1 else 0)
