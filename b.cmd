@echo off
rem ============================================================================
rem  b.cmd  -  WinPE Backup: foydalanuvchi ma'lumotlarini zaxiralash
rem  Barcha xabarlar o'zbekcha (lotin alifbosi).
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

rem ============================================================
rem  0) ADMIN TEKSHIRUV
rem ============================================================
net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Diqqat: administrator huquqisiz ishga tushirilgan.
    echo      Ba'zi himoyalangan fayllar o'tkazib yuborilishi mumkin.
    echo.
)

rem ============================================================
rem  1) BARCHA DISKLARNI TOPISH
rem ============================================================
echo  [*] Disklar aniqlanmoqda...
echo.

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
    echo  [!] Hech qanday disk topilmadi. ESC bosib chiqing.
    pause
    exit /b 1
)

rem ============================================================
rem  2) DISKLAR JADVALI - har bir disk haqida to'liq ma'lumot
rem ============================================================
echo  ============================================================================
echo    MAVJUD DISKLAR
echo  ============================================================================
echo.
echo    #   Harf   Hajm        Bo'sh       Tip               Metka
echo    -------------------------------------------------------------------------
set DNUM=0
for %%L in (%ALL_DRIVES%) do (
    set /A DNUM+=1
    set "DRV_!DNUM!=%%L"
    call :print_disk !DNUM! "%%L"
)
echo    -------------------------------------------------------------------------
echo.
echo    [i] X: - bu WinPE ichki diski (unga tegmang).
echo    [i] Windows o'rnatilgan disk odatda eng katta NTFS disk hisoblanadi.
echo    [i] Fleshkangiz odatda "Sменный" (Removable) tipida ko'rinadi.
echo.

rem ============================================================
rem  3) MANZIL (fleshka) TANLASH - QO'LDA
rem ============================================================
echo  ============================================================================
echo    1-QADAM: ZAXIRA UCHUN DISK TANLASH (fleshka)
echo  ============================================================================
echo.
echo    Qaysi diskka ma'lumotlar nusxalanadi? (odatda bu sizning fleshkangiz)
echo.
:ask_dst
set "DPICK="
set /P DPICK=  Disk raqamini kiriting (1-%DNUM%):
if not defined DPICK goto :ask_dst
call set "DST=%%DRV_!DPICK!%%"
if "!DST!"=="" (
    echo  [!] Noto'g'ri raqam. Qaytadan urining.
    goto :ask_dst
)
rem Tasdiqlash
echo.
echo  [=] Siz tanlagan disk: !DST!
call :print_disk "" "!DST!"
echo.
set "CONF="
set /P CONF=  Bu disk fleshkami? (Y - ha, N - yo'q):
if /I not "!CONF!"=="Y" (
    echo.
    echo  [i] Boshqa disk tanlang.
    echo.
    goto :ask_dst
)
echo.

rem ============================================================
rem  4) MANBA (foydalanuvchi profili) TANLASH - QO'LDA
rem ============================================================
echo  ============================================================================
echo    2-QADAM: FOYDALANUVCHI DISKI TANLASH (Windows disk)
echo  ============================================================================
echo.
echo    Qaysi diskda sizning Windows va foydalanuvchi papkangiz joylashgan?
echo    (odatda bu eng katta NTFS disk, lekin WinPE da harfi o'zgargan bo'lishi mumkin)
echo.
:ask_src_drive
set "SPICK="
set /P SPICK=  Disk raqamini kiriting (1-%DNUM%):
if not defined SPICK goto :ask_src_drive
call set "SYS_DRIVE=%%DRV_!SPICK!%%"
if "!SYS_DRIVE!"=="" (
    echo  [!] Noto'g'ri raqam. Qaytadan urining.
    goto :ask_src_drive
)
if /I "!SYS_DRIVE!"=="!DST!" (
    echo  [!] Manba va manzil bir xil bo'lishi mumkin emas!
    goto :ask_src_drive
)
rem Users papkasi borligini tekshirish
if not exist "!SYS_DRIVE!\Users\" (
    echo  [!] Bu diskda \Users\ papkasi topilmadi.
    echo      Boshqa disk tanlang.
    echo.
    goto :ask_src_drive
)
echo.
echo  [=] Siz tanlagan disk: !SYS_DRIVE!   (Windows diski)
echo.

