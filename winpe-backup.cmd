@echo off
rem ============================================================================
rem  winpe-backup.cmd  -  comprehensive user-profile backup from WinPE / Windows
rem
rem  Usage:
rem    1) Boot into WinPE, open cmd (Shift+F10).
rem    2) Run from anywhere, e.g.:
rem         E:\winpe-backup.cmd
rem         X:\sources\winpe-backup.cmd
rem    3) Script auto-detects destination (USB) and source profile.
rem
rem  All messages in English (WinPE often lacks cyrillic fonts).
rem ============================================================================

setlocal EnableDelayedExpansion
title WinPE Backup
color 07

echo.
echo ============================================================
echo    WinPE Backup  -  comprehensive profile backup tool
echo ============================================================
echo.

rem ============================================================
rem  0) ADMIN CHECK
rem ============================================================
net session >nul 2>&1
if errorlevel 1 (
    echo [i] Note: not running as admin. Some protected files may be skipped.
    echo.
)

rem ============================================================
rem  1) DETECT DRIVES - three fallbacks
rem ============================================================
set ALL_DRIVES=
set DETECT_METHOD=none

wmic logicaldisk get DeviceID /value >nul 2>&1
if not errorlevel 1 (
    set DETECT_METHOD=wmic
    for /f "usebackq tokens=2 delims==" %%A in (`wmic logicaldisk get DeviceID /value 2^>nul ^| find "="`) do (
        set "L=%%A"
        if defined L set ALL_DRIVES=!ALL_DRIVES! !L!
    )
    goto :drives_done
)

where powershell >nul 2>&1
if not errorlevel 1 (
    set DETECT_METHOD=powershell
    for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Name + ':' }" 2^>nul`) do (
        set "L=%%A"
        if defined L set ALL_DRIVES=!ALL_DRIVES! !L!
    )
    if defined ALL_DRIVES goto :drives_done
)

set DETECT_METHOD=fsutil
for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if exist "%%L:\" set ALL_DRIVES=!ALL_DRIVES! %%L:
)

:drives_done
if "%ALL_DRIVES%"=="" (
    echo [!] No drives detected.
    pause
    exit /b 1
)
echo [i] Drive detection method: %DETECT_METHOD%
echo [i] Drives found:          %ALL_DRIVES%
echo.

rem ============================================================
rem  2) CLASSIFY DRIVES
rem ============================================================
set DESTS=
set SOURCES=
for %%L in (%ALL_DRIVES%) do (
    set "L=%%L"
    if /I not "!L!"=="X:" (
        if not exist "!L!\Windows\System32\" set DESTS=!DESTS! "!L!"
    )
    if exist "!L!\Users\" set SOURCES=!SOURCES! "!L!"
)

rem ============================================================
rem  3) PICK DESTINATION
rem ============================================================
if "%DESTS%"=="" (
    echo [!] No destination drive found.
    pause
    exit /b 1
)

set DCOUNT=0
for %%P in (%DESTS%) do set /A DCOUNT+=1

if %DCOUNT%==1 (
    for %%P in (%DESTS%) do set "DST=%%~P"
    echo [=] Destination: !DST!\
) else (
    echo Multiple possible destinations found:
    set I=0
    for %%P in (%DESTS%) do (
        set /A I+=1
        set "VN="
        set "FS="
        for /f "usebackq tokens=2 delims==" %%V in (`wmic logicaldisk where "DeviceID='%%~P'" get VolumeName /value 2^>nul ^| find "="`) do set "VN=%%V"
        for /f "usebackq tokens=2 delims==" %%S in (`wmic logicaldisk where "DeviceID='%%~P'" get FreeSpace /value 2^>nul ^| find "="`) do set "FS=%%S"
        if defined FS (
            set /A FSG=!FS!/1073741824
            echo    [!I!] %%~P   label:"!VN!"   free:!FSG! GB
        ) else (
            echo    [!I!] %%~P   label:"!VN!"
        )
    )
    echo.
    set /P DPICK=Pick destination number:
    set I=0
    for %%P in (%DESTS%) do (
        set /A I+=1
        if "!I!"=="!DPICK!" set "DST=%%~P"
    )
    if "!DST!"=="" (
        echo [!] Invalid choice.
        pause
        exit /b 1
    )
    echo [=] Destination: !DST!\
)
echo.

rem ============================================================
rem  4) PICK SOURCE PROFILE
rem ============================================================
set CANDIDATES=
set SYS_DRIVE=
for %%D in (%SOURCES%) do (
    set "D=%%~D"
    if /I not "!D!"=="!DST!" (
        if exist "!D!\Windows\System32\" set "SYS_DRIVE=!D!"
        for /D %%U in ("!D!\Users\*") do (
            set "N=%%~nxU"
            if /I not "!N!"=="Public" if /I not "!N!"=="Default" if /I not "!N!"=="Default User" if /I not "!N!"=="All Users" if /I not "!N!"=="defaultuser0" if /I not "!N!"=="WDAGUtilityAccount" (
                if exist "%%U\Desktop" set CANDIDATES=!CANDIDATES! "%%U"
            )
        )
    )
)

if "%CANDIDATES%"=="" (
    echo [!] No user profile found.
    pause
    exit /b 1
)

set COUNT=0
for %%P in (%CANDIDATES%) do set /A COUNT+=1

