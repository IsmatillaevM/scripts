@echo off
rem ============================================================================
rem  b.cmd  -  WinPE Backup
rem  Barcha xabarlar o'zbekcha (lotin).
rem ============================================================================

setlocal EnableDelayedExpansion
title WinPE Backup
color 0B
mode con cols=100 lines=40 2>nul
cls

echo.
echo  ============================================================================
echo    WinPE Backup  -  foydalanuvchi ma'lumotlarini zaxiralash
echo  ============================================================================
echo.

rem Admin check: fsutil dirty query ishonchliroq ishlaydi, hatto WinPE'da ham
fsutil dirty query %SystemDrive% >nul 2>&1
if errorlevel 1 (
    echo  [W] Diqqat: administrator huquqisiz ishga tushirilgan.
    echo      Ba'zi himoyalangan fayllar o'tkazib yuborilishi mumkin.
    echo.
)

echo  [*] Disklar aniqlanmoqda...
echo.

rem --- Barcha disklarni topish ---
set ALL_DRIVES=
wmic logicaldisk get DeviceID /value >nul 2>&1
if not errorlevel 1 (
    for /f "usebackq tokens=2 delims==" %%A in (`wmic logicaldisk get DeviceID /value 2^>nul ^| find "="`) do (
        set "L=%%A"
        if defined L set ALL_DRIVES=!ALL_DRIVES! !L!
    )
) else (
    for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
        if exist "%%L:\" set ALL_DRIVES=!ALL_DRIVES! %%L:
    )
)

if "%ALL_DRIVES%"=="" (
    echo  [W] Hech qanday disk topilmadi.
    pause
    exit /b 1
)

rem ============================================================
rem  JADVAL - har bir disk haqida ma'lumotni oldindan hisoblash
rem ============================================================
set DNUM=0
for %%L in (%ALL_DRIVES%) do (
    set /A DNUM+=1
    set "DRV_!DNUM!=%%L"
)

rem Har bir disk uchun ma'lumot yig'ish (oddiy call, for ichida emas)
for /L %%I in (1,1,%DNUM%) do call :gather_disk %%I

echo  ============================================================================
echo    MAVJUD DISKLAR
echo  ============================================================================
echo.
echo    #    Harf   Hajm        Bo'sh       Tip                 Metka
echo    -------------------------------------------------------------------------
for /L %%I in (1,1,%DNUM%) do call :show_disk %%I
echo    -------------------------------------------------------------------------
echo.
echo    [i] X: - bu WinPE ichki diski (unga tegmang).
echo    [i] Fleshka - odatda "Removable" tipida ko'rinadi.
echo.

rem ============================================================
rem  1-QADAM: FLESHKA TANLASH
rem ============================================================
echo  ============================================================================
echo    1-QADAM: ZAXIRA UCHUN DISK TANLASH (fleshka)
echo  ============================================================================
echo.

set DST_TRIES=0
:ask_dst
echo.
set /A DST_TRIES+=1
if !DST_TRIES! GTR 10 (
    echo  [W] Juda ko'p noto'g'ri urinish. Chiqildi.
    exit /b 1
)
set "DPICK="
set /P DPICK=  Fleshka raqamini kiriting (1-%DNUM%):
if not defined DPICK goto :ask_dst
call set "DST=%%DRV_!DPICK!%%"
if "!DST!"=="" (
    echo  [W] Noto'g'ri raqam.
    goto :ask_dst
)
if /I "!DST!"=="X:" (
    echo  [W] X: - bu WinPE ichki diski, zaxira uchun yaroqsiz.
    goto :ask_dst
)
call set "DST_INFO=%%INFO_!DPICK!%%"
echo.
echo  [=] Tanlangan: !DST!   !DST_INFO!
echo.
set "CONF="
set /P CONF=  Bu fleshkami? (Y - ha, N - yo'q):
if /I not "!CONF!"=="Y" (
    echo  [i] Boshqa disk tanlang.
    goto :ask_dst
)
echo.

rem ============================================================
rem  2-QADAM: WINDOWS DISKI
rem ============================================================
echo  ============================================================================
echo    2-QADAM: WINDOWS DISKI TANLASH
echo  ============================================================================
echo.

set SRC_TRIES=0
:ask_src_drive
echo.
set /A SRC_TRIES+=1
if !SRC_TRIES! GTR 10 (
    echo  [W] Juda ko'p noto'g'ri urinish. Chiqildi.
    exit /b 1
)
set "SPICK="
set /P SPICK=  Windows disk raqamini kiriting (1-%DNUM%):
if not defined SPICK goto :ask_src_drive
call set "SYS_DRIVE=%%DRV_!SPICK!%%"
if "!SYS_DRIVE!"=="" (
    echo  [W] Noto'g'ri raqam.
    goto :ask_src_drive
)
if /I "!SYS_DRIVE!"=="X:" (
    echo  [W] X: - bu WinPE ichki diski, Windows u yerda emas.
    goto :ask_src_drive
)
if /I "!SYS_DRIVE!"=="!DST!" (
    echo  [W] Fleshka va Windows disk bir xil bo'lishi mumkin emas!
    goto :ask_src_drive
)
if not exist "!SYS_DRIVE!\Users\" (
    echo  [W] Bu diskda \Users\ papkasi yo'q.
    goto :ask_src_drive
)
echo.
echo  [=] Tanlangan: !SYS_DRIVE!   (Windows diski)
echo.

