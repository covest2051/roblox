--[[
	Выгружает карту уровня в JSON для scripts/render_map.py:
	высоты (сетка 8 studs), маршрут, деревья, вешки, костры, лёд, хворост.
	lune run scripts/export_map.luau build/map.json
]]
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Loader = require("../tests/lib/Loader")

local Level = Loader.shared("Level")
local Heightmap = Loader.shared("Heightmap")
local Layout = Loader.shared("Layout")

local minX, maxX, minZ, maxZ = Heightmap.bounds(200)
local step = 8
local rows = {}
local z = minZ
while z <= maxZ do
	local row = {}
	local x = minX
	while x <= maxX do
		local smp = Heightmap.sample(x, z)
		table.insert(row, { math.floor(smp.height * 10) / 10, if smp.carve > 0.5 then 1 else 0 })
		x += step
	end
	table.insert(rows, row)
	z += step
end

local function pts(list, extra)
	local out = {}
	for _, p in list do
		local o = { x = p.x, z = p.z }
		if extra then
			extra(o, p)
		end
		table.insert(out, o)
	end
	return out
end

local data = {
	bounds = { minX, maxX, minZ, maxZ },
	step = step,
	heights = rows,
	route = Level.Waypoints,
	zones = (function()
		local out = {}
		for _, zn in Level.Zones do
			local x, zz = Level.placeAt(zn.startS, 0)
			table.insert(out, { id = zn.id, x = x, z = zz })
		end
		return out
	end)(),
	trees = pts(Layout.trees(), function(o, p)
		o.blaze = p.blaze
	end),
	poles = pts(Layout.poles(), function(o, p)
		o.toppled = p.toppled
	end),
	fires = pts(Layout.fires(), function(o, p)
		o.id = p.id
	end),
	piles = pts(Layout.woodPiles()),
	ice = pts(Layout.ice(), function(o, p)
		o.thin = p.thin
	end),
	logs = pts(Layout.logs()),
	outcrops = pts(Layout.outcrops(), function(o, p)
		o.size = p.size
	end),
	hut = Level.hutFrame(),
	cedar = Layout.cedar(),
}
fs.writeFile(process.args[1] or "build/map.json", serde.encode("json", data))
print("map exported")
