-- Раскладка объектов мира
return function(t)
	local Level = t.shared("Level")
	local Layout = t.shared("Layout")
	local Heightmap = t.shared("Heightmap")
	local RouteMath = t.shared("RouteMath")

	t.test("layout: poles mark the slope", function()
		local poles = Layout.poles()
		t.ok(#poles >= 25, "poles " .. #poles)
		local standing = 0
		for _, p in poles do
			if not p.toppled then
				standing += 1
			end
			t.eq(Level.zoneAt(p.s).id, "slope")
		end
		t.ok(standing / #poles > 0.65, "too many toppled poles")
	end)

	t.test("layout: no gap > 75 studs between standing poles", function()
		local prev = 0
		for _, p in Layout.poles() do
			if not p.toppled then
				t.ok(p.s - prev <= 75, "gap at s=" .. p.s)
				prev = p.s
			end
		end
	end)

	t.test("layout: trees stay off the trail and out of the creek", function()
		local trees = Layout.trees()
		t.ok(#trees > 300 and #trees < 1600, "trees " .. #trees)
		for _, tr in trees do
			local smp = Heightmap.sample(tr.x, tr.z)
			t.ok(smp.d > 7.5, string.format("tree on trail at %.0f,%.0f", tr.x, tr.z))
			t.ok(smp.carve < 0.1, "tree in creek")
		end
	end)

	t.test("layout: blazed trees line the forest trail", function()
		local n = 0
		for _, tr in Layout.trees() do
			if tr.blaze then
				n += 1
			end
		end
		t.ok(n >= 15, "blazes " .. n)
	end)

	t.test("layout: enough firewood, near the camp too, never in the creek", function()
		local piles = Layout.woodPiles()
		t.ok(#piles >= 20, "piles " .. #piles)
		local camp
		for _, f in Layout.fires() do
			if f.id == "camp" then
				camp = f
			end
		end
		local near = 0
		for _, p in piles do
			if math.sqrt((p.x - camp.x) ^ 2 + (p.z - camp.z) ^ 2) < 45 then
				near += 1
			end
			t.ok(Heightmap.sample(p.x, p.z).carve < 0.1, "pile in creek " .. p.id)
		end
		t.ok(near >= 3, "piles near camp " .. near)
	end)

	t.test("layout: ice covers the creek continuously", function()
		local ice = Layout.ice()
		t.ok(#ice > 50, "ice " .. #ice)
		local thin = 0
		for i, seg in ice do
			if seg.thin then
				thin += 1
			end
			if i > 1 then
				local p = ice[i - 1]
				local gap = math.sqrt((seg.x - p.x) ^ 2 + (seg.z - p.z) ^ 2)
				t.ok(gap <= seg.len + 0.5, "ice gap " .. gap)
			end
		end
		t.ok(thin > #ice * 0.2 and thin < #ice * 0.6, "thin share " .. thin / #ice)
	end)

	t.test("layout: a log bridge at every creek crossing", function()
		local logs = Layout.logs()
		t.eq(#logs, #Layout.creekCrossings())
		for _, l in logs do
			t.near(l.dirX * l.dirX + l.dirZ * l.dirZ, 1, 1e-6)
		end
	end)

	t.test("layout: outcrops are on the slope and close to the trail", function()
		for _, o in Layout.outcrops() do
			t.eq(Level.zoneAt(o.s).id, "slope")
			local _, d = RouteMath.nearest(Level.Route, o.x, o.z)
			t.ok(d < 30 and d > 9, "outcrop distance " .. d)
		end
	end)

	t.test("layout: max gap between shelters on the slope < 160 studs", function()
		local prev = 0
		for _, o in Layout.outcrops() do
			t.ok(o.s - prev < 160, "gap before outcrop at " .. o.s)
			prev = o.s
		end
		t.ok(Level.wpS(Level.checkpointById("cedar").wp) - prev < 160)
	end)

	t.test("layout: camp props exist", function()
		local camp = Layout.camp()
		t.ok(camp.sign and camp.memorial and camp.tent)
		local cedar = Layout.cedar()
		t.ok(cedar.y > 0)
	end)
end
