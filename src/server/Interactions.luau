--[[
	Interactions — обработка ProximityPrompt по атрибуту Kind.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Net = require(Shared.Net)

local World = require(script.Parent.World)
local Props = require(script.Parent.Props)
local PlayerService = require(script.Parent.PlayerService)

local Interactions = {}

local handlers = {}

function handlers.item(st, prompt)
	local item = prompt:GetAttribute("Item")
	if not PlayerService.canTakeItems(st) then
		PlayerService.toast(st.player, "ui.tentBuried")
		return
	end
	local ok, why = Inventory.take(st.inv, item)
	if ok then
		PlayerService.send(st.player, { t = "pickup", item = item })
		if item == "Flashlight" then
			PlayerService.ensureFlashlight(st)
		end
	elseif why == "full" then
		PlayerService.toast(st.player, "ui.full")
	end
end

function handlers.cut(st, _prompt)
	if World.tent and not World.tent:GetAttribute("Cut") then
		Props.cutTent(World.tent)
		Net.ServerEvent:FireAllClients({ t = "tentCut" })
	end
	PlayerService.startTentTimer(st)
end

function handlers.wood(st, prompt)
	local id = prompt:GetAttribute("PileId")
	local pile = World.piles[id]
	if not pile or not pile:GetAttribute("Available") then
		return
	end
	local ok = Inventory.addWood(st.inv)
	if not ok then
		PlayerService.toast(st.player, "ui.full")
		return
	end
	PlayerService.send(st.player, { t = "pickup", item = "Wood" })
	PlayerService.event(st, "wood", st.inv.wood)
	Props.setPileAvailable(pile, false)
	task.delay(Config.Wood.PileRespawn, function()
		Props.setPileAvailable(pile, true)
	end)
end

function handlers.dryWood(st, _prompt)
	if st.inv.wood >= Config.Wood.Max then
		PlayerService.toast(st.player, "ui.full")
		return
	end
	Inventory.addWood(st.inv, Config.Wood.Max)
	PlayerService.send(st.player, { t = "pickup", item = "Wood" })
	PlayerService.event(st, "wood", st.inv.wood)
end

function handlers.fire(st, prompt)
	local id = prompt:GetAttribute("FireId")
	local m = World.fires[id]
	if not m or m:GetAttribute("Lit") then
		return
	end
	local ok, why = Inventory.light(st.inv)
	if not ok then
		if why == "need_wood" then
			PlayerService.toast(st.player, "ui.needWood", { n = Config.Wood.ForFire })
		else
			PlayerService.toast(st.player, "ui.needMatch")
		end
		return
	end
	Props.setFireLit(m, true)
	st.firesLit += 1
	PlayerService.toast(st.player, "ui.fireLit")
	PlayerService.event(st, "fireLit", id)
	Net.ServerEvent:FireAllClients({ t = "fireLit", id = id })
end

function handlers.note(st, prompt)
	local id = prompt:GetAttribute("NoteId")
	PlayerService.event(st, "note", id)
end

function handlers.stash(st, _prompt)
	if st.stashUsed then
		PlayerService.toast(st.player, "ui.stashEmpty")
		return
	end
	st.stashUsed = true
	Inventory.addMatches(st.inv, 1)
	PlayerService.toast(st.player, "ui.stashFound")
end

function handlers.read(_st, _prompt)
	-- текст показывает клиент; серверу делать нечего
end

function Interactions.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local kind = prompt:GetAttribute("Kind")
		local st = PlayerService.get(player)
		local h = kind and handlers[kind]
		if not st or not h or st.fainting then
			return
		end
		local ok, err = pcall(h, st, prompt)
		if not ok then
			warn("[Interactions]", kind, err)
		end
	end)
end

Interactions.handlers = handlers

return Interactions
