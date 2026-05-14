# AI数字人 · 整合包 · 源文件

本目录是**整合包的脚本/文档源**。最终的运营整合包由 `deploy/build-package.ps1` 组装。

## 目录结构

```
deploy/package/
├─ 开始使用.bat        ← 运营双击启动
├─ 环境诊断.bat        ← 故障处理菜单
├─ 停止服务.bat        ← 停后台容器
├─ 安装说明.txt        ← 给运营看的纯文本说明
└─ tools/
   ├─ common.ps1       ← 共享：UTF-8、Invoke-Native、检查项、操作函数
   ├─ start-duix.ps1   ← 启动主逻辑（预检 → 导镜像 → 起容器 → 弹应用）
   ├─ diagnose-duix.ps1 ← 诊断菜单
   └─ stop-duix.ps1    ← 停容器
```

## 打整合包

在仓库根目录：

```powershell
# 1. 先打应用 setup.exe（要在 dist/ 下）
npm run build:win

# 2. 再打整合包
deploy\build-package.bat
```

产物：`dist-package/AI数字人整合包-v<version>/`，体积约 6-8 GB。

`build-package.ps1` 会做的事：
1. 检查 `dist/AI数字人-<version>-setup.exe` 在不在（不在就让你先 build:win）
2. 检查 WSL 离线 zip / Docker installer 路径
3. `docker save guiji2025/duix.avatar` 导出镜像（约 5-10 分钟，5+GB）
4. 复制 installers、deploy/compose、tools、examples 测试素材
5. 写 manifest.json

## 设计原则

- **.bat 入口纯 ASCII**，避免中文编码踩坑
- **所有 .ps1 必须 UTF-8 with BOM**（写完手动补 BOM，PS 5.1 才能正确读中文）
- **PS 第一件事设控制台 UTF-8**，否则 PS 5.1 主机中文字符串输出会乱
- **调 docker.exe / nvidia-smi.exe 走 ProcessStartInfo + 超时**，不直接 `&`
- **运营看到的所有红字都给"怎么做"**，不是只报错

## 修改流程

改完任何 .ps1：

```powershell
# 补 BOM（PS 5.1 / 中文 Windows 必须）
$utf8WithBom = New-Object System.Text.UTF8Encoding($true)
$path = 'deploy\package\tools\start-duix.ps1'
$text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($path, $text, $utf8WithBom)
```

或者跑：

```powershell
deploy\package\tools\_add-bom.ps1   # 一次性给整个目录补 BOM（如果有的话）
```

（参考 `C:\Users\Admin\.claude\CLAUDE.md` 里"Windows 分发脚本"那节）
