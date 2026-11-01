--[[
	World — собирает уровень и хранит ссылки на важные объекты,
	чтобы остальные серверные модули не искали их по дереву.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Make)
local Layout = require(Shared.Layout)
local Config = require(Shared.Config)
local Rng = require(Shared.Rng)

local WorldBuilder = require(script.Parent.WorldBuilder)
local Props = require(script.Parent.Props)

local World = {
	ready = false,
	folder = nil :: Folder?,
	tent = nil :: Model?,
	tentCf = nil :: CFrame?,
	tentSize = nil :: { L: number, W: number, H: number }?,
	tentSide = 1,
	fires = {} :: { [string]: Model },
	piles = {} :: { [number]: Model },
	hut = nil :: Model?,
	finishZone = nil :: BasePart?,
	bell = nil :: BasePart?,
	buildSeconds = 0,
}

function World.build(onProgress: ((string, number) -> ())?)
	local t0 = os.clock()
	local function progress(stage: string, p: number)
		if onProgress then
			onProgress(stage, p)
		end
	end

	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	local folder = Make("Folder", { Name = "World", Parent = workspace })
	World.folder = folder

	if World.isTerrainBaked() then
		print("[Pereval] using pre-baked terrain")
		progress("terrain", 1)
	else
		World.bakeTerrain(function(p)
			progress("terrain", p)
		end)
	end
	progress("props", 0)

	local tent, _, cf, side, size = Props.buildTent(folder)
	World.tent, World.tentCf, World.tentSide, World.tentSize = tent, cf, side, size

	Props.buildCamp(folder)
	Props.buildPoles(folder)
	progress("props", 0.2)
	Props.buildCedar(folder)
	local _, fires = Props.buildFires(folder)
	World.fires = fires
	local piles = Props.buildWoodPiles(folder)
	for _, m in piles:GetChildren() do
		local id = m.PrimaryPart and m.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
		local pileId = id and id:GetAttribute("PileId")
		if pileId then
			World.piles[pileId] = m
		end
	end
	Props.buildIce(folder)
	progress("props", 0.4)
	local hut, finish, bell = Props.buildHut(folder)
	World.hut, World.finishZone, World.bell = hut, finish, bell
	Props.buildTrees(folder)
	progress("props", 1)

	World.buildSeconds = os.clock() - t0
	World.ready = true
	workspace:SetAttribute("WorldReady", true)
end

-- Ключ «запечённого» рельефа: если совпадает, генерацию можно пропустить
local function bakeKey(): string
	return string.format("v%d-seed%d", Config.TerrainVersion, Config.Seed)
end

function World.isTerrainBaked(): boolean
	return workspace.Terrain:GetAttribute("BakedTerrain") == bakeKey()
end

--[[
	Сгенерировать Terrain. Можно вызвать в Studio в режиме редактирования
	(Command Bar или Studio MCP execute_luau, datamodel Edit):
	  require(game.ServerScriptService.Server.World).bakeTerrain()
	и сохранить place — тогда при запуске генерация пропускается.
]]
function World.bakeTerrain(onProgress: ((number) -> ())?)
	WorldBuilder.buildTerrain(onProgress)
	WorldBuilder.buildOutcrops(Layout.outcrops(), Rng.new(Config.Seed + 3))
	WorldBuilder.buryTentEntrance(Props.tentEntrance())
	workspace.Terrain:SetAttribute("BakedTerrain", bakeKey())
end

-- Внутри палатки?
function World.inTent(pos: Vector3): boolean
	if not World.tentCf then
		return false
	end
	local lp = World.tentCf:PointToObjectSpace(pos)
	local s = World.tentSize
	return math.abs(lp.X) < s.W / 2 and math.abs(lp.Z) < s.L / 2 and lp.Y < s.H + 2 and lp.Y > -3
end

-- Точка сразу снаружи разрезанной стенки
function World.tentExitPoint(): Vector3
	local s = World.tentSize
	return World.tentCf * Vector3.new(World.tentSide * (s.W / 2 + 4), 3.5, 0)
end

function World.inHut(pos: Vector3): boolean
	local z = World.finishZone
	if not z then
		return false
	end
	local lp = z.CFrame:PointToObjectSpace(pos)
	return math.abs(lp.X) < z.Size.X / 2 and math.abs(lp.Y) < z.Size.Y / 2 + 1 and math.abs(lp.Z) < z.Size.Z / 2
end

return World
