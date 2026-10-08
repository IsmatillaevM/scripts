<#
    backup.ps1 — умный бэкап пользовательских данных на внешний носитель.

    Сам определяет что подключено:
      - USB-флешка / внешний SSD / SD-карта → копируется через robocopy
      - телефон по USB (режим MTP) → копируется через adb (нужна USB-отладка)

    Если найдено несколько носителей — спросит, какой выбрать.
    Можно задать явно: $env:BACKUP_DEST = 'E:\'  — тогда вопроса не будет.

    Что копируется: Desktop, Documents, Pictures, Videos, Music, Downloads
    (без установщиков .exe/.msi/.iso/...), AppData\Roaming и AppData\Local.
    Что пропускается: системный мусор, кэши браузеров/GPU, Temp, Recycle.Bin,
    Packages, node_modules, __pycache__, логи и т. п.

    Запуск одной строкой из публичного репо:
        irm 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex

    Из приватного репо (нужен personal access token):
        $h = @{ Authorization = 'token <PAT>'; 'User-Agent' = 'ps' }
        irm -Headers $h 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex
#>

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# ======================================================================
# Источники и исключения
# ======================================================================

$userProfile = $env:USERPROFILE
$sources = @(
    @{ Name = 'Desktop';         Path = Join-Path $userProfile 'Desktop' }
    @{ Name = 'Documents';       Path = Join-Path $userProfile 'Documents' }
    @{ Name = 'Pictures';        Path = Join-Path $userProfile 'Pictures' }
    @{ Name = 'Videos';          Path = Join-Path $userProfile 'Videos' }
    @{ Name = 'Music';           Path = Join-Path $userProfile 'Music' }
    @{ Name = 'Downloads';       Path = Join-Path $userProfile 'Downloads' }
    @{ Name = 'AppData_Roaming'; Path = Join-Path $userProfile 'AppData\Roaming' }
    @{ Name = 'AppData_Local';   Path = Join-Path $userProfile 'AppData\Local' }
)

$excludeDirs = @(
    '$Recycle.Bin','System Volume Information','WindowsApps','Windows','Program Files','Program Files (x86)',
    'Temp','tmp','temp',
    'Cache','Cache2','cache2','Code Cache','GPUCache','ShaderCache','DawnCache','DawnGraphiteCache','DawnWebGPUCache',
    'Service Worker','IndexedDB','Local Storage','Session Storage','blob_storage','File System','databases',
    'WebCache','INetCache','INetCookies','History','Temporary Internet Files',
    'Crashpad','CrashDumps','CrashReports','Reporting','BrowserMetrics',
    'logs','Logs',
    'Package Cache','PackageStaging',
    'node_modules','.venv','venv','.env','env','__pycache__','.pytest_cache','.mypy_cache','.ruff_cache',
    '.gradle','.idea','.vscode-server','.m2','.nuget','.cargo-cache',
    'pip','pip-cache','pip-wheels','pip-tmp',
    'D3DSCache','NvidiaLogging','NVIDIA','NVIDIA Corporation','AMD','Intel','ConnectedDevicesPlatform',
    'Packages','SquirrelTemp','pnpm-cache','yarn-cache'
)

$excludeFiles = @(
    'Thumbs.db','desktop.ini','.DS_Store',
    'ntuser.dat*','NTUSER.DAT*','UsrClass.dat*',
    '*.tmp','*.temp','*.log1','*.log2','*.etl','*.lock','hiberfil.sys','pagefile.sys','swapfile.sys'
)

$installerPatterns = @(
    '*.exe','*.msi','*.msix','*.msixbundle','*.appx','*.appxbundle',
    '*.iso','*.img','*.vhd','*.vhdx','*.dmg','*.pkg','*.deb','*.rpm'
)

$excludeDirSet = @{}
foreach ($d in $excludeDirs) { $excludeDirSet[$d.ToLower()] = $true }

function Test-ExcludedDir { param([string]$name)
    return $excludeDirSet.ContainsKey($name.ToLower())
}

