import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/main.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/screens/board_screen.dart';
import 'package:pensine/widgets/marble_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression guard for the dialog controller disposal fix. Pre-fix, the
/// `_itemDialog` in `board_screen.dart` created 4 TextEditingControllers
/// per open and never disposed them. Leak tracking (configured in
/// `test/flutter_test_config.dart`) would flag each undisposed controller
/// as a leak. If someone regresses that fix in the future, this test
/// fails.

void _silenceWakelockChannel() {
  const channel = MethodChannel('dev.fluttercommunity.plus/wakelock_plus');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _silenceWakelockChannel();
    debugPauseMarblePhysics = true;
  });

  tearDown(() {
    debugPauseMarblePhysics = false;
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PensineApp());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('_itemDialog disposes its TextEditingControllers', (tester) async {
    final board = Board(
      name: 'Leak check',
      type: BoardType.thoughts,
      tableMode: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: BoardScreen(board: board, onChanged: () {}),
    ));
    await tester.pump();

    // Empty tableMode board shows a hint whose GestureDetector long-press
    // opens _itemDialog. Repeat open/cancel a few times so a leak regression
    // is obvious in the report (4 controllers × N opens).
    for (var i = 0; i < 3; i++) {
      await tester.longPress(find.textContaining('Empty board'));
      await tester.pump();

      // Dialog open — verify by finding Cancel.
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      // Pump through the full ~150ms AlertDialog exit animation — catches
      // a "used after disposed" error if the dispose pattern races the
      // route's exit transition.
      for (var j = 0; j < 5; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Dialog closed — Cancel gone.
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    }

    // End of test: leak_tracker runs its check. If any of the 12 expected
    // controllers (4 per open × 3 opens) leaked, the framework fails here.
  });

  testWidgets('_createBoard dialog disposes its TextEditingController',
      (tester) async {
    await pumpHome(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('New board'));
      for (var j = 0; j < 5; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      for (var j = 0; j < 5; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    }
  });

  testWidgets('_promptName dialog (new workspace) disposes its controller',
      (tester) async {
    await pumpHome(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('New workspace'));
      for (var j = 0; j < 5; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      for (var j = 0; j < 5; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    }
  });
}
