<#
  Ruijie Supplicant 6.61 (暨南定制版) 离线补丁
  禁用「多网卡检测 → 强制下线(102)」与「提示弹窗」，不改认证逻辑
  适用版本 SHA256 = E8061B2A454D8E8472A7D01B08023E2C7108DA44FAB7913DC0B129444EF9E039
  共 28 处 / 72 字节
#>
param(
    [string]$InstallDir = '',
    [switch]$Rollback,
    [switch]$DryRun,
    [switch]$SkipServiceControl
)
$ErrorActionPreference = 'Continue'
$OrigHash    = 'E8061B2A454D8E8472A7D01B08023E2C7108DA44FAB7913DC0B129444EF9E039'
$PatchedHash = '99ADD8847A49FD62C42509524EC239A18386009012728041632961316CF0B8C1'

# @(偏移, 原字节, 补丁字节)
$Table = @(
    @('0x039B9C','A104','0000'),
    @('0x0427E3','A104','0000'),
    @('0x0429E4','A104','0000'),
    @('0x043574','06','79'),
    @('0x043586','E884E2FFFF','9090909090'),
    @('0x0435A9','A104','0000'),
    @('0x04377B','A104','0000'),
    @('0x043859','A104','0000'),
    @('0x0439E7','A104','0000'),
    @('0x043B14','A104','0000'),
    @('0x044154','A104','0000'),
    @('0x04431C','E8EED4FFFF','9090909090'),
    @('0x04433D','A104','0000'),
    @('0x0443D0','A104','0000'),
    @('0x044C47','A104','0000'),
    @('0x045512','A104','0000'),
    @('0x0455EC','A104','0000'),
    @('0x045908','E802BFFFFF','9090909090'),
    @('0x045936','A104','0000'),
    @('0x045B92','E878BCFFFF','9090909090'),
    @('0x045BF1','A104','0000'),
    @('0x045D10','E8FABAFFFF','9090909090'),
    @('0x045D4F','A104','0000'),
    @('0x0FA61C','6A04B8','33C0C3'),
    @('0x0FA69A','6A04B8','33C0C3'),
    @('0x0FCFC7','A104','0000'),
    @('0x0FD2F3','A104','0000'),
    @('0x0FF27D','A104','0000')
)

function Fail($m) { Write-Host ""; Write-Host "[中止] $m" -ForegroundColor Red; exit 1 }
function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Info($m) { Write-Host "  $m" }

# 定位安装目录
if (-not $InstallDir) {
    $cands = @(
        (Join-Path $env:ProgramFiles '锐捷网络\Ruijie Supplicant'),
        (Join-Path ${env:ProgramFiles(x86)} '锐捷网络\Ruijie Supplicant'),
        (Join-Path $env:ProgramFiles 'Ruijie Supplicant'),
        (Join-Path ${env:ProgramFiles(x86)} 'Ruijie Supplicant')
    )
    foreach ($k in @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match '锐捷|Ruijie' -and $_.InstallLocation } |
            ForEach-Object { if ($cands -notcontains $_.InstallLocation) { $cands += $_.InstallLocation } }
    }
    # 兜底 1：正在运行的客户端路径
    $proc = Get-Process -Name '8021x' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.Path) {
        $d0 = Split-Path -Parent $proc.Path
        if ($cands -notcontains $d0) { $cands += $d0 }
    }
    # 兜底 2：各盘根目录下扫 Ruijie Supplicant / 锐捷网络 目录（最多两层）
    foreach ($drv in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Root -match '^[A-Za-z]:\\\\?$' })) {
        foreach ($nm in @('Ruijie Supplicant', '锐捷网络', '锐捷网络\Ruijie Supplicant')) {
            $cand = Join-Path $drv.Root $nm
            if ((Test-Path -LiteralPath $cand) -and $cands -notcontains $cand) { $cands += $cand }
        }
    }
    foreach ($c in $cands) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c '8021x.exe'))) { $InstallDir = $c; break }
    }
}
if (-not $InstallDir) {
    $InstallDir = Read-Host '未自动找到安装目录，请粘贴 Ruijie Supplicant 文件夹路径'
}
$exe = Join-Path $InstallDir '8021x.exe'
if (-not (Test-Path -LiteralPath $exe)) { Fail "找不到 $exe" }
Info "安装目录: $InstallDir"

