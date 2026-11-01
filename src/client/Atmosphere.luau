--[[
	Atmosphere — буран на стороне клиента: туман по зонам, снег и позёмка
	вокруг камеры по ветру, цветокоррекция, звук ветра,
	событие «огни в небе» и белая мгла на поляне.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Level = require(Shared.Level)
local Heightmap = require(Shared.Heightmap)
local Storm = require(Shared.Storm)
local RouteMath = require(Shared.RouteMath)
local Make = require(Shared.Make)

local Atmosphere = {}

local player = Players.LocalPlayer

local atm: Atmosphere
local cc: ColorCorrectionEffect

local snowPart: BasePart
local snow: ParticleEmitter
local drift: ParticleEmitter
local windSound: Sound?

local override = { density = nil :: number?, untilT = 0 }
local gustBoost = 0
local fogDensity = 0.5

function Atmosphere.sound(name: string, parent: Instance?): Sound?
	local cfg = Config.Sounds[name]
	if not cfg or cfg.Id == "" then
		return nil
	end
	local s = Make("Sound", {
		Name = name,
		SoundId = cfg.Id,
		Volume = cfg.Volume,
		PlaybackSpeed = cfg.Speed,
		Parent = parent or SoundService,
	})
	return s
end

function Atmosphere.play(name: string)
	local s = Atmosphere.sound(name)
	if s then
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
		task.delay(10, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end
end

function Atmosphere.build()
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") or c:IsA("Sky") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(42, 46, 62)
	Lighting.OutdoorAmbient = Color3.fromRGB(84, 94, 118)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ExposureCompensation = 0.25
	Lighting.GlobalShadows = true

	atm = Make("Atmosphere", {
		Density = 0.5,
		Offset = 0,
		Color = Color3.fromRGB(96, 106, 128),
		Decay = Color3.fromRGB(38, 44, 60),
		Glare = 0,
		Haze = 2.2,
		Parent = Lighting,
	})
	Make("Sky", {
		StarCount = 0,
		CelestialBodiesShown = false,
		Parent = Lighting,
	})
	cc = Make("ColorCorrectionEffect", {
		Saturation = -0.25,
		Contrast = 0.08,
		TintColor = Color3.fromRGB(222, 232, 255),
		Parent = Lighting,
	})
	Make("BloomEffect", { Intensity = 0.6, Size = 30, Threshold = 1.2, Parent = Lighting })
	pcall(function()
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.85
		clouds.Density = 0.6
		clouds.Color = Color3.fromRGB(80, 86, 100)
		clouds.Parent = workspace.Terrain
	end)

	-- снег вокруг камеры
	snowPart = Make("Part", {
		Name = "SnowEmitter",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(90, 1, 90),
		Parent = workspace.CurrentCamera,
	})
	snow = Make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(240, 245, 255)),
		LightEmission = 0.35,
		LightInfluence = 0.6,
		Size = NumberSequence.new(0.18, 0.12),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.1),
			NumberSequenceKeypoint.new(0.85, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(2, 3),
		Rate = 500,
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Bottom,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Parent = snowPart,
	})
	drift = Make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(225, 232, 245)),
		LightInfluence = 0.8,
		Size = NumberSequence.new(4, 8),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.2, 2),
		Rate = 40,
		Speed = NumberRange.new(0, 2),
		EmissionDirection = Enum.NormalId.Top,
		Parent = snowPart,
	})

	windSound = Atmosphere.sound("WindLoop")
	if windSound then
		windSound.Looped = true
		windSound:Play()
	end

	RunService.RenderStepped:Connect(Atmosphere.update)
end

-- Плотность метели по месту игрока
local function targetDensity(s: number, t: number): number
	local zp = Heightmap.zoneParams(s)
	local d = zp.fog * (0.85 + 0.15 * Storm.intensity(t))
	if override.density and os.clock() < override.untilT then
		d = override.density
	end
	return d
end

