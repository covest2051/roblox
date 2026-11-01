--[[
	Hud — интерфейс поверх игры: цель, тепло/силы/фонарь, вещи, статусы,
	субтитры, всплывающие сообщения, таймер палатки, стрелка на колокол,
	иней по краям экрана при переохлаждении, окно чтения записок.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Level = require(Shared.Level)

local Ui = require(script.Parent.Ui)
local Lang = require(script.Parent.Lang)

local Make = Ui.Make
local player = Players.LocalPlayer

local Hud = {}

local root: Frame
local refs = {} :: { [string]: any }
local subtitleQueue = {}
local subtitleBusy = false
local bellVisible = false

local function attr(name: string, default: any): any
	local v = player:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function bar(parent: Instance, name: string, order: number, height: number, color: Color3)
	local holder = Make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height + 18),
		LayoutOrder = order,
		Parent = parent,
	})
	local label = Ui.label({
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15,
		Font = Ui.fontBold,
		Parent = holder,
	})
	local back = Make("Frame", {
		Name = "Back",
		BackgroundColor3 = Color3.fromRGB(20, 24, 32),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, height),
		Parent = holder,
	})
	Make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = back })
	local fill = Make("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = back,
	})
	Make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = fill })
	return { holder = holder, label = label, fill = fill }
end

local function chip(parent: Instance, name: string, order: number)
	local c = Ui.panel({
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	})
	Make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = c })
	local l = Ui.label({
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = 15,
		Font = Ui.fontBold,
		TextWrapped = false,
		Parent = c,
	})
	return { frame = c, text = l }
end

-- Иней по краям: 4 рамки с градиентом прозрачности
local function buildFrost(parent: Instance)
	local frost = Make("Frame", {
		Name = "Frost",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
	local edges = {
		{ UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0.72), -90 },
		{ UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0), 180 },
	}
	local frames = {}
	for _, e in edges do
		local f = Make("Frame", {
			BackgroundColor3 = Color3.fromRGB(210, 230, 255),
			BorderSizePixel = 0,
			Size = e[1],
			Position = e[2],
			BackgroundTransparency = 1,
			Parent = frost,
		})
		Make("UIGradient", {
			Rotation = e[3],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = f,
		})
		table.insert(frames, f)
	end
	return frames
end

function Hud.build()
	local screen = Ui.screen()
	root = Make("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = screen,
	})
	refs.frost = buildFrost(root)

	-- цель
	local obj = Ui.panel({
		Name = "Objective",
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = obj,
	})
	Ui.scaled(obj)
	refs.objective = Ui.label({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 17,
		Parent = obj,
	})

	-- полосы
	local bars = Make("Frame", {
		Name = "Bars",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(260, 150),
		Parent = root,
	})
	Ui.scaled(bars)
	Make("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = bars,
	})
	local chips = Make("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 0,
		Parent = bars,
	})
	Make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = chips,
	})
	refs.chipExposure = chip(chips, "Exposure", 1)
	refs.chipWet = chip(chips, "Wet", 2)
	refs.chipLost = chip(chips, "Lost", 3)
	refs.heat = bar(bars, "Heat", 1, 16, Ui.colors.warm)
	refs.stamina = bar(bars, "Stamina", 2, 8, Color3.fromRGB(200, 210, 220))
	refs.battery = bar(bars, "Battery", 3, 6, Color3.fromRGB(255, 240, 170))

	-- вещи
	local inv = Ui.panel({
		Name = "Inventory",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = inv,
	})
	Ui.scaled(inv)
	refs.inventory = Ui.label({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		Parent = inv,
	})

	-- управление
	refs.controls = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(600, 20),
		TextSize = 14,
		TextColor3 = Ui.colors.dim,
		Parent = root,
	})

	-- субтитры
	refs.subtitle = Ui.label({
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.new(0.6, 0, 0, 60),
		TextSize = 21,
		Font = Ui.fontSerif,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})

	-- всплывающие сообщения
	refs.toast = Ui.label({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(600, 28),
		TextSize = 20,
		Font = Ui.fontBold,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})

	-- предупреждение о порыве
	refs.gust = Ui.label({
		Name = "Gust",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(600, 34),
		TextSize = 26,
		Font = Ui.fontBold,
		TextColor3 = Color3.fromRGB(255, 200, 120),
		Visible = false,
		Parent = root,
	})

	-- таймер палатки
	refs.tentTimer = Ui.label({
		Name = "TentTimer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(600, 34),
		TextSize = 26,
		Font = Ui.fontBold,
		TextColor3 = Color3.fromRGB(255, 180, 160),
		Visible = false,
		Parent = root,
	})

	-- стрелка на колокол
	local bell = Make("Frame", {
		Name = "Bell",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(120, 70),
		Visible = false,
		Parent = root,
	})
	refs.bellArrow = Ui.label({
		Text = "▲",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(40, 40),
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 220, 140),
		Parent = bell,
	})
	refs.bellText = Ui.label({
		Position = UDim2.fromScale(0, 0.7),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 220, 140),
		Parent = bell,
	})
	refs.bell = bell
	Ui.scaled(bell)

	-- окно чтения
	local reader = Ui.panel({
		Name = "Reader",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(236, 228, 204),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	})
	Make("UIPadding", {
		PaddingLeft = UDim.new(0, 22),
		PaddingRight = UDim.new(0, 22),
		PaddingTop = UDim.new(0, 18),
		PaddingBottom = UDim.new(0, 18),
		Parent = reader,
	})
	refs.readerText = Ui.label({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Ui.fontSerif,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(40, 34, 28),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = reader,
	})
	refs.reader = reader
	Ui.scaled(reader)
	Ui.scaled(refs.toast)
	Ui.scaled(refs.gust)
	Ui.scaled(refs.tentTimer)
	Ui.scaled(refs.subtitle)

	Lang.onChange(Hud.refreshStatic)
	Hud.refreshStatic()
	RunService.RenderStepped:Connect(Hud.update)