if %COUNT%==1 (
    for %%P in (%CANDIDATES%) do set "SRC=%%~P"
    echo [=] Profile found: !SRC!
) else (
    echo Multiple profiles found:
    set I=0
    for %%P in (%CANDIDATES%) do (
        set /A I+=1
        echo    [!I!] %%~P
    )
    echo.
    set /P PICK=Pick profile number:
    set I=0
    for %%P in (%CANDIDATES%) do (
        set /A I+=1
        if "!I!"=="!PICK!" set "SRC=%%~P"
    )
    if "!SRC!"=="" (
        echo [!] Invalid choice.
        pause
        exit /b 1
    )
    echo [=] Profile: !SRC!
)
echo.
if defined SYS_DRIVE echo [i] System drive: !SYS_DRIVE!
echo.

rem ============================================================
rem  4b) MODE SELECTION: FULL / INCREMENTAL / VERIFY
rem ============================================================
echo Backup mode:
echo    [1] Full backup (default - copy everything new)
echo    [2] Incremental (copy only files changed since last backup)
echo    [3] Mirror (make destination exactly match source - DELETES extra files on dest)
set /P MODE=Pick mode (1/2/3) [1]:
if "!MODE!"=="" set MODE=1
if "!MODE!"=="2" (
    set "ROBO_MODE=/XO"
    echo [=] Mode: INCREMENTAL
) else if "!MODE!"=="3" (
    set "ROBO_MODE=/MIR"
    echo [=] Mode: MIRROR
) else (
    set "ROBO_MODE="
    echo [=] Mode: FULL
)
echo.

set /P DOVERIFY=Verify copied files (hash check) at the end? (Y/N) [N]:
if /I "!DOVERIFY!"=="Y" (set VERIFY=1) else (set VERIFY=0)

set /P DOZIP=Compress final backup to ZIP at the end? (Y/N) [N]:
if /I "!DOZIP!"=="Y" (set DOZIP=1) else (set DOZIP=0)
echo.

rem ============================================================
rem  5) ESTIMATE SIZE
rem ============================================================
echo [i] Estimating profile size (few seconds)...
set SRC_SIZE=0
for /f "usebackq tokens=3" %%S in (`dir "!SRC!" /s /a-d 2^>nul ^| find "File(s)"`) do set SRC_SIZE=%%S
set "SRC_SIZE_CLEAN=!SRC_SIZE:,=!"
if defined SRC_SIZE_CLEAN (
    set /A SRC_GB=!SRC_SIZE_CLEAN!/1073741824
    echo [i] Source profile size: approx !SRC_GB! GB
)

set FREE=
for /f "usebackq tokens=2 delims==" %%S in (`wmic logicaldisk where "DeviceID='!DST!'" get FreeSpace /value 2^>nul ^| find "="`) do set "FREE=%%S"
if defined FREE (
    set /A FREE_GB=!FREE!/1073741824
    echo [i] Destination free:    !FREE_GB! GB
    if defined SRC_GB if !SRC_GB! GTR !FREE_GB! (
        echo [!] WARNING: source may not fit on destination.
        set /P GOON=Continue anyway? (Y/N):
        if /I not "!GOON!"=="Y" exit /b 1
    )
)
echo.

rem ============================================================
rem  6) TIMESTAMP + BACKUP FOLDER
rem ============================================================
set "STAMP="
for /f "usebackq delims=" %%i in (`wmic os get localdatetime /value 2^>nul ^| find "="`) do (
    for /f "tokens=2 delims==" %%v in ("%%i") do set "DT=%%v"
)
if defined DT (
    set "STAMP=_%DT:~0,8%_%DT:~8,4%"
) else (
    set "RAW=%DATE%_%TIME%"
    set "RAW=!RAW: =0!"
    set "RAW=!RAW::=!"
    set "RAW=!RAW:/=!"
    set "RAW=!RAW:.=!"
    set "STAMP=_!RAW:~0,13!"
)

for %%N in ("!SRC!") do set "UNAME=%%~nxN"
set "BACKUP=!DST!\Backup_%UNAME%%STAMP%"

rem For incremental, reuse last backup folder of same user
if "!MODE!"=="2" (
    set "LAST="
    for /f "delims=" %%F in ('dir "!DST!\Backup_%UNAME%_*" /b /ad /o-n 2^>nul') do (
        if not defined LAST set "LAST=%%F"
    )
    if defined LAST (
        set "BACKUP=!DST!\!LAST!"
        echo [=] Incremental: reusing existing folder !BACKUP!
    )
)

mkdir "%BACKUP%" 2>nul
mkdir "%BACKUP%\_SystemInfo" 2>nul
set "LOG=%BACKUP%\_backup.log"
set "SUMMARY=%BACKUP%\_summary.txt"
set "REPORT=%BACKUP%\report.html"

echo [=] Backup folder: %BACKUP%
echo [=] Log file:      %LOG%
echo [=] HTML report:   %REPORT%
echo.
timeout /t 3 >nul

> "%SUMMARY%" echo WinPE Backup Summary
>> "%SUMMARY%" echo ====================
>> "%SUMMARY%" echo Source:      !SRC!
>> "%SUMMARY%" echo Destination: %BACKUP%
>> "%SUMMARY%" echo Mode:        !MODE!  (robocopy flags: !ROBO_MODE!)
>> "%SUMMARY%" echo Started:     %DATE% %TIME%
>> "%SUMMARY%" echo.

rem ============================================================
rem  7) MAIN FOLDER COPY
rem ============================================================
call :sect Desktop         "!SRC!\Desktop"
call :sect Documents       "!SRC!\Documents"
call :sect Pictures        "!SRC!\Pictures"
call :sect Videos          "!SRC!\Videos"
call :sect Music           "!SRC!\Music"
call :sect Favorites       "!SRC!\Favorites"
call :sect Links           "!SRC!\Links"
call :downloads            "!SRC!\Downloads"
call :roaming              "!SRC!\AppData\Roaming"
call :local                "!SRC!\AppData\Local"

