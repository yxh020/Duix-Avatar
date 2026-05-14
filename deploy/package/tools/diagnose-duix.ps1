# AI数字人 - 环境诊断 + 故障处理菜单（运营双击 环境诊断.bat 调起）
# 不会自动改任何东西，只在用户主动选菜单后才动手

. (Join-Path $PSScriptRoot 'common.ps1')

function Show-FullDiagnosis {
    Write-Section '综合诊断'
    $items = @(
        @{ Name='管理员权限';   Fn={ Test-Admin } },
        @{ Name='NVIDIA 驱动';  Fn={ Test-NvidiaDriver } },
        @{ Name='WSL';          Fn={ Test-WslInstalled } },
        @{ Name='Docker 安装';  Fn={ Test-DockerInstalled } },
        @{ Name='Docker GPU';   Fn={ Test-DockerGpuAccess } },
        @{ Name='镜像就绪';     Fn={ Test-ImageReady } },
        @{ Name='容器运行';     Fn={ Test-ContainerRunning } },
        @{ Name='端口占用';     Fn={ Test-Port8383Free } },
        @{ Name='容器 API';     Fn={ Test-EasyApiResponding } }
    )
    foreach ($it in $items) {
        $r = & $it.Fn
        if ($r.Ok) {
            Write-Ok ($it.Name + '：' + $r.Message)
        } else {
            Write-Fail ($it.Name + '：' + $r.Message)
            if ($r.Hint) { Write-Info ('提示：' + $r.Hint) }
        }
    }
    Write-Host ''
    Write-Host '诊断完成。把以上输出截图发给技术。' -ForegroundColor Cyan
}

function Restart-Container {
    Write-Section '重启容器'
    Compose-Down
    Start-Sleep -Seconds 2
    Compose-Up
    Wait-ApiReady -MaxSec 60 | Out-Null
}

function Reimport-Image {
    Write-Section '重新导入镜像'
    # 先停容器，否则旧镜像在用，无法清理
    Compose-Down
    Start-Sleep -Seconds 2
    # 删旧镜像（如果存在）
    $r = Invoke-Native -FilePath 'docker.exe' -Arguments @('images','-q',$Script:ImageName) -TimeoutSec 15
    if (-not [string]::IsNullOrWhiteSpace($r.StdOut)) {
        Write-Info '删除旧镜像 ...'
        Invoke-Native -FilePath 'docker.exe' -Arguments @('rmi','-f',$Script:ImageName) -TimeoutSec 60 | Out-Null
    }
    Import-DuixImage
    Compose-Up
    Wait-ApiReady -MaxSec 60 | Out-Null
}

function Show-Logs {
    Write-Section '查看容器日志（最近 80 行）'
    $r = Invoke-Native -FilePath 'docker.exe' -Arguments @('logs','--tail','80', $Script:ContainerName) -TimeoutSec 30
    if ($r.ExitCode -ne 0) {
        Write-Fail ('docker logs 失败：' + $r.StdErr.Trim())
        return
    }
    Write-Host $r.StdOut
}

function Show-Menu {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║       AI数字人 · 环境诊断 / 故障处理     ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  1. 综合诊断（查看所有检查项的红绿状态）'
    Write-Host '  2. 重启容器（停后重起）'
    Write-Host '  3. 停止容器'
    Write-Host '  4. 重新导入镜像（出现镜像损坏 / 升级时用）'
    Write-Host '  5. 查看容器最近日志'
    Write-Host '  6. 启动应用窗口'
    Write-Host '  0. 退出'
    Write-Host ''
}

while ($true) {
    Show-Menu
    $choice = Read-Host '请输入数字'
    switch ($choice) {
        '1' { Show-FullDiagnosis }
        '2' { Restart-Container }
        '3' { Compose-Down }
        '4' { Reimport-Image }
        '5' { Show-Logs }
        '6' { Open-App | Out-Null }
        '0' { exit 0 }
        default { Write-Warn2 ('未识别的选项：' + $choice) }
    }
}
