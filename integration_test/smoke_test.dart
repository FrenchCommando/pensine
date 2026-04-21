import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pensine/main.dart';

import 'test_helpers.dart';

/// Real integration test: runs against the live Flutter engine on a real
/// target (CI drives Chrome headless via `integration.yml`). Unlike the
/// widget-level flow in `test/app_flow_test.dart`, this exercises real
/// platform channels — `shared_preferences`, `path_provider`, the web
/// runtime — so it catches breakage that `flutter_tester` can't see.
///
/// Run locally:
///   flutter drive \
///       --driver=test_driver/integration_test.dart \
///       --target=integration_test/smoke_test.dart \
///       -d chrome
void main() {
  requireCIOnWindows();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Boot → defaults populate → open board → back to home',
      (tester) async {
    await tester.pumpWidget(const PensineApp());
    await settle(tester);

    // Defaults loaded from real storage (empty on first run).
    expect(find.text('Getting Started'), findsOneWidget,
        reason: 'Welcome workspace must include "Getting Started" on first run');

    await openBoard(tester, 'Getting Started',
        hold: const Duration(milliseconds: 500));

    // Board screen: Back is the reliable landmark across all board types.
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    // Home again.
    expect(find.byTooltip('New board'), findsOneWidget);
  });

  testWidgets('All 5 default workspaces render', (tester) async {
    await tester.pumpWidget(const PensineApp());
    await settle(tester);

    // Scroll each name into view before asserting — the home ListView is
    // lazy, and on real devices (phones/tablets) 2-3 workspaces are below
    // the fold. Without `scrollTo`, `find.text` returns 0 matches for
    // anything not yet laid out.
    for (final name in [
      'Welcome',
      'Cooking Recipes',
      'Workout Routines',
      'French Vocab',
      'Pilot Checklists',
    ]) {
      await scrollTo(tester, find.text(name));
      expect(find.text(name), findsOneWidget,
          reason: '$name should render on the home screen');
    }
  });

  testWidgets('Create a new board persists in the home list', (tester) async {
    await tester.pumpWidget(const PensineApp());
    await settle(tester);

    await tester.tap(find.byTooltip('New board'));
    await settle(tester);

    // New Board dialog: type name, leave default type (thoughts), submit.
    await tester.enterText(find.byType(TextField).first, 'Integration Test');
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settle(tester);

    expect(find.text('Integration Test'), findsOneWidget,
        reason: 'Newly-created board should appear on the home screen');
  });
}