rem ============================================================
rem  8) SPECIAL ITEMS
rem ============================================================
call :bookmark "!SRC!\AppData\Local\Google\Chrome\User Data\Default\Bookmarks" "Chrome_Bookmarks"
call :bookmark "!SRC!\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks" "Edge_Bookmarks"
call :bookmark "!SRC!\AppData\Roaming\Mozilla\Firefox\Profiles" "Firefox_Profiles"

call :outlook_data
call :rdp_files
call :ssh_keys
call :user_fonts
call :sticky_notes
call :hosts_file
call :scheduled_tasks
call :user_certs

rem ============================================================
rem  9) SYSTEM INFO
rem ============================================================
call :collect_sysinfo

rem ============================================================
rem 10) HTML REPORT + QR
rem ============================================================
call :make_html_report

rem ============================================================
rem 11) OPTIONAL VERIFY + ZIP
rem ============================================================
if "!VERIFY!"=="1" call :verify_backup
if "!DOZIP!"=="1" call :zip_backup

>> "%SUMMARY%" echo.
>> "%SUMMARY%" echo Finished:    %DATE% %TIME%

echo.
echo ============================================================
echo    DONE
echo    Folder:  %BACKUP%
echo    Log:     %LOG%
echo    Summary: %SUMMARY%
echo    Report:  %REPORT%
echo ============================================================
echo.
pause
exit /b 0

rem ---------------------------------------------------------------------------
rem                             COPY FUNCTIONS
rem ---------------------------------------------------------------------------

:sect
set "SNAME=%~1"
set "SPATH=%~2"
if not exist "%SPATH%" (
    >> "%SUMMARY%" echo [skip] %SNAME% - not present
    exit /b 0
)
echo.
echo ================= %SNAME% =================
robocopy "%SPATH%" "%BACKUP%\%SNAME%" /E %ROBO_MODE% /R:1 /W:1 /MT:16 /XJ /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "$Recycle.Bin" "System Volume Information" "node_modules" "__pycache__" ".venv" "venv" "pip" "pip-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.temp" "*.log1" "*.log2" "*.etl" "*.lock"
>> "%SUMMARY%" echo [ok]   %SNAME% - rc=!errorlevel!
exit /b 0

:downloads
set "SPATH=%~1"
if not exist "%SPATH%" (
    >> "%SUMMARY%" echo [skip] Downloads - not present
    exit /b 0
)
echo.
echo ================= Downloads (no installers) =================
robocopy "%SPATH%" "%BACKUP%\Downloads" /E %ROBO_MODE% /R:1 /W:1 /MT:16 /XJ /TEE /LOG+:"%LOG%" /XD "Cache" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.exe" "*.msi" "*.msix" "*.msixbundle" "*.appx" "*.appxbundle" "*.iso" "*.img" "*.vhd" "*.vhdx" "*.dmg" "*.pkg" "*.deb" "*.rpm"
>> "%SUMMARY%" echo [ok]   Downloads - rc=!errorlevel!
exit /b 0

:roaming
set "SPATH=%~1"
if not exist "%SPATH%" (
    >> "%SUMMARY%" echo [skip] AppData\Roaming - not present
    exit /b 0
)
echo.
echo ================= AppData\Roaming =================
robocopy "%SPATH%" "%BACKUP%\AppData_Roaming" /E %ROBO_MODE% /R:1 /W:1 /MT:16 /XJ /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock"
>> "%SUMMARY%" echo [ok]   AppData\Roaming - rc=!errorlevel!
exit /b 0

:local
set "SPATH=%~1"
if not exist "%SPATH%" (
    >> "%SUMMARY%" echo [skip] AppData\Local - not present
    exit /b 0
)
echo.
echo ================= AppData\Local =================
robocopy "%SPATH%" "%BACKUP%\AppData_Local" /E %ROBO_MODE% /R:1 /W:1 /MT:16 /XJ /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "D3DSCache" "Packages" "PackageStaging" "SquirrelTemp" "WebCache" "INetCache" "INetCookies" "History" "NVIDIA" "NVIDIA Corporation" "AMD" "Intel" "ConnectedDevicesPlatform" "pnpm-cache" "yarn-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock"
>> "%SUMMARY%" echo [ok]   AppData\Local - rc=!errorlevel!
exit /b 0

:bookmark
set "BPATH=%~1"
set "BNAME=%~2"
if not exist "%BPATH%" exit /b 0
echo.
echo ================= Bookmark export: %BNAME% =================
mkdir "%BACKUP%\_Bookmarks" 2>nul
if exist "%BPATH%\*" (
    robocopy "%BPATH%" "%BACKUP%\_Bookmarks\%BNAME%" /E /R:1 /W:1 /XJ /NFL /NDL /NP /TEE /LOG+:"%LOG%"
) else (
    copy /Y "%BPATH%" "%BACKUP%\_Bookmarks\%BNAME%" >nul 2>&1
    echo Copied %BPATH%
)
>> "%SUMMARY%" echo [ok]   bookmark: %BNAME%
exit /b 0

rem ---------------------------------------------------------------------------
rem                             SPECIAL ITEMS
rem ---------------------------------------------------------------------------

