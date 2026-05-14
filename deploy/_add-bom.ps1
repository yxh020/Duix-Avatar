# 给目标 .ps1 加 UTF-8 BOM。PS 5.1 + 中文 Windows 必须。
# 维护脚本，跑一次就行；提交后可保留以便后续改 ps1 后重跑。

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$files = @(
    'deploy\package\tools\common.ps1',
    'deploy\package\tools\start-duix.ps1',
    'deploy\package\tools\diagnose-duix.ps1',
    'deploy\package\tools\stop-duix.ps1',
    'deploy\build-package.ps1',
    'deploy\_add-bom.ps1'
)
foreach ($f in $files) {
    $abs = Join-Path (Get-Location) $f
    if (-not (Test-Path -LiteralPath $abs)) {
        Write-Host ("缺失：" + $f) -ForegroundColor Yellow
        continue
    }
    $text = [IO.File]::ReadAllText($abs, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($abs, $text, $utf8Bom)
    $bytes = [IO.File]::ReadAllBytes($abs)
    $head = ($bytes[0..2] -join ',')
    if ($head -eq '239,187,191') {
        Write-Host ("OK  " + $f) -ForegroundColor Green
    } else {
        Write-Host ("BAD " + $f + " (head=" + $head + ")") -ForegroundColor Red
    }
}
