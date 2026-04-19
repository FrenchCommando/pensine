import 'dart:js_interop';
import 'dart:convert';
import 'package:web/web.dart' as web;

Future<void> exportFile(String filename, String content) async {
  final bytes = utf8.encode(content);
  final file = web.File(
    [bytes.toJS].toJS,
    filename,
    web.FilePropertyBag(type: 'application/octet-stream'),
  );

  // Prefer the OS share sheet when available (mobile browsers + installed PWAs on
  // Android/iOS). The sheet itself exposes "Save to Files" / "Save to Downloads"
  // as an explicit target, so the user can save from there if they want. If they
  // cancel, respect that — don't silently download. We only fall through to a
  // plain download when the browser can't share files at all (most desktop).
  final shareData = web.ShareData(
    files: [file].toJS,
    title: filename,
  );
  final nav = web.window.navigator;
  if (nav.canShare(shareData)) {
    try {
      await nav.share(shareData).toDart;
    } catch (_) {
      // User cancelled or share errored — either way, the user's action (or
      // lack thereof) is final.
    }
    return;
  }

  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
