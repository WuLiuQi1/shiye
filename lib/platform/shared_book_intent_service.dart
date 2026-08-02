import 'package:share_handler/share_handler.dart';

/// Converts platform share-sheet deliveries into file paths that can be copied
/// immediately into the app-owned local library.
///
/// The platform configuration only registers book document types; text, media
/// and unknown attachments are deliberately ignored.
class SharedBookIntentService {
  static const _supportedExtensions = {'txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3'};

  Future<List<String>> initialPaths() async {
    final media = await ShareHandlerPlatform.instance.getInitialSharedMedia();
    return _bookPaths(media?.attachments ?? const []);
  }

  Stream<List<String>> get paths => ShareHandlerPlatform.instance.sharedMediaStream
      .map((media) => _bookPaths(media.attachments ?? const []))
      .where((paths) => paths.isNotEmpty);

  List<String> _bookPaths(Iterable<dynamic> attachments) {
    final result = <String>[];
    for (final attachment in attachments) {
      final path = attachment?.path;
      if (path is! String || !_isSupported(path) || result.contains(path)) continue;
      result.add(path);
    }
    return result;
  }

  bool _isSupported(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return false;
    return _supportedExtensions.contains(path.substring(dot + 1).toLowerCase());
  }
}
