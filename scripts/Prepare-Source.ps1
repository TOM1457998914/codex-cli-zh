#Requires -Version 7.0
[CmdletBinding()]
param([string]$Destination, [string]$LocalUpstream, [switch]$SkipVendor)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = Get-Content -LiteralPath (Join-Path $projectRoot 'version.json') -Raw | ConvertFrom-Json
if (-not $Destination) { $Destination = Join-Path $projectRoot '.work\source' }
$Destination = [IO.Path]::GetFullPath($Destination)
function Invoke-Git([string[]]$Arguments) {
    & git -c core.longpaths=true @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($Arguments -join ' ')" }
}
$patch = Join-Path $projectRoot $version.patch
if ((Get-FileHash -LiteralPath $patch -Algorithm SHA256).Hash -ne $version.patchSha256) { throw '源码补丁校验失败。' }
if (Test-Path -LiteralPath $Destination) {
    $marker = Join-Path $Destination '.codex-zh-source.json'
    if ((Test-Path -LiteralPath $marker) -and ((Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json).patchSha256 -eq $version.patchSha256)) {
        $state = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
        if (-not $SkipVendor -and -not $state.vendorPrepared) {
            & (Join-Path $PSScriptRoot 'Prepare-V8.ps1') -Source $Destination
            $state.vendorPrepared = $true
            $state | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding utf8
        }
        Write-Host "已准备好源码：$Destination"
        return
    }
    throw '目标目录已存在。为保护已有改动，请指定一个新的空目录。'
}
New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
if ($LocalUpstream) {
    Invoke-Git -Arguments @('clone', '--no-hardlinks', '--no-checkout', '--', [IO.Path]::GetFullPath($LocalUpstream), $Destination)
    Invoke-Git -Arguments @('-C', $Destination, 'checkout', '--detach', $version.upstreamCommit)
} else {
    Invoke-Git -Arguments @('init', $Destination)
    Invoke-Git -Arguments @('-C', $Destination, 'remote', 'add', 'origin', $version.upstreamRepository)
    Invoke-Git -Arguments @('-C', $Destination, 'fetch', '--depth', '1', 'origin', "refs/tags/$($version.upstreamTag)")
    Invoke-Git -Arguments @('-C', $Destination, 'checkout', '--detach', 'FETCH_HEAD')
}
$actual = (& git -C $Destination rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actual -ne $version.upstreamCommit) { throw '上游提交与版本清单不符。' }
Invoke-Git -Arguments @('-C', $Destination, 'apply', '--check', '--whitespace=nowarn', $patch)
Invoke-Git -Arguments @('-C', $Destination, 'apply', '--whitespace=nowarn', $patch)
if (-not $SkipVendor) { & (Join-Path $PSScriptRoot 'Prepare-V8.ps1') -Source $Destination }
@{ upstreamCommit=$actual; patchSha256=$version.patchSha256; revision=$version.revision; vendorPrepared=(-not $SkipVendor) } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Destination '.codex-zh-source.json') -Encoding utf8
Write-Host "源码补丁已应用：$Destination"


