# AI数字人 整合包 - 共享工具
# 被 start-duix.ps1 / diagnose-duix.ps1 / stop-duix.ps1 dot-source 复用
# 本文件不要直接双击。

# 控制台 UTF-8，否则 PS 5.1 + 中文 Windows 会乱码
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding           = [System.Text.UTF8Encoding]::new()
} catch {}

$ErrorActionPreference = 'Stop'

# 包根目录（脚本在 tools 子目录）
$Script:PackageRoot   = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Script:ImageName     = 'guiji2025/duix.avatar'
$Script:ContainerName = 'duix-avatar-gen-video'
$Script:HostPort      = 8383
# 容器数据卷在宿主机的挂载位置。运营机大多是 C:/D: 两盘，优先 D:
$Script:DataRoot      = if (Test-Path 'D:\') { 'D:\duix_avatar_data\face2face' } else { 'C:\duix_avatar_data\face2face' }
# 离线镜像 tar 路径（build-package.ps1 会放在这里）
$Script:ImageTar      = Join-Path $Script:PackageRoot 'docker\duix-avatar.tar'
# Compose 文件
$Script:ComposeFile   = Join-Path $Script:PackageRoot 'deploy\docker-compose-lite.yml'

function Write-Section($text) {
    Write-Host ''
    Write-Host ('==== ' + $text + ' ====') -ForegroundColor Cyan
}

function Write-Ok($text)    { Write-Host ('  [OK] ' + $text) -ForegroundColor Green }
function Write-Warn2($text) { Write-Host ('  [警告] ' + $text) -ForegroundColor Yellow }
function Write-Fail($text)  { Write-Host ('  [失败] ' + $text) -ForegroundColor Red }
function Write-Info($text)  { Write-Host ('  ' + $text) -ForegroundColor Gray }

function ConvertTo-ProcessArgument([string]$Value) {
    if ($null -eq $Value) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + ($Value -replace '"', '\"') + '"'
}

# 调本机原生 exe，强制 UTF-8 + 超时杀进程。
# 不要用 & 直接调，容易吃中文乱码 + 卡死。
function Invoke-Native {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSec = 60
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = (($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow = $true
    try {
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [Text.Encoding]::UTF8
    } catch {}
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch {}
        try { [void]$p.WaitForExit(5000) } catch {}
        return [pscustomobject]@{
            ExitCode = -1
            StdOut   = $outTask.Result
            StdErr   = "进程超时（>${TimeoutSec}s）已被强制结束。`n" + $errTask.Result
            TimedOut = $true
        }
    }
    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        StdOut   = $outTask.Result
        StdErr   = $errTask.Result
        TimedOut = $false
    }
}

# ---- 检查项：每个返回 [pscustomobject] { Ok=bool; Message=string; Hint=string } ----

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    $isAdmin = $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    return [pscustomobject]@{
        Ok      = $isAdmin
        Message = if ($isAdmin) { '当前是管理员' } else { '当前不是管理员（建议右键 bat 选"以管理员身份运行"）' }
        Hint    = '部分操作（启用 WSL 组件、写 D:\ 数据目录）需要管理员权限。'
    }
}

function Test-NvidiaDriver {
    $cmd = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return [pscustomobject]@{
            Ok=$false; Message='nvidia-smi 找不到（NVIDIA 驱动可能没装）'
            Hint='请到 NVIDIA 官网下载对应你显卡型号的驱动并安装，重启电脑后再来。'
        }
    }
    $r = Invoke-Native -FilePath 'nvidia-smi.exe' -Arguments @('--query-gpu=name,driver_version','--format=csv,noheader') -TimeoutSec 15
    if ($r.ExitCode -ne 0) {
        return [pscustomobject]@{
            Ok=$false; Message=('nvidia-smi 执行失败：' + $r.StdErr.Trim())
            Hint='驱动可能损坏，重新安装 NVIDIA 驱动并重启。'
        }
    }
    $line = ($r.StdOut -split "`r?`n" | Where-Object { $_ -and $_.Trim() -ne '' } | Select-Object -First 1)
    return [pscustomobject]@{
        Ok=$true; Message=('显卡：' + $line); Hint=''
    }
}

function Test-WslInstalled {
    $cmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return [pscustomobject]@{
            Ok=$false; Message='wsl.exe 找不到（WSL 未安装）'
            Hint='进入 installers 目录，右键 wsl-offline-installer-20260507\安装WSL.bat 选"以管理员身份运行"，装完重启。'
        }
    }
    $r = Invoke-Native -FilePath 'wsl.exe' -Arguments @('--status') -TimeoutSec 15
    if ($r.ExitCode -ne 0) {
        return [pscustomobject]@{
            Ok=$false; Message='wsl --status 失败，WSL 可能装了但未启用'
            Hint='进入 installers 目录跑离线 WSL 安装包，装完重启。'
        }
    }
    return [pscustomobject]@{ Ok=$true; Message='WSL 已就绪'; Hint='' }
}

