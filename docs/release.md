# 跨平台发布流程

项目使用语义化版本：`MAJOR.MINOR.PATCH[-预发布]+构建号`。对外发布从 `v1.0.0` 开始；`alpha`、`beta`、`rc` 仅用于测试渠道。

## 预检

1. 更新 `pubspec.yaml`、`CHANGELOG.md` 和版本标签。
2. 在 PR 中通过 format、analyze、test。
3. 用 Android 真机的 profile/release 包检查书架滚动、阅读翻页、打开菜单和换源操作。
4. 在 iPhone 真机检查动态字体、深色模式、降低透明度和安全区域。

在干净的 Flutter stable 环境中，先运行：

```bash
bash tool/bootstrap_native_hosts.sh
```

它是生成拾页原生宿主、统一检查 Dart 代码并产出 Android debug APK 的唯一入口。iOS 无签名构建仅能在装有 Xcode 的 macOS 上完成。

## Android

日常提交和 PR 只构建 debug `.apk`，不需要任何签名密钥，可用于测试。Google Play 的 `.aab`、对外测试/侧载的 release `.apk` 必须由正式 keystore 签名；只有推送 `v*` 发布标签时，工作流才会检查以下 GitHub Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

工作流在临时目录还原 keystore，生成 `android/key.properties`，随后执行：

```bash
flutter build appbundle --release
flutter build apk --release
```

没有密钥时不应创建发布标签；工作流会明确失败，而不会生成伪装成正式版的包。不要提交 `key.properties`、keystore 或任何签名密码。

## iOS

当前工作流在 PR 和 `main` 上执行 `--no-codesign` 构建，用于验证 iOS 工程可以编译；它不会产生可安装的 IPA。IPA 必须在 macOS runner 上用 Apple Developer 证书、描述文件和 App Store Connect API key 签名。签名材料就绪后，再新增受保护发布工作流；建议使用 Fastlane `match` 或 GitHub Actions 的临时 keychain，不要把 `.p12`、`.mobileprovision`、`AuthKey_*.p8` 放入 Git。

通过 TestFlight 发布时，CI 先 Archive，再由 Transporter / `xcrun altool` / Fastlane 上传。Apple 的签名材料及正式 Bundle ID 需要由项目所有者提供后才可启用正式发布作业。

## GitHub 仓库

创建**私有**仓库，启用分支保护：合并前必须通过 `quality` 检查；发布只能由受保护标签触发。每次发行创建 GitHub Release，附上 AAB、APK（如适用）和变更说明；IPA 不公开附在 Release。
