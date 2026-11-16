# 校验工具

`node tools/verify.mjs` 校验项目结构、版本清单、补丁哈希、提示数量和不应进入仓库的文件。

它不会把源码扫描的候选数量当作本地化完成率，也不能替代实际运行验证。完整界面回归测试见 `scripts/Test-Localization.ps1`。
