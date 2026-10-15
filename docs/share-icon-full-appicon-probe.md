# 分享图标：完整 AppIcon 方案核验

2026-10-15。正式安装仍为0.3.7/build13，主App未动。

## 目的

区分先前的普通 imageset 与真正的 macOS appiconset，核对分享扩展自己的图标目录、尺寸和元数据。此次没有改变激活规则或剪藏代码。

## 可复现步骤

本机自有图形输入保持原图案、比例、透明留白，不额外添加效果。以下工具只生成本机输出，不是正式打包步骤：

```sh
bash scripts/compile-share-appicon.sh /ABSOLUTE/approved.icns /ABSOLUTE/NEW_OUTPUT
```

- 使用原图生成16、32、128、256、512pt的1x/2x共10个PNG，最大1024×1024；每个槽位检查实际尺寸。
- 建立ShareAssets.xcassets/ShareIcon.appiconset，由actool以macosx、最低14.0、--app-icon ShareIcon编译。
- 编译器产出Assets.car、ShareIcon.icns及Icon-Info.plist，两个图标元数据名称均为ShareIcon。assetutil确认目录中是真正的Icon Image条目，不是普通Image条目。
- 在正式包的隔离副本中，仅替换分享扩展图标及图标元数据，临时build14。两个运行可执行文件、页面脚本、激活规则、bundle ID、凭据服务及签名身份不变，重新签名并通过严格验证。
- 确认剪藏主机和扩展没有运行后保留完整正式包，临时试装；只对该应用执行lsregister -f与pluginkit -a，确认注册项指向应用程序中的扩展。
- 打开用户指定Wikipedia页面并观察实际Safari分享面板，没有点击剪藏、登录或上传。

## 结果及边界

真实面板仍是占位图，不能将该方案标为修复。此次并未为此特定探针再次重启Safari，所以不能断言持久缓存完全无关。未删除Safari缓存/偏好设置，未重建全局LaunchServices，未改系统信任或安全设置。

正式0.3.7/build13已完整恢复，与试验前备份逐文件比对无差异，签名验证通过，约2.4MiB。完整目录试验包约2.8MiB，不作为发布包。

本机证据位于outputs/share-appicon-full-probe/safari-share.png（不公开上传）。原图及其衍生物继续仅留本机。下一步若需要研究缓存，应使用有边界的独立验证，不能以广泛删除用户数据作为默认处理。

参考：[Apple App Icon Type](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html)、[CFBundleIconName](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconname)。
