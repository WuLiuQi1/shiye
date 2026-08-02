import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/book.dart';
import '../../domain/repositories/local_book_storage.dart';

class DeviceLocalBookStorage implements LocalBookStorage {
  const DeviceLocalBookStorage();

  @override
  Future<String> storeCopy({
    required String sourcePath,
    required String title,
    required LocalBookFormat format,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}${Platform.pathSeparator}LocalBooks');
    if (!await directory.exists()) await directory.create(recursive: true);
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final target = File(
      '${directory.path}${Platform.pathSeparator}${safeTitle.isEmpty ? 'book' : safeTitle}-$timestamp.${format.name}',
    );
    return (await File(sourcePath).copy(target.path)).path;
  }
}
