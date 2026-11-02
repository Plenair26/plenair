@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Plenair - laat dit venster open

echo.
echo === 1/2  Onderdelen controleren (eerste keer duurt dit even) ===
py -m pip install -q --disable-pip-version-check -r requirements.txt
if errorlevel 1 (
  echo.
  echo Installeren is mislukt. Maak een screenshot van dit venster.
  pause
  exit /b 1
)
if not exist .env copy .env.example .env >nul

set HASKEY=0
findstr /b /c:"ANTHROPIC_API_KEY=sk-" .env >nul 2>&1 && set HASKEY=1
findstr /b /c:"ANTHROPIC_API_KEY=sk-" "%USERPROFILE%\Plenair\.env" >nul 2>&1 && set HASKEY=1
if "%HASKEY%"=="0" (
  echo.
  echo LET OP: geen API-sleutel gevonden. Alleen moties worden opgehaald, geen nieuws.
  echo Zie LEES-MIJ-EERST.txt hoe je de sleutel invult.
)

echo.
echo === 2/2  Site en bots starten ===
echo De site opent zo in je browser: http://127.0.0.1:5000
echo Zolang dit venster open is, haalt de site elke 10 minuten nieuws op en elk uur moties.
echo Ververs de pagina in je browser om nieuwe berichten te zien.
echo Je sleutel en database staan in: %USERPROFILE%\Plenair
echo Sluit dit venster om alles te stoppen.
echo.
start "" cmd /c "timeout /t 4 >nul & start http://127.0.0.1:5000"
set PLENAIR_RUN_BOTS=1
py -m flask --app app.web run
pause
