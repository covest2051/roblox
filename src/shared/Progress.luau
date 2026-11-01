--[[
	Progress — сюжетные этапы и текущая цель игрока.
	Этапы идут только вперёд (кроме полного рестарта).
]]

local Config = require(script.Parent.Config)

local Progress = {}

Progress.Stages = { "tent", "slope", "cedar", "wood", "fire", "ravine", "hut", "done" }

local RANK = {}
for i, s in Progress.Stages do
	RANK[s] = i
end
Progress.Rank = RANK

export type State = { stage: string }

function Progress.new(): State
	return { stage = "tent" }
end

-- Ключ строки цели для этапа (Strings)
function Progress.objectiveKey(stage: string): string
	return "obj." .. stage
end

local function advance(state: State, to: string): boolean
	if RANK[to] > RANK[state.stage] then
		state.stage = to
		return true
	end
	return false
end

--[[
	События:
	  tentExit
	  zone(zoneId)
	  nearFire(cpId)
	  note(noteId)
	  leftFire(cpId)
	  wood(count)
	  fireLit(cpId)
	  finish
	Возвращает true, если этап изменился.
]]
function Progress.event(state: State, kind: string, arg: any?): boolean
	local st = state.stage
	if kind == "tentExit" then
		return advance(state, "slope")
	elseif kind == "nearFire" and arg == "cedar" then
		return advance(state, "cedar")
	elseif (kind == "note" and arg == "cedar") or (kind == "leftFire" and arg == "cedar") then
		if RANK[st] >= RANK.cedar then
			return advance(state, "wood")
		end
		return false
	elseif kind == "wood" then
		if st == "wood" and (arg :: number) >= Config.Wood.ForFire then
			return advance(state, "fire")
		end
		return false
	elseif kind == "fireLit" and arg == "camp" then
		return advance(state, "ravine")
	elseif kind == "zone" then
		if arg == "forest" then
			-- пришёл в лес, минуя костёр под кедром
			if RANK[st] < RANK.cedar then
				return advance(state, "cedar")
			end
		elseif arg == "ravine" then
			return advance(state, "ravine")
		elseif arg == "clearing" then
			return advance(state, "hut")
		end
		return false
	elseif kind == "finish" then
		return advance(state, "done")
	end
	return false
end

return Progress
