# Codex CLI 简体中文预览包

版本：上游 0.169.0，本地化 r7。平台：Windows x64。

这是非官方、未做发布级优化的源码构建，主要界面已汉化，仍有部分英文提示。项目主页：https://github.com/TOM1457998914/codex-cli-zh

## 免安装运行

保留整个解压目录，运行 `bin\codex-zh.cmd`。不要只移动 `codex.exe`；同目录的运行时文件是必要组成部分。

## 安装命令

在 PowerShell 7 中执行：

```powershell
pwsh -NoProfile -File .\install.ps1
```

重新打开终端后运行 `codex-zh`。安装器校验文件内容，并安装到当前用户的 `%LOCALAPPDATA%\Programs\CodexCliZh`。

只验证、不安装：

```powershell
pwsh -NoProfile -File .\install.ps1 -VerifyOnly
```

## 更新、回退与卸载

更新使用项目的新发布包。旧版本会保留在 `versions` 目录；运行旧版本目录里的 `install.ps1` 可以切换回该版本。

退出中文版后，可运行本包的 `uninstall.ps1` 卸载由此安装器安装的版本。官方 Codex 和个人 `.codex` 数据保留。

## 验证信息

`release.json` 记录各运行文件的 SHA-256、固定上游提交和构建配置。发布页面的 `SHA256SUMS` 记录整个 ZIP 的 SHA-256。

汉化不会改变账号权益或模型功能。命令名称、配置键、模型名称、代码和用户输入保留原文。