rem ============================================================
rem  5) PROFIL TANLASH
rem ============================================================
echo  ============================================================================
echo    3-QADAM: FOYDALANUVCHI PROFILI TANLASH
echo  ============================================================================
echo.

set CANDIDATES=
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
    echo  [!] !SYS_DRIVE!\Users\ ichida haqiqiy profil topilmadi.
    pause
    exit /b 1
)

echo.
if %PNUM%==1 (
    call set "SRC=%%PROF_1%%"
    echo  [=] Avtomatik tanlandi: !SRC!
) else (
    :ask_prof
    set "PPICK="
    set /P PPICK=  Profil raqamini kiriting (1-%PNUM%):
    if not defined PPICK goto :ask_prof
    call set "SRC=%%PROF_!PPICK!%%"
    if "!SRC!"=="" (
        echo  [!] Noto'g'ri raqam.
        goto :ask_prof
    )
    echo  [=] Siz tanlagan profil: !SRC!
)
echo.

for %%N in ("!SRC!") do set "UNAME=%%~nxN"

rem ============================================================
rem  6) HAJMLARNI HISOBLASH
rem ============================================================
echo  ============================================================================
echo    4-QADAM: HAJMNI TEKSHIRISH
echo  ============================================================================
echo.
echo  [*] Profil hajmini hisoblash (bir necha daqiqa kutilsin)...

rem robocopy /L /E hisoblash - dir /s ba'zan nol beradi WinPE da
set "SIZE_BYTES=0"
for /f "tokens=3" %%S in ('robocopy "!SRC!" NULL /L /E /BYTES /NFL /NDL /NJH /NC /NS /XJ 2^>nul ^| find "Bytes :"') do (
    if "%%S" NEQ "" set "SIZE_BYTES=%%S"
)
rem Agar robocopy ishlamasa - dir fallback
if "!SIZE_BYTES!"=="0" (
    for /f "tokens=3" %%S in ('dir "!SRC!" /s /a-d 2^>nul ^| find "File(s)"') do set "SIZE_BYTES=%%S"
    set "SIZE_BYTES=!SIZE_BYTES:,=!"
)

set "SRC_GB=0"
if defined SIZE_BYTES (
    if not "!SIZE_BYTES!"=="" if not "!SIZE_BYTES!"=="0" (
        set "SRC_SHORT=!SIZE_BYTES:~0,-9!"
        if "!SRC_SHORT!"=="" set "SRC_SHORT=0"
        set "SRC_GB=!SRC_SHORT!"
    )
)

rem Fleshkada bo'sh joy
set "FREE_BYTES=0"
for /f "usebackq tokens=2 delims==" %%S in (`wmic logicaldisk where "DeviceID='!DST!'" get FreeSpace /value 2^>nul ^| find "="`) do set "FREE_BYTES=%%S"
set "FREE_GB=0"
if defined FREE_BYTES (
    if not "!FREE_BYTES!"=="" if not "!FREE_BYTES!"=="0" (
        set "FREE_SHORT=!FREE_BYTES:~0,-9!"
        if "!FREE_SHORT!"=="" set "FREE_SHORT=0"
        set "FREE_GB=!FREE_SHORT!"
    )
)

echo.
echo    Profil hajmi (!UNAME!):     ~!SRC_GB! GB
echo    Fleshkada bo'sh joy (!DST!): !FREE_GB! GB
echo.

