# 脚本

| 脚本 | 用途 |
| --- | --- |
| Prepare-Source.ps1 | 获取固定上游版本并校验、应用补丁 |
| Prepare-V8.ps1 | 导出固定版本的 V8 Rust 绑定 |
| Build-Windows.ps1 | 核对 V8 产物并构建 Windows x64 主程序 |
| Test-Localization.ps1 | 运行选定的界面回归测试 |
| Package-Windows.ps1 | 从同版本官方运行时与本地主程序生成分发包 |
| Install.ps1 | 验证并安装指定发布包，保留旧版本 |
| Uninstall.ps1 | 卸载本安装器管理的应用目录 |

构建要求和运行顺序见 `../docs/BUILDING.md`。
