# WizNotePlus Clipper

独立的 Apple Silicon macOS 网页剪藏工程，沿用 Safari「分享 → WizNotePlus 网页剪藏」入口。主 App 在[另一个仓库](https://github.com/Defenceforce1/WizNotePlus/tree/compat/macos-arm64-qt6)维护，本工程不依赖其源码、Qt 或主程序构建。

当前为 **0.3.0 精简候选**。只保留云端上传，移除本机客户端连接、版式预览和内容摘要；不轮询结果、不恢复旧未确认任务。原始拆分基线 0.2.0 及历史仍保留，详见 [0.3.0 修订记录](docs/release-0.3.0.md)。

## 当前能力和限制

- 原生 arm64 宿主＋系统分享扩展，整页／选中内容、标题和个人文件夹选择。
- 独立登录后直接上传为知服务器，不要求本机安装或运行主 App；云端操作需要联网。保存格式是 HTML＋图片／静态 MathML，不是 Markdown。
- 紧凑原生界面仅保留标题、账号／登录、文件夹、整页／选中内容、上传和取消；支持浅色／深色外观。
- 只推送一次：HTTP／接口回应确认后显示“服务器已接收”，不等同于笔记已经保存。回执不明确时提示用户先检查网页版，不自动重传；可关闭窗口，不会持久阻止下次剪藏。
- 已修正含语义 MathML 的 Wikipedia／MathJax／KaTeX 双层公式重复、隐藏后备图片，以及重复长缺图占位。图片下载失败保留简短原图链接；成功嵌入保留已清理尺寸和样式。
- 纯 SVG／canvas、受保护图片和复杂站点排版仍有局限，不能承诺所有网页完整保真。正式云端登录、最终保存与各客户端同步后效果、多机加载仍需用户实测。
- 已删除本地配对、8849 请求和相关钥匙串读写；不删除用户现存钥匙串项、不修改主 App。下一步见[待办](docs/ROADMAP.md)。
- 不读取旧官方剪藏器的钥匙串／账号，不保存密码，不自动重复上传。不是为知官方发行。

## 构建与隔离检查

Apple Silicon Mac，macOS 14 部署目标，系统 Swift／macOS SDK（本机已装 Xcode）。无外部包依赖。仅在新建的绝对输出路径构建：

```sh
bash scripts/build.sh /absolute/new-output-folder
bash scripts/test.sh '/absolute/new-output-folder/WizNotePlus Web Clipper.app'
```

第一条省略签名身份时使用 ad-hoc，运行输入、模拟云端／资源、只推送流程检查；第二条验证实际分享表单和阻断网络的 WebKit 合成捕获。本轮合计 74 项（10＋33＋10＋8＋13）。不会登录真实账号、上传网页、读真实凭据或注册扩展。

本机 Safari 试用可在构建命令最后传入已有的 `Apple Development: …` 身份，不需要提供密码或私钥。开发签名／临时签名都不是 Developer ID 或公证，不保证另一台 Mac 无条件加载。更新已安装程序前，应先关闭分享窗口和剪藏器，完整保留上一版回退；不自动操作真实账号。

可将自己有权使用的图标放入 `Resources/AppIcon.icns`，构建时自动配置宿主图标。用户提供的旧官方图标仅用于本机自用，未确认公开再分发许可，已被 Git 忽略；公开源码／CI 不包含该图标，没有文件时使用系统通用图标。

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
