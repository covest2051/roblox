--[[
	Rng — детерминированный генератор, одинаковый в Roblox и в Lune
	(в Lune нет Roblox-класса Random). Нужен, чтобы лес/камни/лёд
	генерировались одинаково на каждом сервере и в тестах.
]]

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

local MOD = 2147483647 -- 2^31 - 1
local MUL = 48271

function Rng.new(seed: number): Rng
	local s = math.floor(math.abs(seed)) % MOD
	if s == 0 then
		s = 1
	end
	return setmetatable({ state = s }, Rng)
end

-- [0, 1)
function Rng.next(self: Rng): number
	self.state = (self.state * MUL) % MOD
	return (self.state - 1) / (MOD - 1)
end

function Rng.range(self: Rng, a: number, b: number): number
	return a + (b - a) * self:next()
end

function Rng.int(self: Rng, a: number, b: number): number
	return math.min(b, a + math.floor((b - a + 1) * self:next()))
end

-- Хэш точки сетки → [0,1). Без состояния: удобно для «есть ли дерево в клетке».
function Rng.hash2(x: number, z: number, seed: number): number
	local h = (x * 374761393 + z * 668265263 + seed * 362437) % MOD
	h = (h * MUL) % MOD
	h = (h * MUL + 12345) % MOD
	return h / MOD
end

return Rng
