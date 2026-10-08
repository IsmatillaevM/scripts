@echo off
rem backup.cmd - запуск backup.ps1 из cmd двойным кликом или командой.
rem Чтобы задать путь к внешнему диску без вопроса:
rem     set BACKUP_DEST=E:\
rem     backup.cmd

powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex"
echo.
pause
