--[[
	Cinematic — экраны вне игры: загрузка мира, интро с пролётом камеры,
	потеря сознания (белая вспышка), финал с итогами и кнопкой рестарта.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Ui)
local Lang = require(script.Parent.Lang)
local Hud = require(script.Parent.Hud)

local Make = Ui.Make
local player = Players.LocalPlayer

local Cinematic = {}

local overlay: Frame
local fade: Frame
local title: TextLabel
local caption: TextLabel
local skipLabel: TextLabel
local finishFrame: Frame

function Cinematic.build()
	local screen = Ui.screen()
	overlay = Make("Frame", {
		Name = "Overlay",
		BackgroundColor3 = Color3.fromRGB(6, 8, 12),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = screen,
	})
	title = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.8, 0, 0, 80),
		Font = Ui.fontSerif,
		TextSize = 64,
		ZIndex = 21,
		Parent = overlay,
	})
	caption = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.6, 0, 0, 120),
		Font = Ui.fontSerif,
		TextSize = 22,
		TextColor3 = Ui.colors.dim,
		ZIndex = 21,
		Parent = overlay,
	})
	skipLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -16),
		Size = UDim2.fromOffset(300, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 14,
		TextColor3 = Ui.colors.dim,
		Visible = false,
		ZIndex = 21,
		Parent = screen,
	})
	fade = Make("Frame", {
		Name = "Fade",
		BackgroundColor3 = Color3.fromRGB(235, 240, 250),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Parent = screen,
	})
	title.Text = Lang.t("ui.title")
	caption.Text = Lang.t("ui.subtitle")
end

-------------------------------------------------------------------------------
-- Загрузка
-------------------------------------------------------------------------------
function Cinematic.waitForWorld()
	local stages = { terrain = 0, props = 1 }
	while not workspace:GetAttribute("WorldReady") do
		local stage = workspace:GetAttribute("BuildStage") or "terrain"
		local p = workspace:GetAttribute("BuildProgress") or 0
		local total = ((stages[stage] or 0) + p) / 2
		caption.Text = string.format("%s\n\n%d%%", Lang.t("ui.subtitle"), math.floor(total * 100))
		task.wait(0.1)
	end
	caption.Text = Lang.t("ui.subtitle")
end

-------------------------------------------------------------------------------
-- Интро
-------------------------------------------------------------------------------
local function waitOrSkip(seconds: number, skipFlag: { v: boolean })
	local t0 = os.clock()
	while os.clock() - t0 < seconds and not skipFlag.v do
		task.wait()
	end
end

