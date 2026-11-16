# Codex CLI — Simplified Chinese

[中文说明](README.md)

An unofficial source-level localization overlay for [OpenAI Codex](https://github.com/openai/codex), pinned to `rust-v0.169.0` / `d32063f96c2dff1dc96af839b3952abb6acfeda4`.

The current preview is **r5**, tested on **Windows x64**. It translates common menus, session pickers, keymap settings, plugins, apps, usage analytics, MCP status and tooltips. Configuration keys, command names, protocol identifiers and user content are preserved.

Localization is ongoing. CLI help, low-frequency messages and some server-provided text remain untranslated. This project is not affiliated with or endorsed by OpenAI.

## Install

Download the Windows x64 preview ZIP from [Releases](https://github.com/TOM1457998914/codex-cli-zh/releases), extract it, and run:

```powershell
pwsh -NoProfile -File .\install.ps1
```

Open a new terminal and run `codex-zh`. The official `codex` command remains separate. Both use the same Codex account and user data.

## Build and verify

See [BUILDING.md](docs/BUILDING.md). The repository supplies a pinned source patch, reference translation catalogs and PowerShell tooling. V8 artifacts are verified against the checksum manifest pinned by the upstream release.

The r5 local UI regression selection passed **307 tests**. CI checks repository integrity, PowerShell syntax and clean application of the pinned patch; it does not claim to run the complete upstream test suite.

The preview executable uses the unoptimized `dev-small` profile. It is an unsigned community build and does not support updating this localization through `codex update`.

## License

[Apache-2.0](LICENSE), with upstream [NOTICE](NOTICE) retained. Dependencies retain their respective licenses.
