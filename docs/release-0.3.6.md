# 0.3.6 — 分享图标兼容、论坛正文和体积精简

2026-10-15，build10，个人自用开发签名版本，未经公证，非官方发行。

- 上版 Safari 分享面板的占位图问题由用户实测确认仍存在。旧 NSSharingService API 可以返回正确图标，但这不证明 Safari 的新分享面板正确。本版扩展改用显式完整文件名 ShareIcon.icns 的小尺寸静态图标，不复制宿主的原生 Assets.car，不改变 bundle ID。宿主保留原生分层 A 版与原有高分辨率兼容图。是否修复 Safari 实际显示必须另行记录，不能凭包内检查宣称成功。
- 支持识别 esoTalk 讨论结构，包括用户明确提供的超理页面。保留标题、当前已加载的所有帖子、楼层、作者、时间、正文链接、公式、代码、表格和引用；排除站点外围页脚、侧栏滚动器、回复登录框、头像、角色标记及帖子签名/操作区。不自动翻页，不承诺保存未加载的楼层。选区仍只保存选中内容，不扩展成整帖。
- 页面通过 color-scheme 得到白字、但 HTML/body 是透明时，显式保留不透明画布，避免导入浅色笔记后文字消失。
- 生产宿主仅负责承载扩展并立即退出。原先约756KiB的宿主中包含了输入/云端模拟/记住登录/UI/WebKit捕获等测试代码，现在全部编译进独立的构建目录 Tests/ClipperChecks.app，不放进用户安装包。生产宿主约52KiB；扩展以-Osize和无用代码剔除优化，保留 Objective-C 入口。
- 重复的扩展 Assets.car约1.34MiB、高分辨率ICNS约558KiB改为约88KiB静态小图。宿主不再保留扩展专用的页面预处理脚本。App由约5.1MiB降至约2.4MiB（按磁盘占用，约减少53%），没有把测试工具计入安装体积。保留系统框架依赖，不内置Qt/浏览器运行时。
- 登录、凭据服务/权限、接口、取消、仅推送一次及主 App 完全不变。没有读取真实钥匙串、登录或上传。

## 检查

本机179项：构建/资源/模拟83、UI及合成边界78、固定Wikipedia10、固定超理8。公开源码无品牌素材默认152项。测试使用独立测试工具，截图/页面快照仅本机保存，不上传公开仓库。安装后的Safari菜单、真实云端、另一台Mac和未来系统不由这些检查替代。

## 参考

[Apple扩展配置说明](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html)、[NSSharingService](https://developer.apple.com/documentation/appkit/nssharingservice)。不使用私有接口或全局缓存清理来修改系统分享菜单。
