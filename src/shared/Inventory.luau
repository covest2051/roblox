--[[
	Inventory — правила вещей игрока. Чистые функции над таблицей.
	Сервер хранит инвентарь и публикует его в атрибуты Player.
]]

local Config = require(script.Parent.Config)

local Inventory = {}

export type Inv = {
	items: { [string]: boolean },
	taken: number,
	matches: number,
	sips: number,
	battery: number,
	wood: number,
}

local VALID = { Boots = true, Jacket = true, Flashlight = true, Matches = true, Thermos = true }

function Inventory.new(): Inv
	return { items = {}, taken = 0, matches = 0, sips = 0, battery = 0, wood = 0 }
end

function Inventory.has(inv: Inv, item: string): boolean
	return inv.items[item] == true
end

-- Взять вещь из палатки. Возвращает ok, причина
function Inventory.take(inv: Inv, item: string): (boolean, string?)
	if not VALID[item] then
		return false, "invalid"
	end
	if inv.items[item] then
		return false, "already"
	end
	if inv.taken >= Config.Tent.MaxItems then
		return false, "full"
	end
	inv.items[item] = true
	inv.taken += 1
	if item == "Matches" then
		inv.matches += Config.Items.Matches.Count
	elseif item == "Thermos" then
		inv.sips += Config.Items.Thermos.Sips
	elseif item == "Flashlight" then
		inv.battery = Config.Items.Flashlight.BatteryMax
	end
	return true, nil
end

function Inventory.addWood(inv: Inv, n: number?): (boolean, string?)
	if inv.wood >= Config.Wood.Max then
		return false, "full"
	end
	inv.wood = math.min(Config.Wood.Max, inv.wood + (n or 1))
	return true, nil
end

function Inventory.addMatches(inv: Inv, n: number)
	inv.matches += n
end

function Inventory.canLight(inv: Inv): (boolean, string?)
	if inv.wood < Config.Wood.ForFire then
		return false, "need_wood"
	end
	if inv.matches < 1 then
		return false, "need_match"
	end
	return true, nil
end

function Inventory.light(inv: Inv): (boolean, string?)
	local ok, reason = Inventory.canLight(inv)
	if not ok then
		return false, reason
	end
	inv.wood -= Config.Wood.ForFire
	inv.matches -= 1
	return true, nil
end

-- Глоток из термоса: сколько тепла даёт (0 — нечего пить)
function Inventory.sip(inv: Inv): number
	if inv.sips <= 0 then
		return 0
	end
	inv.sips -= 1
	return Config.Items.Thermos.SipHeat
end

-- Разряд фонаря; возвращает true, если фонарь ещё светит
function Inventory.drainBattery(inv: Inv, dt: number): boolean
	if not inv.items.Flashlight then
		return false
	end
	inv.battery = math.max(0, inv.battery - Config.Items.Flashlight.BatteryDrain * dt)
	return inv.battery > 0
end

return Inventory
