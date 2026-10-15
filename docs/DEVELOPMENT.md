# 构建与维护

Apple Silicon Mac，Xcode/macOS SDK，部署目标macOS14；无Qt或第三方运行库依赖。

```sh
bash scripts/build.sh /absolute/new-output
bash scripts/test.sh '/absolute/new-output/WizNotePlus Web Clipper.app'
bash scripts/check-release.sh '/absolute/new-output/WizNotePlus Web Clipper.app'
bash scripts/package.sh '/absolute/new-output/WizNotePlus Web Clipper.app' /absolute/new-delivery
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

- 保持bundle ID、签名团队和凭据服务不变。
- 不构建或修改主笔记App及其图标、资料目录。
- 保留批准图形；宿主使用原生目录，分享扩展使用精简ICNS。
- 替换安装前检查进程、保留上一版，不强退程序。
- 检查arm64、签名、沙盒、菜单名称、版本与安装包解包一致性。
- 优先通过GitHub插件备份；公共资料不得含账号、私人网页、原始日志或品牌图形。
- 精确清理生成目标，优先移入废纸篓；保留当前/上一版、素材原件及唯一验证档案。

试验性图标工具不参与正式构建，历史边界见[历史索引](history/README.md)。
