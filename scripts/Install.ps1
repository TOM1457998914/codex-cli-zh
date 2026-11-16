#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$PackageDirectory,
    [string]$Archive,
    [string]$Version='v0.169.0-zh.5',
    [switch]$VerifyOnly,
    [switch]$NoPath
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw '此安装脚本适用于 Windows。' }
if ($Archive -and $PackageDirectory) { throw 'Archive 与 PackageDirectory 只能指定一个。' }
if ($Version -notmatch '^v\d+\.\d+\.\d+-zh\.\d+$') { throw '无效的版本号。' }
$temporaryDirectories = [Collections.Generic.List[string]]::new()
function Resolve-InPackage([string]$Root, [string]$Relative) {
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath((Join-Path $prefix $Relative))
    if (-not $candidate.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw '安装包含有目录外路径。' }
    return $candidate
}
try {
if (-not $Archive -and -not $PackageDirectory -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'release.json'))) {
    $PackageDirectory = $PSScriptRoot
}
if (-not $Archive -and -not $PackageDirectory) {
    $downloadDir = Join-Path ([IO.Path]::GetTempPath()) ('codex-cli-zh-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $downloadDir | Out-Null
    $temporaryDirectories.Add($downloadDir)
    $asset = "codex-cli-zh-$Version-windows-x64.zip"
    $baseUrl = "https://github.com/TOM1457998914/codex-cli-zh/releases/download/$Version"
    $Archive = Join-Path $downloadDir $asset
    $sums = Join-Path $downloadDir 'SHA256SUMS'
    Invoke-WebRequest "$baseUrl/SHA256SUMS" -OutFile $sums
    $record = Get-Content -LiteralPath $sums | Where-Object { $_ -match ('^[a-fA-F0-9]{64}\s+\*?' + [regex]::Escape($asset) + '$') }
    if (@($record).Count -ne 1) { throw '发布包校验记录缺失或重复。' }
    Invoke-WebRequest "$baseUrl/$asset" -OutFile $Archive
    if ((Get-FileHash -LiteralPath $Archive).Hash -ne ($record -split '\s+')[0]) { throw '下载的安装包校验失败。' }
}
if ($Archive) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $PackageDirectory = Join-Path ([IO.Path]::GetTempPath()) ('codex-cli-zh-extracted-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $PackageDirectory | Out-Null
    $temporaryDirectories.Add($PackageDirectory)
    $zip = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($Archive))
    try { foreach ($entry in $zip.Entries) { $null = Resolve-InPackage $PackageDirectory $entry.FullName } } finally { $zip.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory([IO.Path]::GetFullPath($Archive),$PackageDirectory)
}
$PackageDirectory = [IO.Path]::GetFullPath($PackageDirectory)
$manifest = Get-Content -LiteralPath (Join-Path $PackageDirectory 'release.json') -Raw | ConvertFrom-Json
if ($manifest.project -ne 'codex-cli-zh' -or $manifest.target -ne 'x86_64-pc-windows-msvc' -or $manifest.version -notmatch '^v\d+\.\d+\.\d+-zh\.\d+$') { throw '不支持此安装包。' }
if (-not $manifest.files.'bin/codex.exe') { throw '安装包未列出 Codex 可执行文件。' }
foreach ($entry in $manifest.files.PSObject.Properties) {
    if ($entry.Value -notmatch '^[a-fA-F0-9]{64}$') { throw '安装包中存在无效校验值。' }
    $file = Resolve-InPackage $PackageDirectory $entry.Name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-FileHash -LiteralPath $file).Hash -ne $entry.Value) { throw "文件校验失败：$($entry.Name)" }
}
if ($VerifyOnly) {
    [pscustomobject]@{ Version=$manifest.version; Target=$manifest.target; FilesChecked=@($manifest.files.PSObject.Properties).Count; Passed=$true }
    return
}
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\CodexCliZh'
$receiptPath = Join-Path $installRoot '.codex-zh-install.json'
$oldVersion = if (Test-Path -LiteralPath $receiptPath) { (Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json).currentVersion } else { $null }
$destination = Join-Path $installRoot "versions\$($manifest.version)"
if (Test-Path -LiteralPath $destination) {
    foreach ($entry in $manifest.files.PSObject.Properties) {
        $file = Resolve-InPackage $destination $entry.Name
        if (-not (Test-Path -LiteralPath $file) -or (Get-FileHash -LiteralPath $file).Hash -ne $entry.Value) { throw '此版本目录已有不同构建。请保留它，并使用不同版本号发布新构建。' }
    }
} else {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($entry in $manifest.files.PSObject.Properties) {
        $target = Resolve-InPackage $destination $entry.Name
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Resolve-InPackage $PackageDirectory $entry.Name) -Destination $target
    }
    Copy-Item -LiteralPath (Join-Path $PackageDirectory 'release.json') -Destination (Join-Path $destination 'release.json')
}
$bin = Join-Path $installRoot 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
Set-Content -LiteralPath (Join-Path $bin 'codex-zh.cmd') -Encoding ascii -Value '@echo off', ('"%~dp0..\versions\' + $manifest.version + '\bin\codex.exe" %*'), 'exit /b %errorlevel%'
if (-not $NoPath) {
    $oldPath = [Environment]::GetEnvironmentVariable('Path','User')
    $parts = @($oldPath -split ';' | Where-Object { $_ -and $_.TrimEnd('\','/') -ine $bin.TrimEnd('\','/') })
    [Environment]::SetEnvironmentVariable('Path', (($bin) + ';' + ($parts -join ';')), 'User')
    $env:Path = $bin + ';' + $env:Path
}
@{ project='codex-cli-zh'; installRoot=$installRoot; currentVersion=$manifest.version; previousVersion=$oldVersion } |
    ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8
Write-Host "已安装 $($manifest.version)。重新打开终端后运行 codex-zh。"
Write-Host '官方 codex 命令及个人 .codex 数据保留。'


} finally {
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    foreach ($directory in $temporaryDirectories) {
        if (-not (Test-Path -LiteralPath $directory)) { continue }
        $resolved = (Resolve-Path -LiteralPath $directory).Path
        $item = Get-Item -LiteralPath $resolved
        if ($resolved.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -and
            $item.Name -match '^codex-cli-zh-(extracted-)?[a-f0-9]{32}$' -and
            -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