if !SRC_GB! GTR !FREE_GB! (
    echo  ============================================================================
    echo  [!] DIQQAT: ma'lumotlar fleshkaga sig'maydi!
    echo      Yetishmaydi: taxminan !SRC_GB! GB kerak, !FREE_GB! GB bor.
    echo  ============================================================================
    echo.
    set "GOON="
    set /P GOON=  Baribir davom etilsinmi? (Y - ha, boshqa - yo'q):
    if /I not "!GOON!"=="Y" (
        echo  [i] Bekor qilindi.
        pause
        exit /b 1
    )
    echo  [i] Davom etmoqda - fleshka to'lgandan keyin xatolik beradi.
    echo.
)

rem ============================================================
rem  7) YAKUNIY TASDIQLASH
rem ============================================================
echo  ============================================================================
echo    5-QADAM: HAMMASI TAYYOR - BOSHLAYMIZMI?
echo  ============================================================================
echo.
echo    Nimadan:  !SRC!            (~!SRC_GB! GB)
echo    Qayerga:  !DST!\Backup_!UNAME!_*  (!FREE_GB! GB bo'sh)
echo.
echo    Nusxalanadi: Desktop, Documents, Pictures, Videos, Music,
echo                 Downloads, AppData, brauzer xatcho'plari, Outlook,
echo                 SSH kalitlari, RDP, shriftlar, stikerlar,
echo                 Wi-Fi parollari, drayverlar, Windows kaliti va h.k.
echo.
set "START="
set /P START=  Boshlanishi uchun Y bosing (yoki boshqa harf - bekor qilish):
if /I not "!START!"=="Y" (
    echo  [i] Bekor qilindi.
    pause
    exit /b 0
)
echo.

rem ============================================================
rem  8) ZAXIRA PAPKASI YARATISH
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
echo    Log:   %LOG%
echo  ============================================================================
echo.
timeout /t 2 >nul

> "%SUMMARY%" echo WinPE Backup Summary
>> "%SUMMARY%" echo ====================
>> "%SUMMARY%" echo Manba:     !SRC!
>> "%SUMMARY%" echo Zaxira:    %BACKUP%
>> "%SUMMARY%" echo Boshlandi: %DATE% %TIME%
>> "%SUMMARY%" echo.

rem ============================================================
rem  9) ASOSIY PAPKALARNI NUSXALASH
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
rem 10) QO'SHIMCHA FAYLLAR
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
rem 11) TIZIM MA'LUMOTLARI
rem ============================================================
call :collect_sysinfo

rem ============================================================
rem 12) HTML HISOBOT
rem ============================================================
call :make_html_report

>> "%SUMMARY%" echo.
>> "%SUMMARY%" echo Tugadi:    %DATE% %TIME%

echo.
echo  ============================================================================
echo    TAYYOR! Zaxiralash muvaffaqiyatli yakunlandi
echo  ============================================================================
echo    Papka:    %BACKUP%
echo    Log:      %LOG%
echo    Hisobot:  %REPORT%
echo  ============================================================================
echo.
echo    Fleshkani xavfsiz chiqarib olishni unutmang!
echo.
pause
exit /b 0

rem ===========================================================================
rem                        YORDAMCHI FUNKSIYALAR
rem ===========================================================================

:print_disk
rem %1 = raqam (bo'sh bo'lishi mumkin), %2 = disk harfi (masalan "D:")
set "PD_NUM=%~1"
set "PD_LET=%~2"
set "PD_VN="
set "PD_FS="
set "PD_SIZE="
set "PD_TYPE="
for /f "usebackq tokens=2 delims==" %%V in (`wmic logicaldisk where "DeviceID='%PD_LET%'" get VolumeName /value 2^>nul ^| find "="`) do set "PD_VN=%%V"
for /f "usebackq tokens=2 delims==" %%S in (`wmic logicaldisk where "DeviceID='%PD_LET%'" get FreeSpace /value 2^>nul ^| find "="`) do set "PD_FS=%%S"
for /f "usebackq tokens=2 delims==" %%Z in (`wmic logicaldisk where "DeviceID='%PD_LET%'" get Size /value 2^>nul ^| find "="`) do set "PD_SIZE=%%Z"
for /f "usebackq tokens=2 delims==" %%T in (`wmic logicaldisk where "DeviceID='%PD_LET%'" get DriveType /value 2^>nul ^| find "="`) do set "PD_TYPE=%%T"

