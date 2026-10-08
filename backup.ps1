<#
    backup.ps1 — бэкап пользовательских данных на внешний носитель.

    Сам находит подключённые внешние диски (флешки, SD-карты, внешние SSD/HDD).
    Если найден один — использует его. Если несколько — покажет меню и спросит номер.
    Можно задать явно: $env:BACKUP_DEST = 'E:\' — тогда вопроса не будет.

    Что копируется: Desktop, Documents, Pictures, Videos, Music, Downloads
    (без установщиков .exe/.msi/.iso/...), AppData\Roaming и AppData\Local.
    Что пропускается: системный мусор, кэши браузеров/GPU, Temp, Recycle.Bin,
    Packages, node_modules, __pycache__, логи и т. п.

    Копирование — robocopy (16 потоков, автоповтор, игнор симлинков).
    Всё складывается в одну папку <ИМЯ_ПК>_<ПОЛЬЗ>_<ДАТА-ВРЕМЯ> на диске назначения,
    рядом с ней — _backup.log.

    Запуск одной строкой из публичного репо:
        irm 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex

    Из приватного репо (нужен personal access token):
        $h = @{ Authorization = 'token <PAT>'; 'User-Agent' = 'ps' }
        irm -Headers $h 'https://raw.githubusercontent.com/IsmatillaevM/scripts/main/backup.ps1' | iex
#>

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# ======================================================================
# Что копируем
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

# ======================================================================
# Поиск внешних носителей
# ======================================================================

function Get-ExternalDrives {
    $out = New-Object System.Collections.Generic.List[object]
    try { $disks = @(Get-Disk -ErrorAction SilentlyContinue) } catch { $disks = @() }

    $externalDiskNums = @()
    foreach ($d in $disks) {
        $isExternal = $false
        if ($d.BusType -eq 'USB')  { $isExternal = $true }
        if ($d.BusType -eq '1394') { $isExternal = $true }
        if ($d.BusType -eq 'SD')   { $isExternal = $true }
        if ($d.BusType -eq 'MMC')  { $isExternal = $true }
        # eSATA / внешние корпусы часто показываются как SATA; принимаем, если диск не системный и не загрузочный
        if ($d.BusType -eq 'SATA' -and -not $d.IsBoot -and -not $d.IsSystem) { $isExternal = $true }
        if ($isExternal) { $externalDiskNums += $d.Number }
    }

    try {
        $vols = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
        foreach ($v in $vols) {
            $accept = $false
            if ($v.DriveType -eq 'Removable') { $accept = $true }
            if ($v.DriveType -eq 'Fixed') {
                try {
                    $part = Get-Partition -DriveLetter $v.DriveLetter -ErrorAction SilentlyContinue
                    if ($part -and ($externalDiskNums -contains $part.DiskNumber)) { $accept = $true }
                } catch {}
            }
            if (-not $accept) { continue }

            $out.Add([pscustomobject]@{
                Label  = if ($v.FileSystemLabel) { $v.FileSystemLabel } else { 'без метки' }
                Path   = ('{0}:\' -f $v.DriveLetter)
                SizeGB = [math]::Round(($v.Size/1GB),1)
                FreeGB = [math]::Round(($v.SizeRemaining/1GB),1)
                Fs     = $v.FileSystem
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
        return [pscustomobject]@{ Label='manual'; Path=$env:BACKUP_DEST; SizeGB=$null; FreeGB=$null; Fs=$null }
    }

    $drives = Get-ExternalDrives
    if ($drives.Count -eq 0) {
        throw @"
Не найден ни один внешний диск.
Подключи флешку / внешний SSD / HDD / SD-карту по USB и дождись, пока Windows назначит букву диска.
Если диск виден в 'Этот компьютер', но скрипт его не нашёл — задай путь вручную:
    `$env:BACKUP_DEST = 'E:\'; irm '...' | iex
"@
    }

    Write-Host ''
    Write-Host 'Найденные внешние диски:' -ForegroundColor Cyan
    for ($i=0; $i -lt $drives.Count; $i++) {
        $t = $drives[$i]
        Write-Host ("  [{0}] {1}  '{2}'  {3}  свободно {4} ГБ из {5} ГБ" -f ($i+1), $t.Path, $t.Label, $t.Fs, $t.FreeGB, $t.SizeGB)
    }

    if ($drives.Count -eq 1) {
        Write-Host 'Выбран единственный диск.' -ForegroundColor DarkGray
        return $drives[0]
    }

    $pick = Read-Host 'Выбери номер'
    $n = 0
    if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $drives.Count) { throw 'Неверный выбор' }
    return $drives[$n - 1]
}

# ======================================================================
# Бэкап через robocopy
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
    Write-Host "Лог:            $logFile" -ForegroundColor Green
}

# ======================================================================
# main
# ======================================================================

$target = Select-Target
Write-Host ''
Write-Host ("Цель: {0}  ({1})" -f $target.Path, $target.Label) -ForegroundColor Cyan

Backup-ToDrive -Target $target
