# 校验工具

`node tools/verify.mjs` 校验项目结构、版本清单、补丁哈希、提示数量和不应进入仓库的文件。

它不会把源码扫描的候选数量当作本地化完成率，也不能替代实际运行验证。完整界面回归测试见 `scripts/Test-Localization.ps1`。

## 程序标识与显示边界

准备好源码后，运行小型 Rust 语法树审计工具：

```powershell
cargo test --locked --manifest-path tools/Cargo.toml --target-dir .work/contracts-target
cargo build --locked --manifest-path tools/Cargo.toml --target-dir .work/contracts-target
node tools/verify-contracts.mjs
```

也可把已准备的源码路径作为第一个参数、审计工具路径作为第二个参数。报告写入 `.work/contract-audit/report.json`，不会修改被检查的源码。

`contract-allowlist.json` 仅批准已人工审阅的精确前后值。新增差异或不再匹配的旧例外都会失败。不要直接把生成的 `proposal.json` 当作批准清单。检查范围和限制见 [r6 排查记录](../docs/AUDIT-r6.md)。
