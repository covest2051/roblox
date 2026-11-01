-- Модули логики: тепло, буран, инвентарь, этапы, строки
return function(t)
	local Config = t.shared("Config")
	local Heat = t.shared("Heat")
	local Storm = t.shared("Storm")
	local Inventory = t.shared("Inventory")
	local Progress = t.shared("Progress")
	local Strings = t.shared("Strings")
	local Rng = t.shared("Rng")

	local function ctx(over)
		local c = {
			cold = 1, wind = 1, storm = 1, exposed = true, wet = false, jacket = false, boots = true,
			sprinting = false, nearFire = false, inHut = false, lost = false,
		}
		for k, v in over or {} do
			c[k] = v
		end
		return c
	end

	t.test("heat: exposed drains more than sheltered", function()
		t.lt(Heat.drain(ctx({ exposed = false })), Heat.drain(ctx()))
	end)
	t.test("heat: jacket and boots help, wet hurts", function()
		local base = Heat.drain(ctx())
		t.lt(Heat.drain(ctx({ jacket = true })), base)
		t.lt(base, Heat.drain(ctx({ boots = false })))
		t.lt(base, Heat.drain(ctx({ wet = true })))
	end)
	t.test("heat: fire and hut warm up, god mode freezes", function()
		t.ok(Heat.rate(ctx({ nearFire = true })) > 0)
		t.ok(Heat.rate(ctx({ inHut = true })) > Heat.rate(ctx({ nearFire = true })))
		t.eq(Heat.rate(ctx({ frozen = true })), 0)
	end)
	t.test("heat: step clamps to [0, max]", function()
		t.eq(Heat.step(5, -10, 1), 0)
		t.eq(Heat.step(95, 10, 1), Config.Heat.Max)
	end)
	t.test("heat: no gust penalty in shelter", function()
		t.eq(Heat.gustPenalty(ctx({ exposed = false })), 0)
		t.ok(Heat.gustPenalty(ctx()) > 0)
	end)
	t.test("heat: speed multipliers", function()
		t.eq(Heat.speedMultiplier(100, false, false, true), 1)
		t.lt(Heat.speedMultiplier(100, false, true, false), Heat.speedMultiplier(100, false, true, true))
		t.lt(Heat.speedMultiplier(10, false, false, true), 1)
	end)

	t.test("storm: wind dir is unit and blows downslope (+Z)", function()
		for i = 0, 300, 7 do
			local x, z = Storm.windDir(i)
			t.near(x * x + z * z, 1, 1e-9)
			t.ok(z > 0.6, "wind should blow down the slope, z=" .. z)
		end
	end)
	t.test("storm: intensity in (0.7, 1]", function()
		for i = 0, 500, 3 do
			local v = Storm.intensity(i)
			t.ok(v > 0.7 and v <= 1.0001)
		end
	end)
	t.test("storm: gust schedule respects zone interval and warning", function()
		local zone = { gust = { 9, 15 } }
		local sched = Storm.schedule(zone, 0, 600, 42, 2)
		t.ok(#sched >= 600 / 15 - 1 and #sched <= 600 / 9 + 1, "count " .. #sched)
		local prev = 0
		for _, g in sched do
			t.near(g.at - g.warnAt, 2, 1e-9)
			t.ok(g.at - prev >= 9 - 1e-9 and g.at - prev <= 15 + 1e-9)
			prev = g.at
		end
	end)

	t.test("rng: deterministic and in [0,1)", function()
		local a, b = Rng.new(5), Rng.new(5)
		for _ = 1, 1000 do
			local x = a:next()
			t.eq(x, b:next())
			t.ok(x >= 0 and x < 1)
		end
		for i = -50, 50 do
			local h = Rng.hash2(i, -i * 3, 1959)
			t.ok(h >= 0 and h < 1)
		end
	end)

	t.test("inventory: max 3 distinct items", function()
		local inv = Inventory.new()
		t.ok(Inventory.take(inv, "Boots"))
		local ok, why = Inventory.take(inv, "Boots")
		t.eq(ok, false)
		t.eq(why, "already")
		t.ok(Inventory.take(inv, "Matches"))
		t.ok(Inventory.take(inv, "Thermos"))
		ok, why = Inventory.take(inv, "Jacket")
		t.eq(why, "full")
		t.eq(inv.matches, Config.Items.Matches.Count)
		t.eq(inv.sips, Config.Items.Thermos.Sips)
	end)
	t.test("inventory: fire needs wood and a match", function()
		local inv = Inventory.new()
		t.eq(select(2, Inventory.canLight(inv)), "need_wood")
		for _ = 1, Config.Wood.ForFire do
			Inventory.addWood(inv)
		end
		t.eq(select(2, Inventory.canLight(inv)), "need_match")
		Inventory.addMatches(inv, 1)
		t.ok(Inventory.light(inv))
		t.eq(inv.wood, 0)
		t.eq(inv.matches, 0)
	end)
	t.test("inventory: wood cap, thermos, battery", function()
		local inv = Inventory.new()
		for _ = 1, 10 do
			Inventory.addWood(inv)
		end
		t.eq(inv.wood, Config.Wood.Max)
		t.eq(Inventory.sip(inv), 0)
		Inventory.take(inv, "Thermos")
		t.eq(Inventory.sip(inv), Config.Items.Thermos.SipHeat)
		t.eq(Inventory.drainBattery(inv, 1), false)
		Inventory.take(inv, "Flashlight")
		t.eq(Inventory.drainBattery(inv, 1), true)
		t.ok(inv.battery < Config.Items.Flashlight.BatteryMax)
		t.eq(Inventory.drainBattery(inv, 1e6), false)
	end)

	t.test("progress: happy path", function()
		local p = Progress.new()
		t.eq(p.stage, "tent")
		t.ok(Progress.event(p, "tentExit"))
		t.eq(p.stage, "slope")
		t.ok(Progress.event(p, "nearFire", "cedar"))
		t.ok(Progress.event(p, "note", "cedar"))
		t.eq(p.stage, "wood")
		t.eq(Progress.event(p, "wood", 2), false)
		t.ok(Progress.event(p, "wood", 3))
		t.eq(p.stage, "fire")
		t.ok(Progress.event(p, "fireLit", "camp"))
		t.eq(p.stage, "ravine")
		t.ok(Progress.event(p, "zone", "clearing"))
		t.eq(p.stage, "hut")
		t.ok(Progress.event(p, "finish"))
		t.eq(p.stage, "done")
	end)
	t.test("progress: never goes back, skipping is allowed", function()
		local p = Progress.new()
		Progress.event(p, "tentExit")
		t.ok(Progress.event(p, "zone", "ravine"))
		t.eq(p.stage, "ravine")
		t.eq(Progress.event(p, "nearFire", "cedar"), false)
		t.eq(Progress.event(p, "zone", "forest"), false)
		t.eq(p.stage, "ravine")
	end)
	t.test("progress: every stage has an objective string", function()
		for _, st in Progress.Stages do
			local key = Progress.objectiveKey(st)
			t.ok(Strings.ru[key] and Strings.en[key], "missing " .. key)
		end
	end)

	t.test("strings: same keys in ru and en, none empty", function()
		for k, v in Strings.ru do
			t.ok(Strings.en[k] ~= nil, "en missing " .. k)
			t.ok(#v > 0, "ru empty " .. k)
		end
		for k, v in Strings.en do
			t.ok(Strings.ru[k] ~= nil, "ru missing " .. k)
			t.ok(#v > 0, "en empty " .. k)
		end
	end)
	t.test("strings: placeholders match between languages", function()
		for k, v in Strings.ru do
			local a, b = {}, {}
			for name in string.gmatch(v, "{(%w+)}") do
				a[name] = true
			end
			for name in string.gmatch(Strings.en[k], "{(%w+)}") do
				b[name] = true
			end
			for name in a do
				t.ok(b[name], k .. " en lacks {" .. name .. "}")
			end
			for name in b do
				t.ok(a[name], k .. " ru lacks {" .. name .. "}")
			end
		end
	end)
	t.test("strings: format and locale", function()
		t.eq(Strings.get("ru", "ui.wood", { n = 2, max = 4 }), "Хворост 2/4")
		t.eq(Strings.get("en", "nope.key"), "nope.key")
		t.eq(Strings.langFromLocale("ru-ru"), "ru")
		t.eq(Strings.langFromLocale("en-us"), "en")
		t.eq(Strings.langFromLocale(nil), "en")
		t.eq(Strings.formatTime(754), "12:34")
	end)
	t.test("strings: every item has name and description", function()
		local Level = t.shared("Level")
		for _, it in Level.Items do
			for _, lang in { "ru", "en" } do
				t.ok(Strings[lang]["item." .. it], lang .. " item." .. it)
				t.ok(Strings[lang]["itemdesc." .. it], lang .. " itemdesc." .. it)
			end
		end
	end)
end
