# 拾页构建说明

这是新拾页的完整 Flutter 应用源码，不包含旧项目 `0.4.8` 的 Dart、Kotlin、Swift、资源或构建文件。

## 本地构建

安装 Flutter stable 后，在仓库根目录运行：

```bash
bash tool/bootstrap_native_hosts.sh
```

该命令会：

1. 验证当前源码为 `1.0.0-alpha.20.6+25`；
2. 用 Flutter stable 为拾页创建 Android 与 iOS 宿主，Bundle ID / applicationId 为 `com.shiye.reader`；
3. 配置系统“打开方式”导入 TXT、EPUB 与 PDF；
4. 执行格式化、静态分析和全部测试；
5. 在 Android 上生成 `build/app/outputs/flutter-apk/app-debug.apk`。

在 macOS 加 Xcode 上，该命令还会执行 iOS 无签名构建。无签名构建只用于验证，不能安装或作为 IPA 发布。

## GitHub Actions

- 每次 push 到 `main` 都会生成 Android debug APK，并作为 `android-build` artifact 提供下载。
- 每次 push 到 `main` 都会在 macOS 上验证 iOS 无签名编译，并上传 `Runner.app` 作为 `ios-unsigned` artifact。
- 只有创建 `v*` 标签并配置 Android 签名 Secrets 后，才会生成正式签名的 APK 与 AAB。

第一行有效构建日志必须包含：

```text
Build input verified: 拾页 1.0.0-alpha.20.6+25
```

正式 IPA 需要 Apple Developer 证书、描述文件与已注册的 Bundle ID；它不能由无签名代码或 GitHub Actions 自动合法生成。
