# 工程拆分验证

日期：2026-10-15。独立工程只调整目录、构建资源路径、文档与 CI，运行代码／配置版本仍为 0.2.0。

本机完成：

- `docs/source-baseline.sha256` 中 11 个运行源码／配置文件逐字节核对通过；合成网页与原 fixture 比较通过。
- 独立根目录运行 `scripts/build.sh`，仅使用 macOS SDK／Swift，未读取或构建主 App／Qt。
- 宿主、分享扩展均为 arm64，严格 ad-hoc 签名通过；三个配置文件 plist 语法通过。
- 输入 10 项、模拟云端／资源 28 项、阻断网络的 WebKit 本地捕获 9 项，总计 47 项通过。
- 脚本语法通过。独立 CI 已提供，但不能把本机通过称为 GitHub Actions 已通过。

不安装或注册测试 App，不更换现有扩展、不调用真实钥匙串／账号／云端写入，不改变主 App 14.4.16 或笔记资料。

此次不修复 0.2.0 已知的图片／公式瑕疵、结果轮询／未确认阻塞，不进行真实网页或 Apple Development 多机加载验收；详细待办见 ROADMAP。签名成功不等于扩展在所有 Mac 都可加载，也不是已公证或公开稳定版。

原始构建／测试日志留在本机维护记录，不提交可能包含机器元数据的原始日志。来源和许可见 EXTRACTION。

## 独立 GitHub CI

源码提交 `7b1e284f42fd75242d142b047d2c659c0b73b0cc` 的 [Independent native clipper 运行](https://github.com/Defenceforce1/WizNotePlus-Clipper/actions/runs/38681203468) 已于 2026-10-15 完成，结论 success。在独立 macOS runner 从本仓库检出后执行构建、输入／模拟云端和网络阻断捕获，并生成测试包／对应源码工件。不依赖主 App 仓库或 Qt；不表示系统分享加载、真实云端或多机开发签名已验收。本节为后续 CI 记录，不改变该次实际测试的源码。
