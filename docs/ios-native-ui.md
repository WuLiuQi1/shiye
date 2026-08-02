# iOS Native-Led UI Direction

拾页继续采用 Flutter 双端路线，但界面和交互以 iOS 原生体验为主导标准。

## Principles

- Follow Apple Human Interface Guidelines for navigation, hierarchy, sheets, grouped lists, spacing and feedback.
- Prefer Cupertino widgets and iOS route transitions before considering custom controls.
- Keep reading interactions quiet: tap to reveal controls, bottom sheets for focused choices, and minimal persistent chrome.
- Use haptics for deliberate reading actions such as opening books, changing chapters, switching sources and applying reader settings.
- Keep visual expression original to 拾页. Do not copy Apple Books artwork, icons, brand marks, screenshots or exact visual compositions.

## Flutter Implementation Rules

- Use `CupertinoApp`, `CupertinoPageRoute`, `CupertinoSliverNavigationBar`, `CupertinoListSection`, `CupertinoActionSheet`, `CupertinoPopupSurface`, `CupertinoSlidingSegmentedControl` and `CupertinoScrollbar` where they fit.
- Keep source browsing, parsing, caching and repository work outside widget classes.
- UI may reference Apple Books interaction comfort, but product naming, colors, icons and detailed layouts must remain independent.
- Android remains supported from the same Flutter codebase. iOS-native behavior is the default visual language, not an iOS-only fork.

## Current Alpha.8 Scope

- Bookshelf hierarchy: large title, continue-reading card, grouped surface and polished book covers.
- Reader: iOS-style settings sheet, sliders, segmented controls, bounce scrolling, scrollbar and haptic feedback.
- Search and source management: inset grouped lists, system symbols and native-feeling selection feedback.
