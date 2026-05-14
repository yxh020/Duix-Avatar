# AI数字人 整合包 - 打包脚本
# 在开发机上跑，组装一个可分发的 U 盘目录
#
# 用法：双击 build-package.bat 或 PowerShell 直接跑
# 产物：dist-package\AI数字人整合包-v<version>\

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding           = [System.Text.UTF8Encoding]::new()
} catch {}

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$DeployDir = $PSScriptRoot
$PackageSrc = Join-Path $DeployDir 'package'

# 读 package.json 拿版本号
$pkg = Get-Content -LiteralPath (Join-Path $RepoRoot 'package.json') -Raw | ConvertFrom-Json
$Version = $pkg.version

$OutRoot = Join-Path $RepoRoot 'dist-package'
$OutDir = Join-Path $OutRoot ("AI数字人整合包-v" + $Version)

# ---- 来源路径（如有变化改这里）----
$AppSetupSrc       = Join-Path $RepoRoot ("dist\AI数字人-" + $Version + "-setup.exe")
$WslZipSrc         = 'E:\AI-code\leo-tts\output\wsl-offline-installer-20260507.zip'
$DockerInstallerSrc = 'E:\AI-code\leo-tts\output\DockerDesktopInstaller.exe'  # 可选，找不到只警告
$TestMaterialDir   = 'E:\AI-code\inputfiles'
$ImageName         = 'guiji2025/duix.avatar'

function Write-Section($t) { Write-Host ''; Write-Host ('==== ' + $t + ' ====') -ForegroundColor Cyan }
function Write-Ok($t)      { Write-Host ('  [OK] ' + $t) -ForegroundColor Green }
function Write-Warn2($t)   { Write-Host ('  [警告] ' + $t) -ForegroundColor Yellow }
function Write-Fail($t)    { Write-Host ('  [失败] ' + $t) -ForegroundColor Red }

Write-Host ''
Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║   AI数字人 · 整合包打包                  ║' -ForegroundColor Cyan
Write-Host ('║   版本：' + $Version.PadRight(34) + '║') -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan

# 1. 检查来源
Write-Section '1/7 检查源文件'

if (-not (Test-Path -LiteralPath $AppSetupSrc)) {
    Write-Fail ('找不到应用安装包：' + $AppSetupSrc)
    Write-Host '请先在仓库根目录跑 npm run build:win' -ForegroundColor Yellow
    exit 1
}
Write-Ok ('应用安装包：' + $AppSetupSrc)

if (-not (Test-Path -LiteralPath $WslZipSrc)) {
    Write-Fail ('找不到 WSL 离线包：' + $WslZipSrc)
    exit 1
}
Write-Ok ('WSL 离线包：' + $WslZipSrc)

$hasDockerInstaller = Test-Path -LiteralPath $DockerInstallerSrc
if ($hasDockerInstaller) {
    Write-Ok ('Docker Desktop 安装包：' + $DockerInstallerSrc)
} else {
    Write-Warn2 ('Docker Desktop 安装包未找到（' + $DockerInstallerSrc + '）。会在 installers 里放一个 README 让运营自己下载。')
}

# 检查镜像是否在
$dockerImages = & docker images -q $ImageName 2>$null
if ([string]::IsNullOrWhiteSpace($dockerImages)) {
    Write-Fail ('Docker 里找不到镜像：' + $ImageName + '。请先 docker pull 或 docker load 准备好。')
    exit 1
}
Write-Ok ('镜像在本地：' + $ImageName)

# 2. 清理 / 创建输出
Write-Section '2/7 准备输出目录'
if (Test-Path -LiteralPath $OutDir) {
    Write-Warn2 ('已存在旧目录，删除：' + $OutDir)
    Remove-Item -LiteralPath $OutDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
foreach ($sub in @('installers','docker','deploy','tools','examples')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $OutDir $sub) | Out-Null
}
Write-Ok ('输出目录：' + $OutDir)

