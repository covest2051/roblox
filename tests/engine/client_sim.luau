--[[
	Сервер + клиент в одном DataModel на заглушке движка.
	Проверяет, что весь UI строится (свойства валидирует @lune/roblox),
	интро проходит, и клиент переживает все события сервера.
	Запуск (после rojo build): lune run tests/engine/client_sim.luau
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Sim = require("./Sim")

local failures = {}
local function check(cond, msg)
	print((if cond then "  ✓ " else "  ✗ ") .. msg)
	if not cond then
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
local ws = game:GetService("Workspace")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
Sim.heightAt = Sim.require(RS.Shared.Heightmap).height

local player = Sim.addPlayer("Tester")
Players.LocalPlayer = player
Sim.localPlayer = player
Sim.clientMode = true
roblox.Instance.new("PlayerGui").Parent = player
local cam = roblox.Instance.new("Camera")
cam.Parent = ws
ws.CurrentCamera = cam

-- ошибки внутри потоков клиента ловим через обёртку task.spawn/defer
local clientErrors = {}
local server = game:GetService("ServerScriptService").Server
Sim.runScript(server)
check(waitUntil(function()
	return ws:GetAttribute("WorldReady") == true and player.Character ~= nil
end, 240), "server ready, character spawned")

local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ok, err = pcall(function()
	Sim.runScript(client)
end)
check(ok, "client script starts" .. (if ok then "" else ": " .. tostring(err)))

-- кадры
local rendering = true
task.spawn(function()
	local rs = game:GetService("RunService")
	while rendering do
		local okF, errF = pcall(function()
			Sim.signalOf(rs, "RenderStepped"):Fire(1 / 30)
			for _, fn in Sim.renderSteps or {} do
				fn(1 / 30)
			end
		end)
		if not okF then
			table.insert(clientErrors, tostring(errF))
		end
		task.wait(1 / 30)
	end
end)

local gui = player.PlayerGui
check(waitUntil(function()
	return gui:FindFirstChild("PerevalUI") ~= nil
end, 5), "ScreenGui created")
local ui = gui:FindFirstChild("PerevalUI")
check(ui and ui:FindFirstChild("Hud") ~= nil, "HUD built")
check(ui and ui:FindFirstChild("Overlay") ~= nil, "overlay built")

-- пропускаем интро
task.wait(1.5)
local UIS = game:GetService("UserInputService")
Sim.signalOf(UIS, "InputBegan"):Fire({ KeyCode = roblox.Enum.KeyCode.Space, UserInputType = roblox.Enum.UserInputType.Keyboard }, false)
local PS = Sim.require(server.PlayerService)
local st = PS.get(player)
check(waitUntil(function()
	return st.introDone
end, 10), "intro skipped → server got introDone")
check(ui.Hud.Visible == true, "HUD visible after intro")

-- клавиши
local CAS = Sim.actions or {}
check(CAS.PerevalSprint ~= nil and CAS.PerevalFlashlight ~= nil and CAS.PerevalThermos ~= nil, "actions bound")
CAS.PerevalSprint("PerevalSprint", roblox.Enum.UserInputState.Begin)
task.wait(0.1)
check(st.sprintHeld == true, "Shift → sprint on server")
CAS.PerevalSprint("PerevalSprint", roblox.Enum.UserInputState.End)
CAS.PerevalFlashlight("PerevalFlashlight", roblox.Enum.UserInputState.Begin)
task.wait(0.1)

-- серверные события на клиенте
local RE = RS.Remotes.ServerEvent
local function ev(payload)
	Sim.signalOf(RE, "OnClientEvent"):Fire(payload)
	task.wait(0.1)
end
ev({ t = "toast", key = "ui.fireLit" })
ev({ t = "stage", stage = "slope" })
check(cam:FindFirstChild("FriendsLights") ~= nil, "friends' flashlights appear on the slope")
ev({ t = "stage", stage = "hut" })
ev({ t = "gustWarn", at = ws:GetServerTimeNow() + 2 })
ev({ t = "gust", exposed = true, dx = 0.1, dz = 0.99, push = 20, duration = 2.5 })
ev({ t = "pickup", item = "Boots" })
ev({ t = "pickup", item = "Wood" })
ev({ t = "fellIn" })
ev({ t = "iceCrack" })
ev({ t = "tentCut" })
ev({ t = "zone", id = "forest" })
ev({ t = "faint" })
ev({ t = "wake" })
ev({ t = "selftest", lines = { "[SELFTEST] RESULT 1/1 passed, 0 warnings" } })
task.wait(1)

-- огни в небе: ставим игрока в лес
local Level = Sim.require(RS.Shared.Level)
st.progress.stage = "wood"
Sim.signalOf(RS.Remotes.ClientAction, "OnServerEvent"):Fire(player, { t = "debug", cmd = "s", arg = Level.zoneById("forest").startS + 260 })
task.wait(1.5)
check(cam:FindFirstChild("SkyLight") ~= nil, "lights in the sky event plays")

-- записка
local note = ws.World.Cedar.Note:FindFirstChildOfClass("ProximityPrompt")
Sim.signalOf(game:GetService("ProximityPromptService"), "PromptTriggered"):Fire(note, player)
task.wait(0.2)
check(ui:FindFirstChild("Reader") and ui.Reader.Visible == true, "note opens in the reader")
check(note.ActionText ~= "prompt.read", "prompts are localized (" .. note.ActionText .. ")")

-- финал
ev({ t = "finish", time = 754, faints = 1, fires = 2, items = { "Boots", "Jacket", "Matches" }, best = 700 })
task.wait(10)
local fin = ui:FindFirstChild("Finish")
check(fin ~= nil, "finish screen shown")
local btn = fin and fin:FindFirstChildWhichIsA("TextButton", true)
check(btn ~= nil, "restart button appears")

-- отладочная панель
local dbg
for _, d in ui:GetDescendants() do
	if d:IsA("TextButton") and d.Text == "DBG" then
		dbg = d
	end
end
check(dbg ~= nil, "debug panel present in Studio")

rendering = false
task.wait(0.1)
for _, e in clientErrors do
	print("    " .. e)
end
check(#clientErrors == 0, "no errors in render loop")
print(string.format("\n%d failures", #failures))
process.exit(if #failures > 0 then 1 else 0)
