--[[
	Storm — буран: сила, направление ветра, расписание порывов.
	Ветер дует с перевала вниз по склону (+Z), медленно поворачивая.
]]

local Rng = require(script.Parent.Rng)

local Storm = {}

local BASE_ANGLE = math.atan2(1, 0.15) -- направление в плоскости XZ (угол от оси X)

-- Сила бурана 0..1 (медленно «дышит»)
function Storm.intensity(t: number): number
	return 0.88 + 0.12 * math.sin(t / 23)
end

-- Направление, КУДА дует ветер (единичный вектор XZ)
function Storm.windDir(t: number): (number, number)
	local a = BASE_ANGLE + 0.35 * math.sin(t / 41) + 0.12 * math.sin(t / 7.3)
	return math.cos(a), math.sin(a)
end

-- Через сколько секунд следующий порыв в зоне
function Storm.nextGustDelay(zone, rng: Rng.Rng): number
	return rng:range(zone.gust[1], zone.gust[2])
end

-- Расписание порывов для зоны: { {warnAt, at}, ... } на отрезке [t0, t1)
function Storm.schedule(zone, t0: number, t1: number, seed: number, warning: number)
	local rng = Rng.new(seed)
	local out = {}
	local t = t0 + Storm.nextGustDelay(zone, rng)
	while t < t1 do
		table.insert(out, { warnAt = t - warning, at = t })
		t += Storm.nextGustDelay(zone, rng)
	end
	return out
end

return Storm
