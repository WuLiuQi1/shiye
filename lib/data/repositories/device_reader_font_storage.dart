import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/reader_settings.dart';
import '../../domain/repositories/reader_font_storage.dart';

class DeviceReaderFontStorage implements ReaderFontStorage {
  const DeviceReaderFontStorage();

  @override
  Future<ReaderFont> storeCopy(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw const ReaderFontImportException('字体文件不存在。');
    final extension = sourcePath.split('.').last.toLowerCase();
    if (extension != 'ttf' && extension != 'otf') {
      throw const ReaderFontImportException('请选择 .ttf 或 .otf 字体文件。');
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}${Platform.pathSeparator}ReaderFonts');
    if (!await directory.exists()) await directory.create(recursive: true);
    final name = source.uri.pathSegments.last.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final safeName = name.replaceAll(RegExp(r'[^\w\-\u4e00-\u9fff]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final family = 'shiye_font_$stamp';
    final target = File('${directory.path}${Platform.pathSeparator}$family.$extension');
    await source.copy(target.path);
    return ReaderFont(family: family, path: target.path, name: safeName.isEmpty ? '自定义字体' : safeName);
  }
}

class ReaderFontImportException implements Exception {
  const ReaderFontImportException(this.message);
  final String message;
  @override
  String toString() => message;
}