function Cinematic.playIntro(onDone: () -> ())
	local cam = workspace.CurrentCamera
	local camp = Layout.camp()
	local tent = camp.tent
	local tentPos = Vector3.new(tent.x, tent.y + 3, tent.z)
	local sign = Vector3.new(camp.sign.x, camp.sign.y + 4, camp.sign.z)
	local memorial = Vector3.new(camp.memorial.x, camp.memorial.y + 2.5, camp.memorial.z)
	local down = Vector3.new(tent.tx, 0, tent.tz)
	local side = Vector3.new(tent.nx, 0, tent.nz)

	local skip = { v = false }
	skipLabel.Text = Lang.t("ui.skip")
	skipLabel.Visible = true
	local conn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			skip.v = true
		end
	end)

	cam.CameraType = Enum.CameraType.Scriptable
	Hud.setVisible(false)

	-- кадр 1: табличка перевала
	cam.CFrame = CFrame.lookAt(sign + down * 14 + side * 4 + Vector3.new(0, 1, 0), sign)
	title.Text = ""
	caption.Text = ""
	TweenService:Create(overlay, TweenInfo.new(1.2), { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(cam, TweenInfo.new(6, Enum.EasingStyle.Sine), {
		CFrame = CFrame.lookAt(sign + down * 10 - side * 3 + Vector3.new(0, 2, 0), sign),
	}):Play()
	title.Text = Lang.t("ui.title")
	caption.Text = Lang.t("story.intro.1")
	waitOrSkip(4, skip)

	-- кадр 2: памятный знак
	if not skip.v then
		cam.CFrame = CFrame.lookAt(memorial + Vector3.new(camp.memorial.faceX, 0, camp.memorial.faceZ) * 9 + Vector3.new(0, 1.5, 0), memorial)
		TweenService:Create(cam, TweenInfo.new(7, Enum.EasingStyle.Sine), {
			CFrame = CFrame.lookAt(memorial + Vector3.new(camp.memorial.faceX, 0, camp.memorial.faceZ) * 6 + Vector3.new(0, 1, 0), memorial),
		}):Play()
		title.Text = ""
		caption.Text = Lang.t("story.intro.2")
		waitOrSkip(7, skip)
	end

	-- кадр 3: палатка в буране
	if not skip.v then
		cam.CFrame = CFrame.lookAt(tentPos + down * 30 + side * 18 + Vector3.new(0, 10, 0), tentPos)
		TweenService:Create(cam, TweenInfo.new(5, Enum.EasingStyle.Sine), {
			CFrame = CFrame.lookAt(tentPos + down * 14 + side * 8 + Vector3.new(0, 5, 0), tentPos),
		}):Play()
		caption.Text = Lang.t("story.intro.3")
		waitOrSkip(4, skip)
	end

	conn:Disconnect()
	skipLabel.Visible = false
	TweenService:Create(overlay, TweenInfo.new(0.6), { BackgroundTransparency = 0 }):Play()
	task.wait(0.7)
	title.Text = ""
	caption.Text = ""
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
	Hud.setVisible(true)
	TweenService:Create(overlay, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	Net.ClientAction:FireServer({ t = "introDone" })
	onDone()
end

function Cinematic.hideOverlay()
	overlay.BackgroundTransparency = 1
	title.Text = ""
	caption.Text = ""
end

-------------------------------------------------------------------------------
-- Потеря сознания
-------------------------------------------------------------------------------
function Cinematic.faint()
	Hud.toast("ui.faint")
	TweenService:Create(fade, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
end

function Cinematic.wake()
	TweenService:Create(fade, TweenInfo.new(2.5), { BackgroundTransparency = 1 }):Play()
	Hud.subtitle("ui.faintWake", 4)
end

-------------------------------------------------------------------------------
-- Финал
-------------------------------------------------------------------------------
function Cinematic.finish(ev)
	Hud.setVisible(false)
	local screen = Ui.screen()
	if finishFrame then
		finishFrame:Destroy()
	end
	finishFrame = Make("Frame", {
		Name = "Finish",
		BackgroundColor3 = Color3.fromRGB(8, 8, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 25,
		Parent = screen,
	})
	TweenService:Create(finishFrame, TweenInfo.new(2), { BackgroundTransparency = 0.08 }):Play()
	local list = Make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.85),
		ZIndex = 26,
		Parent = finishFrame,
	})
	Make("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	local order = 0
	local function line(text: string, size: number, color: Color3?, font: Enum.Font?)
		order += 1
		local l = Ui.label({
			Text = text,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = size,
			Font = font or Ui.fontSerif,
			TextColor3 = color or Ui.colors.text,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			LayoutOrder = order,
			ZIndex = 27,
			Parent = list,
		})
		return l
	end
	local itemNames = {}
	for _, it in ev.items or {} do
		table.insert(itemNames, Lang.t("item." .. it))
	end
	local seq = {
		line(Lang.t("end.title"), 44),
		line(Lang.t("end.radio"), 20, Ui.colors.dim),
		line(table.concat({
			Lang.t("end.time", { t = Lang.formatTime(ev.time) }),
			Lang.t("end.faints", { n = ev.faints }),
			Lang.t("end.fires", { n = ev.fires }),
			Lang.t("end.items", { list = table.concat(itemNames, ", ") }),
			if ev.best then Lang.t("end.best", { t = Lang.formatTime(ev.best) }) else "",
		}, "\n"), 20, Ui.colors.text, Ui.font),
		line(Lang.t("end.memorial"), 20, Color3.fromRGB(220, 200, 160)),
		line(Lang.t("end.fiction"), 16, Ui.colors.dim),
	}
	task.spawn(function()
		task.wait(1.5)
		for _, l in seq do
			TweenService:Create(l, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
			task.wait(1.6)
		end
		order += 1
		local btn = Ui.button({
			Text = Lang.t("ui.restart"),
			Size = UDim2.fromOffset(240, 48),
			LayoutOrder = order,
			ZIndex = 27,
			Parent = list,
		})
		btn.Activated:Connect(function()
			Net.ClientAction:FireServer({ t = "restart" })
		end)
	end)
end

function Cinematic.closeFinish()
	if finishFrame then
		finishFrame:Destroy()
		finishFrame = nil
	end
end

return Cinematic