rem GB ga aylantirish (oxirgi 9 raqamni olib tashlab)
set "PD_FS_GB=?"
if defined PD_FS (
    if not "%PD_FS%"=="" (
        set "T=%PD_FS:~0,-9%"
        if "!T!"=="" set "T=0"
        set "PD_FS_GB=!T!"
    )
)
set "PD_SIZE_GB=?"
if defined PD_SIZE (
    if not "%PD_SIZE%"=="" (
        set "T=%PD_SIZE:~0,-9%"
        if "!T!"=="" set "T=0"
        set "PD_SIZE_GB=!T!"
    )
)

rem Tipni so'z bilan ko'rsatish
set "PD_TYPE_NAME=?"
if "%PD_TYPE%"=="2" set "PD_TYPE_NAME=Fleshka (Sменный)"
if "%PD_TYPE%"=="3" set "PD_TYPE_NAME=Qattiq disk"
if "%PD_TYPE%"=="4" set "PD_TYPE_NAME=Tarmoq diski"
if "%PD_TYPE%"=="5" set "PD_TYPE_NAME=CD/DVD"
if "%PD_TYPE%"=="6" set "PD_TYPE_NAME=RAM disk"

rem Metka
if not defined PD_VN set "PD_VN=<nomsiz>"
if "%PD_VN%"=="" set "PD_VN=<nomsiz>"

rem Raqamni formatlab chiqarish
set "NUM_STR=   "
if defined PD_NUM if not "%PD_NUM%"=="" set "NUM_STR=[%PD_NUM%]"

rem WinPE X: diski uchun maxsus
if /I "%PD_LET%"=="X:" (
    echo    !NUM_STR! %PD_LET%    !PD_SIZE_GB! GB     !PD_FS_GB! GB     WinPE ichki        -
) else (
    echo    !NUM_STR! %PD_LET%    !PD_SIZE_GB! GB     !PD_FS_GB! GB     !PD_TYPE_NAME!    !PD_VN!
)
exit /b 0

rem ---------------------------------------------------------------------------
rem                        NUSXALASH FUNKSIYALARI
rem ---------------------------------------------------------------------------

:sect
set "SNAME=%~1"
set "SPATH=%~2"
if not exist "%SPATH%" (
    >> "%SUMMARY%" echo [skip] %SNAME% - mavjud emas
    exit /b 0
)
echo.
echo  ================= %SNAME% =================
robocopy "%SPATH%" "%BACKUP%\%SNAME%" /E /R:1 /W:1 /MT:16 /XJ /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "$Recycle.Bin" "System Volume Information" "node_modules" "__pycache__" ".venv" "venv" "pip" "pip-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.temp" "*.log1" "*.log2" "*.etl" "*.lock"
>> "%SUMMARY%" echo [ok]   %SNAME% - rc=!errorlevel!
exit /b 0

:downloads
set "SPATH=%~1"
if not exist "%SPATH%" (
    >> "%SUMMARY%" echo [skip] Downloads - mavjud emas
    exit /b 0
)
echo.
echo  ================= Downloads (installerlardan tashqari) =================
robocopy "%SPATH%" "%BACKUP%\Downloads" /E /R:1 /W:1 /MT:16 /XJ /TEE /LOG+:"%LOG%" /XD "Cache" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.exe" "*.msi" "*.msix" "*.msixbundle" "*.appx" "*.appxbundle" "*.iso" "*.img" "*.vhd" "*.vhdx" "*.dmg" "*.pkg" "*.deb" "*.rpm"
>> "%SUMMARY%" echo [ok]   Downloads - rc=!errorlevel!
exit /b 0

:roaming
set "SPATH=%~1"
if not exist "%SPATH%" (
    >> "%SUMMARY%" echo [skip] AppData\Roaming - mavjud emas
    exit /b 0
)
echo.
echo  ================= AppData\Roaming =================
robocopy "%SPATH%" "%BACKUP%\AppData_Roaming" /E /R:1 /W:1 /MT:16 /XJ /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock"
>> "%SUMMARY%" echo [ok]   AppData\Roaming - rc=!errorlevel!
exit /b 0