rem ============================================================
rem  3-QADAM: PROFIL
rem ============================================================
echo  ============================================================================
echo    3-QADAM: FOYDALANUVCHI PROFILI
echo  ============================================================================
echo.

set PNUM=0
for /D %%U in ("!SYS_DRIVE!\Users\*") do (
    set "N=%%~nxU"
    if /I not "!N!"=="Public" if /I not "!N!"=="Default" if /I not "!N!"=="Default User" if /I not "!N!"=="All Users" if /I not "!N!"=="defaultuser0" if /I not "!N!"=="WDAGUtilityAccount" (
        if exist "%%U\Desktop" (
            set /A PNUM+=1
            set "PROF_!PNUM!=%%U"
            echo    [!PNUM!] %%U
        )
    )
)

if %PNUM%==0 (
    echo  [W] Profil topilmadi.
    pause
    exit /b 1
)

echo.
if %PNUM% EQU 1 (
    call set "SRC=%%PROF_1%%"
    echo  [=] Avtomatik tanlandi: !SRC!
    goto :prof_done
)

set PROF_TRIES=0
:ask_prof
set /A PROF_TRIES+=1
if !PROF_TRIES! GTR 10 (
    echo  [W] Juda ko'p noto'g'ri urinish. Chiqildi.
    exit /b 1
)
set "PPICK="
set /P PPICK=  Profil raqamini kiriting (1-%PNUM%):
if not defined PPICK goto :ask_prof
call set "SRC=%%PROF_!PPICK!%%"
if "!SRC!"=="" (
    echo  [W] Noto'g'ri raqam.
    goto :ask_prof
)
echo  [=] Tanlangan: !SRC!

:prof_done
echo.
for %%N in ("!SRC!") do set "UNAME=%%~nxN"

rem ============================================================
rem  4-QADAM: HAJM
rem ============================================================
echo  ============================================================================
echo    4-QADAM: HAJMNI TEKSHIRISH
echo  ============================================================================
echo.
echo  [*] Profil hajmini hisoblash (1-3 daqiqa kutilsin)...

rem --- Hajm hisoblash: 3 ta usul ---
set "SIZE_BYTES=0"

rem Usul 1: robocopy /L - til mustaqil: yakuniy jadvalning 3-qatori (Dirs, Files, Bytes)
set RC_ROW=0
for /f "tokens=1* delims=:" %%A in ('robocopy "!SRC!" NULL /L /E /BYTES /NFL /NDL /NJH /NC /NS /XJ /R:0 /W:0 2^>nul ^| find " : "') do (
    set /A RC_ROW+=1
    if !RC_ROW!==3 for /f "tokens=1" %%N in ("%%B") do set "SIZE_BYTES=%%N"
)

rem Usul 2: dir /s
if "!SIZE_BYTES!"=="0" (
    for /f "tokens=1,2,3" %%A in ('dir "!SRC!" /s /a-d 2^>nul ^| find "File(s)"') do (
        set "DIRSIZE=%%C"
        set "DIRSIZE=!DIRSIZE:,=!"
        set "SIZE_BYTES=!DIRSIZE!"
    )
)

