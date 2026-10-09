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
echo  [*] Hajm hisoblanmoqda - istisnolar hisobga olinadi (1-3 daqiqa)...

rem --- Istisnolar: nusxalashda ham, hajm hisobida ham bir xil ---
set "X_STD=/XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "$Recycle.Bin" "System Volume Information" "node_modules" "__pycache__" ".venv" "venv" "pip" "pip-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.temp" "*.log1" "*.log2" "*.etl" "*.lock""
set "X_DL=/XD "Cache" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.exe" "*.msi" "*.msix" "*.msixbundle" "*.appx" "*.appxbundle" "*.iso" "*.img" "*.vhd" "*.vhdx" "*.dmg" "*.pkg" "*.deb" "*.rpm""
set "X_ROAM=/XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock""
set "X_LOCAL=/XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "D3DSCache" "Packages" "PackageStaging" "SquirrelTemp" "WebCache" "INetCache" "INetCookies" "History" "NVIDIA" "NVIDIA Corporation" "AMD" "Intel" "ConnectedDevicesPlatform" "pnpm-cache" "yarn-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock""

rem --- Papkalar ro'yxati: nom, manba, zaxiradagi papka, istisnolar ---
set NSEC=0
call :addsec "Desktop"         "Desktop"          "Desktop"          X_STD
call :addsec "Documents"       "Documents"        "Documents"        X_STD
call :addsec "Pictures"        "Pictures"         "Pictures"         X_STD
call :addsec "Videos"          "Videos"           "Videos"           X_STD
call :addsec "Music"           "Music"            "Music"            X_STD
call :addsec "Favorites"       "Favorites"        "Favorites"        X_STD
call :addsec "Links"           "Links"            "Links"            X_STD
call :addsec "Downloads"       "Downloads"        "Downloads"        X_DL
call :addsec "AppData\Roaming" "AppData\Roaming"  "AppData_Roaming"  X_ROAM
call :addsec "AppData\Local"   "AppData\Local"    "AppData_Local"    X_LOCAL

set TOTAL_MB=0
for /L %%I in (1,1,%NSEC%) do call :measure_sec %%I

call :free_mb
set "FREE_MB=0"
if defined FREE_NOW_MB set "FREE_MB=!FREE_NOW_MB!"
set /A TOTAL_GB=TOTAL_MB/1000

echo.
echo    #   Papka                  Hajm, MB   Holat
echo    --  ---------------------  ---------  ----------------
for /L %%I in (1,1,%NSEC%) do call :draw_row %%I
echo.
echo    Jami:                 !TOTAL_MB! MB  - taxminan !TOTAL_GB! GB
echo    Fleshkada bo'sh joy:  !FREE_MB! MB
echo.

if !TOTAL_MB! GTR !FREE_MB! (
    echo  ============================================================================
    echo  [W] DIQQAT: ma'lumotlar fleshkaga sig'maydi
    echo      Kerak: !TOTAL_MB! MB, bor: !FREE_MB! MB
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

> "%SUMMARY%" echo WinPE Backup Summary
>> "%SUMMARY%" echo ====================
>> "%SUMMARY%" echo Manba:     !SRC!
>> "%SUMMARY%" echo Zaxira:    %BACKUP%
>> "%SUMMARY%" echo Boshlandi: %DATE% %TIME%
>> "%SUMMARY%" echo.

rem robocopy fonda ishlaydi va faqat jurnalga yozadi; ekranda har ~2 soniyada jadval yangilanadi
set "WORKER=%BACKUP%\_wb_worker.cmd"
set "RCFILE=%BACKUP%\_wb_rc.txt"
set "DISK_FULL="
set DONE_MB=0
set CUR_MB=0
set CUR=0
set "CNAME=-"
call :now_sec START_S

for /L %%I in (1,1,%NSEC%) do call :run_sec %%I

set CUR_MB=0
set "CNAME=Qo'shimcha ma'lumotlar"
call :draw
echo.
echo    [*] Xatcho'plar, Outlook, SSH, RDP, shriftlar, tizim ma'lumotlari...
call :bookmark "!SRC!\AppData\Local\Google\Chrome\User Data\Default\Bookmarks" "Chrome_Bookmarks"
call :bookmark "!SRC!\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks" "Edge_Bookmarks"
call :bookmark "!SRC!\AppData\Roaming\Mozilla\Firefox\Profiles" "Firefox_Profiles"

call :outlook_data
call :rdp_files
call :ssh_keys
call :user_fonts
call :sticky_notes
call :hosts_file
call :collect_sysinfo
call :make_html_report
del "%WORKER%" "%RCFILE%" 2>nul

>> "%SUMMARY%" echo.
>> "%SUMMARY%" echo Tugadi: %DATE% %TIME%

set "CNAME=TAYYOR"
call :draw
title TAYYOR - WinPE Backup
echo.
echo    Papka:    %BACKUP%
echo    Hisobot:  %REPORT%
echo    Natija:   _summary.txt
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

:addsec
rem %1 nom, %2 profildagi papka, %3 zaxiradagi papka, %4 istisnolar o'zgaruvchisi
set /A NSEC+=1
set "S_NAME_!NSEC!=%~1"
set "S_SRC_!NSEC!=!SRC!\%~2"
set "S_DST_!NSEC!=%~3"
set "S_X_!NSEC!=!%~4!"
set "S_MB_!NSEC!=0"
set "S_ST_!NSEC!=kutilmoqda"
exit /b 0

:measure_sec
set "MI=%~1"
for %%i in (!MI!) do (
    set "MSRC=!S_SRC_%%i!"
    set "RCX=!S_X_%%i!"
)
if not exist "!MSRC!\" (
    set "S_ST_!MI!=yo'q"
    exit /b 0
)
call :rc_mb "!MSRC!"
set "S_MB_!MI!=!RC_MB!"
set /A TOTAL_MB+=RC_MB
exit /b 0

