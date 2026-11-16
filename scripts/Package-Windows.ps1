#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RuntimeDirectory,
    [Parameter(Mandatory)][string]$Executable,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = Get-Content -LiteralPath (Join-Path $projectRoot 'version.json') -Raw | ConvertFrom-Json
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'artifacts' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stage = Join-Path $OutputDirectory ('package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($name in 'bin','codex-path','codex-resources','codex-package.json','LICENSE','NOTICE') {
    $file = Join-Path $RuntimeDirectory $name
    if (-not (Test-Path -LiteralPath $file)) { throw "官方运行时不完整：$name" }
    Copy-Item -LiteralPath $file -Destination (Join-Path $stage $name) -Recurse
}
Copy-Item -LiteralPath $Executable -Destination (Join-Path $stage 'bin\codex.exe') -Force
Set-Content -LiteralPath (Join-Path $stage 'bin\codex-zh.cmd') -Encoding ascii -Value '@echo off','"%~dp0codex.exe" %*','exit /b %errorlevel%'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install.ps1') -Destination (Join-Path $stage 'install.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Uninstall.ps1') -Destination (Join-Path $stage 'uninstall.ps1')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\PORTABLE.md') -Destination (Join-Path $stage 'README.zh-CN.md')
$files = [ordered]@{}
foreach ($file in Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName) {
    $relative = [IO.Path]::GetRelativePath($stage,$file.FullName).Replace('\','/')
    $files[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
@{ project='codex-cli-zh'; version=$version.releaseTag; target=$version.testedTarget; upstreamVersion=$version.upstreamVersion; upstreamCommit=$version.upstreamCommit; buildProfile=$version.buildProfile; official=$false; allUiTranslated=$false; files=$files } |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $stage 'release.json') -Encoding utf8
& (Join-Path $PSScriptRoot 'Install.ps1') -PackageDirectory $stage -VerifyOnly
$archive = Join-Path $OutputDirectory "codex-cli-zh-$($version.releaseTag)-windows-x64.zip"
if (Test-Path -LiteralPath $archive) { throw '目标发布包已存在，请保留旧包并使用新的输出目录。' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage,$archive,[IO.Compression.CompressionLevel]::Optimal,$false)
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($archive))" | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS') -Encoding ascii
Write-Host "发布包：$archive"
Write-Host "SHA256：$hash"
