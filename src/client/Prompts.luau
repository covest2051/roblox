--[[
	Prompts — локализация ProximityPrompt и их видимость для этого игрока:
	вещи в палатке пропадают, когда взяты (только у себя).
	Также показывает записки/таблички в окне чтения.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Hud = require(script.Parent.Hud)
local Lang = require(script.Parent.Lang)

local Prompts = {}

local player = Players.LocalPlayer
local prompts = {} :: { [ProximityPrompt]: boolean }

local function localize(p: ProximityPrompt)
	local a, o = p:GetAttribute("ActionKey"), p:GetAttribute("ObjectKey")
	if a then
		p.ActionText = Lang.t(a)
	end
	if o then
		p.ObjectText = Lang.t(o)
	end
end

local function itemsState()
	local items = player:GetAttribute("Items") or ""
	local taken = player:GetAttribute("ItemsTaken") or 0
	local exited = player:GetAttribute("TentExited") == true
	return items, taken, exited
end

local function refreshItems()
	local items, taken, exited = itemsState()
	for p in prompts do
		if p.Parent and p:GetAttribute("Kind") == "item" then
			local name = p:GetAttribute("Item")
			local has = string.find(items, name, 1, true) ~= nil
			p.Enabled = not has and taken < 3 and not exited
			local model = p.Parent and p.Parent.Parent
			if model and model:IsA("Model") then
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = if has then 1 else 0
					end
				end
			end
		end
	end
end

local function track(d: Instance)
	if d:IsA("ProximityPrompt") and d:GetAttribute("Kind") then
		prompts[d] = true
		localize(d)
		if d:GetAttribute("Kind") == "item" then
			refreshItems()
		end
	end
end

function Prompts.start()
	local world = workspace:WaitForChild("World")
	for _, d in world:GetDescendants() do
		track(d)
	end
	world.DescendantAdded:Connect(track)
	world.DescendantRemoving:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			prompts[d] = nil
		end
	end)
	Lang.onChange(function()
		for p in prompts do
			localize(p)
		end
	end)
	for _, a in { "Items", "ItemsTaken", "TentExited" } do
		player:GetAttributeChangedSignal(a):Connect(refreshItems)
	end
	ProximityPromptService.PromptTriggered:Connect(function(p)
		local key = p:GetAttribute("TextKey")
		if key then
			Hud.showText(key)
		end
	end)
end

return Prompts
