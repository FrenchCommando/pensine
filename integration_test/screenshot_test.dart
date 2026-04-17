import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pensine/main.dart';
import 'package:pensine/widgets/marble_board.dart';

import 'test_helpers.dart';

/// Takes store-listing screenshots on a fresh install (default workspaces).
///
/// Run with (via driver for file output):
///   flutter drive --driver=test_driver/integration_test.dart \
///       --target=integration_test/screenshot_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Trust scoped to exactly the cert the workflow minted for this run.
  // Cert bytes arrive as base64 via --dart-define; nothing checked in.
  final httpClient = () {
    const certB64 = String.fromEnvironment('SCREENSHOT_CERT_B64');
    if (certB64.isEmpty) return HttpClient();
    final ctx = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(base64Decode(certB64));
    return HttpClient(context: ctx);
  }();

  // Both platforms now capture via a host-side server:
  //   Android — HTTPS + cert pinning over 10.0.2.2 (emulator → host).
  //   iOS     — plain HTTP over 127.0.0.1 (sim shares host loopback).
  // iOS started hanging in `binding.takeScreenshot` because the marble ticker
  // calls setState every frame, so Flutter's screenshot path never sees idle.
  // Host-driven capture bypasses that entirely.
  const host = String.fromEnvironment('SCREENSHOT_HOST');

  Future<void> takeScreenshot(String name) async {
    log('capture:$name start');
    debugPauseMarblePhysics = true;
    try {
      if (host.isNotEmpty) {
        final req =
            await httpClient.postUrl(Uri.parse('$host/screenshot/$name'));
        final res = await req.close();
        await res.drain();
        if (res.statusCode != 200) {
          throw StateError(
              'Screenshot capture failed for "$name": HTTP ${res.statusCode}');
        }
        return;
      }
      await binding.takeScreenshot(name);
    } finally {
      debugPauseMarblePhysics = false;
      log('capture:$name done');
    }
  }

  testWidgets('Store screenshots', (tester) async {
    log('pumpWidget');
    await tester.pumpWidget(const PensineApp());
    log('initial settle');
    await settle(tester);

    await takeScreenshot('01_home');

    log('tap Getting Started');
    await tester.tap(find.text('Getting Started'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('02_thoughts');

    log('tap Back (from thoughts)');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    log('openBoard Essentials');
    await openBoard(tester, 'Essentials');
    await takeScreenshot('03_flashcards');

    log('tap Flip all');
    await tester.tap(find.byTooltip('Flip all'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await takeScreenshot('04_flashcards_flipped');

    log('tap Back (from flashcards)');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    log('openBoard Pancakes');
    await openBoard(tester, 'Pancakes');
    await takeScreenshot('05_checklist');

    log('tap Back (from checklist)');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    log('openBoard Weekend');
    await openBoard(tester, 'Weekend', scrollDelta: -200);
    await takeScreenshot('06_todo');
    log('done');
  });
}