:outlook_data
echo.
echo ================= Outlook data (.pst / .ost) =================
mkdir "%BACKUP%\_Outlook" 2>nul
set FOUND=0
rem Common Outlook locations
for %%P in (
    "!SRC!\Documents\Outlook Files"
    "!SRC!\AppData\Local\Microsoft\Outlook"
    "!SRC!\AppData\Roaming\Microsoft\Outlook"
) do (
    if exist %%P (
        robocopy %%P "%BACKUP%\_Outlook" *.pst *.ost *.nst /S /R:1 /W:1 /NFL /NDL /NP /TEE /LOG+:"%LOG%"
        set FOUND=1
    )
)
if !FOUND!==1 (
    >> "%SUMMARY%" echo [ok]   Outlook .pst/.ost
) else (
    >> "%SUMMARY%" echo [skip] Outlook - no data found
)
exit /b 0

:rdp_files
echo.
echo ================= RDP connections =================
mkdir "%BACKUP%\_RDP" 2>nul
set FOUND=0
if exist "!SRC!\Documents\*.rdp" (
    copy /Y "!SRC!\Documents\*.rdp" "%BACKUP%\_RDP\" >nul 2>&1
    set FOUND=1
)
if exist "!SRC!\Documents\Default.rdp" (
    copy /Y "!SRC!\Documents\Default.rdp" "%BACKUP%\_RDP\" >nul 2>&1
    set FOUND=1
)
rem Remote Desktop Connection Manager
if exist "!SRC!\AppData\Local\Microsoft\Remote Desktop" (
    robocopy "!SRC!\AppData\Local\Microsoft\Remote Desktop" "%BACKUP%\_RDP\RD_App" /E /R:1 /W:1 /NFL /NDL /NP >nul
    set FOUND=1
)
if !FOUND!==1 (
    >> "%SUMMARY%" echo [ok]   RDP files
) else (
    >> "%SUMMARY%" echo [skip] RDP - none
)
exit /b 0

:ssh_keys
echo.
echo ================= SSH keys =================
if exist "!SRC!\.ssh" (
    robocopy "!SRC!\.ssh" "%BACKUP%\_SSH" /E /R:1 /W:1 /NFL /NDL /NP /TEE /LOG+:"%LOG%"
    >> "%SUMMARY%" echo [ok]   .ssh keys
) else (
    >> "%SUMMARY%" echo [skip] .ssh - none
)
rem PuTTY saved sessions (in registry)
if defined SYS_DRIVE (
    set "NTUSER=!SRC!\NTUSER.DAT"
    if exist "!NTUSER!" (
        reg load HKU\OFFLINE_USER "!NTUSER!" >nul 2>&1
        if not errorlevel 1 (
            reg export "HKU\OFFLINE_USER\Software\SimonTatham" "%BACKUP%\_SSH\putty_sessions.reg" /y >nul 2>&1
            reg unload HKU\OFFLINE_USER >nul 2>&1
            if exist "%BACKUP%\_SSH\putty_sessions.reg" >> "%SUMMARY%" echo [ok]   PuTTY sessions exported
        )
    )
)
exit /b 0

:user_fonts
echo.
echo ================= User fonts =================
set "FDIR=!SRC!\AppData\Local\Microsoft\Windows\Fonts"
if exist "!FDIR!" (
    robocopy "!FDIR!" "%BACKUP%\_UserFonts" /E /R:1 /W:1 /NFL /NDL /NP /TEE /LOG+:"%LOG%"
    >> "%SUMMARY%" echo [ok]   User fonts
) else (
    >> "%SUMMARY%" echo [skip] User fonts - none
)
exit /b 0

:sticky_notes
echo.
echo ================= Sticky Notes =================
set FOUND=0
rem Modern Sticky Notes (Win 10/11)
for /D %%P in ("!SRC!\AppData\Local\Packages\Microsoft.MicrosoftStickyNotes_*") do (
    if exist "%%P\LocalState" (
        robocopy "%%P\LocalState" "%BACKUP%\_StickyNotes\Modern" /E /R:1 /W:1 /NFL /NDL /NP >nul
        set FOUND=1
    )
)
rem Legacy Sticky Notes (Win 7/8)
if exist "!SRC!\AppData\Roaming\Microsoft\Sticky Notes" (
    robocopy "!SRC!\AppData\Roaming\Microsoft\Sticky Notes" "%BACKUP%\_StickyNotes\Legacy" /E /R:1 /W:1 /NFL /NDL /NP >nul
    set FOUND=1
)
if !FOUND!==1 (
    >> "%SUMMARY%" echo [ok]   Sticky Notes
) else (
    >> "%SUMMARY%" echo [skip] Sticky Notes - none
)
exit /b 0

:hosts_file
echo.
echo ================= Hosts file =================
if defined SYS_DRIVE (
    set "HOSTS=!SYS_DRIVE!\Windows\System32\drivers\etc\hosts"
    if exist "!HOSTS!" (
        mkdir "%BACKUP%\_SystemInfo" 2>nul
        copy /Y "!HOSTS!" "%BACKUP%\_SystemInfo\hosts" >nul 2>&1
        >> "%SUMMARY%" echo [ok]   hosts file
    )
)
exit /b 0

