@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Plenair voor je telefoon - laat dit venster open

echo.
echo === 1/3  Tunnelprogramma zoeken (cloudflared) ===
set CF=
where cloudflared >nul 2>&1 && set CF=cloudflared
if not defined CF if exist "%ProgramFiles(x86)%\cloudflared\cloudflared.exe" set CF="%ProgramFiles(x86)%\cloudflared\cloudflared.exe"
if not defined CF if exist "%ProgramFiles%\cloudflared\cloudflared.exe" set CF="%ProgramFiles%\cloudflared\cloudflared.exe"
if defined CF goto heeft_cf
echo cloudflared is nog niet geinstalleerd. Dat gebeurt nu (eenmalig).
winget install --id Cloudflare.cloudflared --exact --accept-package-agreements --accept-source-agreements
echo.
echo Klaar. Sluit dit venster en dubbelklik nog een keer op start-telefoon.
pause
exit /b 0
:heeft_cf

echo.
echo === 2/3  Site en bots starten ===
py -m pip install -q --disable-pip-version-check -r requirements.txt
if not exist .env copy .env.example .env >nul
start "Plenair site (niet sluiten)" /min cmd /k "set PLENAIR_RUN_BOTS=1&& py -m flask --app app.web run"
timeout /t 6 >nul

echo.
echo === 3/3  Internetadres maken ===
echo Over een paar seconden verschijnt hieronder een adres dat eindigt op .trycloudflare.com
echo Open dat adres op je telefoon. Het werkt overal, ook buiten je wifi.
echo.
echo Belangrijk:
echo  - Laat de computer AAN staan en niet in slaapstand.
echo  - Laat dit venster EN het geminimaliseerde venster "Plenair site" open.
echo  - Iedereen met het adres kan de site bekijken. Deel het alleen als je dat wilt.
echo  - Bij elke nieuwe start krijg je een nieuw adres.
echo.
%CF% tunnel --no-autoupdate --url http://127.0.0.1:5000 2>&1 | findstr /i "trycloudflare.com ERR failed"
echo.
echo De tunnel is gestopt. Sluit ook het venster "Plenair site".
pause
