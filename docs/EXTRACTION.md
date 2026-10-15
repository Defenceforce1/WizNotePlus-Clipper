# 独立工程迁移记录

本文及 source-baseline.sha256 固定记录原始 0.2.0 拆分基线，不用来检查后来 0.3.0 修改后的文件。当前版本与验证以 README／release-0.3.0.md 为准，历史基线提交仍完整保留。

2026-10-15，用户要求主项目收尾清理，并将剪藏器独立为本地／GitHub 项目 `WizNotePlus-Clipper`。

来源：[WizNotePlus 4757df7](https://github.com/Defenceforce1/WizNotePlus/tree/4757df7bb8aed65172d6b816f8036c0105b32bb8/build/osx/native-clipper)，原候选版本 0.2.0，宿主与扩展内部版本 3。历史仍保留在原仓库，不改写旧提交、不从旧主仓库批量提取账号或二进制。

| 原路径 | 独立工程 |
| --- | --- |
| build/osx/native-clipper/*.swift | Sources/，逐字节不变 |
| build/osx/native-clipper/ClipPage.js | Resources/，逐字节不变 |
| build/osx/native-clipper/*.plist、Extension.entitlements | Configuration/，逐字节不变 |
| build/osx/native-clipper/build.sh | scripts/build.sh，仅调整本工程路径 |
| tests/compat/fixtures/clipper-cloud-page.html | tests/fixtures/，逐字节不变 |
| .github/workflows/web-clipper.yml | 独立 CI，改用 main 与新路径 |
| 独立剪藏说明／参考／验收与原 README | docs/history/，历史保留 |
| build/osx/licenses/GPL-3.0.txt 与 LICENSE | 根 LICENSE 全文、licenses/WizNotePlus-NOTICE.txt |

原作者通知继续保留；新原生实现按已有 GPL-3.0-or-later 范围独立维护。未导入两个社区浏览器项目的源码、库或图标。未包含主程序、Qt、个人账号／网页、原始日志／报告、签名身份、证书或私钥。

原始运行文件 SHA-256 见 `source-baseline.sha256`（相对本工程根目录）。将来功能修改可以据此区分“拆分”和“修复”。原始资料不改写，历史状态与当前差异以 README 和 ROADMAP 为准，尤其当前主 App 14.4.16 不提供新增 8849 桥接。

本次不改显示名、bundle ID、钥匙串服务、版本、功能代码、已安装包或扩展注册；不登录或上传云端，也不宣布图片／公式瑕疵和只推送策略已修复。
