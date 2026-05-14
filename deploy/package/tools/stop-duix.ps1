# AI数字人 - 停止后台容器（双击 停止服务.bat 调起）
# 注意：只停容器。应用窗口要自己关。

. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host ''
Write-Host '停止 AI数字人 后台服务 ...' -ForegroundColor Cyan
Compose-Down

Write-Host ''
Write-Host '完成。下次双击"开始使用.bat"可以重新启动。' -ForegroundColor Green
Write-Host ''
Read-Host '按回车键关闭此窗口'
exit 0
