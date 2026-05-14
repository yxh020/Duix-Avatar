# Duix.Avatar lite 启动脚本
# 通过 deploy/start-duix-lite.bat 双击调起。直接右键 "Run with PowerShell" 也可以。

$ErrorActionPreference = "Stop"

# 让控制台正确显示中文（PS 5.1 默认控制台是 GBK，写入 UTF-8 字符串会乱）
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
} catch {}

$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$ImageName     = "guiji2025/duix.avatar"
$ContainerName = "duix-avatar-gen-video"
$TarPath       = Join-Path $ScriptDir "duix-avatar.tar"
$DataRoot      = "D:\duix_avatar_data\face2face"
$HostPort      = 8383

function Pause-And-Exit([int]$Code) {
    Write-Host ""
    Read-Host "按回车键关闭窗口"
    exit $Code
}

function ConvertTo-ProcessArgument([string]$Value) {
    if ($null -eq $Value) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + ($Value -replace '"', '\"') + '"'
}

function Invoke-Native {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSec = 60,
        [string]$DisplayName = ""
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = (($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join " ")
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    # 确保子进程的 stdout/stderr 用 UTF-8 读，否则中文报错变乱码
    try {
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
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
            Code = -1
            Out  = ""
            Err  = "$DisplayName 超时（>$TimeoutSec 秒）"
        }
    }
    return [pscustomobject]@{
        Code = $p.ExitCode
        Out  = $outTask.Result
        Err  = $errTask.Result
    }
}

function Find-FirstExistingPath([string[]]$Paths) {
    foreach ($p in $Paths) { if (Test-Path -LiteralPath $p) { return $p } }
    return $null
}

function Resolve-CommandPath([string]$Name, [string[]]$Known = @()) {
    $p = Find-FirstExistingPath $Known
    if ($p) { return $p }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Write-Title([string]$Text) {
    Write-Host ""
    Write-Host "============================================"
    Write-Host "  $Text"
    Write-Host "============================================"
}

function Write-Step([string]$Tag, [string]$Msg) {
    Write-Host "[$Tag] $Msg"
}

function Write-Err([string]$Msg) {
    Write-Host "[错误] $Msg" -ForegroundColor Red
}

function Write-Ok([string]$Msg) {
    Write-Host "       $Msg" -ForegroundColor Green
}

# ----------------------------------------------------------------------

Write-Title "Duix.Avatar lite 启动脚本"

# 1. 找 docker
$docker = Resolve-CommandPath "docker" @(
    "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
)
if (-not $docker) {
    Write-Err "没找到 docker.exe"
    Write-Host "请先安装 Docker Desktop（https://www.docker.com/products/docker-desktop）"
    Write-Host "安装后打开 Docker Desktop，等右下角图标变绿，再重新双击本脚本"
    Pause-And-Exit 1
}

# 2. Docker Desktop 在跑吗
Write-Step "1/5" "检查 Docker Desktop..."
$r = Invoke-Native -FilePath $docker -Arguments @("version") -TimeoutSec 30 -DisplayName "docker version"
if ($r.Code -ne 0) {
    Write-Err "Docker Desktop 没启动完"
    Write-Host "打开 Docker Desktop，等右下角图标变绿（约 30~60 秒），然后重新双击本脚本"
    if ($r.Err) { Write-Host "原始报错：$($r.Err)" }
    Pause-And-Exit 1
}
Write-Ok "Docker Desktop OK"

# 3. NVIDIA GPU 接通了吗
Write-Step "2/5" "检查 NVIDIA GPU 接通 Docker..."
$r = Invoke-Native -FilePath $docker -Arguments @("run", "--rm", "--gpus", "all", "guiji2025/duix.avatar", "nvidia-smi") -TimeoutSec 60 -DisplayName "docker nvidia-smi"
$gpuOk = ($r.Code -eq 0 -and $r.Out -match "NVIDIA")
if (-not $gpuOk) {
    # 镜像可能还没 load，先用通用 cuda 镜像快速试一下（也可能没拉）。如果就是 image 没找到，跳过这步
    if ($r.Err -notmatch "Unable to find image|No such image|not found") {
        Write-Err "Docker 调用 GPU 失败"
        Write-Host "原始报错：" -ForegroundColor Yellow
        Write-Host $r.Err
        Write-Host ""
        Write-Host "可能原因：" -ForegroundColor Yellow
        Write-Host "  - 显卡驱动太旧：装最新 NVIDIA 显卡驱动，重启电脑"
        Write-Host "  - Docker Desktop 没启用 WSL2 后端：设置 -> General 勾选 'Use the WSL 2 based engine'"
        Write-Host "  - WSL2 没装：以管理员开 PowerShell 执行 'wsl --install'，重启电脑"
        Pause-And-Exit 1
    }
    # 镜像还没 load，把 GPU 检查推迟到 docker run 时
    Write-Ok "镜像还没 load，GPU 检查将在容器启动时验证"
} else {
    Write-Ok "GPU 接通 OK"
}

# 4. 镜像在不在
Write-Step "3/5" "检查镜像 $ImageName..."
$r = Invoke-Native -FilePath $docker -Arguments @("image", "inspect", $ImageName) -TimeoutSec 30
if ($r.Code -ne 0) {
    if (Test-Path -LiteralPath $TarPath) {
        Write-Ok "镜像不存在，从 duix-avatar.tar 加载（4.7GB，约 2~5 分钟，别关窗口）"
        $r = Invoke-Native -FilePath $docker -Arguments @("load", "-i", $TarPath) -TimeoutSec 1800 -DisplayName "docker load"
        if ($r.Code -ne 0) {
            Write-Err "镜像加载失败"
            if ($r.Err) { Write-Host $r.Err }
            Write-Host ""
            Write-Host "常见原因：" -ForegroundColor Yellow
            Write-Host "  - 磁盘空间不足：Docker 默认安装盘需要至少 15GB 空闲"
            Write-Host "  - U 盘上跑：把整个文件夹复制到本机 SSD 再双击"
            Pause-And-Exit 1
        }
        Write-Ok "镜像加载成功"
    } else {
        Write-Err "镜像不存在，且当前文件夹找不到 duix-avatar.tar"
        Write-Host "把 duix-avatar.tar 跟本脚本放同一个文件夹，再双击本脚本"
        Pause-And-Exit 1
    }
} else {
    Write-Ok "镜像已存在"
}

# 5. 数据目录
Write-Step "4/5" "准备数据目录 $DataRoot..."
foreach ($sub in @("temp", "result", "log")) {
    $p = Join-Path $DataRoot $sub
    if (-not (Test-Path -LiteralPath $p)) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
    }
}
Write-Ok "数据目录就绪"

