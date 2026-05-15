# AI数字人 - Docker 版客户端（绿色版）打包脚本
# 产物：dist-package\AI数字人-Docker版客户端-v<version>-<时间戳>\
#
# 真正的绿色版：根目录直接是 AIShuZiRen.exe + dll/资源 + 使用说明.txt
# 默认连本机 127.0.0.1。要连别的机器，开应用后在左下角"服务器"设置页改 IP。
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\build-client-portable.ps1

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding           = [System.Text.UTF8Encoding]::new()
} catch {}

$ErrorActionPreference = 'Stop'

$RepoRoot     = Split-Path -Parent $PSScriptRoot
$DeployDir    = $PSScriptRoot
$TemplateDir  = Join-Path $DeployDir 'client-portable'

$pkg     = Get-Content -LiteralPath (Join-Path $RepoRoot 'package.json') -Raw | ConvertFrom-Json
$Version = $pkg.version

$WinUnpackedSrc = Join-Path $RepoRoot 'dist\win-unpacked'
$OutRoot        = Join-Path $RepoRoot 'dist-package'
$Stamp          = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutDir         = Join-Path $OutRoot ("AI数字人-Docker版客户端-v" + $Version + "-" + $Stamp)

function Write-Section($t) { Write-Host ''; Write-Host ('==== ' + $t + ' ====') -ForegroundColor Cyan }
function Write-Ok($t)      { Write-Host ('  [OK] ' + $t) -ForegroundColor Green }
function Write-Fail($t)    { Write-Host ('  [失败] ' + $t) -ForegroundColor Red }

Write-Host ''
Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║  AI数字人 · Docker版客户端 · 绿色版打包  ║' -ForegroundColor Cyan
Write-Host ('║  版本：' + $Version.PadRight(35) + '║') -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan

# 1. 检查源
Write-Section '1/3 检查源文件'
if (-not (Test-Path -LiteralPath $WinUnpackedSrc)) {
    Write-Fail ('找不到绿色版目录：' + $WinUnpackedSrc)
    Write-Host '请先在仓库根目录跑 npm run build:win' -ForegroundColor Yellow
    exit 1
}
Write-Ok ('绿色版来源：' + $WinUnpackedSrc)

$readmeTpl = Join-Path $TemplateDir '使用说明.txt'
if (-not (Test-Path -LiteralPath $readmeTpl)) {
    Write-Fail ('模板缺失：' + $readmeTpl)
    exit 1
}
Write-Ok '使用说明.txt 模板存在'

# 2. 复制 win-unpacked 整目录内容到 $OutDir 根（不套 app/ 子目录）
Write-Section '2/3 复制绿色版到输出目录（约 700MB）'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
# 复制 win-unpacked 下所有子项到 $OutDir 根
Get-ChildItem -LiteralPath $WinUnpackedSrc -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $OutDir -Recurse -Force
}
Write-Ok ('输出目录：' + $OutDir)

# 3. 放 使用说明.txt（UTF-8 with BOM，记事本不乱码）
Write-Section '3/3 写入使用说明'
Copy-Item -LiteralPath $readmeTpl -Destination $OutDir
$readmePath = Join-Path $OutDir '使用说明.txt'
$readmeTxt  = [IO.File]::ReadAllText($readmePath, [Text.Encoding]::UTF8)
$utf8Bom    = New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllText($readmePath, $readmeTxt, $utf8Bom)
Write-Ok '使用说明.txt 转 UTF-8 with BOM'

# 总结
$total = (Get-ChildItem -LiteralPath $OutDir -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host ''
Write-Host ('整合包目录：' + $OutDir) -ForegroundColor Green
Write-Host ('总大小：' + [Math]::Round($total / 1MB, 1) + ' MB') -ForegroundColor Green
Write-Host ''
Write-Host '用法：' -ForegroundColor Cyan
Write-Host '  - 整个目录拷给 B 机器'
Write-Host '  - B 机器双击 AIShuZiRen.exe'
Write-Host '  - 默认连本机；要连别的机器进设置页改 IP'
Write-Host ''
Read-Host '按回车键退出'
exit 0