function Atmosphere.update(dt: number)
	local cam = workspace.CurrentCamera
	if not cam or not atm then
		return
	end
	local camPos = cam.CFrame.Position
	local t = workspace:GetServerTimeNow()
	local s = player:GetAttribute("RouteS") or 0
	local zp = Heightmap.zoneParams(s)

	fogDensity += (targetDensity(s, t) - fogDensity) * math.min(1, dt * 0.8)
	atm.Density = fogDensity

	-- снег летит по ветру
	local wx, wz = Storm.windDir(t)
	local windStrength = (0.35 + 0.65 * zp.wind) * Storm.intensity(t) + gustBoost
	if override.density and os.clock() < override.untilT then
		windStrength *= 0.2
	end
	snowPart.CFrame = CFrame.new(camPos + Vector3.new(-wx * 25, 22, -wz * 25))
	snow.Acceleration = Vector3.new(wx * 55 * windStrength, -6, wz * 55 * windStrength)
	snow.Rate = 120 + 600 * windStrength
	drift.Rate = 10 + 60 * windStrength * zp.wind
	drift.Acceleration = Vector3.new(wx * 60 * windStrength, 0, wz * 60 * windStrength)
	if windSound then
		windSound.Volume = Config.Sounds.WindLoop.Volume * (0.5 + windStrength)
		windSound.PlaybackSpeed = Config.Sounds.WindLoop.Speed * (0.85 + 0.3 * windStrength)
	end
	gustBoost = math.max(0, gustBoost - dt * 0.6)
end

-- Ветер на мгновение крепчает (визуал порыва)
function Atmosphere.gust(strength: number)
	gustBoost = math.max(gustBoost, strength)
	Atmosphere.play("Gust")
end

-- Временно сменить плотность тумана (событие «огни», финал)
function Atmosphere.setOverride(density: number?, seconds: number)
	override.density = density
	override.untilT = os.clock() + seconds
end

-------------------------------------------------------------------------------
-- Событие: огни в небе (рационально объясняется в финале пуском ракеты)
-------------------------------------------------------------------------------
local lightsPlayed = false
function Atmosphere.playLights(onLine: (string) -> ())
	if lightsPlayed then
		return
	end
	lightsPlayed = true
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local duration = 26
	Atmosphere.setOverride(0.12, duration)
	onLine("story.lights.1")

	-- над перевалом: «назад» по маршруту и высоко
	local back = Vector3.new(Level.Waypoints[1].x, 0, Level.Waypoints[1].z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	back = if back.Magnitude > 1 then back.Unit else Vector3.new(0, 0, -1)
	local origin = hrp.Position + back * 380 + Vector3.new(80, 120, 0)
	local ball = Make("Part", {
		Name = "SkyLight",
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 150, 60),
		Size = Vector3.new(10, 10, 10),
		CFrame = CFrame.new(origin),
		CastShadow = false,
		Parent = workspace.CurrentCamera,
	})
	local halo = Make("Part", {
		Name = "SkyHalo",
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 190, 120),
		Transparency = 0.9,
		Size = Vector3.new(20, 20, 20),
		CFrame = CFrame.new(origin),
		CastShadow = false,
		Parent = workspace.CurrentCamera,
	})
	local rise = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(ball, rise, { CFrame = CFrame.new(origin + Vector3.new(30, 140, 0)) }):Play()
	TweenService:Create(halo, rise, {
		CFrame = CFrame.new(origin + Vector3.new(30, 150, 0)),
		Size = Vector3.new(240, 200, 240),
		Transparency = 0.97,
	}):Play()
	local warmTint = TweenService:Create(cc, TweenInfo.new(4), { TintColor = Color3.fromRGB(255, 214, 180) })
	local warmAmb = TweenService:Create(Lighting, TweenInfo.new(4), { OutdoorAmbient = Color3.fromRGB(130, 104, 90) })
	warmTint:Play()
	warmAmb:Play()
	task.delay(5, function()
		onLine("story.lights.2")
	end)
	task.delay(duration - 4, function()
		TweenService:Create(cc, TweenInfo.new(4), { TintColor = Color3.fromRGB(222, 232, 255) }):Play()
		TweenService:Create(Lighting, TweenInfo.new(4), { OutdoorAmbient = Color3.fromRGB(84, 94, 118) }):Play()
		TweenService:Create(ball, TweenInfo.new(4), { Transparency = 1 }):Play()
		TweenService:Create(halo, TweenInfo.new(4), { Transparency = 1 }):Play()
	end)
	task.delay(duration, function()
		onLine("story.lights.3")
		ball:Destroy()
		halo:Destroy()
	end)
end

function Atmosphere.resetEvents()
	lightsPlayed = false
end

-- Длина дуги в точке игрока (если сервер ещё не прислал RouteS)
function Atmosphere.routeS(pos: Vector3): number
	return (RouteMath.nearest(Level.Route, pos.X, pos.Z))
end

return Atmosphere