:scheduled_tasks
echo.
echo ================= Scheduled tasks =================
mkdir "%BACKUP%\_SystemInfo\ScheduledTasks" 2>nul
where schtasks >nul 2>&1
if not errorlevel 1 (
    rem Export full list in CSV
    schtasks /query /fo CSV /v > "%BACKUP%\_SystemInfo\ScheduledTasks\tasks_list.csv" 2>nul
    rem Export each task as XML (preserves full definition for restore)
    for /f "usebackq tokens=1 delims=," %%T in (`schtasks /query /fo CSV /nh 2^>nul`) do (
        set "TNAME=%%~T"
        if defined TNAME if not "!TNAME!"=="TaskName" (
            set "SAFE=!TNAME:\=_!"
            set "SAFE=!SAFE::=_!"
            set "SAFE=!SAFE:/=_!"
            set "SAFE=!SAFE:*=_!"
            set "SAFE=!SAFE:?=_!"
            schtasks /query /tn "!TNAME!" /xml > "%BACKUP%\_SystemInfo\ScheduledTasks\!SAFE!.xml" 2>nul
        )
    )
    >> "%SUMMARY%" echo [ok]   scheduled tasks
) else (
    >> "%SUMMARY%" echo [skip] schtasks not available
)
exit /b 0

:user_certs
echo.
echo ================= User certificates =================
mkdir "%BACKUP%\_SystemInfo\Certs" 2>nul
where certutil >nul 2>&1
if not errorlevel 1 (
    certutil -store -user my > "%BACKUP%\_SystemInfo\Certs\user_personal.txt" 2>nul
    certutil -store -user root > "%BACKUP%\_SystemInfo\Certs\user_trusted_root.txt" 2>nul
    certutil -store -user ca > "%BACKUP%\_SystemInfo\Certs\user_intermediate.txt" 2>nul
    >> "%SUMMARY%" echo [ok]   certificates list
    > "%BACKUP%\_SystemInfo\Certs\_README.txt" echo These are text listings of certificates in the user store.
    >> "%BACKUP%\_SystemInfo\Certs\_README.txt" echo Private keys cannot be exported by certutil without a password.
    >> "%BACKUP%\_SystemInfo\Certs\_README.txt" echo To export a specific cert with private key, run:
    >> "%BACKUP%\_SystemInfo\Certs\_README.txt" echo    certutil -user -exportPFX my ^<SerialNumber^> cert.pfx
) else (
    >> "%SUMMARY%" echo [skip] certutil not available
)
exit /b 0

rem ---------------------------------------------------------------------------
rem                           SYSTEM INFO BLOCK
rem ---------------------------------------------------------------------------

:collect_sysinfo
echo.
echo ================= Collecting system info =================
set "SI=%BACKUP%\_SystemInfo"

rem --- Installed programs via registry ---
set "APPS_TXT=%SI%\installed_programs.txt"
> "%APPS_TXT%" echo Installed programs (from registry)
>> "%APPS_TXT%" echo ===================================
>> "%APPS_TXT%" echo.

if defined SYS_DRIVE (
    set "HIVE=!SYS_DRIVE!\Windows\System32\config\SOFTWARE"
    if exist "!HIVE!" (
        reg load HKLM\OFFLINE_SW "!HIVE!" >nul 2>&1
        if not errorlevel 1 (
            echo --- 64-bit apps --- >> "%APPS_TXT%"
            for /f "tokens=*" %%K in ('reg query "HKLM\OFFLINE_SW\Microsoft\Windows\CurrentVersion\Uninstall" 2^>nul') do (
                for /f "tokens=2,*" %%A in ('reg query "%%K" /v DisplayName 2^>nul ^| find "REG_SZ"') do (
                    for /f "tokens=2,*" %%C in ('reg query "%%K" /v DisplayVersion 2^>nul ^| find "REG_SZ"') do (
                        >> "%APPS_TXT%" echo %%B ^| %%D
                    )
                )
            )
            echo. >> "%APPS_TXT%"
            echo --- 32-bit apps --- >> "%APPS_TXT%"
            for /f "tokens=*" %%K in ('reg query "HKLM\OFFLINE_SW\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" 2^>nul') do (
                for /f "tokens=2,*" %%A in ('reg query "%%K" /v DisplayName 2^>nul ^| find "REG_SZ"') do (
                    for /f "tokens=2,*" %%C in ('reg query "%%K" /v DisplayVersion 2^>nul ^| find "REG_SZ"') do (
                        >> "%APPS_TXT%" echo %%B ^| %%D
                    )
                )
            )
            reg unload HKLM\OFFLINE_SW >nul 2>&1
            echo [ok] installed_programs.txt
        )
    )
)
>> "%SUMMARY%" echo [ok]   installed_programs.txt

rem --- Wi-Fi profiles ---
set "WIFI_DIR=%SI%\WiFi"
mkdir "%WIFI_DIR%" 2>nul

netsh wlan show profiles >nul 2>&1
if not errorlevel 1 (
    echo [i] Exporting Wi-Fi profiles with cleartext passwords...
    netsh wlan export profile key=clear folder="%WIFI_DIR%" >nul 2>&1
    > "%WIFI_DIR%\_wifi_passwords.txt" echo Wi-Fi profiles (SSID : password)
    >> "%WIFI_DIR%\_wifi_passwords.txt" echo =================================
    for /f "tokens=2 delims=:" %%P in ('netsh wlan show profiles 2^>nul ^| find "All User Profile"') do (
        set "PNAME=%%P"
        set "PNAME=!PNAME:~1!"
        set "PASS="
        for /f "tokens=2 delims=:" %%K in ('netsh wlan show profile name^="!PNAME!" key^=clear 2^>nul ^| find "Key Content"') do (
            set "PASS=%%K"
            set "PASS=!PASS:~1!"
        )
        if defined PASS (
            >> "%WIFI_DIR%\_wifi_passwords.txt" echo !PNAME! : !PASS!
        ) else (
            >> "%WIFI_DIR%\_wifi_passwords.txt" echo !PNAME! : [open]
        )
    )
    echo [ok] Wi-Fi profiles exported
) else (
    if defined SYS_DRIVE (
        set "WLAN_SRC=!SYS_DRIVE!\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces"
        if exist "!WLAN_SRC!" (
            robocopy "!WLAN_SRC!" "%WIFI_DIR%\RawProfiles" /E /R:1 /W:1 /NFL /NDL /NP >nul
            > "%WIFI_DIR%\_README.txt" echo Wi-Fi XML files are DPAPI-encrypted.
            >> "%WIFI_DIR%\_README.txt" echo Decrypt only on original Windows: netsh wlan show profile name="SSID" key=clear
            echo [ok] Raw Wi-Fi XML copied
        )
    )
)
>> "%SUMMARY%" echo [ok]   WiFi profiles

