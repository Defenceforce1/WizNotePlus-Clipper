# WizNotePlus Clipper

独立的 Apple Silicon macOS 网页剪藏工程，沿用 Safari「分享 → WizNotePlus 网页剪藏」入口。主 App 在[另一个仓库](https://github.com/Defenceforce1/WizNotePlus/tree/compat/macos-arm64-qt6)维护，本工程不依赖其源码、Qt 或主程序构建。

当前代码基线为 **0.2.0 开发候选**。2026-10-15 从主项目提取，Swift、JavaScript、配置与测试网页内容保持原样；只调整目录、构建路径、说明和 CI。**拆分不是新功能版，也不更新已安装剪藏器。**

## 当前能力和限制

- 原生 arm64 宿主＋系统分享扩展，整页／选中内容、标题和个人文件夹选择。
- 独立登录后直接上传为知服务器，不要求本机安装或运行主 App；云端操作需要联网。保存格式是 HTML＋图片／静态 MathML，不是 Markdown。
- 本机预览不上传；正式云端认证、保存及同步后保真、多机加载还没有完整验收。
- 图片、公式和复杂排版仍有瑕疵；现有代码**仍有结果轮询和未确认任务阻塞**，尚未实现用户要求的“只推送、不查询结果”。下一步见[待办](docs/ROADMAP.md)。
- 可选旧「保存到本机客户端」入口仍在源码，但当前主 App 14.4.16 的 8849 服务已经停用，不能把该入口描述为可用的当前配套方案。此次不恢复主 App 服务。
- 不读取旧官方剪藏器的钥匙串／账号，不保存密码，不自动重复上传。不是为知官方发行。

## 构建与隔离检查

Apple Silicon Mac，macOS 14 部署目标，系统 Swift／macOS SDK（本机已装 Xcode）。无外部包依赖。仅在新建的绝对输出路径构建：

```sh
bash scripts/build.sh /absolute/new-output-folder
bash scripts/test.sh '/absolute/new-output-folder/WizNotePlus Web Clipper.app'
```

第一条省略签名身份时使用 ad-hoc，运行 10 项输入与 28 项模拟云端／资源检查；第二条运行 9 项阻断网络的 WebKit 合成网页捕获检查。不会登录真实账号、上传网页、读真实凭据或注册扩展。不要把其他自测参数当作本轮批准的真实联网测试。

需要进一步 Safari 加载联调时，可在构建命令最后传入自己已有的 `Apple Development: …` 身份，不需要在聊天中提供密码或私钥。开发签名／临时签名都不是 Developer ID 或公证，不保证另一台 Mac 无条件加载。此次拆分未安装、注册、开启或重签正在使用的剪藏器。

## 工程结构

```text
Sources/          Swift 宿主、分享界面、输入、云端、凭据、资源和自测
Resources/        Safari 页面预处理 JavaScript
Configuration/    宿主／扩展 plist 和沙盒 entitlement
scripts/          仅本工程的构建与隔离验证
tests/fixtures/   无私人资料的合成网页
docs/             拆分来源、待办、验证与历史参考
```

上游来源、原始逐文件哈希和许可见[迁移记录](docs/EXTRACTION.md)。旧阶段文件保存在 `docs/history/`，里面的旧路径、主 App 版本和状态仅供历史追溯，不是当前使用指南。

GPL-3.0-or-later；全文见 [LICENSE](LICENSE)，保留原项目通知于 `licenses/`。未复制两个参考浏览器扩展的源码、图标或库。公开源码不含个人账号、日志、抓取快照、证书或私钥。剪藏器与主程序分别验收、构建、版本和打包。
