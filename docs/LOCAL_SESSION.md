# Локальная сессия Claude Code + Studio MCP

Этот файл — готовый сценарий для локального Claude Code на Windows, подключённого к Roblox Studio через встроенный MCP-сервер. Задача: потратить минимум лимитов. Claude не исследует проект с нуля, а сразу запускает игру, читает самотест и чинит только то, что видно в движке.

> **Сначала попробуй без Claude.** Ручной плейтест по [`PLAYTEST.md`](PLAYTEST.md) лимитов не тратит. Если до 4 ноября остаются промо-кредиты, присылай найденное (текст из Output, описание проблемы) в облачную сессию — там правки бесплатны для тебя.

## Подготовка (один раз)
1. Studio → **Assistant** → **…** → **Manage MCP Servers** → включить **Enable Studio as MCP server**.
2. Там же **Quick connect** → включить **Claude Code**. Если Claude Code нет в списке, выполни:
   ```powershell
   claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
   ```
3. Собери place и открой его в Studio:
   ```powershell
   rojo build -o game.rbxl
   ```
   Затем запусти `rojo serve` и нажми Plugins → Rojo → Connect.
4. В папке репозитория запусти `claude`.

## Промпт для старта (скопируй целиком)

```
Проект — Roblox-игра «Перевал», Rojo-проект в этом репозитории.
Studio открыта и синхронизирована через `rojo serve`, Studio MCP подключён.

Правила экономии:
- Не читай весь репозиторий: структура описана в README.md, механики — в docs/DESIGN.md.
- Правь ТОЛЬКО файлы src/**, а не скрипты в Studio через multi_edit: Rojo синхронизирует сам.
- screen_capture — только если я прошу или баг без картинки не понять.
- После каждой правки: `lune run tests/run.luau`.

Задача:
1. start_stop_play (запустить Play), подожди ~25 с, get_console_output.
2. Найди строки [SELFTEST] и красные ошибки. Пришли короткую сводку: что FAIL/WARN, какие ошибки.
3. Исправь ошибки по одной: правка → стоп/Play → Output.
4. Когда Output чистый, пройди ключевые точки через отладочные команды.
   execute_luau (datamodel Server), по одной команде за раз:
     workspace:SetAttribute("DebugCommand", "cp 2")   -- кедр
     workspace:SetAttribute("DebugCommand", "cp 3")   -- стоянка
     workspace:SetAttribute("DebugCommand", "s 2000") -- ручей в овраге
     workspace:SetAttribute("DebugCommand", "cp 5")   -- дверь избы
   После каждой — get_console_output; screen_capture только в точке, где что-то подозрительно.
5. Коммить исправления с понятными сообщениями.
```

Все отладочные команды: `cp N` (1 — выход из палатки, 2 — кедр, 3 — стоянка, 4 — лабаз, 5 — изба), `s <studs>` (точка маршрута по расстоянию), `god`, `items`, `heat N`, `wet`, `selftest`, `restart`. Работают только в Studio.

## «Запечь» рельеф, чтобы Play стартовал мгновенно
По умолчанию рельеф генерируется при каждом запуске (5–15 с). Можно сгенерировать его один раз в режиме редактирования:
1. В Studio (не в Play) выполни в Command Bar или через `execute_luau` (datamodel Edit):
   ```lua
   require(game.ServerScriptService.Server.World).bakeTerrain()
   ```
2. Сохрани place (Ctrl+S).

При запуске сервер увидит атрибут `BakedTerrain` и пропустит генерацию. Если меняешь `Heightmap`/`Level`, увеличь `Config.TerrainVersion`: старый рельеф тогда не подхватится. Работает с вариантом «rojo serve в открытый place». `rojo build` создаёт place без рельефа.

## Типичные проблемы, видимые только в движке, и куда смотреть

| Симптом | Где править |
|---|---|
| Ошибка в `WorldBuilder`, мир не строится | `src/server/WorldBuilder.luau` |
| Персонаж застревает в палатке | размеры в `Props.tentFrame` / `Props.buildTent` |
| Слишком темно или слишком светло | `Atmosphere.build` (Ambient, OutdoorAmbient, ExposureCompensation) |
| Ничего не видно в метели / слишком легко | `fog` зон в `Level.Zones` |
| Укрытие за камнями не срабатывает | `PlayerService.isSheltered`, размеры гряд в `Level.Outcrops` |
| Лёд висит в воздухе или утоплен | `Layout.ice` (`y = rimY − 0.35`) |
| Порыв толкает слишком сильно или слабо | `Config.Storm.GustPush` |
| Баланс тепла | `Config.Heat`, затем `lune run tests/run.luau` |
| Лагает (много деталей) | плотность деревьев в `Layout.trees` (`density`) |

## Звуки
В `Config.Sounds` встроены `rbxasset://`-звуки клиента: ветер, плеск, подбор. Колокола, треска костра и разрыва ткани нет. Чтобы добавить:
1. Найди звук через инструмент `search_asset` (Creator Store, тип Audio, бесплатный).
2. Проверь, что автор — **Roblox** или звук открыт для всех (public).
3. Впиши `rbxassetid://<id>` в `Config.Sounds.<Name>.Id`.