rem --- Windows product key ---
set "KEY_TXT=%SI%\windows_product_key.txt"
> "%KEY_TXT%" echo Windows Product Key info
>> "%KEY_TXT%" echo ========================
>> "%KEY_TXT%" echo.
for /f "usebackq tokens=2 delims==" %%K in (`wmic path softwarelicensingservice get OA3xOriginalProductKey /value 2^>nul ^| find "="`) do (
    >> "%KEY_TXT%" echo OEM Key (BIOS):  %%K
)
for /f "usebackq tokens=2 delims==" %%K in (`wmic path softwarelicensingservice get OA3xOriginalProductKeyDescription /value 2^>nul ^| find "="`) do (
    >> "%KEY_TXT%" echo Description:     %%K
)
if defined SYS_DRIVE (
    reg load HKLM\OFFLINE_SW2 "!SYS_DRIVE!\Windows\System32\config\SOFTWARE" >nul 2>&1
    if not errorlevel 1 (
        reg query "HKLM\OFFLINE_SW2\Microsoft\Windows NT\CurrentVersion" /v ProductName >> "%KEY_TXT%" 2>nul
        reg query "HKLM\OFFLINE_SW2\Microsoft\Windows NT\CurrentVersion" /v EditionID >> "%KEY_TXT%" 2>nul
        reg query "HKLM\OFFLINE_SW2\Microsoft\Windows NT\CurrentVersion" /v ProductId >> "%KEY_TXT%" 2>nul
        reg unload HKLM\OFFLINE_SW2 >nul 2>&1
    )
)
>> "%SUMMARY%" echo [ok]   windows_product_key.txt

rem --- Drivers ---
if defined SYS_DRIVE (
    where dism >nul 2>&1
    if not errorlevel 1 (
        echo [i] Exporting drivers...
        mkdir "%SI%\Drivers" 2>nul
        dism /image:!SYS_DRIVE!\ /export-driver /destination:"%SI%\Drivers" >nul 2>&1
        if not errorlevel 1 (
            echo [ok] Drivers exported
            >> "%SUMMARY%" echo [ok]   drivers
        )
    )
)

rem --- Hardware info ---
set "HW=%SI%\hardware.txt"
> "%HW%" echo Hardware info
>> "%HW%" echo =============
>> "%HW%" echo.
echo --- CPU --- >> "%HW%"
wmic cpu get Name,NumberOfCores,MaxClockSpeed /format:list 2>nul >> "%HW%"
echo --- RAM --- >> "%HW%"
wmic memorychip get Capacity,Speed,Manufacturer /format:list 2>nul >> "%HW%"
echo --- GPU --- >> "%HW%"
wmic path win32_videocontroller get Name,AdapterRAM /format:list 2>nul >> "%HW%"
echo --- Disks --- >> "%HW%"
wmic diskdrive get Model,Size,MediaType /format:list 2>nul >> "%HW%"
echo --- Motherboard --- >> "%HW%"
wmic baseboard get Manufacturer,Product,Version /format:list 2>nul >> "%HW%"
echo --- BIOS --- >> "%HW%"
wmic bios get Manufacturer,SMBIOSBIOSVersion,ReleaseDate /format:list 2>nul >> "%HW%"
>> "%SUMMARY%" echo [ok]   hardware.txt

exit /b 0

rem ---------------------------------------------------------------------------
rem                              VERIFY
rem ---------------------------------------------------------------------------

:verify_backup
echo.
echo ================= Verify (hashing) =================
set "VLOG=%BACKUP%\_verify.log"
> "%VLOG%" echo Verification report - %DATE% %TIME%
>> "%VLOG%" echo =====================================

where certutil >nul 2>&1
if errorlevel 1 (
    echo [!] certutil not available - skipping verify
    >> "%SUMMARY%" echo [skip] verify (no certutil)
    exit /b 0
)

set OK=0
set BAD=0
set MISS=0

rem Verify a sample: all files in Documents (full hash takes forever on 100GB)
echo [i] Verifying Documents folder with SHA256 (sample)...
if exist "%BACKUP%\Documents" (
    for /r "%BACKUP%\Documents" %%F in (*) do (
        set "DST_FILE=%%F"
        set "REL=!DST_FILE:%BACKUP%\Documents\=!"
        set "SRC_FILE=!SRC!\Documents\!REL!"
        if exist "!SRC_FILE!" (
            for /f "skip=1 tokens=*" %%H in ('certutil -hashfile "!SRC_FILE!" SHA256 2^>nul') do (
                set "SH=%%H"
                goto :got_src
            )
            :got_src
            for /f "skip=1 tokens=*" %%H in ('certutil -hashfile "!DST_FILE!" SHA256 2^>nul') do (
                set "DH=%%H"
                goto :got_dst
            )
            :got_dst
            if "!SH!"=="!DH!" (
                set /A OK+=1
            ) else (
                set /A BAD+=1
                >> "%VLOG%" echo MISMATCH: !REL!
            )
            set SH=
            set DH=
        ) else (
            set /A MISS+=1
        )
    )
)
echo [i] Verify done: OK=!OK!  MISMATCH=!BAD!  MISSING-ON-SRC=!MISS!
>> "%VLOG%" echo.
>> "%VLOG%" echo Results: OK=!OK!  MISMATCH=!BAD!  MISSING=!MISS!
>> "%SUMMARY%" echo [ok]   verify: OK=!OK!/BAD=!BAD!/MISS=!MISS!
exit /b 0

