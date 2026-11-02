#!/usr/bin/env bash
# Lokaal starten: maakt een virtuele omgeving, installeert pakketten en start de site.
set -euo pipefail
cd "$(dirname "$0")"
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
pip install -q -r requirements.txt
[ -f .env ] || { cp .env.example .env; echo "Vul je ANTHROPIC_API_KEY in .env in en start opnieuw."; }
echo "Site draait op http://127.0.0.1:5000  (stoppen: Ctrl+C)"
exec flask --app app.web run --port 5000
