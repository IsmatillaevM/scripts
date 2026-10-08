@echo off
rem ============================================================================
rem winpe-backup.cmd — автономный бэкап пользовательского профиля из WinPE
rem   (или из обычной Windows, если Powershell недоступен).
rem
rem Как пользоваться:
rem   1) Скачать этот файл: https://raw.githubusercontent.com/IsmatillaevM/scripts/main/winpe-backup.cmd
rem      и положить в корень флешки/внешнего диска.
rem   2) Загрузиться в WinPE (среду восстановления), открыть cmd (Shift+F10).
rem   3) Запустить: <буква_флешки>:\winpe-backup.cmd
rem      например:  E:\winpe-backup.cmd
rem
rem Что делает:
rem   - Назначение = диск, с которого запущен сам этот файл.
rem   - Источник   = автоматически найденный \Users\<имя> на одном из дисков.
rem                  Если профилей несколько — спросит номер.
rem   - Копирует Desktop, Documents, Pictures, Videos, Music, Downloads (без
rem     установщиков), AppData\Roaming, AppData\Local в
rem     <флешка>:\Backup_<имя_пользователя>[_YYYYMMDD_HHMM]\
rem   - Пропускает системный мусор и кэши.
rem ============================================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    winpe-backup.cmd — автономный бэкап профиля
echo ============================================================
echo.

set "DST=%~d0"
echo Назначение (куда копируем): %DST%\
echo.

rem ----- поиск профилей \Users\<name>\Desktop на всех дисках -----
set CANDIDATES=
for %%L in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if /I not "%%L:"=="%DST%" if /I not "%%L:"=="X:" (
        if exist "%%L:\Users\" (
            for /D %%U in ("%%L:\Users\*") do (
                set "N=%%~nxU"
                if /I not "!N!"=="Public" if /I not "!N!"=="Default" if /I not "!N!"=="Default User" if /I not "!N!"=="All Users" if /I not "!N!"=="defaultuser0" if /I not "!N!"=="WDAGUtilityAccount" (
                    if exist "%%U\Desktop" (
                        set CANDIDATES=!CANDIDATES! "%%U"
                    )
                )
            )
        )
    )
)

if "%CANDIDATES%"=="" (
    echo [!] Не найден ни один профиль пользователя на подключённых дисках.
    echo     Проверь вручную:  dir C:\Users   dir D:\Users   dir E:\Users
    echo.
    pause
    exit /b 1
)

set COUNT=0
for %%P in (%CANDIDATES%) do set /A COUNT+=1

if %COUNT%==1 (
    for %%P in (%CANDIDATES%) do set "SRC=%%~P"
    echo Найден профиль: !SRC!
) else (
    echo Найдено несколько профилей:
    set I=0
    for %%P in (%CANDIDATES%) do (
        set /A I+=1
        echo    [!I!] %%~P
    )
    echo.
    set /P PICK=Выбери номер:
    set I=0
    for %%P in (%CANDIDATES%) do (
        set /A I+=1
        if "!I!"=="!PICK!" set "SRC=%%~P"
    )
    if "!SRC!"=="" (
        echo [!] Неверный выбор.
        pause
        exit /b 1
    )
)

echo Источник (откуда копируем): !SRC!
echo.

rem ----- метка времени через wmic (если wmic нет — просто без неё) -----
set "STAMP="
for /f "usebackq delims=" %%i in (`wmic os get localdatetime /value 2^>nul ^| find "="`) do (
    for /f "tokens=2 delims==" %%v in ("%%i") do set "DT=%%v"
)
if defined DT set "STAMP=_%DT:~0,8%_%DT:~8,4%"

for %%N in ("!SRC!") do set "UNAME=%%~nxN"
set "BACKUP=%DST%\Backup_%UNAME%%STAMP%"
mkdir "%BACKUP%" 2>nul
set "LOG=%BACKUP%\_backup.log"

echo Папка резервной копии: %BACKUP%
echo Лог:                   %LOG%
echo.

call :sect Desktop         "!SRC!\Desktop"
call :sect Documents       "!SRC!\Documents"
call :sect Pictures        "!SRC!\Pictures"
call :sect Videos          "!SRC!\Videos"
call :sect Music           "!SRC!\Music"
call :downloads            "!SRC!\Downloads"
call :roaming              "!SRC!\AppData\Roaming"
call :local                "!SRC!\AppData\Local"

echo.
echo ============================================================
echo    ГОТОВО
echo    Папка: %BACKUP%
echo    Лог:   %LOG%
echo ============================================================
echo.
pause
exit /b 0

rem ---------------------------------------------------------------------------
:sect
rem %1 — короткое имя секции, %2 — путь-источник (в кавычках)
set "SNAME=%~1"
set "SPATH=%~2"
if not exist "%SPATH%" exit /b 0
echo === %SNAME%
robocopy "%SPATH%" "%BACKUP%\%SNAME%" /E /R:1 /W:1 /MT:16 /XJ /NFL /NDL /NP /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "$Recycle.Bin" "System Volume Information" "node_modules" "__pycache__" ".venv" "venv" "pip" "pip-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.temp" "*.log1" "*.log2" "*.etl" "*.lock"
echo.
exit /b 0

:downloads
set "SPATH=%~1"
if not exist "%SPATH%" exit /b 0
echo === Downloads (без установщиков)
robocopy "%SPATH%" "%BACKUP%\Downloads" /E /R:1 /W:1 /MT:16 /XJ /NFL /NDL /NP /TEE /LOG+:"%LOG%" /XD "Cache" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.exe" "*.msi" "*.msix" "*.msixbundle" "*.appx" "*.appxbundle" "*.iso" "*.img" "*.vhd" "*.vhdx" "*.dmg" "*.pkg" "*.deb" "*.rpm"
echo.
exit /b 0

:roaming
set "SPATH=%~1"
if not exist "%SPATH%" exit /b 0
echo === AppData\Roaming
robocopy "%SPATH%" "%BACKUP%\AppData_Roaming" /E /R:1 /W:1 /MT:16 /XJ /NFL /NDL /NP /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock"
echo.
exit /b 0

:local
set "SPATH=%~1"
if not exist "%SPATH%" exit /b 0
echo === AppData\Local
robocopy "%SPATH%" "%BACKUP%\AppData_Local" /E /R:1 /W:1 /MT:16 /XJ /NFL /NDL /NP /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "D3DSCache" "Packages" "PackageStaging" "SquirrelTemp" "WebCache" "INetCache" "INetCookies" "History" "NVIDIA" "NVIDIA Corporation" "AMD" "Intel" "ConnectedDevicesPlatform" "pnpm-cache" "yarn-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock"
echo.
exit /b 0
