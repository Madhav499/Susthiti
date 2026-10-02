import 'dart:typed_data';

import 'browser_files_stub.dart' if (dart.library.js_interop) 'browser_files_web.dart' as impl;

/// Browser file handling for the web build: save a file with the browser's normal download, or
/// open it in a new tab. On mobile and desktop both return false and callers use the platform
/// share/print sheet instead.
abstract final class BrowserFiles {
  static bool save(Uint8List bytes, {required String filename, required String mimeType}) => impl.saveFile(bytes, filename, mimeType);

  static bool open(Uint8List bytes, {required String mimeType}) => impl.openFile(bytes, mimeType);
}
