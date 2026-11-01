--[[
	Strings — все тексты игры на русском и английском.
	Язык выбирается по локали игрока (ru* → русский, иначе английский).
	Подстановки: {n}, {max}, {t}, {list}.
	Тест tests/strings.spec.luau проверяет, что ключи совпадают в обоих языках.
]]

local Strings = {}

Strings.ru = {
	-- интерфейс
	["ui.title"] = "ПЕРЕВАЛ",
	["ui.subtitle"] = "Северный Урал · февраль 2026",
	["ui.heat"] = "Тепло",
	["ui.stamina"] = "Силы",
	["ui.battery"] = "Фонарь",
	["ui.wood"] = "Хворост {n}/{max}",
	["ui.matches"] = "Спички: {n}",
	["ui.sips"] = "Термос: {n}",
	["ui.tentTimer"] = "Палатку заваливает: {n}",
	["ui.itemsPicked"] = "Вещи: {n}/{max}",
	["ui.gust"] = "Порыв ветра! В укрытие!",
	["ui.sheltered"] = "Укрытие",
	["ui.exposed"] = "На ветру",
	["ui.nearFire"] = "У огня",
	["ui.lost"] = "Ты сбился с пути. Вернись к тропе.",
	["ui.returned"] = "Ты едва не сорвался со склона и вернулся к тропе.",
	["ui.wet"] = "Мокрая одежда",
	["ui.cold"] = "Ты замерзаешь…",
	["ui.faint"] = "Ты теряешь сознание…",
	["ui.faintWake"] = "…кто-то из ребят дотащил тебя до огня.",
	["ui.skip"] = "Пропустить — [Пробел]",
	["ui.controls"] = "[Shift] бег   [F] фонарь   [Q] термос   [E] действие",
	["ui.restart"] = "Пройти ещё раз",
	["ui.bell"] = "колокол",
	["ui.noFlashlight"] = "Фонаря нет",
	["ui.flashDead"] = "Батарейки сели",
	["ui.full"] = "Больше не унести",
	["ui.needWood"] = "Нужно {n} хвороста",
	["ui.needMatch"] = "Нет спичек",
	["ui.thermosEmpty"] = "Термос пуст",
	["ui.noThermos"] = "Термоса нет",
	["ui.sip"] = "Горячий чай. Теплее.",
	["ui.stashFound"] = "В ящике нашлась одна спичка.",
	["ui.stashEmpty"] = "Ящик пуст.",
	["ui.labazMatch"] = "В лабазе нашлась спичка.",
	["ui.fireLit"] = "Огонь занялся!",
	["ui.dried"] = "Одежда просохла.",
	["ui.iceCrack"] = "Лёд трещит!",
	["ui.fellIn"] = "Ты провалился в ручей!",
	["ui.checkpoint"] = "Здесь можно отогреться",
	["ui.tentBuried"] = "Палатку завалило. Что взял — то взял.",
	["ui.lang"] = "Язык: RU",

	-- вещи
	["item.Boots"] = "Ботинки",
	["item.Jacket"] = "Пуховка",
	["item.Flashlight"] = "Фонарь",
	["item.Matches"] = "Спички",
	["item.Thermos"] = "Термос",
	["itemdesc.Boots"] = "Меньше мёрзнешь, легче идти по глубокому снегу",
	["itemdesc.Jacket"] = "Ветер и холод забирают тепло медленнее",
	["itemdesc.Flashlight"] = "Видно вешки и затесы. [F]",
	["itemdesc.Matches"] = "3 спички — разжечь костёр",
	["itemdesc.Thermos"] = "2 глотка горячего чая. [Q]",

	-- подсказки взаимодействия
	["prompt.take"] = "Взять",
	["prompt.cut"] = "Разрезать",
	["prompt.cutObject"] = "Стенка палатки",
	["prompt.wood"] = "Собрать",
	["prompt.woodObject"] = "Хворост",
	["prompt.light"] = "Разжечь",
	["prompt.fireObject"] = "Кострище",
	["prompt.read"] = "Прочитать",
	["prompt.noteObject"] = "Записка",
	["prompt.search"] = "Открыть",
	["prompt.stashObject"] = "Ящик",
	["prompt.plaqueObject"] = "Памятный знак",
	["prompt.signObject"] = "Табличка",
	["prompt.dryWood"] = "Взять дрова",
	["prompt.dryWoodObject"] = "Лабаз",

	-- цели
	["obj.tent"] = "Возьми 3 вещи и разрежь стенку палатки",
	["obj.slope"] = "Спускайся к лесу вдоль вешек. От порывов прячься за камнями",
	["obj.cedar"] = "Согрейся у костра под кедром",
	["obj.wood"] = "Собери хворост ({n}/{max}) по пути к стоянке",
	["obj.fire"] = "Разожги костёр на стоянке",
	["obj.ravine"] = "Спустись в овраг и иди вдоль ручья. Лёд тонкий!",
	["obj.hut"] = "Иди на звук колокола к избе",
	["obj.done"] = "Ты дошёл",

	-- сюжет
	["story.intro.1"] = "Северный Урал. Склон горы Холатчахль.",
	["story.intro.2"] = "Нас пятеро. Мы идём маршрутом группы 1959 года — в память о девяти туристах, которые не вернулись с этого склона.",
	["story.intro.3"] = "К ночи начался буран.",
	["story.tent.1"] = "Растяжки сорвало. Вход завалило снегом!",
	["story.tent.2"] = "Ребята уже снаружи — кричат, что уходят вниз, к лесу.",
	["story.tent.3"] = "Успею взять только три вещи. Потом — резать стенку ножом.",
	["story.slope.1"] = "Где все?! Внизу мелькнули фонари… Они идут к лесу.",
	["story.slope.2"] = "Ветер с перевала сбивает с ног. За камнями он не достаёт.",
	["story.cedar.1"] = "Кедр. Ребята развели здесь костёр — и ушли дальше.",
	["story.cedar.2"] = "На стволе записка.",
	["note.cedar"] = "Мы пошли к избе лесника — через лес и вниз по оврагу, вдоль ручья. На стоянке в лесу есть кострище, наберёшь хвороста — грейся. Не задерживайся! — Женя",
	["story.wood.1"] = "Сухие ветки под елями. Нужно три охапки на костёр.",
	["story.fire.1"] = "Хвороста хватит. Теперь — на стоянку.",
	["story.lights.1"] = "Ветер вдруг стих…",
	["story.lights.2"] = "Над горами поднимается огненный шар. Небо светится оранжевым.",
	["story.lights.3"] = "Через минуту всё снова затянуло снегом.",
	["story.ravine.1"] = "Овраг. Здесь тише. Ручей подо льдом — тёмный лёд тонкий.",
	["story.ravine.2"] = "Через ручей можно пройти по брёвнам.",
	["story.labaz"] = "Охотничий лабаз. Внутри сухие дрова!",
	["story.hut.1"] = "Ничего не видно… Слышишь? Колокол!",
	["story.hut.2"] = "Ребята звонят, чтобы я нашёл избу.",
	["story.stash"] = "На стоянке ящик с аварийным запасом.",
	["story.firstFire"] = "Без огня я долго не протяну.",

	-- таблички
	["sign.pass"] = "ПЕРЕВАЛ ДЯТЛОВА",
	["sign.passSub"] = "DYATLOV PASS",
	["sign.memorial"] = "Памяти туристов, погибших на этом склоне в феврале 1959 года",
	["sign.labaz"] = "ЛАБАЗ",
	["sign.hut"] = "ИЗБА",

	-- финал
	["end.title"] = "Мы дошли. Все пятеро.",
	["end.radio"] = "По рации: «Ночью был пуск ракеты с Плесецка — свечение видели над всем Северным Уралом».",
	["end.memorial"] = "В феврале 1959 года на этом склоне погибли девять туристов. Что именно произошло той ночью, до сих пор спорят.",
	["end.fiction"] = "События игры вымышлены. Мы помним группу 1959 года.",
	["end.time"] = "Время: {t}",
	["end.faints"] = "Потерь сознания: {n}",
	["end.fires"] = "Разожжено костров: {n}",
	["end.items"] = "Вещи: {list}",
	["end.best"] = "Лучшее время на сервере: {t}",
}

