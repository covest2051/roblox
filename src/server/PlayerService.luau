--[[
	PlayerService — серверная симуляция каждого игрока:
	тепло, силы, укрытие, мокрая одежда, костры-чекпоинты, финиш.
	Состояние публикуется атрибутами Player — HUD клиента читает их.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Level = require(Shared.Level)
local Heightmap = require(Shared.Heightmap)
local RouteMath = require(Shared.RouteMath)
local Heat = require(Shared.Heat)
local Storm = require(Shared.Storm)
local Inventory = require(Shared.Inventory)
local Progress = require(Shared.Progress)
local Net = require(Shared.Net)
local Make = require(Shared.Make)

local World = require(script.Parent.World)
local Props = require(script.Parent.Props)

local PlayerService = {}

export type PState = {
	player: Player,
	inv: Inventory.Inv,
	progress: Progress.State,
	heat: number,
	stamina: number,
	exhausted: boolean,
	wet: boolean,
	wetUntil: number,
	dryTimer: number,
	sprintHeld: boolean,
	sprinting: boolean,
	flashlightOn: boolean,
	checkpoint: number,
	introDone: boolean,
	spawnedAt: number,
	tentDeadline: number,
	tentExited: boolean,
	startTime: number,
	finished: boolean,
	finishTime: number,
	faints: number,
	fainting: boolean,
	firesLit: number,
	zone: string,
	zonesSeen: { [string]: boolean },
	nearFireId: string?,
	wasNearCedar: boolean,
	exposed: boolean,
	lost: boolean,
	god: boolean,
	stashUsed: boolean,
	s: number,
}

PlayerService.states = {} :: { [Player]: PState }
PlayerService.bestTime = nil :: number?

local function now(): number
	return workspace:GetServerTimeNow()
end

function PlayerService.send(player: Player, payload)
	Net.ServerEvent:FireClient(player, payload)
end

function PlayerService.toast(player: Player, key: string, vars: { [string]: any }?)
	PlayerService.send(player, { t = "toast", key = key, vars = vars })
end

local function newState(player: Player): PState
	return {
		player = player,
		inv = Inventory.new(),
		progress = Progress.new(),
		heat = Config.Heat.Start,
		stamina = Config.Stamina.Max,
		exhausted = false,
		wet = false,
		wetUntil = 0,
		dryTimer = 0,
		sprintHeld = false,
		sprinting = false,
		flashlightOn = false,
		checkpoint = 1,
		introDone = false,
		spawnedAt = now(),
		tentDeadline = math.huge,
		tentExited = false,
		startTime = now(),
		finished = false,
		finishTime = 0,
		faints = 0,
		fainting = false,
		firesLit = 0,
		zone = "slope",
		zonesSeen = {},
		nearFireId = nil,
		wasNearCedar = false,
		exposed = false,
		lost = false,
		god = false,
		stashUsed = false,
		s = 0,
	}
end

function PlayerService.get(player: Player): PState?
	return PlayerService.states[player]
end

-------------------------------------------------------------------------------
-- Публикация состояния
-------------------------------------------------------------------------------
function PlayerService.publish(st: PState)
	local p = st.player
	local inv = st.inv
	p:SetAttribute("Heat", math.floor(st.heat * 10) / 10)
	p:SetAttribute("Stamina", math.floor(st.stamina))
	p:SetAttribute("Battery", math.floor(inv.battery))
	p:SetAttribute("Wood", inv.wood)
	p:SetAttribute("Matches", inv.matches)
	p:SetAttribute("Sips", inv.sips)
	p:SetAttribute("ItemsTaken", inv.taken)
	local items = {}
	for _, name in Level.Items do
		if inv.items[name] then
			table.insert(items, name)
		end
	end
	p:SetAttribute("Items", table.concat(items, ","))
	p:SetAttribute("Wet", st.wet)
	p:SetAttribute("Exposed", st.exposed)
	p:SetAttribute("NearFire", st.nearFireId ~= nil)
	p:SetAttribute("Lost", st.lost)
	p:SetAttribute("Zone", st.zone)
	p:SetAttribute("Stage", st.progress.stage)
	p:SetAttribute("Checkpoint", st.checkpoint)
	p:SetAttribute("TentDeadline", if st.tentDeadline == math.huge then 0 else st.tentDeadline)
	p:SetAttribute("TentExited", st.tentExited)
	p:SetAttribute("StartTime", st.startTime)
	p:SetAttribute("Finished", st.finished)
	p:SetAttribute("Flashlight", st.flashlightOn)
	p:SetAttribute("Sprinting", st.sprinting)
	p:SetAttribute("God", st.god)
	p:SetAttribute("RouteS", math.floor(st.s))
end

-------------------------------------------------------------------------------
-- Этапы
-------------------------------------------------------------------------------
function PlayerService.event(st: PState, kind: string, arg: any?)
	if Progress.event(st.progress, kind, arg) then
		PlayerService.send(st.player, { t = "stage", stage = st.progress.stage })
	end
end

-------------------------------------------------------------------------------
-- Персонаж
-------------------------------------------------------------------------------
local function rootOf(player: Player): BasePart?
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local ch = player.Character
	return ch and ch:FindFirstChildOfClass("Humanoid")
end

function PlayerService.ensureFlashlight(st: PState)
	local ch = st.player.Character
	local head = ch and ch:FindFirstChild("Head")
	if not head then
		return
	end
	local light = head:FindFirstChild("Flashlight") :: SpotLight?
	if not light and st.inv.items.Flashlight then
		light = Make("SpotLight", {
			Name = "Flashlight",
			Face = Enum.NormalId.Front,
			Angle = 55,
			Range = 55,
			Brightness = 4,
			Color = Color3.fromRGB(255, 244, 220),
			Shadows = true,
			Enabled = false,
			Parent = head,
		})
	end
	if light then
		light.Enabled = st.flashlightOn and st.inv.battery > 0
	end
end

function PlayerService.spawnPosition(st: PState): Vector3?
	local cp = Level.Checkpoints[st.checkpoint]
	if not cp or not cp.fire then
		return nil -- палатка: стандартный SpawnLocation
	end
	local m = World.fires[cp.id]
	return m and m:GetAttribute("SpawnPos")
end

function PlayerService.teleport(player: Player, pos: Vector3)
	local ch = player.Character
	if not ch then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(pos, 3)
	end)
	ch:PivotTo(CFrame.new(pos))
	local root = rootOf(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function onCharacter(st: PState, character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	hum.MaxSlopeAngle = 50
	hum.WalkSpeed = Config.Speed.Walk
	task.defer(function()
		local pos = PlayerService.spawnPosition(st)
		if pos then
			PlayerService.teleport(st.player, pos)
		end
		PlayerService.ensureFlashlight(st)
	end)
end

-------------------------------------------------------------------------------
-- Потеря сознания
-------------------------------------------------------------------------------
function PlayerService.faint(st: PState)
	if st.fainting then
		return
	end
	st.fainting = true
	st.faints += 1
	PlayerService.send(st.player, { t = "faint" })
	task.delay(2.6, function()
		if PlayerService.states[st.player] ~= st then
			return
		end
		local pos = PlayerService.spawnPosition(st)
		if not pos then
			-- ещё не дошёл до первого костра: приходит в себя у палатки
			pos = World.tentExitPoint()
		end
		PlayerService.teleport(st.player, pos)
		st.heat = Config.Heat.RespawnHeat
		st.wet = false
		st.fainting = false
		PlayerService.send(st.player, { t = "wake" })
	end)
end

-------------------------------------------------------------------------------
-- Финиш
-------------------------------------------------------------------------------
function PlayerService.finish(st: PState)
	if st.finished then
		return
	end
	st.finished = true
	st.finishTime = now() - st.startTime
	if not PlayerService.bestTime or st.finishTime < PlayerService.bestTime then
		PlayerService.bestTime = st.finishTime
	end
	PlayerService.event(st, "finish")
	local items = {}
	for _, name in Level.Items do
		if st.inv.items[name] then
			table.insert(items, name)
		end
	end
	PlayerService.send(st.player, {
		t = "finish",
		time = st.finishTime,
		faints = st.faints,
		fires = st.firesLit,
		items = items,
		best = PlayerService.bestTime,
	})
end

-------------------------------------------------------------------------------
-- Палатка
-------------------------------------------------------------------------------
function PlayerService.startTentTimer(st: PState)
	if st.introDone then
		return
	end
	st.introDone = true
	st.tentDeadline = now() + Config.Tent.SecondsToEscape
	st.startTime = now()
end

function PlayerService.canTakeItems(st: PState): boolean
	return not st.tentExited and now() < st.tentDeadline + 0.5
end

-------------------------------------------------------------------------------
-- Тик
-------------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function characters(): { Instance }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

-- Укрыт ли игрок от ветра: два луча навстречу ветру, параллельно склону
-- (иначе горизонтальный луч упирается в сам склон и «укрывает» всегда)
function PlayerService.isSheltered(pos: Vector3, t: number): boolean
	local wx, wz = Storm.windDir(t)
	local len = Config.Storm.ShelterRayLength
	local tx, tz = pos.X - wx * len, pos.Z - wz * len
	local above = pos.Y - Heightmap.height(pos.X, pos.Z)
	local targetGround = Heightmap.height(tx, tz)
	for _, h in { 0.8, 2.2 } do
		local from = pos + Vector3.new(0, h, 0)
		local to = Vector3.new(tx, targetGround + above + h, tz)
		local hit = workspace:Raycast(from, to - from, rayParams)
		if hit then
			return true
		end
	end
	return false
end

function PlayerService.tickPlayer(st: PState, dt: number, t: number)
	local player = st.player
	local root = rootOf(player)
	local hum = humanoidOf(player)
	if not root or not hum or hum.Health <= 0 then
		return
	end
	local pos = root.Position

	-- где игрок на маршруте
	local s, d = RouteMath.nearest(Level.Route, pos.X, pos.Z)
	st.s = s
	local zp = Heightmap.zoneParams(s)
	local zone = Level.zoneAt(s)

	-- палатка
	local inTent = World.inTent(pos)
	if not st.tentExited then
		if not inTent and World.tent and World.tent:GetAttribute("Cut") then
			st.tentExited = true
			PlayerService.event(st, "tentExit")
		elseif st.introDone and now() > st.tentDeadline then
			st.tentExited = true
			if World.tent then
				Props.cutTent(World.tent)
			end
			if inTent then
				PlayerService.teleport(player, World.tentExitPoint())
			end
			PlayerService.toast(player, "ui.tentBuried")
			PlayerService.event(st, "tentExit")
		end
	end

	-- зона
	if st.tentExited and zone.id ~= st.zone then
		st.zone = zone.id
		PlayerService.event(st, "zone", zone.id)
	end
	if st.tentExited and not st.zonesSeen[zone.id] then
		st.zonesSeen[zone.id] = true
		PlayerService.send(player, { t = "zone", id = zone.id })
	end

	-- костры
	local nearId = nil
	for id, m in World.fires do
		if m:GetAttribute("Lit") then
			local flame = m:FindFirstChild("Flame") :: BasePart
			if flame then
				local fp = flame.Position
				if (Vector3.new(fp.X, 0, fp.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < Config.Heat.FireRadius and math.abs(fp.Y - pos.Y) < 12 then
					nearId = id
					local idx = m:GetAttribute("Checkpoint")
					if idx and idx > st.checkpoint then
						st.checkpoint = idx
						PlayerService.toast(player, "ui.checkpoint")
					end
				end
			end
		end
	end
	if nearId == "cedar" then
		st.wasNearCedar = true
		PlayerService.event(st, "nearFire", "cedar")
	elseif st.wasNearCedar and nearId == nil then
		st.wasNearCedar = false
		PlayerService.event(st, "leftFire", "cedar")
	end
	st.nearFireId = nearId

	local inHut = World.inHut(pos)

	-- укрытие (каждый тик дорого не считать: луч — дешёвая операция, но не чаще 5 Гц)
	rayParams.FilterDescendantsInstances = characters()
	st.exposed = not inTent and not inHut and not PlayerService.isSheltered(pos, t)

	-- сбился с пути
	local lostAt = zp.halfWidth + Config.Route.LostWarning
	local wasLost = st.lost
	st.lost = st.tentExited and d > lostAt
	if st.lost and not wasLost then
		PlayerService.toast(player, "ui.lost")
	end
	if st.tentExited and d > lostAt + Config.Route.HardLimitExtra then
		local px, pz = RouteMath.pointAt(Level.Route, s)
		PlayerService.teleport(player, Vector3.new(px, Heightmap.height(px, pz) + 4, pz))
		PlayerService.toast(player, "ui.returned")
	end

	-- вода в ручье
	local smp = Heightmap.sample(pos.X, pos.Z)
	if smp.carve > 1.2 then
		local wl = Heightmap.waterLevel(smp.s)
		if wl and pos.Y - 2.6 < wl then
			if not st.wet then
				PlayerService.send(player, { t = "fellIn" })
			end
			st.wet = true
			st.wetUntil = t + Config.Wet.Duration
			st.dryTimer = 0
		end
	end
	if st.wet then
		if nearId or inHut then
			st.dryTimer += dt
			if st.dryTimer >= Config.Wet.DryAtFire then
				st.wet = false
				PlayerService.toast(player, "ui.dried")
			end
		elseif t > st.wetUntil then
			st.wet = false
		end
	end

	-- бег
	-- MoveDirection не реплицируется на сервер — смотрим на скорость
	local v = root.AssemblyLinearVelocity
	local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 3
	local S = Config.Stamina
	if st.exhausted and st.stamina >= S.MinToStart then
		st.exhausted = false
	end
	st.sprinting = st.sprintHeld and moving and not st.exhausted and st.stamina > 0
	if st.sprinting then
		st.stamina = math.max(0, st.stamina - S.SprintDrain * dt)
		if st.stamina <= 0 then
			st.exhausted = true
		end
	else
		st.stamina = math.min(S.Max, st.stamina + S.Regen * dt)
	end

	-- тепло
	if not st.fainting and not st.finished then
		local ctx: Heat.Context = {
			cold = zp.cold,
			wind = zp.wind,
			storm = Storm.intensity(t),
			exposed = st.exposed,
			wet = st.wet,
			jacket = st.inv.items.Jacket == true,
			boots = st.inv.items.Boots == true,
			sprinting = st.sprinting,
			nearFire = nearId ~= nil,
			inHut = inHut,
			lost = st.lost,
			frozen = st.god or inTent or not st.tentExited,
		}
		st.heat = Heat.step(st.heat, Heat.rate(ctx), dt)
		if st.heat <= 0 then
			PlayerService.faint(st)
		end
	end

	-- фонарь
	if st.flashlightOn then
		if not Inventory.drainBattery(st.inv, dt) then
			st.flashlightOn = false
			PlayerService.toast(player, "ui.flashDead")
		end
	end
	PlayerService.ensureFlashlight(st)

	-- скорость
	local offTrail = d > Config.Speed.TrailHalfWidth and zone.id ~= "ravine" and st.tentExited
	local base = if st.sprinting then Config.Speed.Sprint else Config.Speed.Walk
	local walk = base * Heat.speedMultiplier(st.heat, st.wet, offTrail, st.inv.items.Boots == true)
	if st.fainting then
		walk = 0
	end
	hum.WalkSpeed = walk

	-- финиш
	if inHut and not st.finished then
		PlayerService.finish(st)
	end
end

function PlayerService.reset(st: PState)
	local player = st.player
	local fresh = newState(player)
	PlayerService.states[player] = fresh
	local head = player.Character and player.Character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	if light then
		light:Destroy()
	end
	player:LoadCharacter()
	PlayerService.publish(fresh)
	PlayerService.send(player, { t = "reset" })
	return fresh
end

-------------------------------------------------------------------------------
-- Запуск
-------------------------------------------------------------------------------
function PlayerService.start()
	local function added(player: Player)
		local st = newState(player)
		PlayerService.states[player] = st
		PlayerService.publish(st)
		player.CharacterAdded:Connect(function(ch)
			local cur = PlayerService.states[player]
			if cur then
				onCharacter(cur, ch)
			end
		end)
		if player.Character then
			onCharacter(st, player.Character)
		end
		-- если клиент не прислал introDone (например, ошибка в интро) — таймер всё равно пойдёт
		task.delay(40, function()
			local cur = PlayerService.states[player]
			if cur and not cur.introDone then
				PlayerService.startTentTimer(cur)
			end
		end)
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		PlayerService.states[p] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.TickSeconds)
			local tnow = os.clock()
			local dt = math.min(tnow - last, 0.5)
			last = tnow
			local t = now()
			for _, st in PlayerService.states do
				local ok, err = pcall(PlayerService.tickPlayer, st, dt, t)
				if not ok then
					warn("[PlayerService] tick error:", err)
				end
				PlayerService.publish(st)
			end
		end
	end)
end

return PlayerService
