# 本地书籍导入

拾页支持 `TXT`、`EPUB`、`PDF`、`MOBI`、`AZW` 与 `AZW3`。从书库的“添加图书”选择文件，或从系统的“打开方式 / 分享”选择拾页后，文件会先复制到 App 私有书库；原文件之后移动、改名或删除都不会影响阅读。

重排阅读适用于 TXT、EPUB。PDF 保持固定版式并进入专用阅读页。MOBI、AZW、AZW3 仍只识别，尚未提供阅读；不会尝试移除或绕过 DRM。

运行 `bash tool/bootstrap_native_hosts.sh` 会为 Android 写入接收分享与打开文件所需的 Intent 配置，并为 iOS 注册相同的文档类型。iOS 的系统“打开方式”可直接把文件交给拾页；若需出现在所有 App 的标准分享面板中，还需要在 Xcode 为 Runner 新建 Share Extension，并按 `share_handler` 的官方 iOS 配置将该目标加入同一个 App Group。该步骤需要 Apple 签名和 Xcode，不能由 Linux CI 代替验证。