function Test-DockerInstalled {
    $cmd = Get-Command docker.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return [pscustomobject]@{
            Ok=$false; Message='docker.exe 找不到（Docker Desktop 未安装）'
            Hint='进入 installers 目录，双击 DockerDesktopInstaller.exe 按默认安装，装完重启电脑并启动 Docker Desktop。'
        }
    }
    $r = Invoke-Native -FilePath 'docker.exe' -Arguments @('version','--format','{{.Server.Version}}') -TimeoutSec 15
    if ($r.ExitCode -ne 0) {
        return [pscustomobject]@{
            Ok=$false; Message='docker 命令在但 Docker Desktop 没启动'
            Hint='打开"开始菜单 → Docker Desktop"，等系统托盘 docker 图标变绿（约 30-60 秒）。'
        }
    }
    return [pscustomobject]@{
        Ok=$true; Message=('Docker 服务版本：' + $r.StdOut.Trim()); Hint=''
    }
}

function Test-DockerGpuAccess {
    $r = Invoke-Native -FilePath 'docker.exe' -Arguments @('info','--format','{{.Runtimes}}') -TimeoutSec 15
    if ($r.ExitCode -ne 0) {
        return [pscustomobject]@{
            Ok=$false; Message='docker info 查 runtimes 失败'
            Hint='Docker Desktop 没启动完，或安装异常。重启 Docker Desktop。'
        }
    }
    if ($r.StdOut -notmatch 'nvidia') {
        return [pscustomobject]@{
            Ok=$false; Message='Docker 没看到 nvidia runtime'
            Hint='打开 Docker Desktop → Settings → Resources → WSL Integration，确认 default WSL distro 打勾。然后重启 Docker Desktop 与电脑各一次。'
        }
    }
    return [pscustomobject]@{ Ok=$true; Message='Docker 可调用 NVIDIA GPU'; Hint='' }
}

function Test-ImageReady {
    $r = Invoke-Native -FilePath 'docker.exe' -Arguments @('images','-q',$Script:ImageName) -TimeoutSec 15
    if ($r.ExitCode -ne 0) {
        return [pscustomobject]@{
            Ok=$false; Message='docker images 查询失败'
            Hint=$r.StdErr.Trim()
        }
    }
    if ([string]::IsNullOrWhiteSpace($r.StdOut)) {
        return [pscustomobject]@{
            Ok=$false; Message=('镜像 ' + $Script:ImageName + ' 未导入')
            Hint='首次启动会自动从 docker\duix-avatar.tar 导入（约 3-5 分钟），稍后启动脚本会自动处理。'
        }
    }
    return [pscustomobject]@{
        Ok=$true; Message=('镜像已就绪：' + $Script:ImageName); Hint=''
    }
}

function Test-ContainerRunning {
    $r = Invoke-Native -FilePath 'docker.exe' -Arguments @('ps','--filter',"name=$($Script:ContainerName)",'--format','{{.Status}}') -TimeoutSec 15
    if ([string]::IsNullOrWhiteSpace($r.StdOut)) {
        return [pscustomobject]@{
            Ok=$false; Message='容器未运行'
            Hint='双击"开始使用.bat"会自动启动。'
        }
    }
    return [pscustomobject]@{
        Ok=$true; Message=('容器状态：' + $r.StdOut.Trim()); Hint=''
    }
}

function Test-Port8383Free {
    # 端口被自己的容器占是好事；被别的进程占是坏事
    try {
        $conn = Get-NetTCPConnection -LocalPort $Script:HostPort -State Listen -ErrorAction SilentlyContinue
        if (-not $conn) {
            return [pscustomobject]@{ Ok=$true; Message=('端口 ' + $Script:HostPort + ' 空闲（容器未起或未占用）'); Hint='' }
        }
        # 看是不是 com.docker.backend / docker / vmmem 在占
        foreach ($c in $conn) {
            $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
            if (-not $proc) { continue }
            if ($proc.ProcessName -match 'docker|vmmem|wslhost|com\.docker') {
                return [pscustomobject]@{ Ok=$true; Message=('端口 ' + $Script:HostPort + ' 已被 Docker 自家进程占用，正常'); Hint='' }
            }
            return [pscustomobject]@{
                Ok=$false; Message=('端口 ' + $Script:HostPort + ' 被进程占用：' + $proc.ProcessName + ' (PID=' + $proc.Id + ')')
                Hint='关闭这个进程或换端口（修改 deploy\docker-compose-lite.yml 的 ports 段）。'
            }
        }
        return [pscustomobject]@{ Ok=$true; Message='端口可用'; Hint='' }
    } catch {
        return [pscustomobject]@{ Ok=$true; Message='端口检查跳过（Get-NetTCPConnection 不可用）'; Hint='' }
    }
}

