<#
    backup.ps1 — резервное копирование пользовательских данных на внешний диск.

    Копирует Desktop, Documents, Pictures, Videos, Music, Downloads (без установщиков),
    AppData\Roaming и AppData\Local (конфиги/сейвы установленных программ). Пропускает
    системный мусор: кэши браузеров/GPU, Temp, Recycle.Bin, Packages, node_modules,
    __pycache__, логи и т. п. Всё в одну папку <ИМЯ_ПК>_<ПОЛЬЗ>_<ДАТА-ВРЕМЯ>.

    Запуск из приватного GitHub-репозитория (нужен personal access token,
    права: Contents=Read для fine-grained, или scope "repo" для classic):

        $h = @{ Authorization = 'token <PAT>'; 'User-Agent' = 'ps' }
        irm -Headers $h 'https://raw.githubusercontent.com/<user>/<repo>/main/backup.ps1' | iex

        # без вопроса о пути — задать переменную заранее:
        $env:BACKUP_DEST = 'E:\'
        $h = @{ Authorization = 'token <PAT>'; 'User-Agent' = 'ps' }
        irm -Headers $h 'https://raw.githubusercontent.com/<user>/<repo>/main/backup.ps1' | iex
#>

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Get-BackupDest {
    if ($env:BACKUP_DEST) { return $env:BACKUP_DEST }
    $d = Read-Host 'Куда копировать? (например E:\ или D:\Backup)'
    if (-not $d) { throw 'Путь не указан' }
    return $d
}

$Destination = Get-BackupDest
if (-not (Test-Path -LiteralPath $Destination)) {
    throw "Папка назначения не найдена: $Destination"
}

$stamp      = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$backupName = '{0}_{1}_{2}' -f $env:COMPUTERNAME, $env:USERNAME, $stamp
$root       = Join-Path $Destination $backupName
New-Item -ItemType Directory -Path $root -Force | Out-Null
$logFile = Join-Path $root '_backup.log'

Write-Host ''
Write-Host "Папка резервной копии: $root" -ForegroundColor Cyan
Write-Host "Лог: $logFile" -ForegroundColor DarkGray

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

# Папки, которые пропускаем везде (системный/кэш-мусор, dev-мусор)
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
    # дополнительно для AppData\Local — мусор, который там копится мегабайтами
    'D3DSCache','NvidiaLogging','NVIDIA','NVIDIA Corporation','AMD','Intel','ConnectedDevicesPlatform',
    'Microsoft\Windows\Explorer','Microsoft\Windows\INetCache','Microsoft\Windows\WebCache',
    'Microsoft\Windows\WER','Microsoft\WindowsApps','Microsoft\OneDrive\setup','Microsoft\EdgeUpdate',
    'Google\Chrome\User Data\Default\Cache','Google\Chrome\User Data\Default\Code Cache',
    'Microsoft\Edge\User Data\Default\Cache','Microsoft\Edge\User Data\Default\Code Cache',
    'Mozilla\Firefox\Profiles\Cache','Yandex\YandexBrowser\User Data\Default\Cache',
    'Packages','PackageStaging','Downloaded Installations','SquirrelTemp','pnpm-cache','yarn-cache'
)

# Файлы, которые пропускаем везде
$excludeFiles = @(
    'Thumbs.db','desktop.ini','.DS_Store',
    'ntuser.dat*','NTUSER.DAT*','UsrClass.dat*',
    '*.tmp','*.temp','*.log1','*.log2','*.etl','*.lock','hiberfil.sys','pagefile.sys','swapfile.sys'
)

# В Downloads дополнительно убираем установщики / образы
$installerPatterns = @(
    '*.exe','*.msi','*.msix','*.msixbundle','*.appx','*.appxbundle',
    '*.iso','*.img','*.vhd','*.vhdx','*.dmg','*.pkg','*.deb','*.rpm'
)

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

    $rcArgs  = @($s.Path, $dest,
        '/E',               # все подпапки, включая пустые
        '/COPY:DAT',        # данные + атрибуты + время (без ACL — не ругается)
        '/DCOPY:DAT',
        '/R:1','/W:1',      # 1 ретрай, 1 сек ожидания
        '/MT:16',           # 16 потоков
        '/NFL','/NDL','/NP',# тише в консоли
        '/XJ',              # игнорировать junction/symlink — чтобы не зациклиться
        '/TEE',
        "/LOG+:$logFile"
    )
    $rcArgs += '/XD'; $rcArgs += $excludeDirs
    $rcArgs += '/XF'; $rcArgs += $xf

    & robocopy @rcArgs | Out-Null
    $code = $LASTEXITCODE
    if ($code -ge 8) {
        Write-Warning "robocopy вернул код $code для $($s.Name) — смотри лог"
    } else {
        Write-Host "ok (robocopy=$code)" -ForegroundColor DarkGreen
    }
}

Write-Host ''
Write-Host 'Готово.' -ForegroundColor Green
Write-Host "Итоговая папка: $root" -ForegroundColor Green
Write-Host "Лог:            $logFile" -ForegroundColor Green
