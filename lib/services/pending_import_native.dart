import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

void Function(String)? _currentListener;
_PendingImportObserver? _observer;

void listenForPendingImports(void Function(String content) onImport) {
  _currentListener = onImport;
  _checkForIncomingFile();

  if (_observer == null &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows)) {
    _observer = _PendingImportObserver();
    WidgetsBinding.instance.addObserver(_observer!);
  }
}

Future<void> _checkForIncomingFile() async {
  try {
    final dir = await getTemporaryDirectory();
    final incoming = File('${dir.path}/pensine_incoming.pensine');
    if (!await incoming.exists()) return;
    final content = await incoming.readAsString();
    await incoming.delete();
    if (content.isNotEmpty) _currentListener?.call(content);
  } catch (_) {
    // best-effort — native side handles edge cases, Dart just polls a file
  }
}

class _PendingImportObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForIncomingFile();
  }
}
