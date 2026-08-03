# 拾页

面向 iOS 和 Android 的独立、闭源阅读器。它以 Apple Books 的清晰交互和阅读节奏为参考，但不包含 Apple 的品牌、字体、图标或素材。

## 当前里程碑

`1.0.0-alpha.20.6`：TXT、EPUB 与 PDF 本地阅读已可用；PDF 使用独立的固定版式阅读器，支持缩放、翻页和进度恢复。支持导入阅读 / Legado 与 ORSP JSON 书源；带 JavaScript、Java、登录或 Cookie 字段的书源可以保存到管理页，但拾页绝不会执行脚本或自动携带鉴权数据，依赖这些能力的源会标记为不可用并跳过搜索。声明式子集（CSS、简单 XPath、正则替换）可参与搜索和阅读，并可在阅读中手动切换已匹配的同书来源。阅读页支持导入 `.ttf/.otf` 字体、关键词/正则内容过滤，以及网络章节缓存的查看与清理。新增设备本地阅读统计：今日/本周/本月时长、连续阅读天数、已读书数与每本书阅读时长。TXT、EPUB 和书源章节支持使用手机系统 TTS 听书：当前章朗读、暂停/继续、语速和自动下一章；正文不上传。Android / iOS 原生工程由项目脚本按 Flutter stable 模板生成，并会注册可打开的本地书籍格式。

## 架构

```
lib/
  app/             应用入口与路由
  design_system/   拾页视觉令牌与组件
  domain/          不依赖 Flutter 的业务模型、仓库接口、Use Case
  data/            数据库、文件、网络和缓存的具体实现
  features/        按书架、阅读、搜索、书源、设置等功能划分的 View / ViewModel
  platform/        MethodChannel 定义及 iOS Swift / Android Kotlin 桥接
```

每个功能遵循 **View → ViewModel → Use Case → Repository**。耗时的书源规则解析、长章节分页、批量检测和导入导出必须进入后台 Isolate；阅读页只更新必要区域。

EPUB 解析器位于数据层，导入时先验证文件并读取元数据，随后复制进 App 私有书库。阅读时只处理本地副本，不访问 EPUB 中声明的外部网络资源；解析失败（含受 DRM 保护的文件）会给出可恢复的错误提示。

书源模块现已提供 ORSP、阅读/Legado JSON 的统一导入和安全校验；兼容范围与明确排除项见 [书源引擎边界](docs/source-engine.md)。

UI 方向见 [iOS 原生化设计基线](docs/ios-native-ui.md)：参考 Apple HIG 和 Apple Books 的舒适操作逻辑，但不复制 Apple Books 的视觉资产、品牌元素或完整界面组合。

书源、书架和近期章节缓存都使用设备本地持久化存储。加入书架时会严格按书名与作者匹配其他已启用书源；阅读页只会显示这些已验证的同书来源，且必须由用户手动选择。章节切换会写入阅读位置并预取下一章，但预取失败不会影响阅读。内容过滤只在设备上处理并在网络正文进入缓存前生效；更新过滤规则会清除旧缓存，避免新旧规则混用。

本地书籍导入以 Apple Books 的使用方式为目标：既可从文件 App 选择，也可从系统“打开方式 / 分享”把受支持的书发送到拾页；导入后会复制进私有书库并直接打开。TXT 与 EPUB 使用重排阅读；EPUB 会读取内嵌标题、作者、目录和章节正文。PDF 使用专用分页阅读器，支持缩放、翻页与进度恢复，但不会改变原始版式。MOBI、AZW、AZW3 目前仍只识别；它们需要引入受 copyleft 约束的现成解析器或另行开发解析内核，不能在不改变闭源许可策略的前提下冒充已支持。受设备内存保护限制，EPUB 为 50 MiB，PDF 为 100 MiB。

听书使用 iOS / Android 安装的系统语音引擎，不将章节内容发往拾页以外的服务。打开 TXT、EPUB 或书源章节后，点阅读页顶栏的扬声器即可朗读；可在面板中调节语速、暂停或停止，朗读完成会自动打开下一章。PDF 暂不支持听书，因为固定版式 PDF 无法可靠、完整地提取正文。

## 本地运行

安装 Flutter stable 后，在项目根目录执行：

```bash
bash tool/bootstrap_native_hosts.sh
flutter run
```

该脚本会生成拾页自己的 Android/iOS 宿主工程，设置应用显示名为“拾页”，执行 format、analyze、test，并在 Android 上生成可安装的 debug APK。它在 macOS + Xcode 上还会进行无签名 iOS 构建；Linux/Windows 只跳过这一项。发布前请将 `com.shiye.reader` 替换为已注册的正式 Bundle ID / applicationId。

## 质量与发布

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

详细的 Android AAB/APK、iOS IPA/TestFlight 签名与 GitHub Actions 要求见 [发布说明](docs/release.md)。开发构建不需要 Android keystore 或 Apple 证书；正式发布才需要。机密信息只保存到 GitHub Actions Secrets，绝不提交到仓库。

本地文件、系统“打开方式”与分享导入的配置要求见 [本地书籍导入](docs/local-book-import.md)。
