# Changelog

## 1.0.0-alpha.20+21

- 修复阅读统计页面的 Dart 括号语法错误，恢复 `dart format`、iOS 与 Android CI 构建流程。

## 1.0.0-alpha.20+20

- Added device-local system-TTS listening for reflowable TXT, EPUB and book-source chapters: start, pause/continue, stop, adjustable speech rate and automatic next chapter.
- Text is supplied only to the platform speech engine; it is not uploaded or sent to a third-party service by 拾页.
- Configured the generated iOS host's audio background mode so an active listening session can continue after locking the device or switching apps.
- Kept PDF listening unavailable: preserving a fixed PDF layout does not provide dependable text extraction.

## 1.0.0-alpha.17+17

- Added shared-file intake for supported book formats, so Android shares and iOS document-opening intents can import directly into the private library.
- Native-host bootstrap now registers TXT, EPUB, PDF, MOBI, AZW and AZW3 document types for “Open in 拾页”.

## 1.0.0-alpha.16+16

- Added local PDF import and a dedicated fixed-layout PDF reader with pinch zoom, paging and durable reading progress.
- Keep PDF rendering separate from reflowable TXT/EPUB reading: reader fonts, text cleanup and text themes do not alter a PDF's authored layout.
- Raised the local PDF import limit to 100 MiB; invalid, encrypted or damaged files report a recoverable open error.

## 1.0.0-alpha.15+15

- 新增原生工程生成与验收脚本：在 Flutter stable 环境中生成 Android/iOS 宿主、设置“拾页”应用显示名、执行格式化/静态分析/测试，并生成 Android debug APK。
- Android 与 iOS CI 改为复用同一套原生宿主生成与验证入口，避免开发机和 CI 的生成参数漂移。
- 明确 iOS 无签名构建只能在 macOS + Xcode 环境运行；当前 Linux 工作环境不将未生成的原生工程误报为已验证。

## 1.0.0-alpha.14+14

- Added safer, broader reading/Legado JSON source compatibility for CSS, simple XPath and declarative regex replacements.
- Manual source switches now retain the current chapter's scroll position whenever the chapter is matched by title.
- Rejected embedded executable expressions in imported source rules; imported header data is never sent automatically.

## 1.0.0-alpha.13+13

- Added import and selection of private `.ttf` / `.otf` reader fonts, with a system-font fallback.
- Added device-local content cleanup rules for keyword and regular-expression replacements.
- Apply enabled cleanup rules before network chapter text is written to cache; changing rules clears outdated cached chapters.
- Added cache-management UI with current size, cached-chapter count and safe full-cache cleanup.
- Added per-source chapter-cache cleanup from the reader settings panel.

## 1.0.0-alpha.12+12

- Added EPUB import, archive validation and durable private-library copies.
- Read EPUB title and author metadata when adding a book to the shelf.
- Added EPUB table of contents, chapter navigation, reader-theme support and progress restoration.
- Kept TXT local reading unchanged; PDF, MOBI, AZW and AZW3 remain explicitly unsupported for reading.

## 1.0.0-alpha.11+11

- Added an Apple Books-style local book import entry from the bookshelf.
- Added local book metadata to bookshelf persistence.
- Added TXT import and reading support.
- Recognise EPUB, PDF, MOBI, AZW and AZW3 at the import boundary for staged parser support.
- Local books now open in the reader without requiring a network book source.

## 1.0.0-alpha.10+10

- Added app-wide appearance preferences: follow device, light and dark.
- Applied the selected appearance to the whole `CupertinoApp` instead of only the reader page.
- React to device brightness changes while the app is set to follow system appearance.
- Kept older reader-settings data compatible by defaulting app appearance to follow device.

## 1.0.0-alpha.9+9

- Added clear retry states for failed book details and initial chapter loads.
- Keep the current chapter visible when navigating to a chapter that fails to load.
- Reject empty chapter text before it reaches the cache or reader.
- Report partially unavailable search sources without hiding successful results.
- Added bookshelf loading and actionable empty states.
- Bound individual source HTTP responses to 5 MiB to protect device memory.

## 1.0.0-alpha.8+8

- Keep the product on Flutter while making iOS-native behavior the UI baseline.
- Refined the bookshelf with iOS grouped hierarchy, a continue-reading card, native-feeling haptics and book-grid polish.
- Reworked reader options into an iOS-style bottom sheet with sliders and segmented controls.
- Added reader scrollbars, bounce physics and selection feedback for core reading actions.
- Refined search, details and source-management surfaces with inset grouped lists and system-style controls.
- Fixed root navigation callbacks so pushed pages resolve the in-app navigator context.

## 1.0.0-alpha.7+7

- Added reader table of contents with current-chapter and local-cache status.
- Added chapter-internal progress restoration and shelf progress updates.
- Added durable font, line-height, theme and reading-layout preferences.
- Added tap-to-hide reader controls and paper, sepia and night themes.

## [1.0.0-alpha.6] - 2026-08-02

### Added

- Load, render and navigate real source chapters in the reader.
- Add a bounded device-local chapter cache and best-effort next-chapter prefetch.
- Persist chapter position and overall reading progress after opening or changing chapters.
- Add reader font-size and paper-color controls.

## 1.0.0-alpha.4

- Add in-app book-source management, including safe JSON import, enable/disable and removal.
- Connect enabled sources to search, book-detail and add-to-bookshelf flows.
- Add a bounded HTTP gateway while keeping imported source rules data-only.

所有重要变更记录在本文件。

## [1.0.0-alpha.3] - 2026-08-02

### Added

- 声明式书源浏览链路：搜索、详情、目录与正文的统一领域模型和 Use Case。
- 可替换的网络网关边界，以及覆盖全链路的离线解析测试。
- 首批 CSS/XPath 风格选择器、文本/属性提取与正文清理实现。

### Security

- 规则解释器只处理数据选择器、正则替换和 URL 模板；不增加任何脚本执行能力。

## [1.0.0-alpha.2] - 2026-08-02

### Added

- 统一的 ORSP 与阅读/Legado JSON 书源导入、验证和领域模型。
- 明确的纯声明式规则安全边界：不接受 JavaScript、Java 或动态代码字段。
- 测试构建无需 Android keystore 或 Apple 签名材料。

### Changed

- Android 仅在 `v*` 发布标签构建签名 AAB/APK；PR 与 main 构建 debug APK。
- iOS CI 明确作为无签名编译检查，不再暗示可导出未签名 IPA。

## [1.0.0-alpha.1] - 2026-08-02

### Added

- 独立 Flutter iOS/Android 工程与模块化 MVVM + Repository 基线。
- Apple Books 风格书架原型和阅读器基础页面。
- GitHub Actions 质量检查与跨平台构建工作流骨架。
# 1.0.0-alpha.5

- Persist the bookshelf and imported sources locally on the device.
- Add strict, explicit matching for alternate sources when a book is added.
- Add reader-level manual source switching, with chapter title then chapter index used to retain position.
- Never offer automatic switching or unverified sources.
