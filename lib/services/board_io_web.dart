import 'dart:js_interop';
import 'dart:convert';
import 'package:web/web.dart' as web;

Future<void> exportFile(String filename, String content) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
