#Requires -Version 7.0
[CmdletBinding()]
param([string]$Source, [switch]$UpdateSnapshots)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Source) { $Source = Join-Path $projectRoot '.work\source' }
& (Join-Path $PSScriptRoot 'Initialize-BuildEnvironment.ps1') -Source $Source
$env:RUST_MIN_STACK = '16777216'
$env:INSTA_UPDATE = if ($UpdateSnapshots) { 'always' } else { 'no' }
Push-Location (Join-Path $Source 'codex-rs')
try {
    & cargo test --locked --profile dev-small -p codex-tui --lib -- keymap_setup:: analytics:: chatwidget::tests::plugin_catalog_tests chatwidget::tests::usage chatwidget::tests::skills_summary_tests app::daemon_menu:: bottom_pane::multi_select_picker:: bottom_pane::status_line_setup:: bottom_pane::title_setup:: tooltips:: --nocapture
    if ($LASTEXITCODE -ne 0) { throw '汉化回归检查未通过。' }
} finally { Pop-Location }