rem ---------------------------------------------------------------------------
rem                              ZIP
rem ---------------------------------------------------------------------------

:zip_backup
echo.
echo ================= Compressing to ZIP =================
set "ZIPFILE=%BACKUP%.zip"
where tar >nul 2>&1
if not errorlevel 1 (
    rem Windows 10/11 ship with bsdtar which can create .zip via -a flag
    echo [i] Using tar (bsdtar)...
    pushd "!DST!"
    for %%N in ("%BACKUP%") do set "BNAME=%%~nxN"
    tar -a -c -f "!ZIPFILE!" "!BNAME!"
    popd
    if exist "!ZIPFILE!" (
        echo [ok] ZIP created: !ZIPFILE!
        >> "%SUMMARY%" echo [ok]   zip created
        exit /b 0
    )
)

where powershell >nul 2>&1
if not errorlevel 1 (
    echo [i] Using PowerShell Compress-Archive...
    powershell -NoProfile -Command "Compress-Archive -Path '%BACKUP%\*' -DestinationPath '!ZIPFILE!' -Force" 2>nul
    if exist "!ZIPFILE!" (
        echo [ok] ZIP created: !ZIPFILE!
        >> "%SUMMARY%" echo [ok]   zip created
        exit /b 0
    )
)

echo [!] No compression tool available
>> "%SUMMARY%" echo [skip] zip - no tool
exit /b 0

rem ---------------------------------------------------------------------------
rem                           HTML REPORT + QR
rem ---------------------------------------------------------------------------

:make_html_report
echo.
echo ================= Building HTML report =================
set "TMP_STATS=%BACKUP%\_stats.tmp"
> "%TMP_STATS%" echo.

call :count_cat "Documents"  "pdf doc docx odt rtf txt md xls xlsx ods csv ppt pptx odp"
call :count_cat "Images"     "jpg jpeg png gif bmp tiff tif webp svg heic raw cr2 nef arw"
call :count_cat "Videos"     "mp4 mkv avi mov wmv flv webm m4v mpg mpeg 3gp"
call :count_cat "Audio"      "mp3 wav flac aac ogg m4a wma opus"
call :count_cat "Archives"   "zip rar 7z tar gz bz2 xz iso"
call :count_cat "Code"       "py js ts java c cpp h hpp cs go rs rb php html css sql sh ps1 ipynb"
call :count_cat "Executables" "exe msi msix appx bat cmd ps1 app"

