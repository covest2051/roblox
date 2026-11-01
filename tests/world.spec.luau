-- Рельеф и маршрут: проходимость, площадки, ручей
return function(t)
	local Level = t.shared("Level")
	local Heightmap = t.shared("Heightmap")
	local RouteMath = t.shared("RouteMath")

	local MAX_SLOPE_DEG = 32 -- персонаж может до 50°, но тропа должна быть пологой

	t.test("route length gives a 10-15 minute level", function()
		local L = Level.Route.length
		t.ok(L > 2600 and L < 3400, "route length " .. L)
	end)

	t.test("trail is walkable: slope along the route stays gentle", function()
		local step = 3
		local worst, worstS = 0, 0
		local s = 0
		while s < Level.Route.length - step do
			local x1, z1 = RouteMath.pointAt(Level.Route, s)
			local x2, z2 = RouteMath.pointAt(Level.Route, s + step)
			local a, b = Heightmap.sample(x1, z1), Heightmap.sample(x2, z2)
			local deg = math.deg(math.atan(math.abs(b.height - a.height) / step))
			-- берега ручья — намеренная ступенька, её перекрывают лёд и брёвна
			if a.carve < 0.2 and b.carve < 0.2 and deg > worst then
				worst, worstS = deg, s
			end
			s += step
		end
		t.ok(worst < MAX_SLOPE_DEG, string.format("steepest %.1f° at s=%.0f", worst, worstS))
	end)

	t.test("trail band (±6 studs) is walkable across", function()
		local s = 0
		while s < Level.Route.length do
			for _, off in { -6, 6 } do
				local x0, z0 = Level.placeAt(s, 0)
				local x1, z1 = Level.placeAt(s, off)
				local h0, h1 = Heightmap.height(x0, z0), Heightmap.height(x1, z1)
				local deg = math.deg(math.atan(math.abs(h1 - h0) / 6))
				local inCreek = Heightmap.sample(x1, z1).carve > 0.2 or Heightmap.sample(x0, z0).carve > 0.2
				if not inCreek then
					t.ok(deg < 40, string.format("cross slope %.1f° at s=%.0f off=%d", deg, s, off))
				end
			end
			s += 10
		end
	end)

	t.test("ravine walls are too steep to climb (forces creek crossings)", function()
		local r0, r1 = Level.ravineRange()
		local s = r0 + 120
		while s < r1 - 120 do
			for _, sign in { -1, 1 } do
				local xa, za = Level.placeAt(s, sign * 18)
				local xb, zb = Level.placeAt(s, sign * 28)
				local deg = math.deg(math.atan((Heightmap.height(xb, zb) - Heightmap.height(xa, za)) / 10))
				t.ok(deg > 52, string.format("ravine wall only %.1f° at s=%.0f", deg, s))
			end
			s += 40
		end
	end)

	t.test("pads are flat (tent, fires, hut)", function()
		for _, pad in Level.pads() do
			local r = pad.r * 0.45
			for a = 0, 7 do
				local x = pad.x + math.cos(a * math.pi / 4) * r
				local z = pad.z + math.sin(a * math.pi / 4) * r
				t.near(Heightmap.height(x, z), pad.y, 0.6, "pad " .. pad.id)
			end
		end
	end)

	t.test("fire pads are not in the creek", function()
		for _, pad in Level.pads() do
			local smp = Heightmap.sample(pad.x, pad.z)
			for ds = -pad.r, pad.r, 2 do
				local co = Level.creekOffset(smp.s + ds)
				if co then
					local gap = math.abs(smp.offset - co)
					t.ok(gap > Level.Creek.HalfWidth + 2 + math.sqrt(math.max(0, pad.r ^ 2 - ds ^ 2)), "pad " .. pad.id .. " hits creek")
				end
			end
		end
	end)

	t.test("creek crosses the trail several times", function()
		local Layout = t.shared("Layout")
		local n = #Layout.creekCrossings()
		t.ok(n >= 3 and n <= 6, "crossings " .. n)
	end)

	t.test("no terrain seams near the route (outside the ravine)", function()
		local minX, maxX, minZ, maxZ = Heightmap.bounds(150)
		local worst, wx, wz = 0, 0, 0
		for x = minX, maxX, 12 do
			for z = minZ, maxZ, 12 do
				local a = Heightmap.sample(x, z)
				if a.d < 140 and a.zone ~= "ravine" and a.carve < 0.1 then
					for _, o in { { 4, 0 }, { 0, 4 } } do
						local b = Heightmap.sample(x + o[1], z + o[2])
						if b.zone ~= "ravine" and b.carve < 0.1 then
							local dh = math.abs(a.height - b.height)
							if dh > worst then
								worst, wx, wz = dh, x, z
							end
						end
					end
				end
			end
		end
		-- 5 studs на 4 по горизонтали ≈ 51°: круче — уже «обрыв-шов»
		t.ok(worst < 5, string.format("seam %.2f at %d,%d", worst, wx, wz))
	end)

	t.test("zones are ordered and cover the route", function()
		local prev = -1
		for _, z in Level.Zones do
			t.ok(z.startS > prev, "zone order " .. z.id)
			prev = z.startS
		end
		t.eq(Level.zoneAt(0).id, "slope")
		t.eq(Level.zoneAt(Level.Route.length).id, "clearing")
	end)
end