rem Usul 3: PowerShell
if "!SIZE_BYTES!"=="0" (
    for /f "usebackq" %%S in (`powershell -NoProfile -Command "(Get-ChildItem -Path '!SRC!' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum" 2^>nul`) do set "SIZE_BYTES=%%S"
)

set "SRC_GB=0"
if not "!SIZE_BYTES!"=="0" (
    set "NUMTMP=!SIZE_BYTES!"
    if not "!NUMTMP!"=="" (
        set "SHORT=!NUMTMP:~0,-9!"
        if "!SHORT!"=="" set "SHORT=0"
        set "SRC_GB=!SHORT!"
    )
)

rem --- Fleshka bo'sh joy ---
set "FREE_BYTES=0"
for /f "usebackq tokens=2 delims==" %%S in (`wmic logicaldisk where "DeviceID='!DST!'" get FreeSpace /value 2^>nul ^| find "="`) do for /f "delims=" %%x in ("%%S") do set "FREE_BYTES=%%x"

set "FREE_GB=0"
if not "!FREE_BYTES!"=="0" (
    set "NUMTMP=!FREE_BYTES!"
    if not "!NUMTMP!"=="" (
        set "SHORT=!NUMTMP:~0,-9!"
        if "!SHORT!"=="" set "SHORT=0"
        set "FREE_GB=!SHORT!"
    )
)

echo.
echo    Profil hajmi (!UNAME!):     ~!SRC_GB! GB
echo    Fleshkada bo'sh joy (!DST!): !FREE_GB! GB
echo.

rem Agar hajm 0 bo'lsa - ogohlantirish
if "!SRC_GB!"=="0" (
    echo  [i] Hajm aniqlanmadi, lekin bu normal - nusxalash davom etadi.
    echo.
)

if !SRC_GB! GTR !FREE_GB! (
    echo  ============================================================================
    echo  [W] DIQQAT: ma'lumotlar fleshkaga sig'maydi!
    echo      Kerak: !SRC_GB! GB, bor: !FREE_GB! GB
    echo  ============================================================================
    echo.
    set "GOON="
    set /P GOON=  Baribir davom etilsinmi? [Y - ha]:
    if /I not "!GOON!"=="Y" (
        echo  [i] Bekor qilindi.
        pause
        exit /b 1
    )
    echo.
)

rem ============================================================
rem  5-QADAM: TASDIQLASH
rem ============================================================
echo  ============================================================================
echo    5-QADAM: BOSHLAYMIZMI?
echo  ============================================================================
echo.
echo    Nimadan:  !SRC!
echo    Qayerga:  !DST!\Backup_!UNAME!_*
echo.
echo    Nusxalanadi: Desktop, Documents, Pictures, Videos, Music,
echo                 Downloads, AppData, brauzer xatcho'plari, Outlook,
echo                 SSH, RDP, shriftlar, Wi-Fi parollari va h.k.
echo.
set "START="
set /P START=  Boshlash uchun Y bosing:
if /I not "!START!"=="Y" (
    echo  [i] Bekor qilindi.
    pause
    exit /b 0
)
echo.

rem ============================================================
rem  ZAXIRA PAPKASI
rem ============================================================
set "STAMP="
for /f "usebackq delims=" %%i in (`wmic os get localdatetime /value 2^>nul ^| find "="`) do (
    for /f "tokens=2 delims==" %%v in ("%%i") do set "DT=%%v"
)
if defined DT (
    set "STAMP=_!DT:~0,8!_!DT:~8,4!"
) else (
    set "RAW=%DATE%_%TIME%"
    set "RAW=!RAW: =0!"
    set "RAW=!RAW::=!"
    set "RAW=!RAW:/=!"
    set "RAW=!RAW:.=!"
    set "STAMP=_!RAW:~0,13!"
)

set "BACKUP=!DST!\Backup_%UNAME%%STAMP%"
mkdir "%BACKUP%" 2>nul
mkdir "%BACKUP%\_SystemInfo" 2>nul
set "LOG=%BACKUP%\_backup.log"
set "SUMMARY=%BACKUP%\_summary.txt"
set "REPORT=%BACKUP%\report.html"

echo  ============================================================================
echo    NUSXALASH BOSHLANDI
echo  ============================================================================
echo    Papka: %BACKUP%
echo  ============================================================================
echo.