$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
Info "当前哈希: $hash"
$state = if ($hash -eq $OrigHash) { 'orig' } elseif ($hash -eq $PatchedHash) { 'patched' } else { 'unknown' }
if ($state -eq 'unknown') {
    Write-Host ""
    Write-Host "版本不匹配，已停止，未做任何修改。" -ForegroundColor Yellow
    Write-Host "  需要: $OrigHash 或 $PatchedHash"
    Fail '无适用偏移'
}
Info ("当前状态: " + $(if ($state -eq 'orig') { '原版（未打补丁）' } else { '已打补丁' }))

$target = if ($Rollback) { 'orig' } else { 'patched' }
if ($state -eq $target) { Ok ("已经是目标状态（" + $(if ($target -eq 'orig') { '原版' } else { '已打补丁' }) + "），无需操作"); exit 0 }

Write-Host ""
Info ("将" + $(if ($Rollback) { '回滚到原版' } else { '打补丁' }) + "：$($Table.Count) 处，共 72 字节")
if ($DryRun) { Ok 'DryRun：只检查不修改'; exit 0 }

$svc = Get-Service RJSuService -ErrorAction SilentlyContinue
if (-not $SkipServiceControl -and $svc -and $svc.Status -eq 'Running') {
    Stop-Service RJSuService -Force -ErrorAction SilentlyContinue
    Info '已停止 RJSuService'
}

$fs = $null
for ($t = 0; $t -lt 40; $t++) {
    if (-not $SkipServiceControl) {
        Get-Process -Name '8021x', 'RuijieSupplicant' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    try { $fs = [System.IO.File]::Open($exe, 'Open', 'ReadWrite', 'None'); break } catch { Start-Sleep -Milliseconds 400 }
}
if (-not $fs) { Fail '拿不到文件独占句柄（有进程一直占用）。请重启电脑后再试' }
Ok '已取得独占句柄'

$len = $fs.Length
$buf = New-Object byte[] $len
$fs.Seek(0, 'Begin') | Out-Null
$read = 0
while ($read -lt $len) { $n = $fs.Read($buf, $read, $len - $read); if ($n -le 0) { break }; $read += $n }

$changed = 0
foreach ($row in $Table) {
    $off = [Convert]::ToInt64($row[0], 16)
    $o = [byte[]]($row[1] -split '(..)' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })
    $p = [byte[]]($row[2] -split '(..)' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })
    $want = if ($Rollback) { $o } else { $p }
    for ($k = 0; $k -lt $want.Length; $k++) {
        if ($buf[$off + $k] -ne $want[$k]) { $buf[$off + $k] = $want[$k]; $changed++ }
    }
}
Info "实际改写 $changed 字节"

$fs.Seek(0, 'Begin') | Out-Null
$fs.Write($buf, 0, $len)
$fs.Flush($true)
$fs.Close(); $fs.Dispose()

$newHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
$expect = if ($Rollback) { $OrigHash } else { $PatchedHash }
if ($newHash -ne $expect) { Fail "写后校验失败：$newHash ≠ $expect" }
Ok "写后校验通过：$newHash"

if (-not $SkipServiceControl) {
    if ($svc) { try { Start-Service RJSuService } catch {} }
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name '8021x' -ErrorAction SilentlyContinue)) {
        $ui = Join-Path $InstallDir 'RuijieSupplicant.exe'
        if (Test-Path -LiteralPath $ui) { Start-Process -FilePath $ui -WorkingDirectory $InstallDir | Out-Null }
        Ok '已启动客户端'
    } else { Ok '客户端已在运行' }
}

Write-Host ""
Write-Host "完成。" -ForegroundColor Green
