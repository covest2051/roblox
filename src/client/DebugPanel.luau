--[[
	DebugPanel — только в Studio: телепорты по чекпоинтам, бессмертие,
	все вещи, самотест. Сервер дополнительно проверяет RunService:IsStudio().
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Ui = require(script.Parent.Ui)
local Lang = require(script.Parent.Lang)

local Make = Ui.Make

local DebugPanel = {}

local function cmd(c: string, arg: any?)
	Net.ClientAction:FireServer({ t = "debug", cmd = c, arg = arg })
end

function DebugPanel.build()
	local screen = Ui.screen()
	local toggle = Ui.button({
		Text = "DBG",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 100),
		Size = UDim2.fromOffset(56, 28),
		TextSize = 14,
		ZIndex = 40,
		Parent = screen,
	})
	local panel = Ui.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 134),
		Size = UDim2.fromOffset(170, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 40,
		Parent = screen,
	})
	Make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = panel,
	})
	Make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })
	Ui.scaled(panel)
	local buttons = {
		{ "→ Tent exit", "cp", 1 },
		{ "→ Cedar", "cp", 2 },
		{ "→ Camp", "cp", 3 },
		{ "→ Labaz", "cp", 4 },
		{ "→ Hut door", "cp", 5 },
		{ "→ Forest lights", "s", 1300 },
		{ "→ Ravine creek", "s", 2000 },
		{ "God mode", "god" },
		{ "All items", "items" },
		{ "Heat = 10", "heat", 10 },
		{ "Wet", "wet" },
		{ "Self-test", "selftest" },
		{ "Restart run", "restart" },
	}
	for i, b in buttons do
		local btn = Ui.button({
			Text = b[1],
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 14,
			LayoutOrder = i,
			ZIndex = 41,
			Parent = panel,
		})
		btn.Activated:Connect(function()
			cmd(b[2], b[3])
		end)
	end
	local lang = Ui.button({
		Text = "RU / EN",
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 14,
		LayoutOrder = #buttons + 1,
		ZIndex = 41,
		Parent = panel,
	})
	lang.Activated:Connect(Lang.toggle)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

return DebugPanel