:local
set "SPATH=%~1"
if not exist "%SPATH%" (
    >> "%SUMMARY%" echo [skip] AppData\Local - mavjud emas
    exit /b 0
)
echo.
echo  ================= AppData\Local =================
robocopy "%SPATH%" "%BACKUP%\AppData_Local" /E /R:1 /W:1 /MT:16 /XJ /TEE /LOG+:"%LOG%" /XD "Cache" "Cache2" "Code Cache" "GPUCache" "ShaderCache" "DawnCache" "Service Worker" "IndexedDB" "Local Storage" "Session Storage" "blob_storage" "Crashpad" "CrashDumps" "logs" "Logs" "Temp" "tmp" "D3DSCache" "Packages" "PackageStaging" "SquirrelTemp" "WebCache" "INetCache" "INetCookies" "History" "NVIDIA" "NVIDIA Corporation" "AMD" "Intel" "ConnectedDevicesPlatform" "pnpm-cache" "yarn-cache" /XF "Thumbs.db" "desktop.ini" "*.tmp" "*.log1" "*.log2" "*.etl" "*.lock"
>> "%SUMMARY%" echo [ok]   AppData\Local - rc=!errorlevel!
exit /b 0

:bookmark
set "BPATH=%~1"
set "BNAME=%~2"
if not exist "%BPATH%" exit /b 0
echo.
echo  ================= Xatcho'plar: %BNAME% =================
mkdir "%BACKUP%\_Bookmarks" 2>nul
if exist "%BPATH%\*" (
    robocopy "%BPATH%" "%BACKUP%\_Bookmarks\%BNAME%" /E /R:1 /W:1 /XJ /NFL /NDL /NP /TEE /LOG+:"%LOG%"
) else (
    copy /Y "%BPATH%" "%BACKUP%\_Bookmarks\%BNAME%" >nul 2>&1
    echo Nusxalandi: %BPATH%
)
>> "%SUMMARY%" echo [ok]   xatcho'p: %BNAME%
exit /b 0

:outlook_data
echo.
echo  ================= Outlook (.pst / .ost) =================
mkdir "%BACKUP%\_Outlook" 2>nul
set FOUND=0
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
    >> "%SUMMARY%" echo [skip] Outlook - topilmadi
)
exit /b 0

:rdp_files
echo.
echo  ================= RDP ulanishlari =================
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
if exist "!SRC!\AppData\Local\Microsoft\Remote Desktop" (
    robocopy "!SRC!\AppData\Local\Microsoft\Remote Desktop" "%BACKUP%\_RDP\RD_App" /E /R:1 /W:1 /NFL /NDL /NP >nul
    set FOUND=1
)
if !FOUND!==1 (
    >> "%SUMMARY%" echo [ok]   RDP fayllari
) else (
    >> "%SUMMARY%" echo [skip] RDP - yo'q
)
exit /b 0

:ssh_keys
echo.
echo  ================= SSH kalitlari =================
if exist "!SRC!\.ssh" (
    robocopy "!SRC!\.ssh" "%BACKUP%\_SSH" /E /R:1 /W:1 /NFL /NDL /NP /TEE /LOG+:"%LOG%"
    >> "%SUMMARY%" echo [ok]   .ssh kalitlari
) else (
    >> "%SUMMARY%" echo [skip] .ssh - yo'q
)
if defined SYS_DRIVE (
    set "NTUSER=!SRC!\NTUSER.DAT"
    if exist "!NTUSER!" (
        reg load HKU\OFFLINE_USER "!NTUSER!" >nul 2>&1
        if not errorlevel 1 (
            reg export "HKU\OFFLINE_USER\Software\SimonTatham" "%BACKUP%\_SSH\putty_sessions.reg" /y >nul 2>&1
            reg unload HKU\OFFLINE_USER >nul 2>&1
            if exist "%BACKUP%\_SSH\putty_sessions.reg" >> "%SUMMARY%" echo [ok]   PuTTY sessiyalari
        )
    )
)
exit /b 0