# 6. 干掉同名旧容器（如果有）
[void](Invoke-Native -FilePath $docker -Arguments @("rm", "-f", $ContainerName) -TimeoutSec 30)

# 7. 启动
Write-Step "5/5" "启动容器..."
$runArgs = @(
    "run", "-d",
    "--name", $ContainerName,
    "--gpus", "all",
    "--restart", "always",
    "--privileged",
    "--shm-size=8g",
    "-e", "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512",
    "-p", "$($HostPort):8383",
    "-v", "$($DataRoot.Replace('\','/')):/code/data",
    $ImageName,
    "python", "/code/app_local.py"
)
$r = Invoke-Native -FilePath $docker -Arguments $runArgs -TimeoutSec 120 -DisplayName "docker run"
if ($r.Code -ne 0) {
    Write-Err "容器启动失败"
    if ($r.Err) { Write-Host $r.Err }
    Write-Host ""
    Write-Host "常见原因：" -ForegroundColor Yellow
    Write-Host "  - GPU 没接通：见上面提示"
    Write-Host "  - $HostPort 端口被占：netstat -ano | findstr $HostPort 查谁占的"
    Pause-And-Exit 1
}
Write-Ok "容器已启动"

# 8. 等服务就绪
Write-Step "*" "等服务就绪（最多 60 秒）..."
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 3
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$HostPort/easy/query?code=ping" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
}

if (-not $ready) {
    Write-Host ""
    Write-Host "[警告] 容器起来了但服务 60 秒没响应。查日志：" -ForegroundColor Yellow
    Write-Host "  docker logs $ContainerName --tail 80"
    Pause-And-Exit 1
}

Write-Title "启动成功"
Write-Host ""
Write-Host "服务地址：http://127.0.0.1:$HostPort"
Write-Host "数据目录：$DataRoot"
Write-Host ""
Write-Host "现在打开 Duix.Avatar 客户端就能用。"
Write-Host ""
Write-Host "关掉这个窗口不会停容器。容器随 Docker Desktop 启动而启动。"
Write-Host "要手动停：在 Docker Desktop 里找到 $ContainerName，点停止；"
Write-Host "或在 PowerShell 里执行：docker stop $ContainerName"
Pause-And-Exit 0