end

function Hud.refreshStatic()
	refs.controls.Text = Lang.t("ui.controls")
	refs.heat.label.Text = Lang.t("ui.heat")
	refs.stamina.label.Text = Lang.t("ui.stamina")
	refs.battery.label.Text = Lang.t("ui.battery")
	refs.bellText.Text = Lang.t("ui.bell")
	refs.gust.Text = "⚠ " .. Lang.t("ui.gust")
end

function Hud.setVisible(v: boolean)
	if root then
		root.Visible = v
	end
end

-- текст текущей цели
local function objectiveText(): string
	local stage = attr("Stage", "tent")
	local vars = { n = attr("Wood", 0), max = Config.Wood.ForFire }
	if stage == "tent" then
		return Lang.t("obj.tent") .. "\n" .. Lang.t("ui.itemsPicked", { n = attr("ItemsTaken", 0), max = Config.Tent.MaxItems })
	end
	return Lang.t("obj." .. stage, vars)
end

local function inventoryText(): string
	local lines = {}
	local items = string.split(attr("Items", ""), ",")
	for _, it in items do
		if it ~= "" then
			table.insert(lines, "• " .. Lang.t("item." .. it))
		end
	end
	table.insert(lines, Lang.t("ui.wood", { n = attr("Wood", 0), max = Config.Wood.Max }))
	table.insert(lines, Lang.t("ui.matches", { n = attr("Matches", 0) }))
	if string.find(attr("Items", ""), "Thermos", 1, true) then
		table.insert(lines, Lang.t("ui.sips", { n = attr("Sips", 0) }))
	end
	return table.concat(lines, "\n")
end

function Hud.setBellVisible(v: boolean)
	bellVisible = v
end

