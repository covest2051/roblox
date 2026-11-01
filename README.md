# Перевал (The Pass)

Короткая игра для Roblox про выживание в буране: один законченный уровень на 10–15 минут.
Февраль 2026 года, Северный Урал. Ты — участник памятной группы, которая идёт маршрутом туристов 1959 года по склону Холатчахль. Ночью палатку заваливает снегом. Нужно выбрать 3 вещи из 5, разрезать стенку и дойти до избы, куда ушли остальные. По дороге — каменные гряды, кедр, лес, овраг с ручьём.

Дизайн-документ: [`docs/DESIGN.md`](docs/DESIGN.md).

Всё в игре построено кодом: рельеф (Terrain), деревья, палатка, изба, интерфейс. Сторонних моделей и платных ассетов нет.

---

## Как запустить в Roblox Studio (Windows)

### Один раз
1. Установи [Roblox Studio](https://create.roblox.com) и войди в аккаунт.
2. Установи [Rokit](https://github.com/rojo-rbx/rokit). В PowerShell:
   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```
   Затем **открой новое окно PowerShell** (или перезагрузись), чтобы обновился PATH.
3. В папке репозитория:
   ```powershell
   git fetch origin
   git checkout claude/roblox-game-concepts-setup-tfp5ox
   rokit install          # rojo, lune, selene, stylua нужных версий
   rojo plugin install    # плагин Rojo в Studio
   ```
   Если Rokit спросит, доверять ли инструментам, отвечай `y`.

### Вариант А: просто поиграть (без синхронизации)
```powershell
git pull
rojo build -o game.rbxl
```
Открой `game.rbxl` в Studio (File → Open from File) и нажми **Play** (F5).
Первые 5–15 секунд строится мир, на экране «ПЕРЕВАЛ» и проценты.

### Вариант Б: живая синхронизация кода (для правок)
1. Собери и открой `game.rbxl`, как в варианте А.
2. В PowerShell в папке репозитория запусти `rojo serve` и не закрывай окно.
3. В Studio: вкладка **Plugins → Rojo → Connect**.

Теперь каждый `git pull` сразу попадает в открытую Studio.

### Если что-то не так
- **Нет мира, только серое небо.** Открой View → Output и найди красные строки.
- **Самотест.** В Studio при старте сервера он запускается сам. В Output ищи строки `[SELFTEST]` и итог `[SELFTEST] RESULT N/N passed`.
- **Отладочная панель.** Кнопка **DBG** справа сверху, есть только в Studio:
  - телепорт к любому костру и к избе;
  - бессмертие, все вещи, «замёрзнуть», «намокнуть»;
  - самотест, рестарт, переключение языка RU/EN.

## Управление
| Клавиша | Действие |
|---|---|
| WASD / стик | идти |
| Shift | бег (тратит силы, чуть греет) |
| F | фонарь (если взял) |
| Q | глоток из термоса (если взял) |
| E (удерживать) | взять, разрезать, собрать хворост, разжечь костёр, прочитать |
| Пробел | пропустить интро |

На телефоне — экранные кнопки «Бег», «Фонарь», «Чай».

---

## Для разработки

### Структура
```
default.project.json    Rojo: как папки ложатся в дерево игры
rokit.toml              версии инструментов
src/shared/             ReplicatedStorage.Shared — чистая логика, общая для сервера и клиента
  Config.luau           все числа баланса
  Level.luau            маршрут, зоны, чекпоинты, ручей, изба
  Heightmap.luau        рельеф (используется генератором и тестами)
  Layout.luau           где стоят деревья, вешки, хворост, лёд, брёвна
  Heat/Storm/Inventory/Progress.luau  механики
  Strings.luau          все тексты RU/EN
src/server/             ServerScriptService.Server
  init.server.luau      точка входа: строит мир, запускает сервисы
  WorldBuilder.luau     Terrain через WriteVoxels
  Props.luau            объекты из примитивов
  PlayerService.luau    тепло, силы, укрытие, костры, финиш
  Interactions/Hazards/Actions.luau   подсказки, порывы и лёд, запросы клиента
  SelfTest.luau         проверки внутри движка
src/client/             StarterPlayerScripts.Client — HUD, атмосфера, управление, интро/финал
tests/                  тесты Lune (логика, рельеф, баланс, раскладка)
tests/engine/           прогон собранного place на «заглушке» движка
scripts/                проверка собранного place, проверка API, check.sh
```

### Проверки
```bash
lune run tests/run.luau                    # юнит-тесты логики и баланса
rojo build -o build/game.rbxl
lune run scripts/validate_place.luau       # все скрипты компилируются, require находятся
lune run tests/engine/server_sim.luau      # бот проходит уровень на заглушке движка (1–3 мин)
selene src && stylua --check src tests     # линтер и формат
```
Или всё сразу: `./scripts/check.sh` (Git Bash). `selene` использует `roblox.yml` из репозитория, интернет не нужен.

### Где менять баланс
Всё в `src/shared/Config.luau`. После правки запусти `lune run tests/run.luau`. Тест `balance.spec.luau` проверяет две вещи:
- уровень проходим с любым набором вещей;
- склон опасен для беспечного игрока.
