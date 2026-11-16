#Requires -Version 7.0
[CmdletBinding()]
param([string]$Source, [ValidateSet('dev-small','release')][string]$Profile='dev-small', [int]$Jobs=4)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Source) { $Source = Join-Path $projectRoot '.work/source' }
& (Join-Path $PSScriptRoot 'Initialize-BuildEnvironment.ps1') -Source $Source -Jobs $Jobs
Push-Location (Join-Path $Source 'codex-rs')
try {
    & cargo build --locked --profile $Profile -p codex-cli --bin codex
    if ($LASTEXITCODE -ne 0) { throw 'Codex 中文源码构建失败。' }
} finally { Pop-Location }
Write-Host "构建完成：$(Join-Path $env:CARGO_TARGET_DIR "$Profile\codex.exe")"

