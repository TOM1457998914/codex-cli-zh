#Requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw '此脚本适用于 Windows。' }
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs\CodexCliZh'))
$receiptPath = Join-Path $expectedRoot '.codex-zh-install.json'
if (-not (Test-Path -LiteralPath $receiptPath)) { throw '未找到由本项目安装的版本，不会移除其他安装。' }
$receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
$actualRoot = (Resolve-Path -LiteralPath $expectedRoot).Path
if ($receipt.project -ne 'codex-cli-zh' -or $actualRoot -ine $expectedRoot -or $receipt.installRoot -ine $expectedRoot) { throw '安装目录验证失败。' }
$running = Get-Process -Name codex -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($expectedRoot + '\',[StringComparison]::OrdinalIgnoreCase) }
if ($running) { throw '请先退出此项目安装的 Codex 中文版，再执行卸载。' }
$bin = Join-Path $expectedRoot 'bin'
$oldPath = [Environment]::GetEnvironmentVariable('Path','User')
$nextPath = @($oldPath -split ';' | Where-Object { $_ -and $_.TrimEnd('\','/') -ine $bin.TrimEnd('\','/') }) -join ';'
# The resolved target is exactly the app directory recorded by this installer.
Remove-Item -LiteralPath $actualRoot -Recurse -Force
[Environment]::SetEnvironmentVariable('Path',$nextPath,'User')
Write-Host '已卸载本项目安装的版本；官方 Codex 和个人 .codex 数据保留。'
