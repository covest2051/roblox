--[[
	Config — все «ручки» баланса в одном месте.
	Меняй числа здесь, логика их подхватит. Тесты (tests/) проверяют,
	что уровень остаётся проходимым при любом наборе вещей.
]]

local Config = {}

-- Общее
Config.TickSeconds = 0.2 -- шаг серверной симуляции состояния игроков
Config.Seed = 1959 -- сид генерации ландшафта и деревьев

-- Тепло (0..100)
Config.Heat = {
	Max = 100,
	Start = 100,
	BaseDrain = 0.155, -- холод в безветрии, ед/с
	WindDrain = 0.55, -- дополнительно при полном ветре и открытом месте, ед/с
	WetMultiplier = 1.8, -- мокрая одежда
	JacketMultiplier = 0.62, -- пуховка
	BootsMultiplier = 0.85, -- ботинки (без них мёрзнешь сильнее)
	SprintMultiplier = 0.85, -- движение греет
	FireWarmth = 7.0, -- ед/с у костра
	HutWarmth = 12.0, -- ед/с в избе
	FireRadius = 16, -- studs
	GustPenalty = 3.5, -- мгновенная потеря при порыве на открытом месте
	RespawnHeat = 60, -- после потери сознания
	ColdThreshold = 30, -- ниже — замедление и визуальные эффекты
	CriticalThreshold = 15,
}

-- Выносливость (бег)
Config.Stamina = {
	Max = 100,
	SprintDrain = 14, -- ед/с
	Regen = 9, -- ед/с
	MinToStart = 15,
}

-- Скорость (studs/s)
Config.Speed = {
	Walk = 11,
	Sprint = 17,
	DeepSnowMultiplier = 0.72, -- вне тропы
	DeepSnowBootsMultiplier = 0.86,
	ColdMultiplier = 0.85,
	WetMultiplier = 0.8,
	TrailHalfWidth = 10, -- ширина «тропы» вокруг маршрута
}

-- Предметы из палатки
Config.Tent = {
	MaxItems = 3,
	SecondsToEscape = 35, -- потом палатку заваливает
}

Config.Items = {
	Flashlight = { BatteryMax = 100, BatteryDrain = 0.12 }, -- ~14 мин
	Matches = { Count = 3 },
	Thermos = { Sips = 2, SipHeat = 30 },
}

Config.Wood = {
	Max = 4,
	ForFire = 3,
	PileRespawn = 45,
}

Config.Wet = {
	Duration = 90, -- секунд, если не сушиться у огня
	DryAtFire = 6, -- секунд у огня, чтобы высохнуть
}

-- Ветер и порывы
Config.Storm = {
	WarningSeconds = 2.0,
	GustDuration = 2.5,
	GustPush = 26, -- скорость толчка, studs/s
	ShelterRayLength = 18,
}

-- Отклонение от маршрута
Config.Route = {
	LostWarning = 45, -- дальше этого от осевой — «ты сбился с пути», холод сильнее
	LostDrainMultiplier = 1.4,
	HardLimitExtra = 60, -- ещё дальше — возвращаем на тропу
}

-- Звуки. rbxasset:// — встроенные в клиент Roblox, работают без загрузки.
-- Можно заменить на rbxassetid://<id> из Creator Store (см. docs/LOCAL_SESSION.md).
Config.Sounds = {
	WindLoop = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.35, Speed = 0.45 },
	Gust = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.8, Speed = 0.7 },
	IceBreak = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.9, Speed = 0.8 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.7, Speed = 1.0 },
	Pickup = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Speed = 0.6 },
	Bell = { Id = "", Volume = 1, Speed = 1 }, -- нет встроенного колокола; подсказка-стрелка работает и без звука
	Fire = { Id = "", Volume = 0.6, Speed = 1 },
	TentTear = { Id = "", Volume = 0.8, Speed = 1 },
}

-- Отладка (работает только в Studio)
Config.Debug = {
	AutoSelfTest = true, -- самотест при старте сервера в Studio
	ShowPanel = true, -- панель телепортов в Studio
}

return Config
