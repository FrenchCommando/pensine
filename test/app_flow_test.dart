import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/main.dart';
import 'package:pensine/widgets/marble_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end flow test: boots the real `PensineApp` widget and drives the
/// golden path. Unlike `integration_test/` (which runs on emulators for
/// screenshots/video), this runs headlessly under `flutter test` so CI can
/// gate on it. Catches regressions that isolated widget tests miss:
/// bootstrapping, default-data population, home ↔ board navigation.

/// Flutter's default test surface is 800×600, which shoves the board-screen
/// action row off-screen and makes `Back` unreachable. Pump at a larger size.
Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const PensineApp());
  // Physics ticker never settles; pump a few frames manually instead of
  // pumpAndSettle which would time out.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    debugPauseMarblePhysics = true;
  });

  tearDown(() {
    debugPauseMarblePhysics = false;
  });

  testWidgets('Boot → defaults render → open board → back to home',
      (tester) async {
    await _pumpApp(tester);

    expect(find.text('Getting Started'), findsOneWidget,
        reason: 'Default "Welcome" workspace should include "Getting Started"');
    expect(find.byTooltip('New board'), findsOneWidget,
        reason: 'Home screen FAB should be present');

    await tester.tap(find.text('Getting Started'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byTooltip('Back'), findsOneWidget,
        reason: 'Should be on a board screen after tapping a board');

    await tester.tap(find.byTooltip('Back'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byTooltip('New board'), findsOneWidget,
        reason: 'Back to home after tapping Back');
  });

  testWidgets('All 5 default workspaces render on first launch',
      (tester) async {
    await _pumpApp(tester);

    for (final name in [
      'Welcome',
      'Cooking Recipes',
      'Workout Routines',
      'French Vocab',
      'Pilot Checklists',
    ]) {
      expect(find.text(name), findsOneWidget,
          reason: '$name workspace should render in the home list');
    }
  });
}
