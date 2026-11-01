--[[
	Controls — бег (Shift), фонарь (F), термос (Q); на телефоне — кнопки.
]]

local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Lang = require(script.Parent.Lang)

local Controls = {}

local function send(payload)
	Net.ClientAction:FireServer(payload)
end

local function sprint(_name, state)
	if state == Enum.UserInputState.Begin then
		send({ t = "sprint", on = true })
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		send({ t = "sprint", on = false })
	end
	return Enum.ContextActionResult.Pass
end

local function flashlight(_name, state)
	if state == Enum.UserInputState.Begin then
		send({ t = "flashlight" })
	end
	return Enum.ContextActionResult.Sink
end

local function thermos(_name, state)
	if state == Enum.UserInputState.Begin then
		send({ t = "thermos" })
	end
	return Enum.ContextActionResult.Sink
end

local function titles()
	local ru = Lang.current == "ru"
	ContextActionService:SetTitle("PerevalSprint", if ru then "Бег" else "Run")
	ContextActionService:SetTitle("PerevalFlashlight", if ru then "Фонарь" else "Light")
	ContextActionService:SetTitle("PerevalThermos", if ru then "Чай" else "Tea")
end

function Controls.start()
	ContextActionService:BindAction("PerevalSprint", sprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("PerevalFlashlight", flashlight, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("PerevalThermos", thermos, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:SetPosition("PerevalSprint", UDim2.new(1, -170, 1, -150))
	ContextActionService:SetPosition("PerevalFlashlight", UDim2.new(1, -230, 1, -90))
	ContextActionService:SetPosition("PerevalThermos", UDim2.new(1, -110, 1, -210))
	titles()
	Lang.onChange(titles)
end

return Controls
