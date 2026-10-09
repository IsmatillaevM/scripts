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
rem Bo'limlar holati vaqtinchalik faylga yoziladi va oxirida HTML hisobotga qo'shiladi
set "SUMMARY=%BACKUP%\_wb_sum.tmp"
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

rem Hisobot UTF-8 da yoziladi: aks holda kirill va boshqa harflar buziladi.
rem Nusxalash tugagandan keyin almashtiriladi, shunda nusxalash qismiga ta'sir qilmaydi.
set "OLDCP="
for /f "tokens=2 delims=:." %%c in ('chcp') do set /A OLDCP=%%c
chcp 65001 >nul 2>&1
echo    [*] Tizim ma'lumotlari va HTML hisobot - 1-5 daqiqa...
call :collect_sysinfo
call :make_html_report
del "%WORKER%" "%RCFILE%" "%SUMMARY%" 2>nul

set "CNAME=TAYYOR"
call :draw
title TAYYOR - WinPE Backup
echo.
echo    Papka:    %BACKUP%
echo    Hisobot:  %REPORT%
echo              - brauzerda oching: barcha natijalar, fayllar, dasturlar, kompyuter
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
set "APPS_TMP=%BACKUP%\_wb_apps.tmp"
type nul > "%APPS_TMP%"
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

rem --- Wi-Fi profillari (tiklash uchun XML) va tarmoq nomlari
set "WIFI_DIR=%SI%\WiFi"
set "WIFI_TMP=%BACKUP%\_wb_wifi.tmp"
type nul > "%WIFI_TMP%"
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
for /r "%WIFI_DIR%" %%F in (*.xml) do call :wifi_name "%%F"
>> "%SUMMARY%" echo [ok]   Wi-Fi

