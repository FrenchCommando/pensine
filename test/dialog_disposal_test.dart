import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/screens/board_screen.dart';
import 'package:pensine/widgets/marble_board.dart';

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

  setUp(() {
    _silenceWakelockChannel();
    debugPauseMarblePhysics = true;
  });

  tearDown(() {
    debugPauseMarblePhysics = false;
  });

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
      await tester.pump();

      // Dialog closed — Cancel gone.
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    }

    // End of test: leak_tracker runs its check. If any of the 12 expected
    // controllers (4 per open × 3 opens) leaked, the framework fails here.
  });
}
