#Requires -Version 7.0
[CmdletBinding()]
param([string]$Source, [switch]$UpdateSnapshots)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Source) { $Source = Join-Path $projectRoot '.work\source' }
& (Join-Path $PSScriptRoot 'Initialize-BuildEnvironment.ps1') -Source $Source
$env:RUST_MIN_STACK = '16777216'
$env:INSTA_UPDATE = if ($UpdateSnapshots) { 'new' } else { 'no' }
$env:INSTA_FORCE_PASS = '0'
if (-not (Get-Command cargo-nextest -ErrorAction SilentlyContinue)) {
    throw '请先安装测试运行器：cargo install cargo-nextest --version "=0.9.95" --locked'
}
Push-Location (Join-Path $Source 'codex-rs')
try {
    # Run the complete unit suites for the localized UI and human-output crates.
    # Snapshot updates are opt-in; a release must pass again without this switch.
    & cargo nextest run --locked --cargo-profile dev-small --profile local --no-fail-fast --retries 0 --test-threads 4 --ignore-default-filter -p codex-tui -p codex-cloud-tasks -p codex-exec --lib
    $uiExit = $LASTEXITCODE
    & cargo nextest run --locked --cargo-profile dev-small --profile local --no-fail-fast --retries 0 --test-threads 4 --ignore-default-filter -p codex-cli --bin codex
    $cliExit = $LASTEXITCODE
    if ($uiExit -ne 0 -or $cliExit -ne 0) { throw '汉化回归检查未通过。' }
} finally { Pop-Location }

