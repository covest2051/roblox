--[[
	Heat — модель тепла тела. Чистые функции, баланс — в Config.Heat.
	Положительная скорость = согреваешься, отрицательная = мёрзнешь.
]]

local Config = require(script.Parent.Config)

local Heat = {}

export type Context = {
	cold: number, -- множитель холода зоны
	wind: number, -- доля ветра зоны 0..1
	storm: number, -- сила бурана сейчас 0..1
	exposed: boolean, -- нет укрытия с наветренной стороны
	wet: boolean,
	jacket: boolean,
	boots: boolean,
	sprinting: boolean,
	nearFire: boolean,
	inHut: boolean,
	lost: boolean, -- сбился с пути
	frozen: boolean?, -- режим «бог» в отладке
}

function Heat.drain(ctx: Context): number
	local H = Config.Heat
	local d = H.BaseDrain * ctx.cold
	if ctx.exposed then
		d += H.WindDrain * ctx.wind * ctx.storm
	end
	if ctx.wet then
		d *= H.WetMultiplier
	end
	if ctx.jacket then
		d *= H.JacketMultiplier
	end
	if not ctx.boots then
		d /= H.BootsMultiplier
	end
	if ctx.sprinting then
		d *= H.SprintMultiplier
	end
	if ctx.lost then
		d *= Config.Route.LostDrainMultiplier
	end
	return d
end

-- Итоговая скорость изменения тепла, ед/с
function Heat.rate(ctx: Context): number
	if ctx.frozen then
		return 0
	end
	if ctx.inHut then
		return Config.Heat.HutWarmth
	end
	if ctx.nearFire then
		return Config.Heat.FireWarmth
	end
	return -Heat.drain(ctx)
end

function Heat.step(heat: number, rate: number, dt: number): number
	return math.clamp(heat + rate * dt, 0, Config.Heat.Max)
end

-- Мгновенная потеря от порыва
function Heat.gustPenalty(ctx: Context): number
	if not ctx.exposed or ctx.inHut or ctx.nearFire or ctx.frozen then
		return 0
	end
	local p = Config.Heat.GustPenalty * ctx.wind
	if ctx.jacket then
		p *= Config.Heat.JacketMultiplier
	end
	return p
end

-- Множитель скорости ходьбы
function Heat.speedMultiplier(heat: number, wet: boolean, offTrail: boolean, boots: boolean): number
	local S = Config.Speed
	local m = 1
	if offTrail then
		m *= if boots then S.DeepSnowBootsMultiplier else S.DeepSnowMultiplier
	end
	if heat < Config.Heat.ColdThreshold then
		m *= S.ColdMultiplier
	end
	if wet then
		m *= S.WetMultiplier
	end
	return m
end

return Heat