function Test-EasyApiResponding {
    try {
        $resp = Invoke-WebRequest -Uri ("http://127.0.0.1:" + $Script:HostPort + "/easy/query?code=ping") -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -ge 200) {
            return [pscustomobject]@{ Ok=$true; Message=('容器 API 已响应（HTTP ' + $resp.StatusCode + '）'); Hint='' }
        }
        return [pscustomobject]@{ Ok=$false; Message=('容器 API 状态码异常：' + $resp.StatusCode); Hint='等几秒重试或重启容器' }
    } catch {
        return [pscustomobject]@{
            Ok=$false; Message='容器 API 暂未响应'
            Hint='容器刚启动通常要 10-30 秒预热，稍等再试。'
        }
    }
}

# ---- 操作类 ----

function Ensure-DataRoot {
    foreach ($sub in @('temp','result')) {
        $full = Join-Path $Script:DataRoot $sub
        if (-not (Test-Path -LiteralPath $full)) {
            try {
                New-Item -ItemType Directory -Force -Path $full | Out-Null
                Write-Ok ('创建数据目录：' + $full)
            } catch {
                Write-Fail ('创建数据目录失败：' + $full + ' - ' + $_.Exception.Message)
                throw
            }
        }
    }
}

function Import-DuixImage {
    if (-not (Test-Path -LiteralPath $Script:ImageTar)) {
        throw ('找不到镜像 tar：' + $Script:ImageTar + '。请确认整合包是否完整。')
    }
    Write-Info ('导入离线镜像（约 3-5 分钟，文件 5+ GB）：' + $Script:ImageTar)
    # docker load 没有进度条；用 Start-Process 阻塞等
    $proc = Start-Process -FilePath 'docker.exe' -ArgumentList @('load','-i', ('"' + $Script:ImageTar + '"')) -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw ('docker load 失败，退出码：' + $proc.ExitCode)
    }
    Write-Ok '镜像导入完成'
}

function Compose-Up {
    if (-not (Test-Path -LiteralPath $Script:ComposeFile)) {
        throw ('找不到 compose 文件：' + $Script:ComposeFile)
    }
    Write-Info '启动容器 ...'
    $r = Invoke-Native -FilePath 'docker.exe' -Arguments @('compose','-f',$Script:ComposeFile,'up','-d') -TimeoutSec 120
    if ($r.ExitCode -ne 0) {
        Write-Fail ('启动容器失败：' + $r.StdErr.Trim())
        throw 'compose up 失败'
    }
    Write-Ok '容器已启动'
}

function Compose-Down {
    if (-not (Test-Path -LiteralPath $Script:ComposeFile)) {
        Write-Warn2 ('找不到 compose 文件：' + $Script:ComposeFile + '，尝试用 docker stop 兜底')
        Invoke-Native -FilePath 'docker.exe' -Arguments @('stop', $Script:ContainerName) -TimeoutSec 30 | Out-Null
        return
    }
    Write-Info '停止容器 ...'
    $r = Invoke-Native -FilePath 'docker.exe' -Arguments @('compose','-f',$Script:ComposeFile,'down') -TimeoutSec 60
    if ($r.ExitCode -ne 0) {
        Write-Warn2 ('compose down 警告：' + $r.StdErr.Trim())
    } else {
        Write-Ok '容器已停止'
    }
}

function Wait-ApiReady {
    param([int]$MaxSec = 60)
    Write-Info ('等待容器 API 就绪（最长 ' + $MaxSec + ' 秒）...')
    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt $MaxSec) {
        $r = Test-EasyApiResponding
        if ($r.Ok) {
            Write-Ok $r.Message
            return $true
        }
        Start-Sleep -Seconds 2
    }
    Write-Warn2 '容器 API 还没响应，可能首次预热慢。可以稍等后再启动应用。'
    return $false
}

function Open-App {
    # 找已安装的 AI数字人 应用
    $candidates = @(
        'C:\Program Files\AI数字人\AIShuZiRen.exe',
        'C:\Program Files (x86)\AI数字人\AIShuZiRen.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\AI数字人\AIShuZiRen.exe')
    )
    $exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($exe) {
        Write-Ok ('启动应用：' + $exe)
        Start-Process -FilePath $exe
        return $true
    }
    Write-Warn2 '没找到 AI数字人.exe（可能没装应用）'
    Write-Info '到 installers 目录运行 AI数字人-1.0.7-setup.exe 安装。'
    return $false
}