:rc_mb
rem Papka hajmi MB da (robocopy /L, RCX - istisnolar). Til mustaqil:
rem yakuniy jadvalning 3-qatori - baytlar (Dirs, Files, Bytes), 2-ustun "Copied":
rem 1-ustun "Total" /XF bilan chiqarilgan fayllarni ham hisoblaydi
set "RC_MB=0"
set "RC_B="
set RC_ROW=0
for /f "tokens=1* delims=:" %%A in ('robocopy "%~1" NULL /L /E /BYTES /NFL /NDL /NJH /NC /NS /XJ /R:0 /W:0 !RCX! 2^>nul ^| find " : "') do (
    set /A RC_ROW+=1
    if !RC_ROW!==3 for /f "tokens=2" %%N in ("%%B") do set "RC_B=%%N"
)
if defined RC_B set "RC_MB=!RC_B:~0,-6!"
if "!RC_MB!"=="" set "RC_MB=0"
exit /b 0

:free_mb
rem Fleshkadagi bo'sh joy MB da; wmic bo'lmasa FREE_NOW_MB aniqlanmaydi
set "FREE_NOW_MB="
set "FB="
for /f "usebackq tokens=2 delims==" %%S in (`wmic logicaldisk where "DeviceID='!DST!'" get FreeSpace /value 2^>nul ^| find "="`) do for /f "delims=" %%x in ("%%S") do set "FB=%%x"
if not defined FB exit /b 0
set "FREE_NOW_MB=!FB:~0,-6!"
if "!FREE_NOW_MB!"=="" set "FREE_NOW_MB=0"
exit /b 0

:now_sec
set "T=%TIME: =0%"
set /A "NS=(1%T:~0,2%-100)*3600+(1%T:~3,2%-100)*60+(1%T:~6,2%-100)"
set "%~1=%NS%"
exit /b 0

:fmt_hms
set /A "FH=%~1/3600, FM=(%~1/60)%%60, FS=%~1%%60"
set "FH=0%FH%"
set "FM=0%FM%"
set "FS=0%FS%"
set "%~2=%FH:~-2%:%FM:~-2%:%FS:~-2%"
exit /b 0

:run_sec
set "CUR=%~1"
for %%i in (!CUR!) do (
    set "CNAME=!S_NAME_%%i!"
    set "CSRC=!S_SRC_%%i!"
    set "CDST=%BACKUP%\!S_DST_%%i!"
    set "CX=!S_X_%%i!"
    set "CPLAN=!S_MB_%%i!"
    set "CST=!S_ST_%%i!"
)
if "!CST!"=="yo'q" (
    >> "%SUMMARY%" echo [skip] !CNAME!
    exit /b 0
)
if defined DISK_FULL (
    set "S_ST_!CUR!=joy yo'q"
    >> "%SUMMARY%" echo [skip] !CNAME! - joy yo'q
    exit /b 0
)
set "S_ST_!CUR!=nusxalanmoqda..."
set CUR_MB=0
call :free_mb
set "SEC_FREE0=!FREE_NOW_MB!"

