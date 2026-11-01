# Локальная сессия Claude Code + Studio MCP

Этот файл — готовый сценарий для локального Claude Code на Windows, подключённого к Roblox Studio через встроенный MCP-сервер. Задача: потратить минимум лимитов. Claude не исследует проект с нуля, а сразу запускает самотест и чинит то, что видно только в движке.

## Подготовка (один раз)
1. Studio → **Assistant** → **…** → **Manage MCP Servers** → включить **Enable Studio as MCP server**.
2. Там же **Quick connect** → включить **Claude Code**. Если Claude Code нет в списке, выполни:
   ```powershell
   claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
   ```
3. Открой в Studio собранный `game.rbxl`, запусти `rojo serve` и нажми Plugins → Rojo → Connect.
4. В папке репозитория запусти `claude`.

## Промпт для старта (скопируй целиком)

```
Проект — Roblox-игра «Перевал», Rojo-проект в этом репозитории. Studio открыта и синхронизирована через `rojo serve`. Studio MCP подключён.
Правила экономии:
- Не читай весь репозиторий. Структура описана в README.md, механики — в docs/DESIGN.md.
- Правки делай ТОЛЬКО в файлах src/**, а не через multi_edit в Studio: Rojo сам синхронизирует.
- screen_capture — только когда я прошу или когда без картинки баг не понять.
- После каждой правки запускай `lune run tests/run.luau`.
Задача:
1. start_stop_play (запустить Play), подожди ~20 с, затем get_console_output.
2. Найди строки [SELFTEST] и любые красные ошибки. Пришли сводку: что FAIL/WARN, какие ошибки.
3. Исправь ошибки по одной, перезапускай Play и проверяй Output.
4. Когда Output чистый, пройди маршрут: execute_luau на сервере, телепорт через отладку:
   game.ReplicatedStorage.Remotes — нет, используй прямой вызов: require(game.ServerScriptService.Server.Actions)
   не нужен — проще character_navigation по точкам маршрута src/shared/Level.luau (Waypoints), с остановками у костров.
5. Коммить исправления с понятными сообщениями.
```

## Типичные проблемы, видимые только в движке, и куда смотреть

| Симптом | Где править |
|---|---|
| Ошибка в `WorldBuilder` / мир не строится | `src/server/WorldBuilder.luau` |
| Персонаж застревает в палатке | размеры палатки в `Props.buildTent` |
| Слишком темно или слишком светло | `Atmosphere.build` (Ambient, OutdoorAmbient, ExposureCompensation) и `fog` зон в `Level.Zones` |
| Ничего не видно в метели / слишком легко | `fog` зон в `Level.Zones` |
| Укрытие за камнями не срабатывает | `PlayerService.isSheltered`, размеры гряд в `Level.Outcrops` |
| Лёд висит в воздухе или утоплен | `Layout.ice` (y = rimY − 0.35) |
| Порыв толкает слишком сильно или слабо | `Config.Storm.GustPush` |
| Баланс тепла | `Config.Heat`, затем `lune run tests/run.luau` |
| Лагает (много деталей) | плотность деревьев в `Layout.trees` (`density`) |

## Звуки
В `Config.Sounds` встроены `rbxasset://`-звуки клиента: ветер, плеск, всплеск. Колокола, треска костра и разрыва ткани нет. Чтобы добавить:
1. Найди звук через инструмент `search_asset` (Creator Store, тип Audio, бесплатный).
2. Проверь, что автор — **Roblox** или звук открыт для всех (public).
3. Впиши `rbxassetid://<id>` в `Config.Sounds.<Name>.Id`.