Strings.en = {
	["ui.title"] = "THE PASS",
	["ui.subtitle"] = "Northern Urals · February 2026",
	["ui.heat"] = "Warmth",
	["ui.stamina"] = "Stamina",
	["ui.battery"] = "Flashlight",
	["ui.wood"] = "Firewood {n}/{max}",
	["ui.matches"] = "Matches: {n}",
	["ui.sips"] = "Thermos: {n}",
	["ui.tentTimer"] = "The tent is collapsing: {n}",
	["ui.itemsPicked"] = "Items: {n}/{max}",
	["ui.gust"] = "Gust incoming! Take cover!",
	["ui.sheltered"] = "Sheltered",
	["ui.exposed"] = "Exposed",
	["ui.nearFire"] = "By the fire",
	["ui.lost"] = "You've lost the trail. Head back.",
	["ui.returned"] = "You nearly slipped off the slope and made it back to the trail.",
	["ui.wet"] = "Wet clothes",
	["ui.cold"] = "You're freezing…",
	["ui.faint"] = "You're losing consciousness…",
	["ui.faintWake"] = "…one of the group dragged you to the fire.",
	["ui.skip"] = "Skip — [Space]",
	["ui.controls"] = "[Shift] run   [F] flashlight   [Q] thermos   [E] interact",
	["ui.restart"] = "Play again",
	["ui.bell"] = "bell",
	["ui.noFlashlight"] = "No flashlight",
	["ui.flashDead"] = "Batteries are dead",
	["ui.full"] = "Can't carry more",
	["ui.needWood"] = "Need {n} firewood",
	["ui.needMatch"] = "No matches",
	["ui.thermosEmpty"] = "Thermos is empty",
	["ui.noThermos"] = "No thermos",
	["ui.sip"] = "Hot tea. Warmer.",
	["ui.stashFound"] = "There's a single match in the box.",
	["ui.stashEmpty"] = "The box is empty.",
	["ui.labazMatch"] = "There's a match in the cache.",
	["ui.fireLit"] = "The fire caught!",
	["ui.dried"] = "Your clothes are dry.",
	["ui.iceCrack"] = "The ice is cracking!",
	["ui.fellIn"] = "You fell through into the creek!",
	["ui.checkpoint"] = "You can warm up here",
	["ui.tentBuried"] = "The tent is buried. What you took is all you have.",
	["ui.lang"] = "Language: EN",

	["item.Boots"] = "Boots",
	["item.Jacket"] = "Down jacket",
	["item.Flashlight"] = "Flashlight",
	["item.Matches"] = "Matches",
	["item.Thermos"] = "Thermos",
	["itemdesc.Boots"] = "Lose less warmth, wade through deep snow faster",
	["itemdesc.Jacket"] = "Wind and cold drain warmth slower",
	["itemdesc.Flashlight"] = "Lights up trail poles and blazes. [F]",
	["itemdesc.Matches"] = "3 matches to light a fire",
	["itemdesc.Thermos"] = "2 sips of hot tea. [Q]",

	["prompt.take"] = "Take",
	["prompt.cut"] = "Cut open",
	["prompt.cutObject"] = "Tent wall",
	["prompt.wood"] = "Gather",
	["prompt.woodObject"] = "Firewood",
	["prompt.light"] = "Light",
	["prompt.fireObject"] = "Fire pit",
	["prompt.read"] = "Read",
	["prompt.noteObject"] = "Note",
	["prompt.search"] = "Open",
	["prompt.stashObject"] = "Box",
	["prompt.plaqueObject"] = "Memorial",
	["prompt.signObject"] = "Sign",
	["prompt.dryWood"] = "Take wood",
	["prompt.dryWoodObject"] = "Hunters' cache",

	["obj.tent"] = "Take 3 items and cut through the tent wall",
	["obj.slope"] = "Head down to the forest along the poles. Hide behind rocks from gusts",
	["obj.cedar"] = "Warm up by the fire under the cedar",
	["obj.wood"] = "Gather firewood ({n}/{max}) on the way to the camp",
	["obj.fire"] = "Light the fire at the forest camp",
	["obj.ravine"] = "Go down into the ravine and follow the creek. The ice is thin!",
	["obj.hut"] = "Follow the sound of the bell to the hut",
	["obj.done"] = "You made it",

	["story.intro.1"] = "Northern Urals. The slope of Kholat Syakhl.",
	["story.intro.2"] = "There are five of us, following the 1959 route in memory of the nine hikers who never came back from this slope.",
	["story.intro.3"] = "By nightfall, a blizzard hit.",
	["story.tent.1"] = "The guy lines snapped. The entrance is buried in snow!",
	["story.tent.2"] = "The others are already outside, shouting that they're heading down to the forest.",
	["story.tent.3"] = "I can only grab three things. Then cut through the wall with a knife.",
	["story.slope.1"] = "Where is everyone?! Flashlights flicker below… They're heading for the forest.",
	["story.slope.2"] = "The wind off the pass knocks you over. It can't reach you behind the rocks.",
	["story.cedar.1"] = "The cedar. The others made a fire here and moved on.",
	["story.cedar.2"] = "There's a note on the trunk.",
	["note.cedar"] = "We went to the forester's hut, through the forest and down the ravine along the creek. There's a fire pit at the forest camp; gather firewood and warm up. Don't linger! — Zhenya",
	["story.wood.1"] = "Dry branches under the spruces. I need three armfuls for a fire.",
	["story.fire.1"] = "That's enough firewood. Now to the camp.",
	["story.lights.1"] = "The wind suddenly dies down…",
	["story.lights.2"] = "A ball of fire rises over the mountains. The sky glows orange.",
	["story.lights.3"] = "A minute later the snow closes in again.",
	["story.ravine.1"] = "The ravine. It's quieter here. The creek is under the ice; dark ice is thin.",
	["story.ravine.2"] = "You can cross the creek on the logs.",
	["story.labaz"] = "A hunters' cache. Dry firewood inside!",
	["story.hut.1"] = "I can't see a thing… Listen! A bell!",
	["story.hut.2"] = "The others are ringing it so I can find the hut.",
	["story.stash"] = "There's an emergency box at the camp.",
	["story.firstFire"] = "I won't last long without a fire.",

	["sign.pass"] = "ПЕРЕВАЛ ДЯТЛОВА",
	["sign.passSub"] = "DYATLOV PASS",
	["sign.memorial"] = "In memory of the hikers who died on this slope in February 1959",
	["sign.labaz"] = "CACHE",
	["sign.hut"] = "HUT",

	["end.title"] = "We made it. All five of us.",
	["end.radio"] = "On the radio: \"There was a rocket launch from Plesetsk last night — the glow was seen all over the Northern Urals.\"",
	["end.memorial"] = "In February 1959, nine hikers died on this slope. What exactly happened that night is still debated.",
	["end.fiction"] = "The events of this game are fictional. We remember the 1959 group.",
	["end.time"] = "Time: {t}",
	["end.faints"] = "Times you passed out: {n}",
	["end.fires"] = "Fires lit: {n}",
	["end.items"] = "Items: {list}",
	["end.best"] = "Best time on this server: {t}",
}

function Strings.langFromLocale(localeId: string?): string
	if localeId and string.sub(string.lower(localeId), 1, 2) == "ru" then
		return "ru"
	end
	return "en"
end

function Strings.get(lang: string, key: string, vars: { [string]: any }?): string
	local tbl = Strings[lang] or Strings.en
	local s = tbl[key] or Strings.en[key] or key
	if vars then
		s = string.gsub(s, "{(%w+)}", function(name)
			local v = vars[name]
			return if v ~= nil then tostring(v) else "{" .. name .. "}"
		end)
	end
	return s
end

-- Формат времени m:ss
function Strings.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Strings
