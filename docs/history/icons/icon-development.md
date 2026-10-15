# 定版图标：圆形剪刀 A，原生渲染

## 0.3.6 分享面板修订（优先于下述0.3.5记录）

用户实测0.3.5的Safari面板仍是占位图，即使旧NSSharingService能返回正确图标。宿主继续使用原始分层Assets.car；分享扩展改为显式完整文件名的ShareIcon.icns，只含16–256像素静态图，不再带CFBundleIconName或另一份Assets.car。静态图从已批准A版机械缩小，不重绘、不加留白、不改变徽章位置。需单独验证Safari面板，不把本机包检查和旧分享API输出当作其成功证据。预计精简约1.8MiB重复图形资源。下文的“相同原生目录”仅为0.3.5历史实现。

## 当前决定

用户已确认：圆形剪刀 A 版构图，较新系统采用原生分层图标，旧系统保留 ICNS。徽章直径41.4%，中心77.5%/77.0%（相对底图满幅、从左上计）。背景 W 和圆形剪刀均为原始 PNG 像素，不重绘、不翻转、不额外调色。

Resources/AppIcon.icon 是本机原生源，内含独立 background.png / candidate-badge.png。构建优先用 Apple actool 编译 Assets.car，并在宿主和 macOS 分享扩展同时选择 CFBundleIconName=AppIcon。目录内保留独立 IconImageStack/IconGroup、材质与阴影属性；没有把已烘焙玻璃的整体 PNG 当原生图层。实际材质、光照和外阴影交系统处理，不再手工叠加此前的38%/28px外投影，外观随系统和显示位置变化。

Resources/AppIcon-final.icns 为已批准的高分辨率静态 A 版，仅作旧系统兼容图，由 CFBundleIconFile 选择；不重缩放或再次渲染。没有原生源时仍可静态回退，公开源码无本地图形时使用通用占位图。

## 主程序不变

主程序14.4.16、名称、签名、资料目录和功能不变，没有新增功能或改版计划。其包内 wiznote.icns 与主工程原版资源字节一致，SHA-256为367bd83f06671ddb8275f6eb7a6036f8d24990301390b8853a947dfd724ef6c1。后续仅按实际故障/系统兼容需要维护，不为剪藏器重建主软件。

## 素材和复现

本机 outputs/Clipper-Icon-Final 保留 AppIcon.icon（当前原生编辑源）、Native-preview.png（Apple工具预览）、AppIcon.icns（旧系统兼容）、Clipper.png（此前静态A外观参考）、原始PNG与过程源。预览不是所有系统显示位置的像素承诺。保存.icon不自动重导出PNG/ICNS；最终构建应重新编译原生目录，而不是覆盖图标文件后继续沿用旧签名。

本机可选素材不进入公共Git，品牌派生资源许可未确认；源码CI默认不携带它们。scripts/compile-icon.sh 与 build.sh 是实际编译路径，compose-raster-icon.swift/clipper-icon-positions.swift 仅是可选设计辅助，不参与日常运行。

## 验证和清理

本机159项：Apple编译2、图标包6、原有非GUI73、分享UI/捕获68、固定Wikipedia阻断网络回放10。另核对原生目录确有独立图层、宿主/扩展资源一致、arm64、严格签名。未用真实密码/令牌，不进行登录或上传；Safari菜单显示、真实云端、多机加载和未来系统仍需实际确认。

用户要求清理：14个已核对的旧设计/构建目标约54MiB移入可恢复废纸篓，保留当前与上一版完整App、用户手动编辑工程、原始图、唯一源码和日志。旧过程记录中的部分输出路径现已在废纸篓，当前使用本页路径。移动废纸篓不等于释放磁盘空间。

详细版本/发行边界见 release-0.3.5.md；更早设计过程见 icon-rework-plan.md（历史）。[Apple图标规范](https://developer.apple.com/design/human-interface-guidelines/app-icons/)建议让系统处理视觉效果，避免预制效果重复叠加。
