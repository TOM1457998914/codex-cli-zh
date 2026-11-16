#Requires -Version 7.0
[CmdletBinding()]
param([string]$Source, [int]$Jobs=4)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') { throw '目前已验证的构建平台为 Windows x64。' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = Get-Content -LiteralPath (Join-Path $projectRoot 'version.json') -Raw | ConvertFrom-Json
if (-not $Source) { $Source = Join-Path $projectRoot '.work\source' }
if (-not (Test-Path -LiteralPath (Join-Path $Source '.codex-zh-source.json'))) { throw '请先运行 Prepare-Source.ps1。' }
foreach ($command in 'cargo','rustup','git','cmake','ninja') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "缺少构建工具：$command。详见 docs/BUILDING.md。" }
}
if (-not $env:VCToolsInstallDir) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) { throw '找不到 Visual Studio C++ Build Tools。请在 x64 开发者 PowerShell 中运行。' }
    $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw '未找到 x64 C++ 编译工具。' }
    $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvarsall.bat'
    $vcEnvironment = & $env:ComSpec /d /s /c ('""{0}" x64 >nul && set"' -f $vcvars)
    if ($LASTEXITCODE -ne 0) { throw '无法初始化 C++ 编译环境。' }
    foreach ($entry in $vcEnvironment) {
        if ($entry -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1],$matches[2],'Process') }
    }
}
$v8 = Join-Path $projectRoot '.work\v8-artifacts'
New-Item -ItemType Directory -Path $v8 -Force | Out-Null
$baseUrl = "https://github.com/openai/codex/releases/download/$($version.v8Release)"
$manifestPath = Join-Path $v8 $version.v8Manifest
if (-not (Test-Path -LiteralPath $manifestPath)) { Invoke-WebRequest "$baseUrl/$($version.v8Manifest)" -OutFile $manifestPath }
if ((Get-FileHash -LiteralPath $manifestPath).Hash -ne $version.v8ManifestSha256) { throw '上游 V8 校验清单不匹配。' }
foreach ($line in Get-Content -LiteralPath $manifestPath) {
    if ($line -notmatch '^([a-fA-F0-9]{64})\s+\*?([^/\\]+)$') { throw '无法识别 V8 校验项。' }
    $expected = $matches[1]; $name = $matches[2]; $file = Join-Path $v8 $name
    if (-not (Test-Path -LiteralPath $file)) { Invoke-WebRequest "$baseUrl/$name" -OutFile $file }
    if ((Get-FileHash -LiteralPath $file).Hash -ne $expected) { throw "V8 文件校验失败：$name" }
}
$env:RUSTUP_TOOLCHAIN = $version.rustToolchain
$env:CARGO_TARGET_DIR = Join-Path $projectRoot '.work\target'
$env:CARGO_BUILD_JOBS = [string]$Jobs
$env:CMAKE_GENERATOR = 'Ninja'
$env:RUSTY_V8_ARCHIVE = Join-Path $v8 'rusty_v8_ptrcomp_sandbox_release_x86_64-pc-windows-msvc.lib.gz'
$env:RUSTY_V8_SRC_BINDING_PATH = Join-Path $v8 'src_binding_ptrcomp_sandbox_release_x86_64-pc-windows-msvc.rs'

