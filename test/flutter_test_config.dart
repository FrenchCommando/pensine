import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Auto-discovered by `flutter_test`. Enables leak tracking for every test
/// in this directory: any `Disposable` (TextEditingController,
/// AnimationController, ValueNotifier, FocusNode, Ticker, …) that becomes
/// GC-unreachable without `dispose()` having been called will fail the
/// test. This is what makes the "dialog controller leak" class of bug
/// detectable in CI — the previously-"untestable" hygiene issue.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withTrackedAll().withIgnored(
    classes: [
      // Framework-internal image cache. Flutter retains these past test
      // teardown because `imageCache` is a global singleton; not a Pensine
      // bug, nothing we can dispose. Safe to ignore.
      'ImageStreamCompleterHandle',
      '_LiveImage',
    ],
  );
  await testMain();
}
