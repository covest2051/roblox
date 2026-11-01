--[[
	Баланс: грубая симуляция прохождения каждого отрезка между кострами
	для всех 10 наборов из 3 вещей. «Аккуратный» игрок прячется от половины
	порывов и стоит на ветру 70% времени; «беспечный» — всегда на ветру.
]]
return function(t)
	local Config = t.shared("Config")
	local Heat = t.shared("Heat")
	local Level = t.shared("Level")
	local Heightmap = t.shared("Heightmap")
	local RouteMath = t.shared("RouteMath")

	local ITEMS = Level.Items
	local combos = {}
	for a = 1, #ITEMS do
		for b = a + 1, #ITEMS do
			for c = b + 1, #ITEMS do
				table.insert(combos, { [ITEMS[a]] = true, [ITEMS[b]] = true, [ITEMS[c]] = true })
			end
		end
	end

	local function cpS(id)
		return Level.wpS(Level.checkpointById(id).wp)
	end

	-- extraSeconds: время на сбор хвороста/обход, проведённое в этой зоне
	local function simulate(items, s0, s1, opts)
		local dt = 0.5
		local heat = 100
		local minHeat = heat
		local s = s0
		local speed = Config.Speed.Walk * opts.speedFactor
		local time = 0
		local nextGust = 0
		local wetUntil = opts.wetAt and -1 or nil
		local extra = opts.extraSeconds or 0
		while s < s1 or extra > 0 do
			local x, z = RouteMath.pointAt(Level.Route, s)
			local p = Heightmap.zoneParams(s)
			local zone = Level.zoneAt(s)
			local exposed = (time % 10) < 10 * opts.exposedShare
			if opts.wetAt and s >= opts.wetAt and wetUntil == -1 then
				wetUntil = time + Config.Wet.Duration
			end
			local c = {
				cold = p.cold, wind = p.wind, storm = 0.94, exposed = exposed,
				wet = wetUntil ~= nil and wetUntil > time, jacket = items.Jacket == true, boots = items.Boots == true,
				sprinting = false, nearFire = false, inHut = false, lost = false,
			}
			heat = Heat.step(heat, Heat.rate(c), dt)
			if time >= nextGust then
				if opts.gustShare >= 1 or ((nextGust * 7) % 1) < opts.gustShare then
					heat -= Heat.gustPenalty(c)
				end
				nextGust += (zone.gust[1] + zone.gust[2]) / 2
			end
			-- глоток из термоса, когда холодно
			if items.Thermos and heat < 25 and (opts.sips or 0) < Config.Items.Thermos.Sips then
				opts.sips = (opts.sips or 0) + 1
				heat += Config.Items.Thermos.SipHeat
			end
			minHeat = math.min(minHeat, heat)
			if s < s1 then
				s += speed * Heat.speedMultiplier(heat, c.wet, false, c.boots) * dt
			else
				extra -= dt
			end
			time += dt
		end
		return minHeat, time
	end

	local CAREFUL = { speedFactor = 0.85, exposedShare = 0.7, gustShare = 0.5 }
	local CARELESS = { speedFactor = 0.95, exposedShare = 1.0, gustShare = 1.0 }

	local function with(base, over)
		local o = table.clone(base)
		for k, v in over do
			o[k] = v
		end
		return o
	end

	local segments = {
		{ name = "tent→cedar", s0 = 0, s1 = cpS("cedar"), extra = 0 },
		{ name = "cedar→camp", s0 = cpS("cedar"), s1 = cpS("camp"), extra = 40 },
		{ name = "camp→labaz", s0 = cpS("camp"), s1 = cpS("labaz"), extra = 0, wet = true },
		{ name = "labaz→hut", s0 = cpS("labaz"), s1 = Level.Route.length, extra = 15 },
	}

	for _, seg in segments do
		t.test("balance: careful player survives " .. seg.name .. " with any 3 items", function()
			for _, items in combos do
				local opts = with(CAREFUL, { extraSeconds = seg.extra, wetAt = seg.wet and (seg.s0 + 300) or nil })
				local minHeat = simulate(items, seg.s0, seg.s1, opts)
				local names = {}
				for k in items do
					table.insert(names, k)
				end
				t.ok(minHeat > 8, string.format("%s: min heat %.1f with %s", seg.name, minHeat, table.concat(names, "+")))
			end
		end)
	end

	t.test("balance: the slope is a real threat for a careless player without jacket", function()
		local items = { Boots = true, Flashlight = true, Matches = true }
		local minHeat = simulate(items, 0, cpS("cedar"), table.clone(CARELESS))
		t.ok(minHeat < 5, string.format("careless min heat %.1f — slope is too easy", minHeat))
	end)

	t.test("balance: pure walking time is 4-7 minutes", function()
		local _, time = simulate({ Jacket = true, Boots = true, Thermos = true }, 0, Level.Route.length,
			{ speedFactor = 0.85, exposedShare = 0, gustShare = 0 })
		t.ok(time > 240 and time < 420, "walk time " .. time)
	end)
end