del "%RCFILE%" 2>nul
> "%WORKER%" echo @echo off
>> "%WORKER%" echo robocopy "!CSRC!" "!CDST!" /E /R:0 /W:0 /MT:16 /XJ /NFL /NDL /NJH /NJS /NP /LOG+:"%LOG%" !CX! ^>nul 2^>^&1
>> "%WORKER%" echo ^> "%RCFILE%" echo %%ERRORLEVEL%%
start "" /b cmd /c call "%WORKER%"

:run_wait
call :measure_cur
call :draw
if exist "%RCFILE%" goto :run_done
ping -n 3 127.0.0.1 >nul 2>&1
goto :run_wait

:run_done
set "RRC="
set /p RRC=<"%RCFILE%"
if not defined RRC (
    ping -n 2 127.0.0.1 >nul 2>&1
    set /p RRC=<"%RCFILE%"
)
if not defined RRC set RRC=0
rem Tugagan papka hajmini aniq o'lchaymiz
set "RCX="
set "RC_MB=0"
if exist "!CDST!\" call :rc_mb "!CDST!"
set /A DONE_MB+=RC_MB
set CUR_MB=0
if !RRC! GEQ 8 (
    set "S_ST_!CUR!=xato, kod !RRC!"
    >> "%SUMMARY%" echo [xato] !CNAME! - kod !RRC!
) else (
    set "S_ST_!CUR!=tayyor"
    >> "%SUMMARY%" echo [ok]   !CNAME!
)
rem 100 MB dan kam qolsa - qolgan papkalar o'tkazib yuboriladi
call :free_mb
if defined FREE_NOW_MB if !FREE_NOW_MB! LSS 100 set "DISK_FULL=1"
exit /b 0

:measure_cur
rem wmic bo'lsa - tez usul: bo'sh joy qancha kamaygani; bo'lmasa - robocopy /L bilan
call :free_mb
if defined FREE_NOW_MB if defined SEC_FREE0 (
    set /A CUR_MB=SEC_FREE0-FREE_NOW_MB
    if !CUR_MB! LSS 0 set CUR_MB=0
    if !CUR_MB! GTR !CPLAN! set CUR_MB=!CPLAN!
    exit /b 0
)
set "RCX="
set "RC_MB=0"
if exist "!CDST!\" call :rc_mb "!CDST!"
set "CUR_MB=!RC_MB!"
exit /b 0

:draw
call :now_sec NOW_S
set /A EL=NOW_S-START_S
if !EL! LSS 0 set /A EL+=86400
set /A COPIED=DONE_MB+CUR_MB
set PCT=0
if !TOTAL_MB! GTR 0 set /A PCT=COPIED*100/TOTAL_MB
if !PCT! GTR 100 set PCT=100
set "SPD=-"
set "ETA=hisoblanmoqda..."
if !EL! GTR 0 if !COPIED! GTR 0 (
    set /A SP10=COPIED*10/EL
    set /A SPI=SP10/10, SPF=SP10%%10
    set "SPD=!SPI!.!SPF! MB/s"
    if !SP10! GTR 0 (
        set /A RMB=TOTAL_MB-COPIED
        if !RMB! LSS 0 set RMB=0
        set /A ETA_S=RMB*10/SP10
        call :fmt_hms !ETA_S! ETA
    )
)
call :fmt_hms !EL! ELT
set /A FILLED=PCT*40/100
set "BAR="
for /L %%b in (1,1,40) do if %%b LEQ !FILLED! (set "BAR=!BAR!#") else (set "BAR=!BAR!.")
title !PCT!%% - !CNAME! - WinPE Backup
cls
echo.
echo  ============================================================================
echo    ZAXIRALASH JARAYONI  -  !UNAME!
echo  ============================================================================
echo.
echo    Hozir:          [!CUR!/!NSEC!] !CNAME!
echo    Nusxalandi:     !COPIED! MB / !TOTAL_MB! MB   - !PCT!%%
echo    [!BAR!]
echo.
echo    Tezlik:         !SPD!
echo    O'tgan vaqt:    !ELT!
echo    Qolgan vaqt:    !ETA!
if defined FREE_NOW_MB echo    Fleshkada joy:  !FREE_NOW_MB! MB
echo.
echo    #   Papka                  Hajm, MB   Holat
echo    --  ---------------------  ---------  ----------------
for /L %%I in (1,1,!NSEC!) do call :draw_row %%I
echo  ============================================================================
exit /b 0

:draw_row
for %%i in (%~1) do (
    set "RN=!S_NAME_%%i!"
    set "RM=!S_MB_%%i!"
    set "RS=!S_ST_%%i!"
)
set "RN=!RN!                       "
set "RM=         !RM!"
set "RI=  %~1"
echo    !RI:~-2!  !RN:~0,21!  !RM:~-9!  !RS!
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
