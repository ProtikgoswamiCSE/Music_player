import 'dart:io';

Future<bool> deleteLocalMediaFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    return true;
  } catch (_) {
    return false;
  }
}
