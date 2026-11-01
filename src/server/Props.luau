--[[
	Props — строит из примитивов все объекты уровня по данным Layout.
	Интерактивные объекты получают ProximityPrompt с атрибутами:
	  Kind = item | cut | wood | fire | note | stash | dryWood | read
	Тексты подсказок локализует клиент (атрибуты ActionKey / ObjectKey).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Make)
local Layout = require(Shared.Layout)
local Level = require(Shared.Level)
local Heightmap = require(Shared.Heightmap)
local Config = require(Shared.Config)
local Rng = require(Shared.Rng)

local Props = {}

local C = {
	fabric = Color3.fromRGB(196, 92, 38),
	fabricDark = Color3.fromRGB(150, 66, 28),
	wood = Color3.fromRGB(86, 60, 42),
	woodLight = Color3.fromRGB(140, 104, 70),
	bark = Color3.fromRGB(58, 44, 36),
	needles = Color3.fromRGB(38, 66, 52),
	needlesSnow = Color3.fromRGB(196, 210, 214),
	stone = Color3.fromRGB(92, 94, 100),
	metal = Color3.fromRGB(46, 48, 52),
	ice = Color3.fromRGB(190, 214, 232),
	iceThin = Color3.fromRGB(70, 100, 120),
	warm = Color3.fromRGB(255, 176, 92),
	poleRed = Color3.fromRGB(210, 40, 40),
	poleWhite = Color3.fromRGB(235, 235, 235),
}

local function v3(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function part(props)
	props.Anchored = true
	if props.TopSurface == nil then
		props.TopSurface = Enum.SurfaceType.Smooth
		props.BottomSurface = Enum.SurfaceType.Smooth
	end
	return Make("Part", props)
end

local function wedge(props)
	props.Anchored = true
	return Make("WedgePart", props)
end

local function prompt(parent: Instance, kind: string, actionKey: string, objectKey: string, extra)
	local attrs = { Kind = kind, ActionKey = actionKey, ObjectKey = objectKey }
	for k, v in extra or {} do
		attrs[k] = v
	end
	return Make("ProximityPrompt", {
		ActionText = actionKey,
		ObjectText = objectKey,
		HoldDuration = attrs.Hold or 0.4,
		MaxActivationDistance = attrs.Distance or 9,
		RequiresLineOfSight = false,
		Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton,
		Attributes = attrs,
		Parent = parent,
	})
end

-- Табличка с текстом (SurfaceGui на передней грани)
local function textPanel(p: BasePart, text: string, opts)
	local gui = Make("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = opts.light or 1,
		Parent = p,
	})
	Make("TextLabel", {
		Size = UDim2.fromScale(0.92, 0.9),
		Position = UDim2.fromScale(0.04, 0.05),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		TextWrapped = true,
		Font = opts.font or Enum.Font.Merriweather,
		TextColor3 = opts.color or Color3.new(1, 1, 1),
		Parent = gui,
	})
	return gui
end

-------------------------------------------------------------------------------
-- Палатка
-------------------------------------------------------------------------------
function Props.buildTent(parent: Instance)
	local camp = Layout.camp().tent
	local L, W, H = 18, 11, 7.5
	local base = v3(camp.x, camp.y, camp.z)
	local longAxis = v3(camp.nx, 0, camp.nz)
	local downslope = v3(camp.tx, 0, camp.tz)
	local cf = CFrame.lookAt(base, base + longAxis)
	-- с какой стороны (локальный X) находится низ склона
	local sideSign = if cf.RightVector:Dot(downslope) > 0 then 1 else -1

	local model = Make("Model", { Name = "Tent", Parent = parent })
	part({
		Name = "Floor",
		Size = v3(W - 1, 0.4, L - 1),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Color = Color3.fromRGB(60, 58, 64),
		Material = Enum.Material.Fabric,
		Parent = model,
	})
	-- узкая полоса по центру, чтобы персонаж не появлялся под скатом
	Make("SpawnLocation", {
		Name = "Spawn",
		Anchored = true,
		Size = v3(1.5, 0.2, 8),
		CFrame = cf * CFrame.new(sideSign * 0.5, 0.5, 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Duration = 0,
		Neutral = true,
		AllowTeamChangeOnTouch = false,
		Parent = model,
	})

	local theta = math.atan2(H, W / 2)
	local slopeLen = math.sqrt((W / 2) ^ 2 + H ^ 2)
	local roofs = {}
	for _, s in { 1, -1 } do
		local roof = part({
			Name = if s == sideSign then "CutWall" else "Roof",
			Size = v3(slopeLen, 0.25, L),
			CFrame = cf * CFrame.new(s * W / 4, H / 2, 0) * CFrame.Angles(0, 0, -s * theta),
			Color = C.fabric,
			Material = Enum.Material.Fabric,
			CastShadow = true,
			Parent = model,
		})
		roofs[s] = roof
	end
	-- торцы — по два клина
	for _, zs in { 1, -1 } do
		for _, s in { 1, -1 } do
			local pos = cf * v3(s * W / 4, H / 2, zs * (L / 2 - 0.12))
			local dir = cf:VectorToWorldSpace(v3(s, 0, 0))
			wedge({
				Name = "End",
				Size = v3(0.25, H, W / 2),
				CFrame = CFrame.lookAt(pos, pos + dir),
				Color = C.fabricDark,
				Material = Enum.Material.Fabric,
				Parent = model,
			})
		end
	end
	-- растяжки и колышки (декор)
	for _, zs in { -0.4, 0.4 } do
		for _, s in { 1, -1 } do
			part({
				Name = "Stake",
				Size = v3(0.2, 1.2, 0.2),
				CFrame = cf * CFrame.new(s * (W / 2 + 2.5), 0.4, zs * L),
				Color = C.metal,
				CanCollide = false,
				Parent = model,
			})
		end
	end
	-- тусклый свет внутри (свеча)
	local candle = part({
		Name = "Candle",
		Size = v3(0.3, 0.6, 0.3),
		CFrame = cf * CFrame.new(-sideSign * 2.5, 0.7, -L / 2 + 2),
		Color = Color3.fromRGB(240, 230, 200),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	Make("PointLight", {
		Color = C.warm,
		Range = 14,
		Brightness = 1.6,
		Shadows = true,
		Parent = candle,
	})

	-- стенку, которую режут
	local cut = roofs[sideSign]
	prompt(cut, "cut", "prompt.cut", "prompt.cutObject", { Hold = 1.2, Distance = 8 })
	model:SetAttribute("Cut", false)

	-- предметы на полу
	local items = Make("Folder", { Name = "Items", Parent = model })
	local itemZ = { -6, -3, 0, 3, 6 }
	for i, name in Level.Items do
		local m = Make("Model", { Name = name, Parent = items })
		local at = cf * CFrame.new(-sideSign * 1.4, 0.4, itemZ[i])
		local main
		if name == "Boots" then
			main = part({ Name = "Main", Size = v3(0.9, 0.9, 1.7), CFrame = at * CFrame.new(-0.6, 0.45, 0), Color = Color3.fromRGB(52, 40, 32), Material = Enum.Material.Fabric, CanCollide = false, Parent = m })
			part({ Name = "B2", Size = v3(0.9, 0.9, 1.7), CFrame = at * CFrame.new(0.6, 0.45, 0.2), Color = Color3.fromRGB(52, 40, 32), Material = Enum.Material.Fabric, CanCollide = false, Parent = m })
		elseif name == "Jacket" then
			main = part({ Name = "Main", Size = v3(2.2, 0.6, 1.8), CFrame = at * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(40, 70, 140), Material = Enum.Material.Fabric, CanCollide = false, Parent = m })
		elseif name == "Flashlight" then
			main = part({ Name = "Main", Shape = Enum.PartType.Cylinder, Size = v3(1.3, 0.45, 0.45), CFrame = at * CFrame.new(0, 0.25, 0), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Metal, CanCollide = false, Parent = m })
			part({ Name = "Lens", Shape = Enum.PartType.Cylinder, Size = v3(0.1, 0.5, 0.5), CFrame = at * CFrame.new(0.68, 0.25, 0), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, CanCollide = false, Parent = m })
		elseif name == "Matches" then
			main = part({ Name = "Main", Size = v3(0.8, 0.3, 0.55), CFrame = at * CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(170, 50, 40), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = m })
		else -- Thermos
			main = part({ Name = "Main", Shape = Enum.PartType.Cylinder, Size = v3(1.5, 0.55, 0.55), CFrame = at * CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(70, 96, 80), Material = Enum.Material.Metal, CanCollide = false, Parent = m })
		end
		m.PrimaryPart = main
		prompt(main, "item", "prompt.take", "item." .. name, { Item = name, Hold = 0.3, Distance = 7 })
	end

	-- вход завален: позиция сугроба за торцом
	local entrance = cf * v3(0, 1.5, -L / 2 - 5)
	return model, entrance, cf, sideSign, { L = L, W = W, H = H }
end

-- Разрезать стенку: убрать стенку, повесить два лоскута
function Props.cutTent(model: Model)
	if model:GetAttribute("Cut") then
		return
	end
	model:SetAttribute("Cut", true)
	local wall = model:FindFirstChild("CutWall") :: BasePart
	if not wall then
		return
	end
	local p = wall:FindFirstChildOfClass("ProximityPrompt")
	if p then
		p.Enabled = false
	end
	wall.Transparency = 1
	wall.CanCollide = false
	wall.CanQuery = false
	local cf = wall.CFrame
	for _, s in { 1, -1 } do
		part({
			Name = "Flap",
			Size = v3(wall.Size.X * 0.9, 0.2, wall.Size.Z * 0.22),
			CFrame = cf * CFrame.new(0, 0, s * wall.Size.Z * 0.39) * CFrame.Angles(s * 0.5, 0, 0),
			Color = C.fabric,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = model,
		})
	end
end

-------------------------------------------------------------------------------
-- Табличка «Перевал Дятлова» и памятный знак
-------------------------------------------------------------------------------
function Props.buildCamp(parent: Instance)
	local camp = Layout.camp()
	local folder = Make("Folder", { Name = "Camp", Parent = parent })

	-- табличка на двух столбах, лицом к палатке
	local s = camp.sign
	local t = camp.tent
	local pos = v3(s.x, s.y, s.z)
	local face = CFrame.lookAt(pos, v3(t.x, s.y, t.z))
	for _, dx in { -2.2, 2.2 } do
		part({ Name = "Post", Size = v3(0.4, 6, 0.4), CFrame = face * CFrame.new(dx, 2.6, 0), Color = C.wood, Material = Enum.Material.Wood, Parent = folder })
	end
	local board = part({ Name = "Board", Size = v3(5.6, 2.4, 0.25), CFrame = face * CFrame.new(0, 4.4, -0.25), Color = Color3.fromRGB(34, 60, 110), Material = Enum.Material.Metal, Parent = folder })
	textPanel(board, "ПЕРЕВАЛ ДЯТЛОВА\nDYATLOV PASS", { font = Enum.Font.BuilderSansBold, light = 0.4 })
	prompt(board, "read", "prompt.read", "prompt.signObject", { TextKey = "sign.pass", Distance = 10 })

	-- памятный знак: камень с металлической пластиной
	local m = camp.memorial
	local mpos = v3(m.x, m.y, m.z)
	local mface = CFrame.lookAt(mpos, mpos + v3(m.faceX, 0, m.faceZ))
	part({ Name = "Stone", Size = v3(4, 4.5, 2.4), CFrame = mface * CFrame.new(0, 1.8, 0) * CFrame.Angles(0.05, 0.1, 0.04), Color = C.stone, Material = Enum.Material.Slate, Parent = folder })
	local plaque = part({ Name = "Plaque", Size = v3(2.6, 1.8, 0.12), CFrame = mface * CFrame.new(0, 2.4, -1.25), Color = Color3.fromRGB(40, 38, 36), Material = Enum.Material.Metal, Parent = folder })
	textPanel(plaque, "Памяти туристов,\nпогибших на этом склоне\nв феврале 1959 года", { color = Color3.fromRGB(220, 200, 150), light = 0.6 })
	prompt(plaque, "read", "prompt.read", "prompt.plaqueObject", { TextKey = "sign.memorial", Distance = 10 })
	return folder
end

-------------------------------------------------------------------------------
-- Вешки на склоне
-------------------------------------------------------------------------------
function Props.buildPoles(parent: Instance)
	local folder = Make("Folder", { Name = "Poles", Parent = parent })
	for _, p in Layout.poles() do
		local baseCf = CFrame.new(p.x, p.y, p.z) * CFrame.Angles(0, math.rad(p.yaw), 0)
		local cf
		if p.toppled then
			cf = baseCf * CFrame.new(0, 0.4, 0) * CFrame.Angles(math.rad(80), 0, 0) * CFrame.new(0, 3.4, 0)
		else
			cf = baseCf * CFrame.Angles(math.rad(p.tilt), 0, math.rad(p.tilt * 0.5)) * CFrame.new(0, 2.8, 0)
		end
		local m = Make("Model", { Name = "Pole", Parent = folder })
		part({ Name = "Shaft", Size = v3(0.32, 7, 0.32), CFrame = cf, Color = C.bark, Material = Enum.Material.Wood, Parent = m })
		part({ Name = "BandR", Size = v3(0.42, 0.55, 0.42), CFrame = cf * CFrame.new(0, 3.0, 0), Color = C.poleRed, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = m })
		part({ Name = "BandW", Size = v3(0.42, 0.45, 0.42), CFrame = cf * CFrame.new(0, 2.45, 0), Color = C.poleWhite, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = m })
		-- лоскут-флажок
		part({ Name = "Rag", Size = v3(0.05, 0.5, 1.1), CFrame = cf * CFrame.new(0, 3.2, 0.6) * CFrame.Angles(0, 0, 0.2), Color = C.poleRed, Material = Enum.Material.Fabric, CanCollide = false, CastShadow = false, Parent = m })
	end
	return folder
end

-------------------------------------------------------------------------------
-- Ели
-------------------------------------------------------------------------------
local function spruce(folder: Instance, t)
	local sc = t.scale
	local base = v3(t.x, t.y - 0.6, t.z)
	local trunkH = 5 * sc + 1
	local m = Make("Model", { Name = if t.blaze then "BlazedTree" else "Tree", Parent = folder })
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = v3(trunkH + 6 * sc, 1.1 * sc + 0.2, 1.1 * sc + 0.2),
		CFrame = CFrame.new(base + v3(0, (trunkH + 6 * sc) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = C.bark,
		Material = Enum.Material.Wood,
		Parent = m,
	})
	local tiers = if sc < 0.95 then 2 else 3
	local y = trunkH * 0.55
	local w, h = 9 * sc, 6.5 * sc
	local yaw = (t.x * 13 + t.z * 7) % 90
	for i = 1, tiers do
		local center = base + v3(0, y + h / 2, 0)
		local color = if i == tiers then C.needlesSnow else C.needles
		local mat = if i == tiers then Enum.Material.Snow else Enum.Material.Grass
		for q = 0, 3 do
			local a = math.rad(yaw + q * 90)
			local out = v3(math.cos(a), 0, math.sin(a))
			local pos = center + out * (w / 4)
			wedge({
				Name = "Crown",
				Size = v3(w, h, w / 2),
				CFrame = CFrame.lookAt(pos, pos + out),
				Color = color,
				Material = mat,
				CanCollide = false,
				CanTouch = false,
				Parent = m,
			})
		end
		y += h * 0.62
		w *= 0.72
		h *= 0.85
	end
	if t.blaze then
		local fx, fz = t.faceX, t.faceZ
		local l = math.sqrt(fx * fx + fz * fz)
		local dir = v3(fx / l, 0, fz / l)
		local r = (1.1 * sc + 0.2) / 2
		local pos = base + v3(0, 4.2, 0) + dir * (r + 0.02)
		part({
			Name = "Blaze",
			Size = v3(0.8, 1.3, 0.1),
			CFrame = CFrame.lookAt(pos, pos + dir),
			Color = Color3.fromRGB(150, 128, 86),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = m,
		})
	end
end

function Props.buildTrees(parent: Instance)
	local folder = Make("Folder", { Name = "Trees", Parent = parent })
	for i, t in Layout.trees() do
		spruce(folder, t)
		if i % 60 == 0 then
			task.wait()
		end
	end
	return folder
end

-------------------------------------------------------------------------------
-- Кедр и записка
-------------------------------------------------------------------------------
function Props.buildCedar(parent: Instance)
	local c = Layout.cedar()
	local m = Make("Model", { Name = "Cedar", Parent = parent })
	local base = v3(c.x, c.y - 1, c.z)
	local trunk = part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = v3(22, 3.4, 3.4),
		CFrame = CFrame.new(base + v3(0, 11, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(74, 52, 40),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	local rng = Rng.new(Config.Seed + 77)
	-- мощные нижние ветви
	for i = 1, 5 do
		local a = rng:range(0, math.pi * 2)
		local dir = v3(math.cos(a), 0, math.sin(a))
		local pos = base + v3(0, 9 + i * 1.6, 0) + dir * 3.5
		part({
			Name = "Branch",
			Size = v3(0.8, 0.8, 7),
			CFrame = CFrame.lookAt(pos, pos + dir + v3(0, 0.35, 0)),
			Color = Color3.fromRGB(70, 50, 40),
			Material = Enum.Material.Wood,
			CanCollide = false,
			Parent = m,
		})
	end
	-- крона из шаров
	for i = 1, 7 do
		local a = rng:range(0, math.pi * 2)
		local r = rng:range(1.5, 6)
		local pos = base + v3(math.cos(a) * r, rng:range(17, 26), math.sin(a) * r)
		local size = rng:range(8, 12)
		part({
			Name = "Crown",
			Shape = Enum.PartType.Ball,
			Size = v3(size, size * 0.8, size),
			CFrame = CFrame.new(pos),
			Color = if i > 5 then C.needlesSnow else C.needles,
			Material = if i > 5 then Enum.Material.Snow else Enum.Material.Grass,
			CanCollide = false,
			CanTouch = false,
			Parent = m,
		})
	end
	-- записка на стволе со стороны костра
	local fire
	for _, f in Layout.fires() do
		if f.id == "cedar" then
			fire = f
		end
	end
	local toFire = v3(fire.x - c.x, 0, fire.z - c.z).Unit
	local npos = base + v3(0, 5.5, 0) + toFire * 1.75
	local note = part({
		Name = "Note",
		Size = v3(1.0, 1.3, 0.05),
		CFrame = CFrame.lookAt(npos, npos + toFire),
		Color = Color3.fromRGB(235, 228, 205),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = m,
	})
	prompt(note, "note", "prompt.read", "prompt.noteObject", { NoteId = "cedar", TextKey = "note.cedar", Distance = 10 })
	return m, trunk
end

-------------------------------------------------------------------------------
-- Костры
-------------------------------------------------------------------------------
local function setFireLit(model: Model, lit: boolean)
	model:SetAttribute("Lit", lit)
	local flame = model:FindFirstChild("Flame")
	if flame then
		for _, d in flame:GetChildren() do
			if d:IsA("Fire") or d:IsA("Light") or d:IsA("Smoke") or d:IsA("Sound") then
				if d:IsA("Sound") then
					if lit then
						d:Play()
					end
				else
					d.Enabled = lit
				end
			end
		end
	end
	local pit = model:FindFirstChild("Pit")
	local p = pit and pit:FindFirstChildOfClass("ProximityPrompt")
	if p then
		p.Enabled = not lit
	end
end
Props.setFireLit = setFireLit

function Props.buildFires(parent: Instance)
	local folder = Make("Folder", { Name = "Fires", Parent = parent })
	local models = {}
	for _, f in Layout.fires() do
		local m = Make("Model", { Name = f.id, Parent = folder })
		local center = v3(f.x, f.y, f.z)
		local pit = part({
			Name = "Pit",
			Shape = Enum.PartType.Cylinder,
			Size = v3(0.3, 4.2, 4.2),
			CFrame = CFrame.new(center + v3(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(40, 36, 34),
			Material = Enum.Material.Slate,
			CanCollide = false,
			Parent = m,
		})
		for i = 0, 7 do
			local a = i * math.pi / 4
			part({
				Name = "Stone",
				Size = v3(0.9, 0.6, 0.7),
				CFrame = CFrame.new(center + v3(math.cos(a) * 2.2, 0.25, math.sin(a) * 2.2)) * CFrame.Angles(0, -a, 0),
				Color = C.stone,
				Material = Enum.Material.Slate,
				CanCollide = false,
				Parent = m,
			})
		end
		for i = 0, 2 do
			part({
				Name = "Log",
				Shape = Enum.PartType.Cylinder,
				Size = v3(2.6, 0.45, 0.45),
				CFrame = CFrame.new(center + v3(0, 0.4, 0)) * CFrame.Angles(0, i * math.pi / 3, 0.25),
				Color = Color3.fromRGB(50, 34, 26),
				Material = Enum.Material.Wood,
				CanCollide = false,
				Parent = m,
			})
		end
		local flame = part({
			Name = "Flame",
			Size = v3(1, 1, 1),
			CFrame = CFrame.new(center + v3(0, 1.2, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = m,
		})
		Make("Fire", { Size = 5, Heat = 8, Color = Color3.fromRGB(255, 140, 40), SecondaryColor = Color3.fromRGB(255, 60, 10), Enabled = false, Parent = flame })
		Make("Smoke", { Size = 2.5, Opacity = 0.08, RiseVelocity = 4, Color = Color3.fromRGB(120, 120, 120), Enabled = false, Parent = flame })
		Make("PointLight", { Color = C.warm, Range = 30, Brightness = 2.4, Shadows = true, Enabled = false, Parent = flame })
		local snd = Config.Sounds.Fire
		if snd.Id ~= "" then
			Make("Sound", { SoundId = snd.Id, Volume = snd.Volume, Looped = true, RollOffMaxDistance = 60, Parent = flame })
		end
		prompt(pit, "fire", "prompt.light", "prompt.fireObject", { FireId = f.id, Hold = 1.5, Distance = 9 })
		m:SetAttribute("FireId", f.id)
		m:SetAttribute("Checkpoint", f.index)
		setFireLit(m, f.prelit)
		models[f.id] = m

		-- место появления у костра (со стороны тропы)
		local sTr = Heightmap.sample(f.x, f.z).s
		local px, pz = Level.placeAt(sTr, 0)
		local dir = v3(px - f.x, 0, pz - f.z)
		dir = if dir.Magnitude > 0.1 then dir.Unit else v3(1, 0, 0)
		local sp = center + dir * 4.5
		m:SetAttribute("SpawnPos", v3(sp.X, Heightmap.height(sp.X, sp.Z) + 3.5, sp.Z))

		-- бревно-лавка
		local bench = center - dir * 4 + v3(0, 0.5, 0)
		part({
			Name = "Bench",
			Shape = Enum.PartType.Cylinder,
			Size = v3(5, 1.1, 1.1),
			CFrame = CFrame.lookAt(bench, bench + dir) * CFrame.Angles(0, math.pi / 2, 0),
			Color = C.wood,
			Material = Enum.Material.Wood,
			Parent = m,
		})

		if f.stash then
			local bpos = center + dir:Cross(Vector3.yAxis) * 4.5 + v3(0, 0.6, 0)
			local box = part({
				Name = "Stash",
				Size = v3(2, 1.2, 1.4),
				CFrame = CFrame.lookAt(bpos, bpos + dir),
				Color = Color3.fromRGB(90, 110, 70),
				Material = Enum.Material.WoodPlanks,
				Parent = m,
			})
			prompt(box, "stash", "prompt.search", "prompt.stashObject", { Hold = 0.6 })
		end
		if f.dryWood then
			Props.buildLabaz(m, center, dir)
		end
	end
	return folder, models
end

-- Лабаз: настил на сваях с сухими дровами
function Props.buildLabaz(parent: Instance, fireCenter: Vector3, towardTrail: Vector3)
	local m = Make("Model", { Name = "Labaz", Parent = parent })
	local pos = fireCenter - towardTrail * 7
	local ground = Heightmap.height(pos.X, pos.Z)
	local cf = CFrame.lookAt(v3(pos.X, ground, pos.Z), v3(pos.X, ground, pos.Z) + towardTrail)
	for _, dx in { -2, 2 } do
		for _, dz in { -1.6, 1.6 } do
			part({ Name = "Post", Size = v3(0.5, 4.5, 0.5), CFrame = cf * CFrame.new(dx, 2.2, dz), Color = C.wood, Material = Enum.Material.Wood, Parent = m })
		end
	end
	part({ Name = "Deck", Size = v3(5, 0.4, 4), CFrame = cf * CFrame.new(0, 4.4, 0), Color = C.woodLight, Material = Enum.Material.WoodPlanks, Parent = m })
	local woodStack = part({ Name = "DryWood", Size = v3(3.6, 1.2, 2.4), CFrame = cf * CFrame.new(0, 5.2, 0), Color = Color3.fromRGB(120, 86, 56), Material = Enum.Material.Wood, Parent = m })
	part({ Name = "Roof", Size = v3(6, 0.3, 5), CFrame = cf * CFrame.new(0, 6.6, 0) * CFrame.Angles(0.25, 0, 0), Color = C.wood, Material = Enum.Material.WoodPlanks, Parent = m })
	part({ Name = "RoofSnow", Size = v3(6.1, 0.5, 5.1), CFrame = cf * CFrame.new(0, 6.95, 0) * CFrame.Angles(0.25, 0, 0), Color = Color3.fromRGB(230, 236, 245), Material = Enum.Material.Snow, CanCollide = false, Parent = m })
	local sign = part({ Name = "Sign", Size = v3(2.4, 0.8, 0.1), CFrame = cf * CFrame.new(0, 3.4, -1.75), Color = C.wood, Material = Enum.Material.Wood, Parent = m })
	textPanel(sign, "ЛАБАЗ", { color = Color3.fromRGB(230, 210, 170) })
	prompt(woodStack, "dryWood", "prompt.dryWood", "prompt.dryWoodObject", { Hold = 0.8, Distance = 10 })
	return m
end

-------------------------------------------------------------------------------
-- Хворост
-------------------------------------------------------------------------------
function Props.setPileAvailable(m: Model, available: boolean)
	m:SetAttribute("Available", available)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if available then 0 else 1
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = available
		end
	end
end

function Props.buildWoodPiles(parent: Instance)
	local folder = Make("Folder", { Name = "WoodPiles", Parent = parent })
	for _, p in Layout.woodPiles() do
		local m = Make("Model", { Name = "Pile" .. p.id, Parent = folder })
		local center = v3(p.x, p.y + 0.3, p.z)
		local main
		for i = 0, 3 do
			local stick = part({
				Name = if i == 0 then "Main" else "Stick",
				Shape = Enum.PartType.Cylinder,
				Size = v3(3.2 - i * 0.3, 0.3, 0.3),
				CFrame = CFrame.new(center + v3(0, i * 0.18, 0)) * CFrame.Angles(0, i * 1.1 + p.id, 0.08),
				Color = Color3.fromRGB(96, 70, 48),
				Material = Enum.Material.Wood,
				CanCollide = false,
				Parent = m,
			})
			main = main or stick
		end
		m.PrimaryPart = main
		prompt(main, "wood", "prompt.wood", "prompt.woodObject", { PileId = p.id, Hold = 0.7, Distance = 8 })
		Props.setPileAvailable(m, true)
	end
	return folder
end

-------------------------------------------------------------------------------
-- Лёд и брёвна
-------------------------------------------------------------------------------
function Props.buildIce(parent: Instance)
	local folder = Make("Folder", { Name = "Ice", Parent = parent })
	for _, s in Layout.ice() do
		local pos = v3(s.x, s.y, s.z)
		local p = part({
			Name = if s.thin then "ThinIce" else "Ice",
			Size = v3(s.width, 0.6, s.len),
			CFrame = CFrame.lookAt(pos, pos + v3(s.dirX, 0, s.dirZ)),
			Color = if s.thin then C.iceThin else C.ice,
			Material = Enum.Material.Ice,
			Transparency = if s.thin then 0.3 else 0.05,
			Reflectance = if s.thin then 0.15 else 0.05,
			CastShadow = false,
			Attributes = { Thin = s.thin, IceId = s.id },
			Tags = if s.thin then { "ThinIce" } else nil,
			Parent = folder,
		})
		p.CanTouch = s.thin
	end
	for i, l in Layout.logs() do
		local pos = v3(l.x, l.y, l.z)
		part({
			Name = "LogBridge" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = v3(l.len, 2.2, 2.2),
			CFrame = CFrame.lookAt(pos, pos + v3(l.dirX, 0, l.dirZ)) * CFrame.Angles(0, math.pi / 2, 0),
			Color = Color3.fromRGB(72, 54, 40),
			Material = Enum.Material.Wood,
			Parent = folder,
		})
	end
	return folder
end

-------------------------------------------------------------------------------
-- Изба, ребята, колокол
-------------------------------------------------------------------------------
local function friend(parent: Instance, cf: CFrame, jacket: Color3, hat: Color3)
	local m = Make("Model", { Name = "Friend", Parent = parent })
	part({ Name = "Legs", Size = v3(1.8, 1, 2), CFrame = cf * CFrame.new(0, 0.5, -0.5), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Fabric, CanCollide = false, Parent = m })
	part({ Name = "Torso", Size = v3(2, 2, 1.1), CFrame = cf * CFrame.new(0, 2, 0.4), Color = jacket, Material = Enum.Material.Fabric, CanCollide = false, Parent = m })
	part({ Name = "Head", Shape = Enum.PartType.Ball, Size = v3(1.3, 1.3, 1.3), CFrame = cf * CFrame.new(0, 3.65, 0.4), Color = Color3.fromRGB(230, 190, 160), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = m })
	part({ Name = "Hat", Size = v3(1.35, 0.6, 1.35), CFrame = cf * CFrame.new(0, 4.25, 0.4), Color = hat, Material = Enum.Material.Fabric, CanCollide = false, Parent = m })
	return m
end

function Props.buildHut(parent: Instance)
	local size = Level.Hut.size
	local hf = Level.hutFrame()
	-- дверь смотрит назад по маршруту — навстречу игроку
	local toPlayer = v3(hf.dirX, 0, hf.dirZ)
	local center = v3(hf.x, hf.y, hf.z)
	local cf = CFrame.lookAt(center, center + toPlayer) -- -Z (LookVector) = к двери
	local m = Make("Model", { Name = "Hut", Parent = parent })
	local wallT = 1
	local Wx, Wy, Wz = size.x, size.y, size.z
	local logColor = Color3.fromRGB(96, 66, 44)
	local function wall(name, sz, offset)
		return part({ Name = name, Size = sz, CFrame = cf * CFrame.new(offset), Color = logColor, Material = Enum.Material.WoodPlanks, Parent = m })
	end
	part({ Name = "Floor", Size = v3(Wx, 0.6, Wz), CFrame = cf * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(80, 56, 38), Material = Enum.Material.WoodPlanks, Parent = m })
	wall("Back", v3(Wx, Wy, wallT), v3(0, Wy / 2, Wz / 2))
	wall("Left", v3(wallT, Wy, Wz), v3(-Wx / 2, Wy / 2, 0))
	wall("Right", v3(wallT, Wy, Wz), v3(Wx / 2, Wy / 2, 0))
	-- передняя стена с дверным проёмом 5×8
	local doorW, doorH = 5, 8
	local sideW = (Wx - doorW) / 2
	wall("FrontL", v3(sideW, Wy, wallT), v3(-(doorW / 2 + sideW / 2), Wy / 2, -Wz / 2))
	wall("FrontR", v3(sideW, Wy, wallT), v3(doorW / 2 + sideW / 2, Wy / 2, -Wz / 2))
	wall("FrontTop", v3(doorW, Wy - doorH, wallT), v3(0, doorH + (Wy - doorH) / 2, -Wz / 2))
	-- крыша двускатная
	local rise = 6
	local roofLen = math.sqrt((Wx / 2 + 1.5) ^ 2 + rise ^ 2)
	local ang = math.atan2(rise, Wx / 2 + 1.5)
	for _, s in { 1, -1 } do
		local rcf = cf * CFrame.new(s * (Wx / 4 + 0.75), Wy + rise / 2, 0) * CFrame.Angles(0, 0, -s * ang)
		part({ Name = "Roof", Size = v3(roofLen, 0.6, Wz + 3), CFrame = rcf, Color = Color3.fromRGB(70, 50, 36), Material = Enum.Material.WoodPlanks, Parent = m })
		part({ Name = "RoofSnow", Size = v3(roofLen, 0.8, Wz + 3.2), CFrame = rcf * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(232, 238, 246), Material = Enum.Material.Snow, CanCollide = false, Parent = m })
	end
	for _, zs in { 1, -1 } do
		for _, s in { 1, -1 } do
			local pos = cf * v3(s * Wx / 4, Wy + rise / 2, zs * (Wz / 2))
			local dir = cf:VectorToWorldSpace(v3(s, 0, 0))
			wedge({ Name = "Gable", Size = v3(wallT, rise, Wx / 2), CFrame = CFrame.lookAt(pos, pos + dir), Color = logColor, Material = Enum.Material.WoodPlanks, Parent = m })
		end
	end
	-- окна (тёплый свет)
	for _, x in { -Wx / 2 + 4, Wx / 2 - 4 } do
		part({ Name = "Window", Size = v3(3, 2.4, 0.3), CFrame = cf * CFrame.new(x, 5.5, -Wz / 2 - 0.1), Color = Color3.fromRGB(255, 196, 110), Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	end
	for _, s in { 1, -1 } do
		part({ Name = "Window", Size = v3(0.3, 2.4, 3), CFrame = cf * CFrame.new(s * (Wx / 2 + 0.1), 5.5, 0), Color = Color3.fromRGB(255, 196, 110), Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	end
	-- печь и труба
	local stove = part({ Name = "Stove", Size = v3(4, 3.5, 3), CFrame = cf * CFrame.new(Wx / 2 - 3.5, 2.35, Wz / 2 - 3), Color = Color3.fromRGB(36, 34, 34), Material = Enum.Material.Metal, Parent = m })
	Make("Fire", { Size = 3, Heat = 4, Color = Color3.fromRGB(255, 140, 40), Parent = stove })
	local chimney = part({ Name = "Chimney", Size = v3(1.6, 8, 1.6), CFrame = cf * CFrame.new(Wx / 2 - 3.5, Wy + 3, Wz / 2 - 3), Color = Color3.fromRGB(60, 56, 54), Material = Enum.Material.Brick, Parent = m })
	Make("Smoke", { Size = 4, Opacity = 0.15, RiseVelocity = 6, Color = Color3.fromRGB(150, 150, 150), Parent = chimney })
	local lamp = part({ Name = "Lamp", Size = v3(0.6, 0.8, 0.6), CFrame = cf * CFrame.new(0, Wy - 1.5, 0), Color = Color3.fromRGB(255, 220, 160), Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	Make("PointLight", { Color = C.warm, Range = 26, Brightness = 2.2, Shadows = true, Parent = lamp })
	-- лавки и ребята
	for _, x in { -Wx / 2 + 2, Wx / 2 - 2 } do
		part({ Name = "Bench", Size = v3(2, 1.6, Wz - 8), CFrame = cf * CFrame.new(x, 1.4, 1), Color = Color3.fromRGB(110, 80, 54), Material = Enum.Material.WoodPlanks, Parent = m })
	end
	local jackets = { Color3.fromRGB(180, 40, 40), Color3.fromRGB(50, 120, 60), Color3.fromRGB(200, 160, 40), Color3.fromRGB(60, 80, 150) }
	local hats = { Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 40), Color3.fromRGB(150, 30, 30), Color3.fromRGB(230, 200, 60) }
	local seats = { { -Wx / 2 + 2, -2 }, { -Wx / 2 + 2, 3 }, { Wx / 2 - 2, -3 }, { Wx / 2 - 2, 2 } }
	for i, st in seats do
		local x, z = st[1], st[2]
		local face = if x < 0 then math.pi / 2 else -math.pi / 2
		friend(m, cf * CFrame.new(x, 1.6, z) * CFrame.Angles(0, face, 0), jackets[i], hats[i])
	end

	-- зона финиша внутри избы
	local finish = part({
		Name = "FinishZone",
		Size = v3(Wx - 2, Wy - 1, Wz - 2),
		CFrame = cf * CFrame.new(0, Wy / 2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = m,
	})

	-- колокол у двери и маяк
	local postPos = cf * v3(doorW / 2 + 2.5, 0, -Wz / 2 - 3)
	local post = part({ Name = "BellPost", Size = v3(0.5, 9, 0.5), CFrame = CFrame.new(postPos + v3(0, 4.5, 0)), Color = C.wood, Material = Enum.Material.Wood, Parent = m })
	local bell = part({ Name = "Bell", Shape = Enum.PartType.Ball, Size = v3(1.6, 1.8, 1.6), CFrame = post.CFrame * CFrame.new(0, 3.6, -0.9), Color = Color3.fromRGB(200, 160, 70), Material = Enum.Material.Metal, CanCollide = false, Parent = m })
	local lantern = part({ Name = "Lantern", Size = v3(0.9, 1.2, 0.9), CFrame = post.CFrame * CFrame.new(0, 4.9, 0), Color = Color3.fromRGB(255, 210, 130), Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	Make("PointLight", { Color = C.warm, Range = 50, Brightness = 3, Parent = lantern })
	local snd = Config.Sounds.Bell
	if snd.Id ~= "" then
		Make("Sound", { Name = "BellSound", SoundId = snd.Id, Volume = snd.Volume, RollOffMaxDistance = 500, RollOffMinDistance = 30, Parent = bell })
	end
	-- табличка
	local sign = part({ Name = "Sign", Size = v3(3, 1, 0.15), CFrame = cf * CFrame.new(0, doorH + 1.2, -Wz / 2 - 0.6), Color = C.wood, Material = Enum.Material.Wood, Parent = m })
	textPanel(sign, "ИЗБА", { color = Color3.fromRGB(230, 210, 170) })
	return m, finish, bell
end

return Props
