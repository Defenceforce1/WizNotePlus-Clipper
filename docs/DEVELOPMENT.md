# 构建与维护

Apple Silicon Mac，Xcode/macOS SDK，部署目标macOS14；无Qt或第三方运行库依赖。

```sh
bash scripts/build.sh /absolute/new-output
bash scripts/test.sh '/absolute/new-output/WizNotePlus Clipper.app'
bash scripts/check-release.sh '/absolute/new-output/WizNotePlus Clipper.app'
bash scripts/package.sh '/absolute/new-output/WizNotePlus Clipper.app' /absolute/new-delivery
```

输出目录必须不存在。省略第二参数为ad-hoc测试签名；自用交付可追加本机已有的 `Apple Development: …` 身份。不要提交证书、私钥或个人签名身份。严格签名不等于Developer ID或Apple公证。

## 目录

```text
Sources/         生产宿主、分享界面、云端、凭据和资源
Resources/       Safari脚本；本机可选图形原件
Configuration/   宿主/扩展配置及沙盒权限
scripts/         构建、测试与发行检查
tests/           合成网页及独立测试工具
docs/            当前指南；历史集中于history/
outputs/         忽略的本机发行包、回退及验证档案
```

测试程序单独生成于输出目录 `Tests/ClipperChecks.app`，不随App分发。只用合成账号与注入存储/传输，不读取真实凭据或上传笔记。网页回放样本与截图仅留本机。

## 发布约束

- 从1.1.0起固定正式身份：宿主 `io.github.defenceforce1.wiznoteplus.webclipper`，扩展为其 `.share` 子标识；以后更新保持这些ID、签名团队及凭据服务不变，不能复用临时诊断ID。
- 登录服务固定为宿主ID的 `.cloud` 与 `.cloud.password`；不自动迁移旧凭据。内部身份迁移是1.1.0经明确授权的一次性变更，不是日常版本更新方式。
- 不构建或修改主笔记App及其图标、资料目录。
- 保留批准图形；宿主使用原生目录，分享扩展使用精简ICNS。
- 替换安装前检查进程、保留上一版，不强退程序。
- 检查arm64、签名、沙盒、菜单名称、版本与安装包解包一致性。
- 先在隐藏装配目录构建完整、签名并验证，再移到最终输出路径；图标检查不对未完成的包进行系统登记。正式安装/扩展登记属于单独操作，打包脚本不自动安装。
- 生产包仅保留用户指南、许可、单份原生图标目录与兼容ICNS、扩展脚本及小图标；自测工具、生成图标源、截图、调试资源和第三方运行库不得打包。
- 优先通过GitHub插件备份；公共资料不得含账号、私人网页、原始日志或品牌图形。
- 精确清理生成目标，优先移入废纸篓；保留当前/上一版、素材原件及唯一验证档案。

试验性图标工具不参与正式构建，历史边界见[历史索引](history/README.md)。