rem --- Windows OEM kaliti (faqat ishlab turgan Windows da o'qiladi)
set "WKEY="
for /f "usebackq tokens=2 delims==" %%K in (`wmic path softwarelicensingservice get OA3xOriginalProductKey /value 2^>nul ^| find "="`) do for /f "tokens=*" %%x in ("%%K") do set "WKEY=%%x"
if defined WKEY (>> "%SUMMARY%" echo [ok]   Windows kaliti) else (>> "%SUMMARY%" echo [skip] Windows kaliti)

rem --- Kompyuter haqida (wmic qiymatlari qatorma-qator olinadi)
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
>> "%SUMMARY%" echo [ok]   kompyuter ma'lumotlari
exit /b 0

:apps_from
for /f "tokens=*" %%K in ('reg query "%~1" 2^>nul') do (
    for /f "tokens=2,*" %%A in ('reg query "%%K" /v DisplayName 2^>nul ^| find "REG_SZ"') do (
        set "AN=%%B"
        >> "%APPS_TMP%" echo(!AN!
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
>> "%WIFI_TMP%" echo(!SS!
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

:make_html_report
rem Hisobot = shablon + xom ma'lumotlar (<script type=text/plain> ichida). Brauzer ularni o'zi tahlil qiladi,
rem shuning uchun yuz minglab fayl bo'lsa ham cmd har bir qatorni qayta ishlamaydi.
set "FLIST=%BACKUP%\_wb_files.log"
robocopy "%BACKUP%" NULL /L /E /BYTES /TS /NC /NJH /NJS /XJ /R:0 /W:0 /XF "report.html" "_backup.log" "_wb_*" /UNILOG:"%FLIST%" >nul 2>&1

set N_OK=0
set N_ALL=0
for /L %%I in (1,1,%NSEC%) do (
    if not "!S_ST_%%I!"=="yo'q" set /A N_ALL+=1
    if "!S_ST_%%I!"=="tayyor" set /A N_OK+=1
)

type nul > "%REPORT%"
call :emit HEAD

>> "%REPORT%" echo ^<script type='text/plain' id='d-meta'^>
>> "%REPORT%" echo(user=!UNAME!
>> "%REPORT%" echo(src=!SRC!
>> "%REPORT%" echo(backup=%BACKUP%
>> "%REPORT%" echo(begin=!T_BEGIN!
>> "%REPORT%" echo(end=%DATE% %TIME:~0,8%
>> "%REPORT%" echo(copyhms=!COPY_HMS!
>> "%REPORT%" echo(avgspd=!AVG_SPD!
>> "%REPORT%" echo(donemb=!DONE_MB!
>> "%REPORT%" echo(planmb=!TOTAL_MB!
>> "%REPORT%" echo(freemb=!FREE_NOW_MB!
>> "%REPORT%" echo(okn=!N_OK!
>> "%REPORT%" echo(alln=!N_ALL!
>> "%REPORT%" echo(man=!HW_MAN!
>> "%REPORT%" echo(model=!HW_MODEL!
>> "%REPORT%" echo(serial=!HW_SERIAL!
>> "%REPORT%" echo(cpu=!HW_CPU!
>> "%REPORT%" echo(ct=!HW_CT!
>> "%REPORT%" echo(ram=!HW_RAM!
>> "%REPORT%" echo(gpu=!HW_GPU!
>> "%REPORT%" echo(disks=!HW_DISKS!
>> "%REPORT%" echo(bios=!HW_BIOS!
>> "%REPORT%" echo(wkey=!WKEY!
>> "%REPORT%" echo ^</script^>

>> "%REPORT%" echo ^<script type='text/plain' id='d-sec'^>
for /L %%I in (1,1,%NSEC%) do (
    >> "%REPORT%" echo(!S_NAME_%%I!^|!S_MB_%%I!^|!S_CP_%%I!^|!S_T_%%I!^|!S_ST_%%I!
)
>> "%REPORT%" echo ^</script^>

>> "%REPORT%" echo ^<script type='text/plain' id='d-ext'^>
set "SKIPOPT="
if !SUM_LINES! GTR 0 set "SKIPOPT=skip=!SUM_LINES!"
for /f "usebackq %SKIPOPT% delims=" %%A in ("%SUMMARY%") do >> "%REPORT%" echo(%%A
>> "%REPORT%" echo ^</script^>

>> "%REPORT%" echo ^<script type='text/plain' id='d-apps'^>
type "%APPS_TMP%" >> "%REPORT%" 2>nul
>> "%REPORT%" echo ^</script^>

>> "%REPORT%" echo ^<script type='text/plain' id='d-wifi'^>
type "%WIFI_TMP%" >> "%REPORT%" 2>nul
>> "%REPORT%" echo ^</script^>

rem Xatolar: robocopy jurnalida xato qatorlarida "(0x..." kodi bor - bu tilga bog'liq emas
set ERRN=0
>> "%REPORT%" echo ^<script type='text/plain' id='d-err'^>
for /f "delims=" %%E in ('type "%LOG%" 2^>nul ^| find "(0x"') do (
    set /A ERRN+=1
    if !ERRN! LEQ 2000 >> "%REPORT%" echo(%%E
)
>> "%REPORT%" echo ^</script^>
>> "%REPORT%" echo ^<script type='text/plain' id='d-errn'^>!ERRN!^</script^>

>> "%REPORT%" echo ^<script type='text/plain' id='d-files'^>
type "%FLIST%" >> "%REPORT%" 2>nul
>> "%REPORT%" echo ^</script^>

call :emit TAIL
del "%FLIST%" "%APPS_TMP%" "%WIFI_TMP%" 2>nul
exit /b 0

:emit
rem Shu faylning oxiridagi ::BEGIN_x ... ::END_x orasidagi qatorlarni hisobotga yozadi
setlocal DisableDelayedExpansion
set "EMIT="
for /f "usebackq eol=` delims=" %%L in ("%SELF%") do (
    if "%%L"=="::END_%~1" set "EMIT="
    if defined EMIT >> "%REPORT%" echo(%%L
    if "%%L"=="::BEGIN_%~1" set "EMIT=1"
)
endlocal
exit /b 0

rem ===========================================================================
rem  HTML shabloni - bajarilmaydi, faqat :emit o'qiydi.
rem  Qoidalar: qo'sh tirnoq ishlatilmaydi, qator ` yoki : bilan boshlanmaydi.
rem ===========================================================================
::BEGIN_HEAD
<!DOCTYPE html>
<html lang='uz'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Zaxira hisoboti</title>
<style>
html{--bg:#f6f7f9;--card:#ffffff;--text:#1f2328;--muted:#656d76;--line:#d8dee4;--accent:#0969da;--hover:#eef2f6;--ok:#1a7f37;--warn:#9a6700;--err:#cf222e;--skip:#6e7781}
@media (prefers-color-scheme:dark){html{--bg:#0d1117;--card:#161b22;--text:#e6edf3;--muted:#8d96a0;--line:#30363d;--accent:#4493f8;--hover:#1f2630;--ok:#3fb950;--warn:#d29922;--err:#f85149;--skip:#8d96a0}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 -apple-system,'Segoe UI',Roboto,Arial,sans-serif}
.app{display:grid;grid-template-columns:230px minmax(0,1fr);min-height:100vh}
nav{position:sticky;top:0;height:100vh;overflow:auto;padding:20px 12px;background:var(--card);border-right:1px solid var(--line)}
nav .brand{font-weight:700;font-size:16px;padding:0 10px 2px}
nav .who{color:var(--muted);font-size:12px;padding:0 10px 14px}
nav a{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:7px 10px;border-radius:7px;color:var(--text);text-decoration:none}
nav a:hover{background:var(--hover)}
nav a.on{background:var(--accent);color:#fff}
nav a .c{font-size:12px;color:var(--muted);font-variant-numeric:tabular-nums}
nav a.on .c{color:#fff}
main{padding:24px 28px 64px;min-width:0}
section{display:none;max-width:1200px}
section.on{display:block}
h1{font-size:24px;margin:0 0 4px;letter-spacing:-.01em}
h2{font-size:16px;margin:26px 0 10px}
.sub{color:var(--muted);margin:0 0 16px}
.muted{color:var(--muted)}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}
.kpi,.box{background:var(--card);border:1px solid var(--line);border-radius:10px}
.kpi{padding:12px 14px}
.kpi .l{color:var(--muted);font-size:12px}
.kpi .v{font-size:22px;font-weight:650;font-variant-numeric:tabular-nums;line-height:1.3}
.box{overflow:auto}
.row{display:grid;grid-template-columns:minmax(0,1.3fr) minmax(0,1fr);gap:16px}
table{width:100%;border-collapse:collapse;font-variant-numeric:tabular-nums}
th,td{text-align:left;padding:7px 12px;border-bottom:1px solid var(--line);white-space:nowrap}
th{font-size:12px;color:var(--muted);font-weight:600;background:var(--card)}
th.s{cursor:pointer;user-select:none}
th.s:hover{color:var(--text)}
tr:last-child td{border-bottom:0}
tr.k,.legend div{cursor:pointer}
tr.k:hover td,.legend div:hover{background:var(--hover)}
.n{text-align:right}
td.p{white-space:normal;word-break:break-all;color:var(--muted);font-size:12px;min-width:160px}
td.w{white-space:normal;word-break:break-all}
.b{display:inline-block;padding:0 9px;border-radius:999px;font-size:12px;font-weight:600;border:1px solid currentColor}
.ok{color:var(--ok)}
.skip{color:var(--skip)}
.err{color:var(--err)}
.warn{color:var(--warn)}
.bar{height:8px;background:var(--line);border-radius:4px;overflow:hidden;min-width:70px}
.bar i{display:block;height:100%;border-radius:4px;background:var(--accent)}
.dot{display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:8px;vertical-align:-1px}
.donut{width:170px;height:170px;border-radius:50%;margin:18px auto 10px;position:relative}
.donut::after{content:'';position:absolute;inset:36px;border-radius:50%;background:var(--card)}
.legend{padding:0 8px 10px}
.legend div{display:flex;justify-content:space-between;gap:10px;padding:4px 8px;border-radius:6px}
.tools{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:10px}
input,select,button{font:inherit;color:var(--text);background:var(--card);border:1px solid var(--line);border-radius:8px;padding:7px 10px}
input[type=search]{flex:1;min-width:200px}
button{cursor:pointer}
button:hover{background:var(--hover)}
.more{display:block;margin:12px auto}
.crumb{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:4px 0 6px}
.crumb a{color:var(--accent);cursor:pointer}
.kv{display:grid;grid-template-columns:minmax(120px,190px) 1fr;gap:8px 16px;padding:14px 16px;margin:0}
.kv div:nth-child(odd){color:var(--muted)}
.kv div:nth-child(even){word-break:break-word}
ul.apps{columns:2 300px;column-gap:28px;margin:0;padding:12px 16px 12px 32px}
ul.apps li{break-inside:avoid;padding:2px 0}
pre{margin:0;padding:12px 16px;font:12px/1.55 Consolas,'Courier New',monospace;white-space:pre-wrap;word-break:break-all}
@media (max-width:760px){.app{grid-template-columns:1fr}nav{height:auto;display:flex;gap:4px;overflow-x:auto;padding:8px;border-right:0;border-bottom:1px solid var(--line);z-index:2}nav .brand,nav .who{display:none}nav a{white-space:nowrap}main{padding:16px}.row{grid-template-columns:1fr}}
</style>
</head>
<body>
<div class='app'>
<nav id='nav'><div class='brand'>Zaxira hisoboti</div><div class='who' id='who'></div></nav>
<main id='main'><noscript>Hisobotni ko'rish uchun brauzerda JavaScript yoqilgan bo'lishi kerak.</noscript></main>
</div>
::END_HEAD
::BEGIN_TAIL
<script>
(function(){
'use strict';
function $(id){return document.getElementById(id)}
function txt(id){var e=$(id);return e?e.textContent:''}
function lines(id){return txt(id).split(/\r?\n/).map(function(l){return l.replace(/\s+$/,'')}).filter(function(l){return l.length>0})}
var ENT={'&':'&amp;','<':'&lt;','>':'&gt;','\x27':'&#39;'};
function esc(s){return String(s==null?'':s).replace(/[&<>\x27]/g,function(c){return ENT[c]})}
function pad(v){return (v<10?'0':'')+v}
function fmt(n){n=+n||0;if(n<1024)return n+' B';var u=['KB','MB','GB','TB'],i=-1;do{n/=1024;i++}while(n>=1024&&i<3);return n.toFixed(n<10?2:1)+' '+u[i]}
function num(n){return (+n||0).toLocaleString('ru-RU')}
function hms(s){s=Math.max(0,s|0);return pad(s/3600|0)+':'+pad((s%3600)/60|0)+':'+pad(s%60)}
function dt(t){if(!t)return '-';var d=new Date(t);return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate())+' '+pad(d.getHours())+':'+pad(d.getMinutes())}
function bar(p,c){p=Math.max(0,Math.min(100,+p||0));if(p>0&&p<1)p=1;return `<div class=bar><i style='width:${p.toFixed(1)}%;${c?'background:'+c:''}'></i></div>`}
function kpi(l,v){return `<div class=kpi><div class=l>${esc(l)}</div><div class=v>${esc(v)}</div></div>`}
function stc(s){s=String(s||'').toLowerCase();if(s==='tayyor'||s==='ok')return 'ok';if(s.indexOf('xato')===0)return 'err';if(s.indexOf('joy')===0)return 'warn';return 'skip'}
function badge(s,label){return `<span class='b ${stc(s)}'>${esc(label||s)}</span>`}
function uniq(a){var seen={},r=[];a.forEach(function(x){var k=x.toLowerCase();if(x&&!seen[k]){seen[k]=1;r.push(x)}});return r}

var M={};
lines('d-meta').forEach(function(l){var i=l.indexOf('=');if(i>0)M[l.slice(0,i)]=l.slice(i+1).trim()});
var SEC=lines('d-sec').map(function(l){var p=l.split('|');return {name:p[0],plan:+p[1]||0,cp:+p[2]||0,t:+p[3]||0,st:(p[4]||'').trim()}});
var EXTRA=lines('d-ext').map(function(l){var m=l.match(/^\[(\w+)\]\s+(.*)$/);return m?{st:m[1],name:m[2]}:null}).filter(Boolean);
var APPS=uniq(lines('d-apps').map(function(s){return s.trim()})).sort(function(a,b){return a.localeCompare(b)});
var WIFI=uniq(lines('d-wifi').map(function(s){return s.trim()}));
var ERR=lines('d-err');
var ERRN=+txt('d-errn')||ERR.length;

var CATS=[
{n:'Hujjatlar',c:'#4493f8',x:'pdf doc docx odt rtf txt md xls xlsx ods csv ppt pptx odp'},
{n:'Rasmlar',c:'#3fb950',x:'jpg jpeg png gif bmp tif tiff webp svg heic raw cr2 nef arw ico'},
{n:'Videolar',c:'#f85149',x:'mp4 mkv avi mov wmv flv webm m4v mpg mpeg 3gp'},
{n:'Audio',c:'#d29922',x:'mp3 wav flac aac ogg m4a wma opus'},
{n:'Arxivlar',c:'#a371f7',x:'zip rar 7z tar gz bz2 xz iso cab'},
{n:'Kod',c:'#39c5cf',x:'py ipynb js ts jsx tsx java c cpp h hpp cs go rs rb php html css sql sh ps1 json xml yml yaml toml'},
{n:'Dastur fayllari',c:'#db61a2',x:'exe dll pyd so sys msi lib bin dat'},
{n:'Boshqa',c:'#8d96a0',x:''}];
var OTHER=CATS.length-1,EXT2C={};
CATS.forEach(function(c,i){c.x.split(' ').forEach(function(e){if(e)EXT2C[e]=i})});

var DIRS=[],FILES=[];
(function(){
var raw=txt('d-files').split(/\r?\n/),map={},root='',cur=-1,re=/^(\d+)\s+(\d{4})\/(\d\d)\/(\d\d)\s+(\d\d):(\d\d):(\d\d)/;
for(var k=0;k<raw.length;k++){
var l=raw[k];if(l.indexOf('\t')<0)continue;
var f=l.split('\t'),name=f[f.length-1],meta=(f[f.length-2]||'').trim();
if(!name)continue;
if(name.charAt(name.length-1)==='\\'){
if(root==='')root=name;
var rel=name.slice(root.length,-1),par=-1;
if(rel!==''){var j=rel.lastIndexOf('\\'),pp=j<0?'':rel.slice(0,j);par=map[pp]===undefined?0:map[pp]}
map[rel]=DIRS.length;
DIRS.push({p:rel,nm:rel===''?'Zaxira':rel.slice(rel.lastIndexOf('\\')+1),par:par,size:0,cnt:0,kids:[],files:[],top:-1});
if(par>=0)DIRS[par].kids.push(DIRS.length-1);
cur=DIRS.length-1;
}else if(cur>=0){
var m=re.exec(meta),size=m?+m[1]:(parseInt(meta,10)||0);
var t=m?Date.UTC(+m[2],m[3]-1,+m[4],+m[5],+m[6],+m[7]):0;
var dot=name.lastIndexOf('.'),ext=dot>0?name.slice(dot+1).toLowerCase():'';
var ci=EXT2C[ext];if(ci===undefined)ci=OTHER;
FILES.push({n:name,s:size,t:t,d:cur,e:ext,c:ci});
DIRS[cur].files.push(FILES.length-1);
for(var q=cur;q>=0;q=DIRS[q].par){DIRS[q].size+=size;DIRS[q].cnt++}
}
}
DIRS.forEach(function(d,i){var q=i;while(q>0&&DIRS[q].par>0)q=DIRS[q].par;d.top=i===0?-1:q});
})();
var TOT=DIRS.length?DIRS[0].size:0;
var CS=CATS.map(function(){return {n:0,s:0}}),EXT={};
FILES.forEach(function(f){CS[f.c].n++;CS[f.c].s+=f.s;var e=EXT[f.e]||(EXT[f.e]={e:f.e,n:0,s:0,c:f.c});e.n++;e.s+=f.s});
var EXTL=Object.keys(EXT).map(function(k){return EXT[k]}).sort(function(a,b){return b.s-a.s});
function topDirs(){return DIRS.length?DIRS[0].kids.slice().sort(function(a,b){return DIRS[b].size-DIRS[a].size}):[]}
function topN(n){var r=[];for(var i=0;i<FILES.length;i++){if(r.length<n||FILES[i].s>FILES[r[r.length-1]].s){r.push(i);r.sort(function(a,b){return FILES[b].s-FILES[a].s});if(r.length>n)r.pop()}}return r}

var PAGES=[
{id:'umumiy',t:'Umumiy',r:pOverview},
{id:'papkalar',t:'Papkalar',r:pSections,c:SEC.length},
{id:'turlar',t:'Fayl turlari',r:pTypes},
{id:'fayllar',t:'Fayllar',r:pFiles,c:FILES.length},
{id:'daraxt',t:'Papka daraxti',r:pTree},
{id:'dasturlar',t:'Dasturlar',r:pApps,c:APPS.length},
{id:'kompyuter',t:'Kompyuter',r:pPC},
{id:'qoshimcha',t:'Qo\x27shimcha',r:pExtra},
{id:'xatolar',t:'Xatolar',r:pErr,c:ERRN}];
var nav=$('nav'),main=$('main');
main.innerHTML='';
$('who').textContent=(M.user||'')+' - '+(M.begin||'');
PAGES.forEach(function(p){
var a=document.createElement('a');a.href='#'+p.id;a.id='n-'+p.id;
a.innerHTML=esc(p.t)+(p.c!==undefined?`<span class=c>${num(p.c)}</span>`:'');
nav.appendChild(a);
var s=document.createElement('section');s.id='s-'+p.id;main.appendChild(s);
});
function show(){
var id=(location.hash||'#umumiy').slice(1),p=PAGES.filter(function(x){return x.id===id})[0]||PAGES[0];
PAGES.forEach(function(x){$('n-'+x.id).classList.toggle('on',x===p);$('s-'+x.id).classList.toggle('on',x===p)});
var s=$('s-'+p.id);if(!s.dataset.done){s.dataset.done='1';p.r(s)}
window.scrollTo(0,0);
}
function go(id){if(location.hash==='#'+id)show();else location.hash=id}

function pOverview(s){
var tops=topDirs(),mx=tops.length?DIRS[tops[0]].size||1:1,big=topN(10),deg=0,stops=[];
CS.forEach(function(c,i){if(!c.s||!TOT)return;var a=deg;deg+=c.s/TOT*360;stops.push(CATS[i].c+' '+a.toFixed(2)+'deg '+deg.toFixed(2)+'deg')});
if(!stops.length)stops.push('var(--line) 0deg 360deg');
s.innerHTML=`<h1>Zaxira hisoboti</h1><p class=sub>${esc(M.user)} - ${esc(M.man)} ${esc(M.model)} - ${esc(M.begin)}</p>
<div class=kpis>${kpi('Nusxalandi',fmt(TOT))}${kpi('Fayllar',num(FILES.length))}${kpi('Sarflangan vaqt',M.copyhms||'-')}${kpi('O\x27rtacha tezlik',M.avgspd||'-')}${kpi('Tayyor papkalar',(M.okn||0)+' / '+(M.alln||0))}${kpi('Xatolar',num(ERRN))}</div>
<div class=row><div><h2>Papkalar bo\x27yicha hajm</h2><div class=box><table>${tops.map(function(i){var d=DIRS[i];return `<tr class=k data-d=${i}><td>${esc(d.nm)}</td><td class=n>${fmt(d.size)}</td><td style='width:45%'>${bar(d.size/mx*100)}</td></tr>`}).join('')}</table></div></div>
<div><h2>Fayl turlari</h2><div class=box><div class=donut style='background:conic-gradient(${stops.join(',')})'></div><div class=legend>${CS.map(function(c,i){return c.n?`<div data-c=${i}><span><span class=dot style='background:${CATS[i].c}'></span>${esc(CATS[i].n)}</span><span class=muted>${fmt(c.s)}</span></div>`:''}).join('')}</div></div></div></div>
<h2>Eng katta 10 fayl</h2><div class=box><table><tr><th>Nomi</th><th>Papka</th><th class=n>Hajmi</th></tr>${big.map(function(i){var f=FILES[i];return `<tr><td class=w>${esc(f.n)}</td><td class=p>${esc(DIRS[f.d].p)}</td><td class=n>${fmt(f.s)}</td></tr>`}).join('')}</table></div>
<p class=muted>Manba: ${esc(M.src)}<br>Zaxira: ${esc(M.backup)}<br>Boshlandi: ${esc(M.begin)}, tugadi: ${esc(M.end)}</p>`;
s.querySelectorAll('tr[data-d]').forEach(function(tr){tr.onclick=function(){openTree(+tr.dataset.d)}});
s.querySelectorAll('.legend div[data-c]').forEach(function(d){d.onclick=function(){openFiles({cat:+d.dataset.c,ext:null})}});
}

function pSections(s){
var mx=Math.max.apply(null,SEC.map(function(x){return x.cp}).concat([1]));
s.innerHTML=`<h1>Papkalar</h1><p class=sub>Reja - nusxalashdan oldin hisoblangan hajm. Nusxalandi - fleshkaga yozilgan hajm.</p><div class=box><table><tr><th>#</th><th>Papka</th><th class=n>Reja</th><th class=n>Nusxalandi</th><th></th><th class=n>Vaqt</th><th>Holat</th></tr>${SEC.map(function(x,i){var sk=stc(x.st)==='skip';return `<tr><td>${i+1}</td><td>${esc(x.name)}</td><td class=n>${num(x.plan)} MB</td><td class=n>${sk?'-':num(x.cp)+' MB'}</td><td style='width:30%'>${sk?'':bar(x.cp/mx*100)}</td><td class=n>${sk?'-':hms(x.t)}</td><td>${badge(x.st)}</td></tr>`}).join('')}</table></div>`;
}

function pTypes(s){
var h=`<h1>Fayl turlari</h1><p class=sub>Qatorni bosing - shu turdagi fayllar ro\x27yxati ochiladi.</p><h2>Toifalar</h2><div class=box><table><tr><th>Toifa</th><th class=n>Fayllar</th><th class=n>Hajmi</th><th>Ulushi</th></tr>`;
CS.forEach(function(c,i){if(!c.n)return;h+=`<tr class=k data-c=${i}><td><span class=dot style='background:${CATS[i].c}'></span>${esc(CATS[i].n)}</td><td class=n>${num(c.n)}</td><td class=n>${fmt(c.s)}</td><td style='width:40%'>${bar(TOT?c.s/TOT*100:0,CATS[i].c)}</td></tr>`});
h+=`</table></div><h2>Kengaytmalar - eng katta 60 ta</h2><div class=box><table><tr><th>Kengaytma</th><th>Toifa</th><th class=n>Fayllar</th><th class=n>Hajmi</th><th>Ulushi</th></tr>`;
EXTL.slice(0,60).forEach(function(e){h+=`<tr class=k data-e='${esc(e.e)}'><td>${e.e?'.'+esc(e.e):'kengaytmasiz'}</td><td>${esc(CATS[e.c].n)}</td><td class=n>${num(e.n)}</td><td class=n>${fmt(e.s)}</td><td style='width:35%'>${bar(TOT?e.s/TOT*100:0,CATS[e.c].c)}</td></tr>`});
s.innerHTML=h+'</table></div>';
s.querySelectorAll('tr[data-c]').forEach(function(tr){tr.onclick=function(){openFiles({cat:+tr.dataset.c,ext:null})}});
s.querySelectorAll('tr[data-e]').forEach(function(tr){tr.onclick=function(){openFiles({ext:tr.dataset.e,cat:-1})}});
}

var FST={q:'',cat:-1,ext:null,top:-1,min:0,sort:'s',asc:false,limit:200},filesUI=null;
function openFiles(o){Object.assign(FST,{q:'',top:-1,min:0,limit:200},o);if(filesUI)filesUI();go('fayllar')}
function pFiles(s){
var tops=topDirs();
s.innerHTML=`<h1>Fayllar</h1><div class=tools><input type=search id=fq placeholder='Fayl yoki papka nomi...' autocomplete=off>
<select id=fc><option value=-1>Barcha turlar</option>${CATS.map(function(c,i){return `<option value=${i}>${esc(c.n)}</option>`}).join('')}</select>
<select id=ft><option value=-1>Barcha papkalar</option>${tops.map(function(i){return `<option value=${i}>${esc(DIRS[i].nm)}</option>`}).join('')}</select>
<select id=fm><option value=0>Har qanday hajm</option><option value=1048576>1 MB dan katta</option><option value=10485760>10 MB dan katta</option><option value=104857600>100 MB dan katta</option><option value=1073741824>1 GB dan katta</option></select>
<button id=fx>Tozalash</button></div><p class=sub id=fsum></p>
<div class=box><table><thead><tr><th class=s data-k=n>Nomi</th><th class=s data-k=p>Papka</th><th class=s data-k=e>Turi</th><th class='s n' data-k=s>Hajmi</th><th class='s n' data-k=t>O\x27zgartirilgan</th></tr></thead><tbody id=fb></tbody></table></div>
<button class=more id=fmore>Yana 200 ta</button>`;
var q=$('fq'),c=$('fc'),t=$('ft'),m=$('fm'),res=[],tm=0;
function sync(){q.value=FST.q;c.value=String(FST.cat);t.value=String(FST.top);m.value=String(FST.min);run()}
function run(){
var qq=FST.q.toLowerCase(),out=[];
for(var i=0;i<FILES.length;i++){var f=FILES[i];
if(FST.cat>=0&&f.c!==FST.cat)continue;
if(FST.ext!==null&&f.e!==FST.ext)continue;
if(f.s<FST.min)continue;
if(FST.top>=0&&DIRS[f.d].top!==FST.top)continue;
if(qq&&f.n.toLowerCase().indexOf(qq)<0&&DIRS[f.d].p.toLowerCase().indexOf(qq)<0)continue;
out.push(i)}
var k=FST.sort,dir=FST.asc?1:-1;
out.sort(function(a,b){var x=FILES[a],y=FILES[b],u,v;
if(k==='s'){u=x.s;v=y.s}else if(k==='t'){u=x.t;v=y.t}else if(k==='e'){u=x.e;v=y.e}else if(k==='p'){u=DIRS[x.d].p;v=DIRS[y.d].p}else{u=x.n.toLowerCase();v=y.n.toLowerCase()}
return (u<v?-1:u>v?1:0)*dir});
res=out;var sz=0;for(var j=0;j<out.length;j++)sz+=FILES[out[j]].s;
$('fsum').textContent=num(out.length)+' ta fayl, '+fmt(sz)+(FST.ext!==null?' - turi: '+(FST.ext?'.'+FST.ext:'kengaytmasiz'):'');
draw()}
function draw(){
var h='',n=Math.min(res.length,FST.limit);
for(var i=0;i<n;i++){var f=FILES[res[i]];h+=`<tr><td class=w>${esc(f.n)}</td><td class=p>${esc(DIRS[f.d].p)}</td><td>${esc(f.e)}</td><td class=n>${fmt(f.s)}</td><td class=n>${dt(f.t)}</td></tr>`}
$('fb').innerHTML=h||'<tr><td colspan=5 class=muted>Hech narsa topilmadi</td></tr>';
$('fmore').style.display=res.length>FST.limit?'block':'none';
s.querySelectorAll('th.s').forEach(function(th){th.textContent=th.textContent.replace(/ [\u2191\u2193]$/,'');if(th.dataset.k===FST.sort)th.textContent+=FST.asc?' \u2191':' \u2193'})}
q.oninput=function(){clearTimeout(tm);tm=setTimeout(function(){FST.q=q.value;FST.limit=200;run()},250)};
c.onchange=function(){FST.cat=+c.value;FST.ext=null;FST.limit=200;run()};
t.onchange=function(){FST.top=+t.value;FST.limit=200;run()};
m.onchange=function(){FST.min=+m.value;FST.limit=200;run()};
$('fx').onclick=function(){Object.assign(FST,{q:'',cat:-1,ext:null,top:-1,min:0,limit:200});sync()};
$('fmore').onclick=function(){FST.limit+=200;draw()};
s.querySelectorAll('th.s').forEach(function(th){th.onclick=function(){var k=th.dataset.k;if(FST.sort===k)FST.asc=!FST.asc;else{FST.sort=k;FST.asc=(k==='n'||k==='p'||k==='e')}run()}});
filesUI=sync;sync();
}

var TREE=0,treeUI=null;
function openTree(d){TREE=d;if(treeUI)treeUI();go('daraxt')}
function pTree(s){
function draw(){
if(!DIRS.length){s.innerHTML='<h1>Papka daraxti</h1><p class=muted>Ma\x27lumot yo\x27q</p>';return}
var d=DIRS[TREE],chain=[],q=TREE;while(q>=0){chain.unshift(q);q=DIRS[q].par}
var kids=d.kids.slice().sort(function(a,b){return DIRS[b].size-DIRS[a].size});
var fl=d.files.slice().sort(function(a,b){return FILES[b].s-FILES[a].s}),more=fl.length-300,mx=d.size||1;fl=fl.slice(0,300);
var h=`<h1>Papka daraxti</h1><p class=sub>Papkani bosing - ichiga kirasiz. Yuqoridagi yo\x27l orqali orqaga qaytasiz.</p><div class=crumb>${chain.map(function(i,k){return (k?'<span class=muted>\\</span>':'')+`<a data-d=${i}>${esc(DIRS[i].nm)}</a>`}).join('')}</div><p class=sub>${num(d.cnt)} ta fayl, ${fmt(d.size)}</p><div class=box><table><tr><th>Nomi</th><th class=n>Fayllar</th><th class=n>Hajmi</th><th>Ulushi</th></tr>`;
kids.forEach(function(i){var k=DIRS[i];h+=`<tr class=k data-d=${i}><td class=w>&#9656; ${esc(k.nm)}</td><td class=n>${num(k.cnt)}</td><td class=n>${fmt(k.size)}</td><td style='width:40%'>${bar(k.size/mx*100)}</td></tr>`});
fl.forEach(function(i){var f=FILES[i];h+=`<tr><td class='w muted'>${esc(f.n)}</td><td class=n></td><td class=n>${fmt(f.s)}</td><td style='width:40%'>${bar(f.s/mx*100,CATS[f.c].c)}</td></tr>`});
if(more>0)h+=`<tr><td colspan=4 class=muted>... yana ${num(more)} ta fayl - Fayllar bo\x27limida qidiring</td></tr>`;
s.innerHTML=h+'</table></div>';
s.querySelectorAll('[data-d]').forEach(function(e){e.onclick=function(){TREE=+e.dataset.d;draw();window.scrollTo(0,0)}});
}
treeUI=draw;draw();
}

function pApps(s){
s.innerHTML=`<h1>O\x27rnatilgan dasturlar</h1><div class=tools><input type=search id=aq placeholder='Qidirish...' autocomplete=off></div><p class=sub id=an></p><div class=box><ul class=apps id=al></ul></div>`;
function run(){var v=$('aq').value.toLowerCase(),r=APPS.filter(function(a){return a.toLowerCase().indexOf(v)>=0});$('an').textContent=num(r.length)+' ta dastur';$('al').innerHTML=r.map(function(a){return '<li>'+esc(a)+'</li>'}).join('')||'<li class=muted>Topilmadi</li>'}
$('aq').oninput=run;run();
}

function pPC(s){
var rows=[['Ishlab chiqaruvchi',M.man],['Model',M.model],['Seriya raqami',M.serial],['Protsessor',M.cpu],['Yadrolar',M.ct],['Operativ xotira',M.ram],['Videokarta',M.gpu],['Disklar',M.disks],['BIOS',M.bios]],key=M.wkey||'';
s.innerHTML=`<h1>Kompyuter</h1><div class=box><div class=kv>${rows.map(function(r){return `<div>${esc(r[0])}</div><div>${esc(r[1]||'-')}</div>`}).join('')}<div>Windows kaliti</div><div>${key?`<span id=wk>*****-*****-*****-*****-${esc(key.slice(-5))}</span> <button id=wkb>Ko\x27rsatish</button>`:'topilmadi - WinPE da kalitni o\x27qib bo\x27lmaydi'}</div></div></div>
<h2>Wi-Fi tarmoqlari - ${WIFI.length}</h2><div class=box>${WIFI.length?'<ul class=apps>'+WIFI.map(function(w){return '<li>'+esc(w)+'</li>'}).join('')+'</ul>':'<p class=kv>Topilmadi</p>'}</div>
<p class=muted>Tiklash uchun Wi-Fi profillari (XML) va hosts fayli: _SystemInfo papkasida.</p>`;
var b=$('wkb');if(b)b.onclick=function(){$('wk').textContent=key;b.remove()};
}

function pExtra(s){
var lab={ok:'tayyor',skip:'o\x27tkazildi',xato:'xato'};
s.innerHTML=`<h1>Qo\x27shimcha ma\x27lumotlar</h1><p class=sub>Asosiy papkalardan tashqari alohida saqlanadigan narsalar.</p><div class=box><table><tr><th>Nima</th><th>Holat</th></tr>${EXTRA.map(function(x){return `<tr><td>${esc(x.name)}</td><td>${badge(x.st==='ok'?'ok':(x.st==='xato'?'xato':'skip'),lab[x.st]||x.st)}</td></tr>`}).join('')}</table></div>`;
}

function pErr(s){
s.innerHTML=`<h1>Xatolar - ${num(ERRN)}</h1><p class=sub>Nusxalab bo\x27lmagan fayllar. To\x27liq ro\x27yxat va sabablari: _backup.log${ERRN>ERR.length?' (bu yerda birinchi '+num(ERR.length)+' tasi)':''}.</p>${ERR.length?'<div class=box><pre>'+esc(ERR.join('\n'))+'</pre></div>':'<p>Xatolar yo\x27q.</p>'}`;
}

window.addEventListener('hashchange',show);
show();
})();
</script>
</body>
</html>
::END_TAIL