function Test-ExcludedFile { param([string]$name, [string]$sectionName)
    foreach ($pat in $excludeFiles) { if ($name -like $pat) { return $true } }
    if ($sectionName -eq 'Downloads') {
        foreach ($pat in $installerPatterns) { if ($name -like $pat) { return $true } }
    }
    return $false
}

# ======================================================================
# Поиск носителей
# ======================================================================

function Get-TargetDrives {
    $out = New-Object System.Collections.Generic.List[object]
    $usbDisks = @()
    try { $usbDisks = (Get-Disk -ErrorAction SilentlyContinue | Where-Object BusType -eq 'USB').Number } catch {}
    try {
        $vols = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
        foreach ($v in $vols) {
            $isRemovable = $v.DriveType -eq 'Removable'
            $isUsbFixed  = $false
            if ($v.DriveType -eq 'Fixed') {
                try {
                    $part = Get-Partition -DriveLetter $v.DriveLetter -ErrorAction SilentlyContinue
                    if ($part -and ($usbDisks -contains $part.DiskNumber)) { $isUsbFixed = $true }
                } catch {}
            }
            if ($isRemovable -or $isUsbFixed) {
                $out.Add([pscustomobject]@{
                    Kind   = 'Drive'
                    Label  = if ($v.FileSystemLabel) { $v.FileSystemLabel } else { 'USB' }
                    Path   = ('{0}:\' -f $v.DriveLetter)
                    SizeGB = [math]::Round(($v.Size/1GB),1)
                    FreeGB = [math]::Round(($v.SizeRemaining/1GB),1)
                    Fs     = $v.FileSystem
                })
            }
        }
    } catch {}
    return $out
}

function Get-TargetMtp {
    $out = New-Object System.Collections.Generic.List[object]
    try {
        $devs = Get-CimInstance -Class Win32_PnPEntity -ErrorAction SilentlyContinue |
                Where-Object { $_.PNPClass -eq 'WPD' -and $_.Status -eq 'OK' }
        foreach ($d in $devs) {
            if ($d.Caption -match 'FileSystem Volume Driver|Device Service|Composite') { continue }
            $out.Add([pscustomobject]@{
                Kind  = 'MTP'
                Label = $d.Caption
                Path  = $d.DeviceID
            })
        }
    } catch {}
    return $out
}

function Select-Target {
    if ($env:BACKUP_DEST) {
        if (-not (Test-Path -LiteralPath $env:BACKUP_DEST)) {
            throw "BACKUP_DEST указывает на несуществующий путь: $env:BACKUP_DEST"
        }
        return [pscustomobject]@{ Kind='Drive'; Label='manual'; Path=$env:BACKUP_DEST; SizeGB=$null; FreeGB=$null; Fs=$null }
    }

    $drives = Get-TargetDrives
    $mtps   = Get-TargetMtp
    $all = @(); $all += $drives; $all += $mtps

    if ($all.Count -eq 0) {
        throw @"
Не найден ни один внешний носитель.
  - флешка / внешний SSD: подключи USB, дождись назначения буквы диска
  - телефон: подключи USB и
      * для MTP-копирования нужно включить 'Отладка по USB':
        Настройки → О телефоне → 7 раз на 'Номер сборки'
        Для разработчиков → Отладка по USB
        Подтверди запрос RSA-ключа на экране телефона
"@
    }

    Write-Host ''
    Write-Host 'Найденные носители:' -ForegroundColor Cyan
    for ($i=0; $i -lt $all.Count; $i++) {
        $t = $all[$i]
        if ($t.Kind -eq 'Drive') {
            Write-Host ("  [{0}] диск  {1}  '{2}'  {3}  свободно {4} ГБ из {5} ГБ" -f ($i+1), $t.Path, $t.Label, $t.Fs, $t.FreeGB, $t.SizeGB)
        } else {
            Write-Host ("  [{0}] телефон (MTP): {1}" -f ($i+1), $t.Label)
        }
    }

    if ($all.Count -eq 1) {
        Write-Host 'Выбран единственный носитель.' -ForegroundColor DarkGray
        return $all[0]
    }

    $pick = Read-Host 'Выбери номер'
    $n = 0
    if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $all.Count) { throw 'Неверный выбор' }
    return $all[$n - 1]
}