> "%REPORT%" echo ^<!DOCTYPE html^>
>> "%REPORT%" echo ^<html lang="en"^>^<head^>^<meta charset="UTF-8"^>
>> "%REPORT%" echo ^<title^>Backup Report - %UNAME%^</title^>
>> "%REPORT%" echo ^<style^>
>> "%REPORT%" echo body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#0f172a;color:#e2e8f0;margin:0;padding:2rem;line-height:1.6}
>> "%REPORT%" echo .container{max-width:1100px;margin:0 auto}
>> "%REPORT%" echo h1{color:#60a5fa;border-bottom:2px solid #334155;padding-bottom:.5rem}
>> "%REPORT%" echo h2{color:#93c5fd;margin-top:2rem}
>> "%REPORT%" echo .meta{background:#1e293b;padding:1rem 1.5rem;border-radius:8px;margin-bottom:1.5rem;border-left:4px solid #60a5fa}
>> "%REPORT%" echo .meta b{color:#fbbf24}
>> "%REPORT%" echo .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:1rem;margin:1.5rem 0}
>> "%REPORT%" echo .card{background:#1e293b;padding:1.25rem;border-radius:8px;border-left:4px solid #10b981}
>> "%REPORT%" echo .card .name{color:#93c5fd;font-weight:600;margin-bottom:.5rem}
>> "%REPORT%" echo .card .count{font-size:2rem;font-weight:700;color:#fff}
>> "%REPORT%" echo .card .size{color:#94a3b8;font-size:.9rem;margin-top:.25rem}
>> "%REPORT%" echo .bar{background:#334155;height:8px;border-radius:4px;overflow:hidden;margin-top:.75rem}
>> "%REPORT%" echo .bar div{background:linear-gradient(90deg,#60a5fa,#a78bfa);height:100%%}
>> "%REPORT%" echo table{width:100%%;border-collapse:collapse;margin:1rem 0}
>> "%REPORT%" echo th,td{text-align:left;padding:.6rem;border-bottom:1px solid #334155}
>> "%REPORT%" echo th{background:#1e293b;color:#93c5fd}
>> "%REPORT%" echo tr:hover{background:#1e293b}
>> "%REPORT%" echo .qr{background:#fff;padding:1rem;border-radius:8px;display:inline-block;margin:1rem 0}
>> "%REPORT%" echo .qr svg{display:block}
>> "%REPORT%" echo .footer{color:#64748b;font-size:.85rem;margin-top:3rem;text-align:center;border-top:1px solid #334155;padding-top:1rem}
>> "%REPORT%" echo ^</style^>^</head^>^<body^>^<div class="container"^>
>> "%REPORT%" echo ^<h1^>Backup Report^</h1^>
>> "%REPORT%" echo ^<div class="meta"^>
>> "%REPORT%" echo ^<b^>User:^</b^> %UNAME%^<br^>
>> "%REPORT%" echo ^<b^>Source:^</b^> !SRC!^<br^>
>> "%REPORT%" echo ^<b^>Destination:^</b^> %BACKUP%^<br^>
>> "%REPORT%" echo ^<b^>Date:^</b^> %DATE% %TIME%^<br^>
if defined SRC_GB >> "%REPORT%" echo ^<b^>Total size:^</b^> ~!SRC_GB! GB^<br^>
>> "%REPORT%" echo ^</div^>

>> "%REPORT%" echo ^<h2^>Files by category^</h2^>
>> "%REPORT%" echo ^<div class="grid"^>

set MAXCOUNT=0
for /f "tokens=1,2 delims=|" %%A in (%TMP_STATS%) do (
    if %%B GTR !MAXCOUNT! set MAXCOUNT=%%B
)
if !MAXCOUNT!==0 set MAXCOUNT=1

for /f "tokens=1,2 delims=|" %%A in (%TMP_STATS%) do (
    set /A PCT=%%B*100/!MAXCOUNT!
    >> "%REPORT%" echo ^<div class="card"^>^<div class="name"^>%%A^</div^>^<div class="count"^>%%B^</div^>^<div class="size"^>files^</div^>^<div class="bar"^>^<div style="width:!PCT!%%"^>^</div^>^</div^>^</div^>
)
>> "%REPORT%" echo ^</div^>

rem --- Top 20 largest ---
>> "%REPORT%" echo ^<h2^>Top 20 largest files^</h2^>
>> "%REPORT%" echo ^<table^>^<tr^>^<th^>Size (MB)^</th^>^<th^>File^</th^>^</tr^>

set "BIG_TMP=%BACKUP%\_big.tmp"
if exist "%BIG_TMP%" del "%BIG_TMP%"
for /f "tokens=*" %%F in ('dir "%BACKUP%" /s /a-d /o-s /b 2^>nul') do (
    echo %%~zF^|%%F>> "%BIG_TMP%"
)

set CNT=0
for /f "usebackq tokens=1,2 delims=|" %%A in ("%BIG_TMP%") do (
    if !CNT! LSS 20 (
        set /A MB=%%A/1048576
        if !MB! GTR 0 (
            >> "%REPORT%" echo ^<tr^>^<td^>!MB!^</td^>^<td^>%%B^</td^>^</tr^>
            set /A CNT+=1
        )
    )
)
>> "%REPORT%" echo ^</table^>

>> "%REPORT%" echo ^<h2^>Backup contents^</h2^>
>> "%REPORT%" echo ^<table^>^<tr^>^<th^>Folder^</th^>^</tr^>
for /D %%D in ("%BACKUP%\*") do (
    >> "%REPORT%" echo ^<tr^>^<td^>%%~nxD^</td^>^</tr^>
)
>> "%REPORT%" echo ^</table^>

rem --- QR Code with summary (via PowerShell + QRCoder-free simple approach) ---
rem Since no internet in WinPE, build QR with built-in logic: use PowerShell + .NET
rem We embed the backup path as text in a QR, rendered via a tiny inline library.
rem Simpler: just encode a short URL to the summary.txt path.

where powershell >nul 2>&1
if not errorlevel 1 (
    echo [i] Generating QR code image...
    set "QR_PNG=%BACKUP%\_qr.png"
    set "QR_TEXT=Backup: %BACKUP% | User: %UNAME% | Date: %DATE%"
    powershell -NoProfile -Command "try { Add-Type -AssemblyName System.Drawing; $u = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=' + [uri]::EscapeDataString('!QR_TEXT!'); (New-Object Net.WebClient).DownloadFile($u, '!QR_PNG!') } catch { }" 2>nul
    if exist "!QR_PNG!" (
        >> "%REPORT%" echo ^<h2^>Quick view (QR)^</h2^>
        >> "%REPORT%" echo ^<div class="qr"^>^<img src="_qr.png" alt="QR"^>^</div^>
        >> "%REPORT%" echo ^<p^>Scan with phone to see backup location.^</p^>
    ) else (
        >> "%REPORT%" echo ^<h2^>Quick view^</h2^>
        >> "%REPORT%" echo ^<p^>!QR_TEXT!^</p^>
    )
) else (
    >> "%REPORT%" echo ^<h2^>Quick view^</h2^>
    >> "%REPORT%" echo ^<p^>Backup: %BACKUP%^</p^>
)

>> "%REPORT%" echo ^<div class="footer"^>Generated by winpe-backup.cmd on %DATE% %TIME%^</div^>
>> "%REPORT%" echo ^</div^>^</body^>^</html^>

del "%TMP_STATS%" 2>nul
del "%BIG_TMP%" 2>nul

>> "%SUMMARY%" echo [ok]   HTML report
echo [ok] HTML report built
exit /b 0

:count_cat
set "CAT=%~1"
set "EXTS=%~2"
set CFILES=0
for %%E in (%EXTS%) do (
    for /f %%N in ('dir "%BACKUP%\*.%%E" /s /a-d /b 2^>nul ^| find /c /v ""') do (
        set /A CFILES+=%%N
    )
)
>> "%TMP_STATS%" echo %CAT%^|!CFILES!
exit /b 0