:user_fonts
echo.
echo  ================= Foydalanuvchi shriftlari =================
set "FDIR=!SRC!\AppData\Local\Microsoft\Windows\Fonts"
if exist "!FDIR!" (
    robocopy "!FDIR!" "%BACKUP%\_UserFonts" /E /R:1 /W:1 /NFL /NDL /NP /TEE /LOG+:"%LOG%"
    >> "%SUMMARY%" echo [ok]   shriftlar
) else (
    >> "%SUMMARY%" echo [skip] shriftlar - yo'q
)
exit /b 0

:sticky_notes
echo.
echo  ================= Sticky Notes (stikerlar) =================
set FOUND=0
for /D %%P in ("!SRC!\AppData\Local\Packages\Microsoft.MicrosoftStickyNotes_*") do (
    if exist "%%P\LocalState" (
        robocopy "%%P\LocalState" "%BACKUP%\_StickyNotes\Modern" /E /R:1 /W:1 /NFL /NDL /NP >nul
        set FOUND=1
    )
)
if exist "!SRC!\AppData\Roaming\Microsoft\Sticky Notes" (
    robocopy "!SRC!\AppData\Roaming\Microsoft\Sticky Notes" "%BACKUP%\_StickyNotes\Legacy" /E /R:1 /W:1 /NFL /NDL /NP >nul
    set FOUND=1
)
if !FOUND!==1 (
    >> "%SUMMARY%" echo [ok]   stikerlar
) else (
    >> "%SUMMARY%" echo [skip] stikerlar - yo'q
)
exit /b 0

:hosts_file
echo.
echo  ================= hosts fayli =================
if defined SYS_DRIVE (
    set "HOSTS=!SYS_DRIVE!\Windows\System32\drivers\etc\hosts"
    if exist "!HOSTS!" (
        copy /Y "!HOSTS!" "%BACKUP%\_SystemInfo\hosts" >nul 2>&1
        >> "%SUMMARY%" echo [ok]   hosts
    )
)
exit /b 0

:scheduled_tasks
echo.
echo  ================= Rejalashtiruvchi vazifalari =================
mkdir "%BACKUP%\_SystemInfo\ScheduledTasks" 2>nul
where schtasks >nul 2>&1
if not errorlevel 1 (
    schtasks /query /fo CSV /v > "%BACKUP%\_SystemInfo\ScheduledTasks\tasks_list.csv" 2>nul
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
    >> "%SUMMARY%" echo [ok]   vazifalar
) else (
    >> "%SUMMARY%" echo [skip] schtasks yo'q
)
exit /b 0

:user_certs
echo.
echo  ================= Sertifikatlar =================
mkdir "%BACKUP%\_SystemInfo\Certs" 2>nul
where certutil >nul 2>&1
if not errorlevel 1 (
    certutil -store -user my > "%BACKUP%\_SystemInfo\Certs\user_personal.txt" 2>nul
    certutil -store -user root > "%BACKUP%\_SystemInfo\Certs\user_trusted_root.txt" 2>nul
    certutil -store -user ca > "%BACKUP%\_SystemInfo\Certs\user_intermediate.txt" 2>nul
    >> "%SUMMARY%" echo [ok]   sertifikatlar ro'yxati
) else (
    >> "%SUMMARY%" echo [skip] certutil yo'q
)
exit /b 0

rem ---------------------------------------------------------------------------
rem                           TIZIM MA'LUMOTLARI
rem ---------------------------------------------------------------------------

:collect_sysinfo
echo.
echo  ================= Tizim ma'lumotlarini yig'ish =================
set "SI=%BACKUP%\_SystemInfo"

set "APPS_TXT=%SI%\installed_programs.txt"
> "%APPS_TXT%" echo O'rnatilgan dasturlar (registrydan)
>> "%APPS_TXT%" echo ====================================
>> "%APPS_TXT%" echo.