# ======================================================================
# Бэкап на диск
# ======================================================================

function Backup-ToDrive {
    param([pscustomobject]$Target)

    $stamp      = Get-Date -Format 'yyyy-MM-dd_HH-mm'
    $backupName = '{0}_{1}_{2}' -f $env:COMPUTERNAME, $env:USERNAME, $stamp
    $root       = Join-Path $Target.Path $backupName
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $logFile = Join-Path $root '_backup.log'

    Write-Host ''
    Write-Host "Папка резервной копии: $root" -ForegroundColor Cyan
    Write-Host "Лог: $logFile" -ForegroundColor DarkGray

    foreach ($s in $sources) {
        if (-not (Test-Path -LiteralPath $s.Path)) {
            Write-Host "пропуск (нет пути): $($s.Path)" -ForegroundColor DarkGray
            continue
        }
        $dest = Join-Path $root $s.Name
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        $xf = $excludeFiles
        if ($s.Name -eq 'Downloads') { $xf = $excludeFiles + $installerPatterns }

        Write-Host ''
        Write-Host "=== $($s.Name): $($s.Path) -> $dest" -ForegroundColor Yellow

        $rcArgs  = @($s.Path, $dest, '/E','/COPY:DAT','/DCOPY:DAT','/R:1','/W:1','/MT:16','/NFL','/NDL','/NP','/XJ','/TEE',"/LOG+:$logFile")
        $rcArgs += '/XD'; $rcArgs += $excludeDirs
        $rcArgs += '/XF'; $rcArgs += $xf
        & robocopy @rcArgs | Out-Null
        $code = $LASTEXITCODE
        if ($code -ge 8) { Write-Warning "robocopy $($s.Name) вернул код $code — см. лог" }
        else { Write-Host "ok (robocopy=$code)" -ForegroundColor DarkGreen }
    }
    Write-Host ''
    Write-Host 'Готово.' -ForegroundColor Green
    Write-Host "Итоговая папка: $root" -ForegroundColor Green
}

# ======================================================================
# Бэкап на телефон через adb
# ======================================================================

function Ensure-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\adb.exe'),
        (Join-Path ${env:ProgramFiles} 'WindowsApps\Google.PlatformTools*\adb.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Android\android-sdk\platform-tools\adb.exe')
    )
    foreach ($c in $candidates) {
        $resolved = Get-ChildItem -Path $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($resolved) { return $resolved.FullName }
    }
    throw @"
adb не найден. Для копирования на телефон установи Google Platform Tools:

    winget install -e --id Google.PlatformTools

На телефоне: Настройки → О телефоне → 7 раз на 'Номер сборки',
затем 'Для разработчиков' → включи 'Отладка по USB', подтверди RSA-ключ на экране.
После установки перезапусти PowerShell и запусти скрипт снова.
"@
}

