import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pensine/main.dart';

import 'test_helpers.dart';

/// Verifies the native -> Dart file-import handoff on real desktop targets
/// (Windows + macOS, via `integration.yml`'s `windows` / `macos` jobs).
///
/// The native side writes the incoming `.pensine` contents to
/// `getTemporaryDirectory()/pensine_incoming.pensine` before the Flutter
/// window/view is created:
///   - Windows: `windows/runner/utils.cpp::HandleIncomingPensineFile`
///     runs in `wWinMain` with the paths from `GetCommandLineW`.
///   - macOS: `macos/Runner/AppDelegate.swift::application(_:open:)`
///     runs when Cocoa hands off the URL(s) from Finder / `open`.
/// `pending_import_native.dart` polls that file on cold launch. This test
/// simulates the native write by dropping the file directly, then boots
/// the app and asserts the imported workspace surfaces.
///
/// Also guards the path alignment: if Dart's `getTemporaryDirectory()`
/// ever diverges from what the native side writes to (Win32's
/// `GetTempPathW()` / Cocoa's `NSTemporaryDirectory()`), the import won't
/// fire and this test fails.
///
/// Run locally (inside CI or the OSX-KVM VM — blocked otherwise by
/// `requireCIForNativeDesktop`):
///   tool/run_windows_integration.sh integration_test/pending_import_test.dart
///   tool/run_macos_integration.sh   integration_test/pending_import_test.dart
void main() {
  requireCIForNativeDesktop();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const workspaceName = 'Integration Test Workspace';
  const boardName = 'Cold Launch Board';

  final payload = jsonEncode({
    'pensine_version': 2,
    'exported_at': '2026-04-20T00:00:00.000Z',
    'workspace': {
      'id': 'ws-integration',
      'name': workspaceName,
      'colorIndex': 0,
      'createdAt': '2026-04-20T00:00:00.000Z',
      'boards': [
        {
          'id': 'b-integration',
          'name': boardName,
          'type': 'thoughts',
          'colorIndex': -1,
          'workspaceId': 'ws-integration',
          'createdAt': '2026-04-20T00:00:00.000Z',
          'items': [],
          'tableMode': false,
        },
      ],
    },
  });

  testWidgets('Cold-launch import from temp file surfaces on home',
      (tester) async {
    final tempDir = await getTemporaryDirectory();
    final pending = File('${tempDir.path}/pensine_incoming.pensine');
    // Clean up any stale file from a prior run so we know we're reading ours.
    if (await pending.exists()) {
      await pending.delete();
    }
    await pending.writeAsString(payload);

    await tester.pumpWidget(const PensineApp());
    await settle(tester);

    // `listenForPendingImports` drains the file on registration and fires the
    // import callback. The v2 payload creates a new workspace with a fresh id.
    await scrollTo(tester, find.text(workspaceName));
    expect(find.text(workspaceName), findsOneWidget,
        reason: 'Imported workspace should appear on the home screen');

    // And the file should be drained by the listener.
    expect(await pending.exists(), isFalse,
        reason: 'pending_import_native must delete the temp file after reading');
  });
}