if defined SYS_DRIVE (
    set "HIVE=!SYS_DRIVE!\Windows\System32\config\SOFTWARE"
    if exist "!HIVE!" (
        reg load HKLM\OFFLINE_SW "!HIVE!" >nul 2>&1
        if not errorlevel 1 (
            echo --- 64-bit dasturlar --- >> "%APPS_TXT%"
            for /f "tokens=*" %%K in ('reg query "HKLM\OFFLINE_SW\Microsoft\Windows\CurrentVersion\Uninstall" 2^>nul') do (
                for /f "tokens=2,*" %%A in ('reg query "%%K" /v DisplayName 2^>nul ^| find "REG_SZ"') do (
                    for /f "tokens=2,*" %%C in ('reg query "%%K" /v DisplayVersion 2^>nul ^| find "REG_SZ"') do (
                        >> "%APPS_TXT%" echo %%B ^| %%D
                    )
                )
            )
            echo. >> "%APPS_TXT%"
            echo --- 32-bit dasturlar --- >> "%APPS_TXT%"
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
>> "%SUMMARY%" echo [ok]   o'rnatilgan dasturlar

set "WIFI_DIR=%SI%\WiFi"
mkdir "%WIFI_DIR%" 2>nul

netsh wlan show profiles >nul 2>&1
if not errorlevel 1 (
    echo [i] Wi-Fi parollarini eksport qilish...
    netsh wlan export profile key=clear folder="%WIFI_DIR%" >nul 2>&1
    > "%WIFI_DIR%\_wifi_passwords.txt" echo Wi-Fi profillari (SSID : parol)
    >> "%WIFI_DIR%\_wifi_passwords.txt" echo ================================
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
            >> "%WIFI_DIR%\_wifi_passwords.txt" echo !PNAME! : [ochiq tarmoq]
        )
    )
    echo [ok] Wi-Fi profillari
) else (
    if defined SYS_DRIVE (
        set "WLAN_SRC=!SYS_DRIVE!\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces"
        if exist "!WLAN_SRC!" (
            robocopy "!WLAN_SRC!" "%WIFI_DIR%\RawProfiles" /E /R:1 /W:1 /NFL /NDL /NP >nul
            > "%WIFI_DIR%\_README.txt" echo Wi-Fi XML fayllari DPAPI bilan shifrlangan.
            >> "%WIFI_DIR%\_README.txt" echo Faqat asl Windows'da ochiladi: netsh wlan show profile name="SSID" key=clear
            echo [ok] Wi-Fi XML (shifrlangan)
        )
    )
)
>> "%SUMMARY%" echo [ok]   Wi-Fi profillari

set "KEY_TXT=%SI%\windows_product_key.txt"
> "%KEY_TXT%" echo Windows Product Key
>> "%KEY_TXT%" echo ===================
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
>> "%SUMMARY%" echo [ok]   Windows kaliti

if defined SYS_DRIVE (
    where dism >nul 2>&1
    if not errorlevel 1 (
        echo [i] Drayverlarni eksport qilish...
        mkdir "%SI%\Drivers" 2>nul
        dism /image:!SYS_DRIVE!\ /export-driver /destination:"%SI%\Drivers" >nul 2>&1
        if not errorlevel 1 (
            echo [ok] Drayverlar
            >> "%SUMMARY%" echo [ok]   drayverlar
        )
    )
)

set "HW=%SI%\hardware.txt"
> "%HW%" echo Qurilma ma'lumotlari
>> "%HW%" echo =====================
>> "%HW%" echo.
echo --- CPU --- >> "%HW%"
wmic cpu get Name,NumberOfCores,MaxClockSpeed /format:list 2>nul >> "%HW%"
echo --- RAM --- >> "%HW%"
wmic memorychip get Capacity,Speed,Manufacturer /format:list 2>nul >> "%HW%"
echo --- GPU --- >> "%HW%"
wmic path win32_videocontroller get Name,AdapterRAM /format:list 2>nul >> "%HW%"
echo --- Disklar --- >> "%HW%"
wmic diskdrive get Model,Size,MediaType /format:list 2>nul >> "%HW%"
echo --- Motherboard --- >> "%HW%"
wmic baseboard get Manufacturer,Product,Version /format:list 2>nul >> "%HW%"
echo --- BIOS --- >> "%HW%"
wmic bios get Manufacturer,SMBIOSBIOSVersion,ReleaseDate /format:list 2>nul >> "%HW%"
>> "%SUMMARY%" echo [ok]   hardware.txt

exit /b 0

rem ---------------------------------------------------------------------------
rem                              HTML HISOBOT
rem ---------------------------------------------------------------------------

:make_html_report
echo.
echo  ================= HTML hisobotini yaratish =================
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
>> "%REPORT%" echo .card .size{color:#94a3b8;font-size:.9rem;margin-top:.25rem}
>> "%REPORT%" echo .bar{background:#334155;height:8px;border-radius:4px;overflow:hidden;margin-top:.75rem}
>> "%REPORT%" echo .bar div{background:linear-gradient(90deg,#60a5fa,#a78bfa);height:100%%}
>> "%REPORT%" echo table{width:100%%;border-collapse:collapse;margin:1rem 0}
>> "%REPORT%" echo th,td{text-align:left;padding:.6rem;border-bottom:1px solid #334155}
>> "%REPORT%" echo th{background:#1e293b;color:#93c5fd}
>> "%REPORT%" echo tr:hover{background:#1e293b}
>> "%REPORT%" echo .footer{color:#64748b;font-size:.85rem;margin-top:3rem;text-align:center;border-top:1px solid #334155;padding-top:1rem}
>> "%REPORT%" echo ^</style^>^</head^>^<body^>^<div class="container"^>
>> "%REPORT%" echo ^<h1^>Zaxira hisoboti^</h1^>
>> "%REPORT%" echo ^<div class="meta"^>
>> "%REPORT%" echo ^<b^>Foydalanuvchi:^</b^> %UNAME%^<br^>
>> "%REPORT%" echo ^<b^>Manba:^</b^> !SRC!^<br^>
>> "%REPORT%" echo ^<b^>Zaxira joyi:^</b^> %BACKUP%^<br^>
>> "%REPORT%" echo ^<b^>Sana:^</b^> %DATE% %TIME%^<br^>
>> "%REPORT%" echo ^<b^>Umumiy hajm:^</b^> ~!SRC_GB! GB^<br^>
>> "%REPORT%" echo ^</div^>

>> "%REPORT%" echo ^<h2^>Fayllar toifalari bo'yicha^</h2^>
>> "%REPORT%" echo ^<div class="grid"^>

set MAXCOUNT=0
for /f "tokens=1,2 delims=|" %%A in (%TMP_STATS%) do (
    if %%B GTR !MAXCOUNT! set MAXCOUNT=%%B
)
if !MAXCOUNT!==0 set MAXCOUNT=1

for /f "tokens=1,2 delims=|" %%A in (%TMP_STATS%) do (
    set /A PCT=%%B*100/!MAXCOUNT!
    >> "%REPORT%" echo ^<div class="card"^>^<div class="name"^>%%A^</div^>^<div class="count"^>%%B^</div^>^<div class="size"^>fayl^</div^>^<div class="bar"^>^<div style="width:!PCT!%%"^>^</div^>^</div^>^</div^>
)
>> "%REPORT%" echo ^</div^>

>> "%REPORT%" echo ^<h2^>Eng katta 20 ta fayl^</h2^>
>> "%REPORT%" echo ^<table^>^<tr^>^<th^>Hajm (MB)^</th^>^<th^>Fayl^</th^>^</tr^>

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

>> "%REPORT%" echo ^<h2^>Zaxira tarkibi^</h2^>
>> "%REPORT%" echo ^<table^>^<tr^>^<th^>Papka^</th^>^</tr^>
for /D %%D in ("%BACKUP%\*") do (
    >> "%REPORT%" echo ^<tr^>^<td^>%%~nxD^</td^>^</tr^>
)
>> "%REPORT%" echo ^</table^>

>> "%REPORT%" echo ^<div class="footer"^>b.cmd tomonidan yaratilgan - %DATE% %TIME%^</div^>
>> "%REPORT%" echo ^</div^>^</body^>^</html^>

del "%TMP_STATS%" 2>nul
del "%BIG_TMP%" 2>nul

>> "%SUMMARY%" echo [ok]   HTML hisobot
echo [ok] HTML hisobot tayyor
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
