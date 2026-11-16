#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Source)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = Get-Content -LiteralPath (Join-Path $projectRoot 'version.json') -Raw | ConvertFrom-Json
$cache = Join-Path $projectRoot '.work\v8-source'
$destination = Join-Path $Source 'codex-rs\vendor\rusty_v8'
if (Test-Path -LiteralPath (Join-Path $destination 'Cargo.toml')) { return }
New-Item -ItemType Directory -Path $cache, $destination -Force | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $cache '.git'))) {
    & git init $cache
    if ($LASTEXITCODE -ne 0) { throw '无法初始化 V8 源码缓存。' }
    & git -C $cache remote add origin $version.v8Repository
    if ($LASTEXITCODE -ne 0) { throw '无法设置 V8 源码来源。' }
}
& git -C $cache -c core.longpaths=true fetch --depth 1 origin $version.v8Revision
if ($LASTEXITCODE -ne 0) { throw '无法获取固定版本的 V8 Rust 绑定。' }
$actual = (& git -C $cache rev-parse FETCH_HEAD).Trim()
if ($actual -ne $version.v8Revision) { throw 'V8 提交校验失败。' }
$archive = Join-Path $projectRoot '.work\v8-source.tar'
& git -C $cache archive --format=tar --output=$archive FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw '无法导出 V8 Rust 绑定源码。' }
& tar -xf $archive -C $destination
if ($LASTEXITCODE -ne 0) { throw '无法解包 V8 Rust 绑定源码。' }
"Unmodified Rust bindings from $($version.v8Repository) at $actual. C++ submodules are omitted; build uses upstream verified prebuilt artifacts." |
    Set-Content -LiteralPath (Join-Path $destination 'CODEX-ZH-PROVENANCE.txt') -Encoding utf8