> "%SUMMARY%" echo WinPE Backup Summary
>> "%SUMMARY%" echo ====================
>> "%SUMMARY%" echo Manba:     !SRC!
>> "%SUMMARY%" echo Zaxira:    %BACKUP%
>> "%SUMMARY%" echo Boshlandi: %DATE% %TIME%
>> "%SUMMARY%" echo.

rem Ekranda faqat fayl nomlari: foiz, "Yangi fayl", hajm va robocopy sarlavhalarisiz
set "RCF=/E /R:0 /W:0 /MT:16 /XJ /NDL /NC /NS /NP /NJH /NJS /TEE /LOG+:"%LOG%""
set STEP=0
set TOTAL=12
set "DISK_FULL="
set "FULL_WARNED="

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

call :header "Qo'shimcha: xatcho'plar, Outlook, SSH, RDP, shriftlar" "!SRC!"
call :bookmark "!SRC!\AppData\Local\Google\Chrome\User Data\Default\Bookmarks" "Chrome_Bookmarks"
call :bookmark "!SRC!\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks" "Edge_Bookmarks"
call :bookmark "!SRC!\AppData\Roaming\Mozilla\Firefox\Profiles" "Firefox_Profiles"

call :outlook_data
call :rdp_files
call :ssh_keys
call :user_fonts
call :sticky_notes
call :hosts_file
call :header "Tizim ma'lumotlari va hisobot" "%BACKUP%\_SystemInfo"
call :collect_sysinfo
call :make_html_report

>> "%SUMMARY%" echo.
>> "%SUMMARY%" echo Tugadi: %DATE% %TIME%

title TAYYOR - WinPE Backup
echo.
echo  ============================================================================
echo    TAYYOR!
echo  ============================================================================
echo.
type "%SUMMARY%"
echo.
echo  ============================================================================
echo    Papka:   %BACKUP%
echo    Hisobot: %REPORT%
echo  ============================================================================
echo.
pause
exit /b 0

