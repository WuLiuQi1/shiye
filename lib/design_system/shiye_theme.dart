import 'package:flutter/cupertino.dart';

/// Independent visual tokens inspired by modern iOS hierarchy, without using
/// Apple-owned artwork, fonts, or brand assets.
abstract final class ShiyeTheme {
  static const _accent = Color(0xFF0A7B69);
  static const groupedBackground = Color(0xFFF2F2F7);
  static const darkGroupedBackground = Color(0xFF000000);
  static const paperBackground = Color(0xFFF8F4EA);
  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0x1F000000),
    darkColor: Color(0x36FFFFFF),
  );
  static const secondaryFill = CupertinoDynamicColor.withBrightness(
    color: Color(0x1F767680),
    darkColor: Color(0x3A767680),
  );

  static const light = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: _accent,
    scaffoldBackgroundColor: groupedBackground,
    barBackgroundColor: Color(0xEEF2F2F7),
    textTheme: CupertinoTextThemeData(
      navLargeTitleTextStyle: TextStyle(
        color: Color(0xFF1D1C1A),
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      navTitleTextStyle: TextStyle(
        color: Color(0xFF1D1C1A),
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static const dark = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: _accent,
    scaffoldBackgroundColor: darkGroupedBackground,
    barBackgroundColor: Color(0xEE1C1C1E),
    textTheme: CupertinoTextThemeData(
      navLargeTitleTextStyle: TextStyle(
        color: Color(0xFFF2F2F7),
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      navTitleTextStyle: TextStyle(
        color: Color(0xFFF2F2F7),
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
