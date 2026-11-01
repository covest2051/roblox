--[[
	Ui — общие стили и маленькие фабрики элементов интерфейса.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Make)

local Ui = {}

Ui.Make = Make
Ui.font = Enum.Font.BuilderSans
Ui.fontBold = Enum.Font.BuilderSansBold
Ui.fontSerif = Enum.Font.Merriweather

Ui.colors = {
	text = Color3.fromRGB(236, 240, 246),
	dim = Color3.fromRGB(170, 180, 196),
	panel = Color3.fromRGB(12, 16, 24),
	warm = Color3.fromRGB(255, 170, 80),
	cold = Color3.fromRGB(120, 180, 255),
	danger = Color3.fromRGB(255, 90, 70),
	good = Color3.fromRGB(140, 220, 150),
}

local screen: ScreenGui? = nil

function Ui.screen(): ScreenGui
	if screen then
		return screen
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = Make("ScreenGui", {
		Name = "PerevalUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = pg,
	})
	return screen :: ScreenGui
end

-- Масштаб панелей под экран (макет рассчитан на 1280×720).
-- UIScale вешается на отдельные панели, а не на весь ScreenGui,
-- иначе сжались бы и полноэкранные затемнения.
local scales: { UIScale } = {}
local currentScale = 1

local function computeScale()
	local ok, vp = pcall(function()
		return workspace.CurrentCamera.ViewportSize
	end)
	if ok and vp and vp.X > 0 then
		currentScale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.6, 1.25)
	end
	for _, s in scales do
		s.Scale = currentScale
	end
end

function Ui.scaled(obj: GuiObject): GuiObject
	local s = Make("UIScale", { Scale = currentScale, Parent = obj })
	table.insert(scales, s)
	return obj
end

function Ui.watchViewport()
	computeScale()
	pcall(function()
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(computeScale)
	end)
end

function Ui.label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = Ui.font,
		TextColor3 = Ui.colors.text,
		TextStrokeTransparency = 0.6,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextSize = 18,
		TextWrapped = true,
		RichText = true,
	}
	for k, v in props do
		p[k] = v
	end
	return Make("TextLabel", p)
end

function Ui.panel(props)
	local p = {
		BackgroundColor3 = Ui.colors.panel,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}
	for k, v in props do
		p[k] = v
	end
	local f = Make("Frame", p)
	Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = f })
	return f
end

function Ui.button(props)
	local p = {
		BackgroundColor3 = Color3.fromRGB(40, 48, 64),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Font = Ui.fontBold,
		TextColor3 = Ui.colors.text,
		TextSize = 18,
		AutoButtonColor = true,
	}
	for k, v in props do
		p[k] = v
	end
	local b = Make("TextButton", p)
	Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = b })
	return b
end

return Ui
