--[[
	Gust — порыв ветра на клиенте: предупреждение, толчок, тряска камеры.
	Толкаем на клиенте, потому что персонаж физически принадлежит клиенту.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hud = require(script.Parent.Hud)
local Atmosphere = require(script.Parent.Atmosphere)

local Gust = {}

local player = Players.LocalPlayer
local shakeUntil = 0
local shakeAmp = 0

function Gust.warn(at: number)
	local left = math.max(0.5, at - workspace:GetServerTimeNow())
	Hud.gustWarning(left + 0.5)
end

function Gust.hit(ev)
	Atmosphere.gust(if ev.exposed then 1.2 else 0.4)
	if not ev.exposed then
		return
	end
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	shakeUntil = os.clock() + (ev.duration or 2)
	shakeAmp = 0.35
	local dir = Vector3.new(ev.dx, 0, ev.dz)
	local push = ev.push or 20
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - t0
		if e > 0.7 or not hrp.Parent then
			conn:Disconnect()
			return
		end
		local v = hrp.AssemblyLinearVelocity
		local k = push * (1 - e / 0.7)
		hrp.AssemblyLinearVelocity = Vector3.new(dir.X * k + v.X * 0.6, v.Y, dir.Z * k + v.Z * 0.6)
	end)
end

function Gust.start()
	RunService:BindToRenderStep("PerevalShake", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() < shakeUntil then
			local cam = workspace.CurrentCamera
			local a = shakeAmp * math.clamp((shakeUntil - os.clock()) / 1.5, 0, 1)
			cam.CFrame *= CFrame.Angles(
				math.rad(math.noise(os.clock() * 9, 1) * a * 4),
				math.rad(math.noise(os.clock() * 9, 2) * a * 4),
				0
			)
		end
	end)
end

return Gust
