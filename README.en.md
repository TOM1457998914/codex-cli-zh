# Codex CLI — Simplified Chinese

[中文说明](README.md)

An unofficial source-level localization overlay for [OpenAI Codex](https://github.com/openai/codex), pinned to `rust-v0.169.0` / `d32063f96c2dff1dc96af839b3952abb6acfeda4`.

The current preview is **r7**, tested on **Windows x64**. It translates common menus, session pickers, keymap settings, plugins, apps, usage analytics, MCP status and tooltips. Configuration keys, command names, protocol identifiers and user content are preserved.

Localization is ongoing. Static CLI help and more low-frequency workflows are now covered. Some server-provided messages, third-party errors and raw diagnostics retain their original text. This project is not affiliated with or endorsed by OpenAI.

## Install

Download the Windows x64 preview ZIP from [Releases](https://github.com/TOM1457998914/codex-cli-zh/releases), extract it, and run:

```powershell
pwsh -NoProfile -File .\install.ps1
```

Open a new terminal and run `codex-zh`. The official `codex` command remains separate. Both use the same Codex account and user data.

## Build and verify

See [BUILDING.md](docs/BUILDING.md). The repository supplies a pinned source patch, reference translation catalogs and PowerShell tooling. V8 artifacts are verified against the checksum manifest pinned by the upstream release.

r7 fixes translated internal identifiers, copy payloads, paste-label collisions, CJK geometry, URL targets and shortcut hints. Final local verification passed 6052 TUI, 310 CLI, 24 cloud-task and 64 noninteractive-output unit tests, with snapshot updates and retries disabled. The upstream Nextest runner isolates test processes. See [verification.json](docs/verification.json) and [the audit record](docs/AUDIT-r7.md). CI verifies project integrity, PowerShell syntax, clean patch application and identifier contracts; the full Windows test run is recorded separately.

The preview executable uses the unoptimized `dev-small` profile. It is an unsigned community build and does not support updating this localization through `codex update`.

## License

[Apache-2.0](LICENSE), with upstream [NOTICE](NOTICE) retained. Dependencies retain their respective licenses.
