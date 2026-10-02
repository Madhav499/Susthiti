import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

web.Blob _blob(Uint8List bytes, String mimeType) => web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));

/// Downloads through a temporary object URL (the file never goes to a public URL).
bool saveFile(Uint8List bytes, String filename, String mimeType) {
  final url = web.URL.createObjectURL(_blob(bytes, mimeType));
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return true;
}

/// Opens the file in a new tab with the browser's own viewer (PDF, image).
bool openFile(Uint8List bytes, String mimeType) {
  final url = web.URL.createObjectURL(_blob(bytes, mimeType));
  web.window.open(url, '_blank');
  Future<void>.delayed(const Duration(minutes: 5), () => web.URL.revokeObjectURL(url));
  return true;
}