function Backup-ToPhone {
    param([pscustomobject]$Target)

    $adb = Ensure-Adb
    & $adb start-server 2>&1 | Out-Null
    $raw = & $adb devices
    $devLines = $raw | Select-Object -Skip 1 | Where-Object { $_ -match '\s(device|unauthorized|offline)\s*$' }
    if (-not $devLines) {
        throw 'adb не видит телефон. Переключи USB-режим в "Передача файлов", включи USB-отладку и подтверди ключ на экране.'
    }
    foreach ($line in $devLines) {
        if ($line -match 'unauthorized') { throw 'Телефон в состоянии unauthorized: подтверди RSA-ключ на экране телефона и переподключи USB.' }
        if ($line -match 'offline')      { throw 'Телефон offline для adb: разблокируй экран и переподключи USB.' }
    }

    $stamp      = Get-Date -Format 'yyyy-MM-dd_HH-mm'
    $remoteRoot = "/sdcard/Backup_${env:COMPUTERNAME}_${env:USERNAME}_$stamp"
    Write-Host ''
    Write-Host "Папка на телефоне: $remoteRoot" -ForegroundColor Cyan
    & $adb shell "mkdir -p '$remoteRoot'" | Out-Null

    foreach ($s in $sources) {
        if (-not (Test-Path -LiteralPath $s.Path)) { continue }
        Write-Host ''
        Write-Host "=== $($s.Name): $($s.Path) -> phone:$remoteRoot/$($s.Name)" -ForegroundColor Yellow

        $files   = New-Object System.Collections.Generic.List[string]
        $relDirs = New-Object System.Collections.Generic.List[string]
        $srcLen  = $s.Path.Length
        $stack   = New-Object System.Collections.Generic.Stack[string]
        $stack.Push($s.Path)
        while ($stack.Count -gt 0) {
            $dir = $stack.Pop()
            try { $entries = [System.IO.Directory]::EnumerateFileSystemEntries($dir) } catch { continue }
            foreach ($e in $entries) {
                $name = [System.IO.Path]::GetFileName($e)
                try { $attr = [System.IO.File]::GetAttributes($e) } catch { continue }
                $isDir  = ($attr -band [System.IO.FileAttributes]::Directory)    -ne 0
                $isLink = ($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
                if ($isLink) { continue }
                if ($isDir) {
                    if (Test-ExcludedDir $name) { continue }
                    $stack.Push($e)
                    $rel = $e.Substring($srcLen).TrimStart('\')
                    if ($rel) { $relDirs.Add($rel) }
                } else {
                    if (Test-ExcludedFile -name $name -sectionName $s.Name) { continue }
                    $files.Add($e)
                }
            }
        }

        if ($relDirs.Count -gt 0) {
            $chunk = New-Object System.Text.StringBuilder
            foreach ($rd in $relDirs) {
                $cmd = "mkdir -p '$remoteRoot/$($s.Name)/" + ($rd -replace '\\','/') + "'"
                if ($chunk.Length + $cmd.Length -gt 7000) {
                    & $adb shell $chunk.ToString() | Out-Null
                    [void]$chunk.Clear()
                }
                [void]$chunk.Append($cmd); [void]$chunk.Append(' ; ')
            }
            if ($chunk.Length -gt 0) { & $adb shell $chunk.ToString() | Out-Null }
        }

        $n = $files.Count
        if ($n -eq 0) { Write-Host 'нет файлов' -ForegroundColor DarkGray; continue }
        Write-Host "файлов: $n" -ForegroundColor DarkGray
        $i = 0; $errors = 0
        foreach ($f in $files) {
            $rel    = $f.Substring($srcLen).TrimStart('\') -replace '\\','/'
            $remote = "$remoteRoot/$($s.Name)/$rel"
            & $adb push "$f" "$remote" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $errors++ }
            $i++
            if (($i % 25) -eq 0 -or $i -eq $n) {
                Write-Progress -Activity "$($s.Name)" -Status "$i / $n (ошибок $errors)" -PercentComplete ([int](($i / $n) * 100))
            }
        }
        Write-Progress -Activity "$($s.Name)" -Completed
        if ($errors -gt 0) { Write-Warning "$($s.Name): $errors файл(ов) не удалось скопировать" }
        else { Write-Host 'ok' -ForegroundColor DarkGreen }
    }

    Write-Host ''
    Write-Host 'Готово.' -ForegroundColor Green
    Write-Host "Папка на телефоне: $remoteRoot" -ForegroundColor Green
}

# ======================================================================
# main
# ======================================================================

$target = Select-Target
Write-Host ''
Write-Host ("Цель: {0} — {1}" -f $target.Kind, $target.Label) -ForegroundColor Cyan

switch ($target.Kind) {
    'Drive' { Backup-ToDrive -Target $target }
    'MTP'   { Backup-ToPhone -Target $target }
    default { throw "Неизвестный тип цели: $($target.Kind)" }
}