rem ===========================================================================
rem  Disk ma'lumotlarini yig'ish (INFO_1, INFO_2, ... o'zgaruvchilari)
rem ===========================================================================

:gather_disk
set "GN=%~1"
call set "GL=%%DRV_!GN!%%"

set "GVN="
set "GFS="
set "GSZ="
set "GTP="
rem Ichki "for /f" wmic qo'shadigan oxirgi CR belgisini olib tashlaydi
for /f "usebackq tokens=2 delims==" %%V in (`wmic logicaldisk where "DeviceID='!GL!'" get VolumeName /value 2^>nul ^| find "="`) do for /f "delims=" %%x in ("%%V") do set "GVN=%%x"
for /f "usebackq tokens=2 delims==" %%S in (`wmic logicaldisk where "DeviceID='!GL!'" get FreeSpace /value 2^>nul ^| find "="`) do for /f "delims=" %%x in ("%%S") do set "GFS=%%x"
for /f "usebackq tokens=2 delims==" %%Z in (`wmic logicaldisk where "DeviceID='!GL!'" get Size /value 2^>nul ^| find "="`) do for /f "delims=" %%x in ("%%Z") do set "GSZ=%%x"
for /f "usebackq tokens=2 delims==" %%T in (`wmic logicaldisk where "DeviceID='!GL!'" get DriveType /value 2^>nul ^| find "="`) do for /f "delims=" %%x in ("%%T") do set "GTP=%%x"

rem GB konversiya
set "GFS_GB=?"
if defined GFS if not "!GFS!"=="" (
    set "TT=!GFS:~0,-9!"
    if "!TT!"=="" set "TT=0"
    set "GFS_GB=!TT!"
)
set "GSZ_GB=?"
if defined GSZ if not "!GSZ!"=="" (
    set "TT=!GSZ:~0,-9!"
    if "!TT!"=="" set "TT=0"
    set "GSZ_GB=!TT!"
)

rem Tip
set "GTP_NAME=?                "
if "!GTP!"=="2" set "GTP_NAME=Fleshka (Removable)"
if "!GTP!"=="3" set "GTP_NAME=Qattiq disk        "
if "!GTP!"=="4" set "GTP_NAME=Tarmoq diski       "
if "!GTP!"=="5" set "GTP_NAME=CD/DVD             "
if "!GTP!"=="6" set "GTP_NAME=RAM disk           "

if not defined GVN set "GVN=<nomsiz>"
if "!GVN!"=="" set "GVN=<nomsiz>"

if /I "!GL!"=="X:" (
    set "SZ_1=!GSZ_GB!"
    set "SZ_2=!GFS_GB!"
    set "INFO_!GN!=!GL!    !SZ_1! GB  !SZ_2! GB  WinPE ichki         -"
) else (
    set "SZ_1=!GSZ_GB!"
    set "SZ_2=!GFS_GB!"
    set "INFO_!GN!=!GL!    !SZ_1! GB  !SZ_2! GB  !GTP_NAME! !GVN!"
)
exit /b 0

:show_disk
set "SN=%~1"
call set "SI=%%INFO_!SN!%%"
echo    [!SN!]  !SI!
exit /b 0

rem ===========================================================================
rem                        NUSXALASH FUNKSIYALARI
rem ===========================================================================

:header
set /A STEP+=1
title [!STEP!/%TOTAL%] %~1 - WinPE Backup
echo.
echo  ============================================================================
echo    [!STEP!/%TOTAL%] %~1
echo    %~2
echo  ============================================================================
exit /b 0

:can_copy
if not exist "%~2" (
    echo    [i] Papka yo'q - o'tkazib yuborildi.
    >> "%SUMMARY%" echo [skip] %~1
    exit /b 1
)
if defined DISK_FULL (
    echo    [W] Fleshkada joy yo'q - o'tkazib yuborildi.
    >> "%SUMMARY%" echo [skip] %~1 - joy yo'q
    exit /b 1
)
exit /b 0

:result
set "RN=%~1"
set "RRC=%~2"
call :check_space
if %RRC% GEQ 8 (
    echo    [W] %RN%: xatolar bor, kod %RRC% - _backup.log faylini ko'ring.
    >> "%SUMMARY%" echo [xato] %RN% - kod %RRC%
) else (
    echo    [OK] %RN% nusxalandi.
    >> "%SUMMARY%" echo [ok]   %RN%
)
if defined DISK_FULL if not defined FULL_WARNED (
    set FULL_WARNED=1
    echo.
    echo  ============================================================================
    echo    [W] FLESHKADA JOY TUGADI
    echo        Qolgan papkalar o'tkazib yuboriladi.
    echo  ============================================================================
)
exit /b 0

:check_space
rem 100 MB dan kam qolsa (9 raqamdan qisqa son) - fleshka to'lgan deb hisoblaymiz
set "CS_FREE="
for /f "usebackq tokens=2 delims==" %%S in (`wmic logicaldisk where "DeviceID='!DST!'" get FreeSpace /value 2^>nul ^| find "="`) do for /f "delims=" %%x in ("%%S") do set "CS_FREE=%%x"
if not defined CS_FREE exit /b 0
if "!CS_FREE:~8,1!"=="" set "DISK_FULL=1"
exit /b 0

:sect
set "SNAME=%~1"
set "SPATH=%~2"
call :header "%SNAME%" "%SPATH%"
call :can_copy "%SNAME%" "%SPATH%" || exit /b 0
robocopy "%SPATH%" "%BACKUP%\%SNAME%" %RCF% /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "$Recycle.Bin" "System Volume Information" "node_modules" "__pycache__" ".venv" "venv" "pip" "pip-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.temp" "*.log1" "*.log2" "*.etl" "*.lock"
call :result "%SNAME%" %ERRORLEVEL%
exit /b 0

:downloads
set "SPATH=%~1"
call :header "Downloads - o'rnatuvchi fayllarsiz" "%SPATH%"
call :can_copy "Downloads" "%SPATH%" || exit /b 0
robocopy "%SPATH%" "%BACKUP%\Downloads" %RCF% /XD "Cache" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.exe" "*.msi" "*.msix" "*.msixbundle" "*.appx" "*.appxbundle" "*.iso" "*.img" "*.vhd" "*.vhdx" "*.dmg" "*.pkg" "*.deb" "*.rpm"
call :result "Downloads" %ERRORLEVEL%
exit /b 0

:roaming
set "SPATH=%~1"
call :header "AppData\Roaming - dastur sozlamalari" "%SPATH%"
call :can_copy "AppData\Roaming" "%SPATH%" || exit /b 0
robocopy "%SPATH%" "%BACKUP%\AppData_Roaming" %RCF% /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock"
call :result "AppData\Roaming" %ERRORLEVEL%
exit /b 0

:local
set "SPATH=%~1"
call :header "AppData\Local - dastur ma'lumotlari" "%SPATH%"
call :can_copy "AppData\Local" "%SPATH%" || exit /b 0
robocopy "%SPATH%" "%BACKUP%\AppData_Local" %RCF% /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "D3DSCache" "Packages" "PackageStaging" "SquirrelTemp" "WebCache" "INetCache" "INetCookies" "History" "NVIDIA" "NVIDIA Corporation" "AMD" "Intel" "ConnectedDevicesPlatform" "pnpm-cache" "yarn-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock"
call :result "AppData\Local" %ERRORLEVEL%
exit /b 0

:bookmark
set "BPATH=%~1"
set "BNAME=%~2"
if not exist "%BPATH%" exit /b 0
echo.
echo    - %BNAME%
mkdir "%BACKUP%\_Bookmarks" 2>nul
if exist "%BPATH%\*" (
    robocopy "%BPATH%" "%BACKUP%\_Bookmarks\%BNAME%" /E /R:1 /W:1 /XJ /NFL /NDL /NP /NJH /NJS /LOG+:"%LOG%"
) else (
    copy /Y "%BPATH%" "%BACKUP%\_Bookmarks\%BNAME%" >nul 2>&1
)
>> "%SUMMARY%" echo [ok]   %BNAME%
exit /b 0

:outlook_data
echo.
echo    - Outlook
mkdir "%BACKUP%\_Outlook" 2>nul
set FOUND=0
for %%P in ("!SRC!\Documents\Outlook Files" "!SRC!\AppData\Local\Microsoft\Outlook" "!SRC!\AppData\Roaming\Microsoft\Outlook") do (
    if exist %%P (
        robocopy %%P "%BACKUP%\_Outlook" *.pst *.ost *.nst /S /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /LOG+:"%LOG%"
        set FOUND=1
    )
)
if !FOUND!==1 (>> "%SUMMARY%" echo [ok]   Outlook) else (>> "%SUMMARY%" echo [skip] Outlook)
exit /b 0

:rdp_files
echo.
echo    - RDP
mkdir "%BACKUP%\_RDP" 2>nul
if exist "!SRC!\Documents\*.rdp" copy /Y "!SRC!\Documents\*.rdp" "%BACKUP%\_RDP\" >nul 2>&1
if exist "!SRC!\AppData\Local\Microsoft\Remote Desktop" robocopy "!SRC!\AppData\Local\Microsoft\Remote Desktop" "%BACKUP%\_RDP\RD_App" /E /R:1 /W:1 /NFL /NDL /NP >nul
>> "%SUMMARY%" echo [ok]   RDP
exit /b 0

:ssh_keys
echo.
echo    - SSH
if exist "!SRC!\.ssh" (
    robocopy "!SRC!\.ssh" "%BACKUP%\_SSH" /E /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /LOG+:"%LOG%"
    >> "%SUMMARY%" echo [ok]   .ssh
) else (
    >> "%SUMMARY%" echo [skip] .ssh
)
if defined SYS_DRIVE (
    set "NTUSER=!SRC!\NTUSER.DAT"
    if exist "!NTUSER!" (
        reg load HKU\OFFLINE_USER "!NTUSER!" >nul 2>&1
        if not errorlevel 1 (
            reg export "HKU\OFFLINE_USER\Software\SimonTatham" "%BACKUP%\_SSH\putty_sessions.reg" /y >nul 2>&1
            reg unload HKU\OFFLINE_USER >nul 2>&1
        )
    )
)
exit /b 0

:user_fonts
echo.
echo    - Shriftlar
if exist "!SRC!\AppData\Local\Microsoft\Windows\Fonts" (
    robocopy "!SRC!\AppData\Local\Microsoft\Windows\Fonts" "%BACKUP%\_UserFonts" /E /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /LOG+:"%LOG%"
    >> "%SUMMARY%" echo [ok]   shriftlar
) else (
    >> "%SUMMARY%" echo [skip] shriftlar
)
exit /b 0

:sticky_notes
echo.
echo    - Sticky Notes
for /D %%P in ("!SRC!\AppData\Local\Packages\Microsoft.MicrosoftStickyNotes_*") do (
    if exist "%%P\LocalState" robocopy "%%P\LocalState" "%BACKUP%\_StickyNotes\Modern" /E /R:1 /W:1 /NFL /NDL /NP >nul
)
if exist "!SRC!\AppData\Roaming\Microsoft\Sticky Notes" robocopy "!SRC!\AppData\Roaming\Microsoft\Sticky Notes" "%BACKUP%\_StickyNotes\Legacy" /E /R:1 /W:1 /NFL /NDL /NP >nul
>> "%SUMMARY%" echo [ok]   stikerlar
exit /b 0

:hosts_file
echo.
echo    - hosts
if defined SYS_DRIVE (
    set "HOSTS=!SYS_DRIVE!\Windows\System32\drivers\etc\hosts"
    if exist "!HOSTS!" (
        copy /Y "!HOSTS!" "%BACKUP%\_SystemInfo\hosts" >nul 2>&1
        >> "%SUMMARY%" echo [ok]   hosts
    )
)
exit /b 0

:collect_sysinfo
echo.
echo    - O'rnatilgan dasturlar, Wi-Fi, Windows kaliti
set "SI=%BACKUP%\_SystemInfo"

set "APPS_TXT=%SI%\installed_programs.txt"
> "%APPS_TXT%" echo O'rnatilgan dasturlar
>> "%APPS_TXT%" echo ====================
echo. >> "%APPS_TXT%"

if defined SYS_DRIVE (
    set "HIVE=!SYS_DRIVE!\Windows\System32\config\SOFTWARE"
    if exist "!HIVE!" (
        reg load HKLM\OFFLINE_SW "!HIVE!" >nul 2>&1
        if not errorlevel 1 (
            for /f "tokens=*" %%K in ('reg query "HKLM\OFFLINE_SW\Microsoft\Windows\CurrentVersion\Uninstall" 2^>nul') do (
                for /f "tokens=2,*" %%A in ('reg query "%%K" /v DisplayName 2^>nul ^| find "REG_SZ"') do (
                    >> "%APPS_TXT%" echo %%B
                )
            )
            for /f "tokens=*" %%K in ('reg query "HKLM\OFFLINE_SW\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" 2^>nul') do (
                for /f "tokens=2,*" %%A in ('reg query "%%K" /v DisplayName 2^>nul ^| find "REG_SZ"') do (
                    >> "%APPS_TXT%" echo %%B
                )
            )
            reg unload HKLM\OFFLINE_SW >nul 2>&1
        )
    )
)
>> "%SUMMARY%" echo [ok]   dasturlar

set "WIFI_DIR=%SI%\WiFi"
mkdir "%WIFI_DIR%" 2>nul
netsh wlan show profiles >nul 2>&1
if not errorlevel 1 (
    netsh wlan export profile key=clear folder="%WIFI_DIR%" >nul 2>&1
) else (
    if defined SYS_DRIVE (
        set "WLAN_SRC=!SYS_DRIVE!\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces"
        if exist "!WLAN_SRC!" robocopy "!WLAN_SRC!" "%WIFI_DIR%\RawProfiles" /E /R:1 /W:1 /NFL /NDL /NP >nul
    )
)
>> "%SUMMARY%" echo [ok]   Wi-Fi

set "KEY_TXT=%SI%\windows_product_key.txt"
> "%KEY_TXT%" echo Windows Product Key
echo. >> "%KEY_TXT%"
for /f "usebackq tokens=2 delims==" %%K in (`wmic path softwarelicensingservice get OA3xOriginalProductKey /value 2^>nul ^| find "="`) do (
    >> "%KEY_TXT%" echo OEM Key: %%K
)
>> "%SUMMARY%" echo [ok]   Windows kaliti


set "HW=%SI%\hardware.txt"
> "%HW%" echo Hardware
echo. >> "%HW%"
echo --- CPU --- >> "%HW%"
wmic cpu get Name,NumberOfCores,MaxClockSpeed /format:list 2>nul >> "%HW%"
echo --- RAM --- >> "%HW%"
wmic memorychip get Capacity,Speed,Manufacturer /format:list 2>nul >> "%HW%"
echo --- GPU --- >> "%HW%"
wmic path win32_videocontroller get Name,AdapterRAM /format:list 2>nul >> "%HW%"
echo --- Disks --- >> "%HW%"
wmic diskdrive get Model,Size /format:list 2>nul >> "%HW%"
echo --- BIOS --- >> "%HW%"
wmic bios get Manufacturer,SMBIOSBIOSVersion,ReleaseDate /format:list 2>nul >> "%HW%"
>> "%SUMMARY%" echo [ok]   hardware
exit /b 0

:make_html_report
echo.
echo    - HTML hisobot
set "TMP_STATS=%BACKUP%\_stats.tmp"
> "%TMP_STATS%" echo.

call :count_cat "Documents" "pdf doc docx odt rtf txt md xls xlsx ods csv ppt pptx odp"
call :count_cat "Images" "jpg jpeg png gif bmp tiff tif webp svg heic"
call :count_cat "Videos" "mp4 mkv avi mov wmv flv webm m4v mpg mpeg 3gp"
call :count_cat "Audio" "mp3 wav flac aac ogg m4a wma opus"
call :count_cat "Archives" "zip rar 7z tar gz bz2 xz iso"
call :count_cat "Code" "py js ts java c cpp h hpp cs go rs rb php html css sql sh ps1 ipynb"
call :count_cat "Executables" "exe msi msix appx bat cmd ps1 app"

> "%REPORT%" echo ^<!DOCTYPE html^>
>> "%REPORT%" echo ^<html lang="uz"^>^<head^>^<meta charset="UTF-8"^>
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
>> "%REPORT%" echo .bar{background:#334155;height:8px;border-radius:4px;overflow:hidden;margin-top:.75rem}
>> "%REPORT%" echo .bar div{background:linear-gradient(90deg,#60a5fa,#a78bfa);height:100%%}
>> "%REPORT%" echo table{width:100%%;border-collapse:collapse;margin:1rem 0}
>> "%REPORT%" echo th,td{text-align:left;padding:.6rem;border-bottom:1px solid #334155}
>> "%REPORT%" echo th{background:#1e293b;color:#93c5fd}
>> "%REPORT%" echo ^</style^>^</head^>^<body^>^<div class="container"^>
>> "%REPORT%" echo ^<h1^>Backup Report^</h1^>
>> "%REPORT%" echo ^<div class="meta"^>
>> "%REPORT%" echo ^<b^>Foydalanuvchi:^</b^> %UNAME%^<br^>
>> "%REPORT%" echo ^<b^>Manba:^</b^> !SRC!^<br^>
>> "%REPORT%" echo ^<b^>Zaxira:^</b^> %BACKUP%^<br^>
>> "%REPORT%" echo ^<b^>Sana:^</b^> %DATE% %TIME%^<br^>
>> "%REPORT%" echo ^</div^>
>> "%REPORT%" echo ^<h2^>Fayllar toifalari^</h2^>
>> "%REPORT%" echo ^<div class="grid"^>

set MAXCOUNT=0
for /f "tokens=1,2 delims=|" %%A in (%TMP_STATS%) do if %%B GTR !MAXCOUNT! set MAXCOUNT=%%B
if !MAXCOUNT!==0 set MAXCOUNT=1

for /f "tokens=1,2 delims=|" %%A in (%TMP_STATS%) do (
    set /A PCT=%%B*100/!MAXCOUNT!
    >> "%REPORT%" echo ^<div class="card"^>^<div class="name"^>%%A^</div^>^<div class="count"^>%%B^</div^>^<div class="bar"^>^<div style="width:!PCT!%%"^>^</div^>^</div^>^</div^>
)
>> "%REPORT%" echo ^</div^>

>> "%REPORT%" echo ^<h2^>Zaxira tarkibi^</h2^>
>> "%REPORT%" echo ^<table^>^<tr^>^<th^>Papka^</th^>^</tr^>
for /D %%D in ("%BACKUP%\*") do >> "%REPORT%" echo ^<tr^>^<td^>%%~nxD^</td^>^</tr^>
>> "%REPORT%" echo ^</table^>
>> "%REPORT%" echo ^</div^>^</body^>^</html^>

del "%TMP_STATS%" 2>nul
>> "%SUMMARY%" echo [ok]   HTML
exit /b 0

:count_cat
set "CAT=%~1"
set "EXTS=%~2"
set CFILES=0
for %%E in (%EXTS%) do (
    for /f %%N in ('dir "%BACKUP%\*.%%E" /s /a-d /b 2^>nul ^| find /c /v ""') do set /A CFILES+=%%N
)
>> "%TMP_STATS%" echo %CAT%^|!CFILES!
exit /b 0
