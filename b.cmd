@echo off
rem ============================================================================
rem  b.cmd  -  WinPE Backup
rem  Barcha xabarlar o'zbekcha (lotin).
rem ============================================================================

setlocal EnableDelayedExpansion
set "SELF=%~f0"
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
rem Keshlar ham nusxalanadi; faqat vaqtinchalik fayllar, savat va (Downloads'da) o'rnatuvchilar chiqariladi
set "X_STD=/XD "$Recycle.Bin" "System Volume Information" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.temp""
set "X_DL=/XD "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.temp" "*.exe" "*.msi" "*.msix" "*.msixbundle" "*.appx" "*.appxbundle" "*.iso" "*.img" "*.vhd" "*.vhdx" "*.dmg" "*.pkg" "*.deb" "*.rpm""

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
call :addsec "AppData\Roaming" "AppData\Roaming"  "AppData_Roaming"  X_STD
call :addsec "AppData\Local"   "AppData\Local"    "AppData_Local"    X_STD
rem Profil ildizidagi qolgan hamma narsa (.cache, anaconda3, .vscode va h.k.) - yuqoridagi papkalarsiz
set "X_ROOT=/XD "!SRC!\Desktop" "!SRC!\Documents" "!SRC!\Pictures" "!SRC!\Videos" "!SRC!\Music" "!SRC!\Favorites" "!SRC!\Links" "!SRC!\Downloads" "!SRC!\AppData" "$Recycle.Bin" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.temp" "ntuser.*" "NTUSER.*""
call :addsec "Boshqa papkalar" ""                 "Profil_boshqa"    X_ROOT

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
rem Natijalar avval vaqtinchalik faylga yoziladi, oxirida _summary.txt UTF-8 da yig'iladi
set "SUMMARY=%BACKUP%\_wb_sum.tmp"
set "SUMFINAL=%BACKUP%\_summary.txt"
set "REPORT=%BACKUP%\report.html"
set "T_BEGIN=%DATE% %TIME:~0,8%"
type nul > "%SUMMARY%"
rem Jurnalni Unicode (UTF-16) qilib yaratamiz: /UNILOG+ yangi faylga oddiy kodlashda yozadi,
rem mavjud Unicode faylga esa Unicode da qo'shadi
robocopy "%BACKUP%" NULL _wb_nofile_ /L /NJH /NJS /UNILOG:"%LOG%" >nul 2>&1

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

call :now_sec END_S
set /A COPY_EL=END_S-START_S
if !COPY_EL! LSS 0 set /A COPY_EL+=86400
call :fmt_hms !COPY_EL! COPY_HMS
set "AVG_SPD=-"
if !COPY_EL! GTR 0 (
    set /A SP10=DONE_MB*10/COPY_EL
    set /A SPI=SP10/10, SPF=SP10%%10
    set "AVG_SPD=!SPI!.!SPF! MB/s"
)

set CUR_MB=0
set "CNAME=Qo'shimcha ma'lumotlar"
call :draw
echo.
echo    [*] Xatcho'plar, Outlook, SSH, RDP, shriftlar...
set SUM_LINES=0
for /f %%n in ('find /c /v "" ^< "%SUMMARY%"') do set SUM_LINES=%%n
call :bookmark "!SRC!\AppData\Local\Google\Chrome\User Data\Default\Bookmarks" "Chrome_Bookmarks"
call :bookmark "!SRC!\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks" "Edge_Bookmarks"
call :bookmark "!SRC!\AppData\Roaming\Mozilla\Firefox\Profiles" "Firefox_Profiles"

call :outlook_data
call :rdp_files
call :ssh_keys
call :user_fonts
call :sticky_notes
call :hosts_file

rem Hisobot va matn fayllari UTF-8 da yoziladi: aks holda Bloknot kirill harflarini buzadi.
rem Nusxalash tugagandan keyin almashtiriladi, shunda nusxalash qismiga ta'sir qilmaydi.
set "OLDCP="
for /f "tokens=2 delims=:." %%c in ('chcp') do set /A OLDCP=%%c
chcp 65001 >nul 2>&1
echo    [*] Tizim ma'lumotlari va HTML hisobot - 1-5 daqiqa...
call :collect_sysinfo
call :make_html_report
call :write_summary
del "%WORKER%" "%RCFILE%" "%SUMMARY%" 2>nul

set "CNAME=TAYYOR"
call :draw
title TAYYOR - WinPE Backup
echo.
echo    Papka:    %BACKUP%
echo    Hisobot:  %REPORT%   - brauzerda oching
echo    Natija:   _summary.txt
echo  ============================================================================
echo.
pause
if defined OLDCP chcp !OLDCP! >nul 2>&1
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
if "%~2"=="" set "S_SRC_!NSEC!=!SRC!"
set "S_DST_!NSEC!=%~3"
set "S_X_!NSEC!=!%~4!"
set "S_MB_!NSEC!=0"
set "S_CP_!NSEC!=0"
set "S_T_!NSEC!=0"
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
call :now_sec SEC_T0
call :free_mb
set "SEC_FREE0=!FREE_NOW_MB!"

del "%RCFILE%" 2>nul
> "%WORKER%" echo @echo off
>> "%WORKER%" echo robocopy "!CSRC!" "!CDST!" /E /R:0 /W:0 /MT:16 /XJ /NDL /NP /UNILOG+:"%LOG%" !CX! ^>nul 2^>^&1
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
set "S_CP_!CUR!=!RC_MB!"
call :now_sec SEC_T1
set /A SEC_DT=SEC_T1-SEC_T0
if !SEC_DT! LSS 0 set /A SEC_DT+=86400
set "S_T_!CUR!=!SEC_DT!"
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
    robocopy "%BPATH%" "%BACKUP%\_Bookmarks\%BNAME%" /E /R:1 /W:1 /XJ /NFL /NDL /NP /NJH /NJS /UNILOG+:"%LOG%"
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
        robocopy %%P "%BACKUP%\_Outlook" *.pst *.ost *.nst /S /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /UNILOG+:"%LOG%"
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
    robocopy "!SRC!\.ssh" "%BACKUP%\_SSH" /E /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /UNILOG+:"%LOG%"
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
    robocopy "!SRC!\AppData\Local\Microsoft\Windows\Fonts" "%BACKUP%\_UserFonts" /E /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /UNILOG+:"%LOG%"
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
set "SI=%BACKUP%\_SystemInfo"

rem --- O'rnatilgan dasturlar: WinPE da - Windows diskidagi reestrdan, oddiy Windows da - joriy reestrdan
set "APPS_TXT=%SI%\installed_programs.txt"
set "APPS_LI=%BACKUP%\_wb_apps.tmp"
> "%APPS_TXT%" echo O'rnatilgan dasturlar
>> "%APPS_TXT%" echo =====================
type nul > "%APPS_LI%"
set APPS_N=0
set "APPS_DONE="
if defined SYS_DRIVE if exist "!SYS_DRIVE!\Windows\System32\config\SOFTWARE" (
    reg load HKLM\OFFLINE_SW "!SYS_DRIVE!\Windows\System32\config\SOFTWARE" >nul 2>&1
    if not errorlevel 1 (
        call :apps_from "HKLM\OFFLINE_SW\Microsoft\Windows\CurrentVersion\Uninstall"
        call :apps_from "HKLM\OFFLINE_SW\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        reg unload HKLM\OFFLINE_SW >nul 2>&1
        set "APPS_DONE=1"
    )
)
if not defined APPS_DONE (
    call :apps_from "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    call :apps_from "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
>> "%SUMMARY%" echo [ok]   dasturlar

rem --- Wi-Fi profillari va tarmoq nomlari
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
set "WIFI_LIST="
for /r "%WIFI_DIR%" %%F in (*.xml) do call :wifi_name "%%F"
>> "%SUMMARY%" echo [ok]   Wi-Fi

rem --- Windows OEM kaliti
set "WKEY="
for /f "usebackq tokens=2 delims==" %%K in (`wmic path softwarelicensingservice get OA3xOriginalProductKey /value 2^>nul ^| find "="`) do for /f "tokens=*" %%x in ("%%K") do set "WKEY=%%x"
set "KEY_TXT=%SI%\windows_product_key.txt"
> "%KEY_TXT%" echo Windows OEM kaliti
if defined WKEY (
    >> "%KEY_TXT%" echo !WKEY!
    set "WKEY_M=*****-*****-*****-*****-!WKEY:~-5!"
    >> "%SUMMARY%" echo [ok]   Windows kaliti
) else (
    >> "%KEY_TXT%" echo topilmadi - WinPE da kalitni o'qib bo'lmaydi
    set "WKEY_M=topilmadi"
    >> "%SUMMARY%" echo [skip] Windows kaliti
)

rem --- Kompyuter haqida (wmic qiymatlari qatorma-qator olinadi: UTF-16 aralashmaydi)
call :wmi1 "computersystem" "Manufacturer" HW_MAN
call :wmi1 "computersystem" "Model" HW_MODEL
call :wmi1 "bios" "SerialNumber" HW_SERIAL
call :wmi1 "cpu" "Name" HW_CPU
call :wmi1 "cpu" "NumberOfCores" HW_CORES
call :wmi1 "cpu" "NumberOfLogicalProcessors" HW_THREADS
call :wmi1 "computersystem" "TotalPhysicalMemory" HW_RAMB
call :wmi_list "path win32_videocontroller" "Name" HW_GPU
call :disks
call :wmi1 "bios" "Manufacturer" HW_BIOSM
call :wmi1 "bios" "SMBIOSBIOSVersion" HW_BIOSV
call :wmi1 "bios" "ReleaseDate" HW_BIOSD
set "HW_RAM="
if defined HW_RAMB (
    set "NUMTMP=!HW_RAMB:~0,-6!"
    if "!NUMTMP!"=="" set "NUMTMP=0"
    rem baytlar/10^6 dan GiB ga: 1 GiB = 1073.74 * 10^6 bayt
    set /A "HW_RAMGB=(NUMTMP+537)/1074"
    set "HW_RAM=!HW_RAMGB! GB"
)
set "HW_BIOS=!HW_BIOSM! !HW_BIOSV!"
if defined HW_BIOSD set "HW_BIOS=!HW_BIOS!, !HW_BIOSD:~0,4!-!HW_BIOSD:~4,2!-!HW_BIOSD:~6,2!"
set "HW_CT="
if defined HW_CORES set "HW_CT=!HW_CORES! yadro / !HW_THREADS! oqim"

set "HW=%SI%\hardware.txt"
> "%HW%" echo Kompyuter haqida
>> "%HW%" echo ================
>> "%HW%" echo Ishlab chiqaruvchi: !HW_MAN!
>> "%HW%" echo Model:              !HW_MODEL!
>> "%HW%" echo Seriya raqami:      !HW_SERIAL!
>> "%HW%" echo Protsessor:         !HW_CPU!
>> "%HW%" echo Yadrolar:           !HW_CT!
>> "%HW%" echo Operativ xotira:    !HW_RAM!
>> "%HW%" echo Videokarta:         !HW_GPU!
>> "%HW%" echo Disklar:            !HW_DISKS!
>> "%HW%" echo BIOS:               !HW_BIOS!
>> "%SUMMARY%" echo [ok]   kompyuter ma'lumotlari
exit /b 0

:apps_from
for /f "tokens=*" %%K in ('reg query "%~1" 2^>nul') do (
    for /f "tokens=2,*" %%A in ('reg query "%%K" /v DisplayName 2^>nul ^| find "REG_SZ"') do (
        set "AN=%%B"
        >> "%APPS_TXT%" echo(!AN!
        call :esc AN
        >> "%APPS_LI%" echo ^<li^>!AN!^</li^>
        set /A APPS_N+=1
    )
)
exit /b 0

:wifi_name
set "SS="
for /f "usebackq delims=" %%L in (`type "%~1" 2^>nul ^| find "<name>"`) do if not defined SS set "SS=%%L"
if not defined SS exit /b 0
set "SS=!SS:<name>=!"
set "SS=!SS:</name>=!"
for /f "tokens=*" %%t in ("!SS!") do set "SS=%%t"
if defined WIFI_LIST (set "WIFI_LIST=!WIFI_LIST!, !SS!") else set "WIFI_LIST=!SS!"
exit /b 0

:wmi1
rem %1 wmic sinfi, %2 xususiyat, %3 natija o'zgaruvchisi - birinchi qiymat
set "%~3="
for /f "usebackq tokens=1* delims==" %%A in (`wmic %~1 get %~2 /value 2^>nul ^| find "="`) do (
    if not defined %~3 for /f "tokens=*" %%x in ("%%B") do set "%~3=%%x"
)
exit /b 0

:wmi_list
rem Barcha qiymatlar vergul bilan
set "%~3="
for /f "usebackq tokens=1* delims==" %%A in (`wmic %~1 get %~2 /value 2^>nul ^| find "="`) do for /f "tokens=*" %%x in ("%%B") do (
    if defined %~3 (set "%~3=!%~3!, %%x") else set "%~3=%%x"
)
exit /b 0

:disks
set "HW_DISKS="
set "DM="
for /f "usebackq tokens=1* delims==" %%A in (`wmic diskdrive get Model^,Size /value 2^>nul ^| find "="`) do for /f "tokens=*" %%x in ("%%B") do (
    if /I "%%A"=="Model" set "DM=%%x"
    if /I "%%A"=="Size" (
        set "DSZ=%%x"
        set "DSZ=!DSZ:~0,-9!"
        if "!DSZ!"=="" set "DSZ=0"
        if defined HW_DISKS (set "HW_DISKS=!HW_DISKS!; !DM! - !DSZ! GB") else set "HW_DISKS=!DM! - !DSZ! GB"
    )
)
exit /b 0

:esc
rem O'zgaruvchidagi & < > belgilarini HTML uchun xavfsiz qiladi
if not defined %~1 exit /b 0
set "EV=!%~1!"
set "EV=!EV:&=&amp;!"
set "EV=!EV:<=&lt;!"
set "EV=!EV:>=&gt;!"
set "%~1=!EV!"
exit /b 0

:rc_stats
rem Zaxiradagi CATF maskali fayllar: soni RS_FILES va hajmi RS_MB
set "RS_FILES=0"
set "RS_B="
set RC_ROW=0
for /f "tokens=1* delims=:" %%A in ('robocopy "%~1" NULL !CATF! /L /S /BYTES /NFL /NDL /NJH /NC /NS /XJ /R:0 /W:0 /XD "%~1\_SystemInfo" 2^>nul ^| find " : "') do (
    set /A RC_ROW+=1
    if !RC_ROW!==2 for /f "tokens=2" %%N in ("%%B") do set "RS_FILES=%%N"
    if !RC_ROW!==3 for /f "tokens=2" %%N in ("%%B") do set "RS_B=%%N"
)
set "RS_MB=0"
if defined RS_B set "RS_MB=!RS_B:~0,-6!"
if "!RS_MB!"=="" set "RS_MB=0"
exit /b 0

:cat
set /A NCAT+=1
set "C_NAME_!NCAT!=%~1"
set "CATF=%~2"
call :rc_stats "%BACKUP%"
set "C_N_!NCAT!=!RS_FILES!"
set "C_MB_!NCAT!=!RS_MB!"
exit /b 0

:make_html_report
set NCAT=0
call :cat "Hujjatlar" "*.pdf *.doc *.docx *.odt *.rtf *.txt *.md *.xls *.xlsx *.ods *.csv *.ppt *.pptx *.odp"
call :cat "Rasmlar"   "*.jpg *.jpeg *.png *.gif *.bmp *.tif *.tiff *.webp *.svg *.heic *.raw *.cr2 *.nef *.arw"
call :cat "Videolar"  "*.mp4 *.mkv *.avi *.mov *.wmv *.flv *.webm *.m4v *.mpg *.mpeg *.3gp"
call :cat "Audio"     "*.mp3 *.wav *.flac *.aac *.ogg *.m4a *.wma *.opus"
call :cat "Arxivlar"  "*.zip *.rar *.7z *.tar *.gz *.bz2 *.xz"
call :cat "Kod"       "*.py *.ipynb *.js *.ts *.java *.c *.cpp *.h *.hpp *.cs *.go *.rs *.rb *.php *.html *.css *.sql *.sh *.ps1"

set N_OK=0
set N_ALL=0
for /L %%I in (1,1,%NSEC%) do (
    if not "!S_ST_%%I!"=="yo'q" set /A N_ALL+=1
    if "!S_ST_%%I!"=="tayyor" set /A N_OK+=1
)
set /A GBI=DONE_MB/1000, GBF=(DONE_MB%%1000)/100
set "DONE_STR=!GBI!.!GBF! GB"
if !DONE_MB! LSS 1000 set "DONE_STR=!DONE_MB! MB"

set "HU=!UNAME!"
call :esc HU
set "HSRC=!SRC!"
call :esc HSRC
set "HBK=%BACKUP%"
call :esc HBK
for %%v in (HW_MAN HW_MODEL HW_SERIAL HW_CPU HW_GPU HW_DISKS HW_BIOS WIFI_LIST) do call :esc %%v

type nul > "%REPORT%"
call :emit HEAD
>> "%REPORT%" echo ^<h1^>Zaxira hisoboti^</h1^>
>> "%REPORT%" echo ^<p class='sub'^>!HU! - !HW_MAN! !HW_MODEL! - !T_BEGIN!^</p^>

>> "%REPORT%" echo ^<div class='kpis'^>
>> "%REPORT%" echo ^<div class='kpi'^>^<div class='l'^>Nusxalandi^</div^>^<div class='v'^>!DONE_STR!^</div^>^</div^>
>> "%REPORT%" echo ^<div class='kpi'^>^<div class='l'^>Sarflangan vaqt^</div^>^<div class='v'^>!COPY_HMS!^</div^>^</div^>
>> "%REPORT%" echo ^<div class='kpi'^>^<div class='l'^>O'rtacha tezlik^</div^>^<div class='v'^>!AVG_SPD!^</div^>^</div^>
>> "%REPORT%" echo ^<div class='kpi'^>^<div class='l'^>Tayyor papkalar^</div^>^<div class='v'^>!N_OK! / !N_ALL!^</div^>^</div^>
>> "%REPORT%" echo ^</div^>

>> "%REPORT%" echo ^<h2^>Papkalar^</h2^>
>> "%REPORT%" echo ^<div class='card'^>^<table^>^<tr^>^<th^>#^</th^>^<th^>Papka^</th^>^<th class='n'^>Reja, MB^</th^>^<th class='n'^>Nusxalandi, MB^</th^>^<th class='n'^>Vaqt^</th^>^<th^>Holat^</th^>^</tr^>
for /L %%I in (1,1,%NSEC%) do call :html_row %%I
>> "%REPORT%" echo ^</table^>^</div^>

>> "%REPORT%" echo ^<h2^>Fayl turlari^</h2^>
>> "%REPORT%" echo ^<div class='grid'^>
for /L %%I in (1,1,!NCAT!) do call :html_cat %%I
>> "%REPORT%" echo ^</div^>

>> "%REPORT%" echo ^<h2^>Qo'shimcha ma'lumotlar^</h2^>
>> "%REPORT%" echo ^<div class='card'^>^<table^>
set "SKIPOPT="
if !SUM_LINES! GTR 0 set "SKIPOPT=skip=!SUM_LINES!"
for /f "usebackq %SKIPOPT% tokens=1*" %%A in ("%SUMMARY%") do call :html_extra "%%A" "%%B"
>> "%REPORT%" echo ^</table^>^</div^>

>> "%REPORT%" echo ^<h2^>Kompyuter^</h2^>
>> "%REPORT%" echo ^<div class='card'^>^<div class='kv'^>
call :kv "Ishlab chiqaruvchi" HW_MAN
call :kv "Model" HW_MODEL
call :kv "Seriya raqami" HW_SERIAL
call :kv "Protsessor" HW_CPU
call :kv "Yadrolar" HW_CT
call :kv "Operativ xotira" HW_RAM
call :kv "Videokarta" HW_GPU
call :kv "Disklar" HW_DISKS
call :kv "BIOS" HW_BIOS
call :kv "Windows kaliti" WKEY_M
call :kv "Wi-Fi tarmoqlari" WIFI_LIST
>> "%REPORT%" echo ^</div^>^</div^>

>> "%REPORT%" echo ^<h2^>O'rnatilgan dasturlar - ^<span id='appcount'^>!APPS_N!^</span^>^</h2^>
>> "%REPORT%" echo ^<input id='q' type='search' placeholder='Qidirish...' autocomplete='off'^>
>> "%REPORT%" echo ^<div class='card'^>^<ul class='apps' id='apps'^>
if !APPS_N! GTR 0 (type "%APPS_LI%" >> "%REPORT%") else (>> "%REPORT%" echo ^<li^>Ro'yxat topilmadi^</li^>)
>> "%REPORT%" echo ^</ul^>^</div^>

>> "%REPORT%" echo ^<div class='foot'^>Manba: ^<code^>!HSRC!^</code^>^<br^>Zaxira: ^<code^>!HBK!^</code^>^<br^>Batafsil jurnal: ^<code^>_backup.log^</code^> - tizim fayllari: ^<code^>_SystemInfo^</code^>^</div^>
call :emit TAIL
del "%APPS_LI%" 2>nul
exit /b 0

:html_row
for %%i in (%~1) do (
    set "RN=!S_NAME_%%i!"
    set "RP=!S_MB_%%i!"
    set "RCP=!S_CP_%%i!"
    set "RS=!S_ST_%%i!"
    set "RT=!S_T_%%i!"
)
set "CLS=skip"
if "!RS!"=="tayyor" set "CLS=ok"
if "!RS:~0,4!"=="xato" set "CLS=err"
if "!RS!"=="joy yo'q" set "CLS=warn"
call :fmt_hms !RT! RTH
if "!CLS!"=="skip" (
    set "RTH=-"
    set "RCP=-"
)
>> "%REPORT%" echo ^<tr^>^<td^>%~1^</td^>^<td^>!RN!^</td^>^<td class='n'^>!RP!^</td^>^<td class='n'^>!RCP!^</td^>^<td class='n'^>!RTH!^</td^>^<td^>^<span class='b !CLS!'^>!RS!^</span^>^</td^>^</tr^>
exit /b 0

:html_cat
for %%i in (%~1) do (
    set "CN=!C_NAME_%%i!"
    set "CC=!C_N_%%i!"
    set "CM=!C_MB_%%i!"
)
set PW=0
if !DONE_MB! GTR 0 set /A PW=CM*100/DONE_MB
if !PW! GTR 100 set PW=100
if !PW! EQU 0 if !CM! GTR 0 set PW=1
>> "%REPORT%" echo ^<div class='kpi'^>^<div class='l'^>!CN!^</div^>^<div class='v'^>!CC!^</div^>^<div class='l'^>fayl, !CM! MB^</div^>^<div class='bar'^>^<i style='width:!PW!%%'^>^</i^>^</div^>^</div^>
exit /b 0

:html_extra
set "XS=%~1"
set "XN=%~2"
set "CLS=skip"
set "XT=o'tkazildi"
if "!XS!"=="[ok]" (
    set "CLS=ok"
    set "XT=tayyor"
)
if "!XS!"=="[xato]" (
    set "CLS=err"
    set "XT=xato"
)
call :esc XN
>> "%REPORT%" echo ^<tr^>^<td^>!XN!^</td^>^<td^>^<span class='b !CLS!'^>!XT!^</span^>^</td^>^</tr^>
exit /b 0

:kv
set "KV=!%~2!"
if not defined KV set "KV=-"
>> "%REPORT%" echo ^<div^>%~1^</div^>^<div^>!KV!^</div^>
exit /b 0

:emit
rem Shu faylning oxiridagi ::BEGIN_x ... ::END_x orasidagi HTML qatorlarini hisobotga yozadi
setlocal DisableDelayedExpansion
set "EMIT="
for /f "usebackq eol=` delims=" %%L in ("%SELF%") do (
    if "%%L"=="::END_%~1" set "EMIT="
    if defined EMIT >> "%REPORT%" echo(%%L
    if "%%L"=="::BEGIN_%~1" set "EMIT=1"
)
endlocal
exit /b 0

:write_summary
> "%SUMFINAL%" echo Zaxira natijasi
>> "%SUMFINAL%" echo ===============
>> "%SUMFINAL%" echo Foydalanuvchi: !UNAME!
>> "%SUMFINAL%" echo Manba:         !SRC!
>> "%SUMFINAL%" echo Zaxira:        %BACKUP%
>> "%SUMFINAL%" echo Boshlandi:     !T_BEGIN!
>> "%SUMFINAL%" echo Tugadi:        %DATE% %TIME:~0,8%
>> "%SUMFINAL%" echo Nusxalandi:    !DONE_MB! MB, vaqt !COPY_HMS!, o'rtacha tezlik !AVG_SPD!
>> "%SUMFINAL%" echo.
type "%SUMMARY%" >> "%SUMFINAL%"
exit /b 0

rem ===========================================================================
rem  HTML shabloni - bajarilmaydi, faqat :emit o'qiydi.
rem  Ichida qo'sh tirnoq ishlatilmaydi (faqat bittalik), qatorlar ; bilan boshlanmaydi.
rem ===========================================================================
::BEGIN_HEAD
<!DOCTYPE html>
<html lang='uz'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Zaxira hisoboti</title>
<style>
html{--bg:#f6f7f9;--card:#ffffff;--text:#1f2328;--muted:#656d76;--line:#d8dee4;--accent:#0969da;--ok:#1a7f37;--warn:#9a6700;--err:#cf222e;--skip:#6e7781}
@media (prefers-color-scheme:dark){html{--bg:#0d1117;--card:#161b22;--text:#e6edf3;--muted:#8d96a0;--line:#30363d;--accent:#4493f8;--ok:#3fb950;--warn:#d29922;--err:#f85149;--skip:#8d96a0}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.5 -apple-system,'Segoe UI',Roboto,Arial,sans-serif}
.wrap{max-width:1080px;margin:0 auto;padding:28px 16px 56px}
h1{font-size:28px;margin:0 0 4px;letter-spacing:-.01em}
h2{font-size:18px;margin:36px 0 12px}
.sub{color:var(--muted);margin:0 0 22px}
.kpis,.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
.kpi .l{color:var(--muted);font-size:13px}
.kpi .v{font-size:24px;font-weight:650;font-variant-numeric:tabular-nums;line-height:1.3}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:auto}
table{width:100%;border-collapse:collapse;font-variant-numeric:tabular-nums}
th,td{text-align:left;padding:9px 14px;border-bottom:1px solid var(--line);white-space:nowrap}
th{font-size:13px;color:var(--muted);font-weight:600}
tr:last-child td{border-bottom:0}
.n{text-align:right}
.b{display:inline-block;padding:1px 10px;border-radius:999px;font-size:12px;font-weight:600;border:1px solid currentColor}
.ok{color:var(--ok)}
.skip{color:var(--skip)}
.err{color:var(--err)}
.warn{color:var(--warn)}
.bar{height:6px;background:var(--line);border-radius:3px;overflow:hidden;margin-top:10px}
.bar i{display:block;height:100%;background:var(--accent);border-radius:3px}
.kv{display:grid;grid-template-columns:minmax(120px,190px) 1fr;gap:8px 16px;padding:16px}
.kv div:nth-child(odd){color:var(--muted)}
.kv div:nth-child(even){word-break:break-word}
input{width:100%;padding:10px 12px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--text);font:inherit;margin-bottom:10px}
ul.apps{columns:2 300px;column-gap:28px;margin:0;padding:14px 16px 14px 34px}
ul.apps li{break-inside:avoid;padding:2px 0}
.foot{color:var(--muted);font-size:13px;margin-top:36px;word-break:break-all}
code{font-family:Consolas,'Courier New',monospace;font-size:13px}
@media print{body{background:#fff}.kpi,.card{break-inside:avoid}input{display:none}}
</style>
</head>
<body><div class='wrap'>
::END_HEAD
::BEGIN_TAIL
<script>
(function(){
var ul=document.getElementById('apps');if(ul===null){return}
var seen={},items=[];
Array.prototype.forEach.call(ul.querySelectorAll('li'),function(li){var t=li.textContent.trim(),k=t.toLowerCase();if(t.length>0&&seen[k]===undefined){seen[k]=1;items.push(t)}});
items.sort(function(a,b){return a.localeCompare(b)});
ul.innerHTML='';
items.forEach(function(t){var li=document.createElement('li');li.textContent=t;ul.appendChild(li)});
var c=document.getElementById('appcount');if(c){c.textContent=items.length}
var q=document.getElementById('q');
if(q){q.addEventListener('input',function(){var v=q.value.toLowerCase();Array.prototype.forEach.call(ul.children,function(li){li.style.display=li.textContent.toLowerCase().indexOf(v)<0?'none':''})})}
})();
</script>
</div></body></html>
::END_TAIL