# 3. 复制 installers
Write-Section '3/7 复制安装包'
$installersDir = Join-Path $OutDir 'installers'
Copy-Item -LiteralPath $AppSetupSrc -Destination $installersDir
Write-Ok 'AI数字人 setup.exe'
Copy-Item -LiteralPath $WslZipSrc -Destination $installersDir
Write-Ok 'WSL 离线包'
if ($hasDockerInstaller) {
    Copy-Item -LiteralPath $DockerInstallerSrc -Destination $installersDir
    Write-Ok 'Docker Desktop 安装包'
} else {
    $readme = @"
本目录少了 Docker Desktop 安装包。

请到 https://www.docker.com/products/docker-desktop/ 下载 Windows 版本，
保存为本目录下的 DockerDesktopInstaller.exe。

之后按"安装说明.txt"步骤继续。
"@
    Set-Content -LiteralPath (Join-Path $installersDir 'Docker 安装包请自己下.txt') -Value $readme -Encoding utf8
    Write-Warn2 '已写一份 README 让运营自己下 Docker'
}

# 4. docker save 镜像 tar
Write-Section '4/7 导出镜像 tar（约 5-10 分钟）'
$tarPath = Join-Path $OutDir 'docker\duix-avatar.tar'
Write-Host ('  正在 docker save 到 ' + $tarPath + ' ...') -ForegroundColor Gray
& docker save -o $tarPath $ImageName
if ($LASTEXITCODE -ne 0) {
    Write-Fail 'docker save 失败'
    exit 1
}
$tarSize = (Get-Item -LiteralPath $tarPath).Length
Write-Ok ('镜像 tar：' + [Math]::Round($tarSize / 1GB, 2) + ' GB')

# 5. 复制 compose / 启动脚本 / 测试素材
Write-Section '5/7 复制 compose 和脚本'

# compose 文件
Copy-Item -LiteralPath (Join-Path $DeployDir 'docker-compose-lite.yml') -Destination (Join-Path $OutDir 'deploy\docker-compose-lite.yml')
Write-Ok 'docker-compose-lite.yml'

# 包脚本（bat + tools 整个复制）
Copy-Item -LiteralPath (Join-Path $PackageSrc '开始使用.bat')   -Destination $OutDir
Copy-Item -LiteralPath (Join-Path $PackageSrc '环境诊断.bat')   -Destination $OutDir
Copy-Item -LiteralPath (Join-Path $PackageSrc '停止服务.bat')   -Destination $OutDir
Copy-Item -LiteralPath (Join-Path $PackageSrc '安装说明.txt')   -Destination $OutDir
Copy-Item -LiteralPath (Join-Path $PackageSrc 'tools')          -Destination $OutDir -Recurse -Force
Write-Ok '运营脚本'

# 测试素材（按文件名挑 2 个视频 + 2 个音频，避开 副本）
$videoCandidates = Get-ChildItem -LiteralPath $TestMaterialDir -Filter *.mp4 | Sort-Object Length | Select-Object -First 2
$audioCandidates = Get-ChildItem -LiteralPath $TestMaterialDir -Filter *.mp3 | Sort-Object Length | Select-Object -First 2
$examplesDir = Join-Path $OutDir 'examples'
foreach ($f in $videoCandidates + $audioCandidates) {
    Copy-Item -LiteralPath $f.FullName -Destination $examplesDir
    Write-Ok ('测试素材：' + $f.Name)
}

# 6. 写 manifest
Write-Section '6/7 写 manifest'
$manifest = [ordered]@{
    name        = 'AI数字人整合包'
    version     = $Version
    builtAt     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    image       = $ImageName
    files       = @()
}
foreach ($f in (Get-ChildItem -LiteralPath $OutDir -Recurse -File)) {
    $rel = $f.FullName.Substring($OutDir.Length + 1)
    $manifest.files += [ordered]@{
        path = $rel
        size = $f.Length
    }
}
$manifestJson = $manifest | ConvertTo-Json -Depth 5
$manifestPath = Join-Path $OutDir 'manifest.json'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)
Write-Ok ('manifest.json：' + $manifest.files.Count + ' 文件')

# 7. 总结
Write-Section '7/7 完成'
$total = (Get-ChildItem -LiteralPath $OutDir -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host ''
Write-Host ('整合包目录：' + $OutDir) -ForegroundColor Green
Write-Host ('总大小：' + [Math]::Round($total / 1GB, 2) + ' GB') -ForegroundColor Green
Write-Host ''
Write-Host '后续：' -ForegroundColor Cyan
Write-Host '  - 用 exFAT / NTFS 的 U 盘整目录拷过去'
Write-Host '  - 不要用 FAT32（duix-avatar.tar 超过 4GB）'
Write-Host '  - 不要再压缩'
Write-Host ''
Read-Host '按回车键退出'
exit 0
