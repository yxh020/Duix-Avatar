# AI数字人 - 一键启动脚本（运营双击 开始使用.bat 调起）
# 流程：预检查 → 必要时导入镜像 → 启动容器 → 等待 API → 弹应用

. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host ''
Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║       AI数字人 · 启动服务                ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan

# 1. 预检查
Write-Section '1/4 环境预检查'

$checks = @(
    @{ Name='管理员权限';    Fn={ Test-Admin };          Hard=$false },
    @{ Name='NVIDIA 驱动';   Fn={ Test-NvidiaDriver };   Hard=$true  },
    @{ Name='WSL';           Fn={ Test-WslInstalled };   Hard=$true  },
    @{ Name='Docker';        Fn={ Test-DockerInstalled };Hard=$true  },
    @{ Name='GPU 直通';      Fn={ Test-DockerGpuAccess };Hard=$true  }
)

$hardFail = $false
foreach ($c in $checks) {
    $r = & $c.Fn
    if ($r.Ok) {
        Write-Ok ($c.Name + '：' + $r.Message)
    } else {
        if ($c.Hard) {
            Write-Fail ($c.Name + '：' + $r.Message)
            if ($r.Hint) { Write-Info ('提示：' + $r.Hint) }
            $hardFail = $true
        } else {
            Write-Warn2 ($c.Name + '：' + $r.Message)
            if ($r.Hint) { Write-Info ('提示：' + $r.Hint) }
        }
    }
}

if ($hardFail) {
    Write-Host ''
    Write-Host '硬性条件未满足，无法启动。请按上面的提示处理后，再双击"开始使用.bat"。' -ForegroundColor Red
    Write-Host ''
    Read-Host '按回车键退出'
    exit 1
}

# 2. 数据目录
Write-Section '2/4 准备数据目录'
Ensure-DataRoot

# 3. 镜像 & 容器
Write-Section '3/4 启动容器'
$imageCheck = Test-ImageReady
if (-not $imageCheck.Ok) {
    Write-Info $imageCheck.Message
    Import-DuixImage
}
Compose-Up

# 4. 等 API 就绪
Write-Section '4/4 等待服务就绪'
Wait-ApiReady -MaxSec 60 | Out-Null

# 5. 弹应用
Write-Section '启动应用'
Open-App | Out-Null

Write-Host ''
Write-Host '完成。如果应用没有自动打开，请到桌面双击 "AI数字人" 快捷方式。' -ForegroundColor Green
Write-Host ''
Read-Host '按回车键关闭此窗口（容器会继续在后台运行）'
exit 0
