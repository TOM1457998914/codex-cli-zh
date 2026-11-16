# 构建与验证

## 已验证环境

- Windows x64、PowerShell 7。
- 上游 Codex `0.169.0`，Rust 工具链 `1.95.0`。
- Visual Studio C++ 工具、Windows SDK、CMake、Ninja。
- r7 预览构建使用 `dev-small`；完整的 `release` 优化构建尚未作为此预览包验证。

源码和编译缓存会占用较多磁盘空间。建议把项目放在较短的路径，例如 `C:\src\codex-cli-zh`，并为 `.work` 预留充足空间。

## 准备源码

```powershell
pwsh -NoProfile -File .\scripts\Prepare-Source.ps1
```

脚本获取 `version.json` 指定的上游标签，核对提交 SHA，校验本地补丁，再应用补丁。目标目录已有其他内容时会退出，避免覆盖开发中的改动。

也可以使用现有的上游 Git 仓库进行离线补丁验证：

```powershell
pwsh -NoProfile -File .\scripts\Prepare-Source.ps1 `
  -LocalUpstream C:\src\codex `
  -Destination .\.work\verify-source `
  -SkipVendor
```

`-SkipVendor` 仅用于补丁检查；构建前还需运行 `Prepare-V8.ps1 -Source <源码目录>`。

## V8 依赖

本地补丁把固定的 Rust V8 绑定依赖转换为本地 `vendor/rusty_v8` 路径，版本仍为上游固定提交：

```text
90a65f887a0c0f048f3784afbcb320b373c8a2e0
```

`Prepare-V8.ps1` 从该 Git 提交导出 Rust 绑定，不拉取构建预编译库时不需要的 C++ 子模块。`Build-Windows.ps1` 使用 OpenAI 发布的 `rusty-v8-v152.2.0` Windows x64 库和绑定文件。

校验链为：本项目版本清单中的 SHA-256 → 上游发布校验清单 → 原生库与 Rust 绑定文件。该清单哈希与上游 `third_party/v8/rusty_v8_152_2_0_release_manifests.sha256` 一致。

## 编译

先确保 `git`、`rustup`、`cargo`、`cmake`、`ninja` 可从命令行调用。安装固定工具链：

```powershell
rustup toolchain install 1.95.0 --profile minimal
pwsh -NoProfile -File .\scripts\Build-Windows.ps1
```

脚本会尝试通过 `vswhere` 找到 C++ 工具，也可在已经配置好的 x64 开发者 PowerShell 中运行。产物位于 `.work\target\dev-small\codex.exe`。

依赖环境只在构建进程中设置，不写入系统级环境变量。若使用自定义 Cargo/Rustup 目录，请在启动构建的会话中设置它们。

## 测试

在已经配置好 C++、Cargo 和 V8 环境的会话中运行：

```powershell
cargo install cargo-nextest --version "=0.9.95" --locked
pwsh -NoProfile -File .\scripts\Test-Localization.ps1
```

该脚本运行完整 TUI、CLI、云任务和非交互输出单元测试，采用上游 Nextest 运行器，每个测试使用独立进程，默认 4 个测试并行，失败不重试。默认禁止自动更新快照。仅在有意改变文案或布局、并准备审阅差异时，才使用 `-UpdateSnapshots`。

更新内嵌快照时，安装与上游一致的 `cargo-insta` 1.46.3，在准备好的 `codex-rs` 目录运行 `cargo insta review --workspace`。先审阅差异，再接受；不要将内容消失、动态时间或内部标识变化当成正常翻译。完成后不带 `-UpdateSnapshots` 再运行完整测试。

本地 r7 结果保存在 `docs/verification.json`。全量源码扫描发现的候选项仍需要人工区分：程序标识、用户内容和远端文本不能直接算作漏译。

## 打包

准备同版本官方独立安装包的运行时目录，其中应包含 `bin`、`codex-path`、`codex-resources`、`codex-package.json`、`LICENSE` 和 `NOTICE`。然后运行：

```powershell
pwsh -NoProfile -File .\scripts\Package-Windows.ps1 `
  -RuntimeDirectory C:\packages\codex-0.169.0 `
  -Executable .\.work\target\dev-small\codex.exe
```

打包器复制运行所需的文件，替换为本地编译的主程序，并生成 `release.json`、安装器、ZIP 和 `SHA256SUMS`。它不收集个人 `.codex` 目录、账号文件、日志或聊天记录。

公开发布前必须重新验证 ZIP、检查清单与源代码版本，并清楚说明构建配置及已知缺口。
