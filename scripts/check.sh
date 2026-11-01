#!/usr/bin/env bash
# Все проверки проекта одной командой (Linux/macOS/Git Bash):
#   ./scripts/check.sh
# Переменная API_DUMP=/путь/к/API-Dump.json включает проверку свойств по API Roblox.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== stylua";   stylua --check src tests scripts
echo "== selene";   selene src
echo "== tests";    lune run tests/run.luau
echo "== build";    mkdir -p build && rojo build -o build/game.rbxl
echo "== place";    lune run scripts/validate_place.luau build/game.rbxl
if [[ -n "${API_DUMP:-}" ]]; then
	echo "== api";  python3 scripts/check_api.py "$API_DUMP"
fi
echo "ALL CHECKS PASSED"
