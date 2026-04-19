import 'dart:js_interop';
import 'dart:convert';
import 'package:web/web.dart' as web;

Future<void> exportFile(String filename, String content) async {
  final bytes = utf8.encode(content);
  final nav = web.window.navigator;

  // Our .pensine payload is JSON text. Use text/plain everywhere: it is on
  // Chrome's Web Share file allow-list (application/octet-stream is not), and
  // MIME is advisory for downloads — the .pensine extension drives open-with
  // behaviour regardless.
  const mime = 'text/plain';

  // Touch-primary devices (phones, tablets incl. iPadOS Safari which lies
  // about its UA) benefit from the native share sheet — Save to Files, Drive,
  // messaging apps. Pointer-fine devices (desktop/laptop) take the anchor
  // download path, which is reliable across every browser.
  final touchPrimary =
      web.window.matchMedia('(pointer: coarse)').matches;

  if (touchPrimary) {
    final file = web.File(
      [bytes.toJS].toJS,
      filename,
      web.FilePropertyBag(type: mime),
    );
    final shareData = web.ShareData(files: [file].toJS, title: filename);
    try {
      if (nav.canShare(shareData)) {
        await nav.share(shareData).toDart;
        return;
      }
    } catch (e) {
      // AbortError = user cancelled the share sheet → respect that, done.
      // Anything else = browser rejected the share → fall through so the
      // user still gets their file via anchor download.
      if (e.toString().contains('AbortError')) return;
    }
  }

  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