local frostLevel = 0
function Hud.update(dt: number)
	if not root or not root.Visible then
		return
	end
	local heat = attr("Heat", 100)
	local stamina = attr("Stamina", 100)
	refs.heat.fill.Size = UDim2.fromScale(math.clamp(heat / 100, 0, 1), 1)
	local cold = Color3.fromRGB(120, 170, 255)
	local warm = Color3.fromRGB(255, 160, 70)
	refs.heat.fill.BackgroundColor3 = cold:Lerp(warm, math.clamp(heat / 100, 0, 1))
	refs.heat.label.Text = string.format("%s  %d", Lang.t("ui.heat"), math.floor(heat))
	refs.stamina.fill.Size = UDim2.fromScale(math.clamp(stamina / 100, 0, 1), 1)

	local hasFlash = string.find(attr("Items", ""), "Flashlight", 1, true) ~= nil
	refs.battery.holder.Visible = hasFlash
	if hasFlash then
		refs.battery.fill.Size = UDim2.fromScale(math.clamp(attr("Battery", 0) / 100, 0, 1), 1)
		refs.battery.label.Text = Lang.t("ui.battery") .. (if attr("Flashlight", false) then "  ●" else "  ○")
	end

	refs.objective.Text = objectiveText()
	refs.inventory.Text = inventoryText()

	-- статусы
	local exited = attr("TentExited", false)
	local near = attr("NearFire", false)
	local exposed = attr("Exposed", false)
	refs.chipExposure.frame.Visible = exited
	if near then
		refs.chipExposure.text.Text = "🔥 " .. Lang.t("ui.nearFire")
		refs.chipExposure.text.TextColor3 = Ui.colors.warm
	elseif exposed then
		refs.chipExposure.text.Text = "≋ " .. Lang.t("ui.exposed")
		refs.chipExposure.text.TextColor3 = Ui.colors.cold
	else
		refs.chipExposure.text.Text = "▲ " .. Lang.t("ui.sheltered")
		refs.chipExposure.text.TextColor3 = Ui.colors.good
	end
	refs.chipWet.frame.Visible = attr("Wet", false)
	refs.chipWet.text.Text = "💧 " .. Lang.t("ui.wet")
	refs.chipWet.text.TextColor3 = Ui.colors.cold
	refs.chipLost.frame.Visible = attr("Lost", false)
	refs.chipLost.text.Text = "? " .. Lang.t("ui.lost")
	refs.chipLost.text.TextColor3 = Ui.colors.danger

	-- таймер палатки
	local deadline = attr("TentDeadline", 0)
	if not exited and deadline > 0 then
		local left = math.max(0, deadline - workspace:GetServerTimeNow())
		refs.tentTimer.Visible = true
		refs.tentTimer.Text = Lang.t("ui.tentTimer", { n = math.ceil(left) })
	else
		refs.tentTimer.Visible = false
	end

	-- иней
	local target = 0
	if heat < Config.Heat.ColdThreshold then
		target = 1 - heat / Config.Heat.ColdThreshold
	end
	frostLevel += (target - frostLevel) * math.min(1, dt * 2)
	local pulse = if heat < Config.Heat.CriticalThreshold then 0.12 * math.sin(os.clock() * 6) else 0
	for _, f in refs.frost do
		f.BackgroundTransparency = 1 - math.clamp(frostLevel * 0.75 + pulse, 0, 0.85)
	end

	-- колокол
	refs.bell.Visible = bellVisible
	if bellVisible then
		local cam = workspace.CurrentCamera
		local hf = Level.hutFrame()
		local ch = player.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		if cam and hrp then
			local to = Vector3.new(hf.x - hrp.CFrame.Position.X, 0, hf.z - hrp.CFrame.Position.Z)
			local look = cam.CFrame.LookVector
			local fwd = Vector3.new(look.X, 0, look.Z)
			if to.Magnitude > 1 and fwd.Magnitude > 0.01 then
				to, fwd = to.Unit, fwd.Unit
				local ang = math.atan2(fwd:Cross(to).Y, fwd:Dot(to))
				refs.bellArrow.Rotation = -math.deg(ang)
			end
			local ring = (os.clock() % 2.5) < 0.4
			refs.bellArrow.TextTransparency = if ring then 0 else 0.35
		end
	end
end

function Hud.toast(key: string, vars: { [string]: any }?)
	local l = refs.toast
	if not l then
		return
	end
	l.Text = Lang.t(key, vars)
	l.TextTransparency = 0
	l.TextStrokeTransparency = 0.5
	local stamp = os.clock()
	l:SetAttribute("Stamp", stamp)
	task.delay(3, function()
		if l:GetAttribute("Stamp") == stamp then
			TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function pumpSubtitles()
	if subtitleBusy then
		return
	end
	local item = table.remove(subtitleQueue, 1)
	if not item then
		return
	end
	subtitleBusy = true
	local l = refs.subtitle
	l.Text = Lang.t(item.key)
	TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	local seconds = item.seconds or math.clamp(#l.Text / 14, 3, 7)
	task.delay(seconds, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.45)
		subtitleBusy = false
		pumpSubtitles()
	end)
end

function Hud.subtitle(key: string, seconds: number?)
	table.insert(subtitleQueue, { key = key, seconds = seconds })
	pumpSubtitles()
end

function Hud.subtitles(keys: { string })
	for _, k in keys do
		table.insert(subtitleQueue, { key = k })
	end
	pumpSubtitles()
end

function Hud.gustWarning(seconds: number)
	local g = refs.gust
	if not g then
		return
	end
	g.Visible = true
	local stamp = os.clock()
	g:SetAttribute("Stamp", stamp)
	task.spawn(function()
		while g:GetAttribute("Stamp") == stamp and os.clock() - stamp < seconds do
			g.TextTransparency = if (os.clock() * 4) % 1 < 0.5 then 0 else 0.4
			task.wait(0.05)
		end
		if g:GetAttribute("Stamp") == stamp then
			g.Visible = false
		end
	end)
end

local readerOpenAt = 0
function Hud.showText(key: string)
	refs.readerText.Text = Lang.t(key)
	refs.reader.Visible = true
	readerOpenAt = os.clock()
	local stamp = readerOpenAt
	task.delay(10, function()
		if readerOpenAt == stamp then
			refs.reader.Visible = false
		end
	end)
end

function Hud.hideText()
	if refs.reader and refs.reader.Visible and os.clock() - readerOpenAt > 0.3 then
		refs.reader.Visible = false
		return true
	end
	return false
end

return Hud
