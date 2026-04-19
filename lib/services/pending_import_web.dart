import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

void listenForPendingImports(void Function(String content) onImport) {
  final callback = ((JSString content) => onImport(content.toDart)).toJS;
  web.window.callMethod('pensineRegisterImportListener'.toJS, callback);
}
