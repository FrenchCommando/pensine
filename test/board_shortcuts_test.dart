import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/screens/board_screen.dart';
import 'package:pensine/widgets/marble_board.dart';

/// Keyboard shortcut coverage for `BoardScreen`. Mirrors the
/// `board_screen_interactions_test.dart` setup (wakelock channel mock +
/// paused marble physics) so shortcuts fire in table mode without the
/// ticker stealing frames.

void _silenceWakelockChannel() {
  const channel = MethodChannel('dev.fluttercommunity.plus/wakelock_plus');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => null);
}

Future<void> _pump(WidgetTester tester, Board board,
    {VoidCallback? onChanged}) async {
  await tester.pumpWidget(MaterialApp(
    home: BoardScreen(board: board, onChanged: onChanged ?? () {}),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    _silenceWakelockChannel();
    // showPensineAbout awaits PackageInfo.fromPlatform() before showing the
    // dialog; without a mock, that future never resolves under flutter_tester.
    PackageInfo.setMockInitialValues(
      appName: 'Pensine',
      packageName: 'com.frenchcommando.pensine',
      version: '1.1.3',
      buildNumber: '1',
      buildSignature: '',
    );
    debugPauseMarblePhysics = true;
  });
  tearDown(() {
    debugPauseMarblePhysics = false;
  });

  group('Board screen shortcuts', () {
    testWidgets('R clears done flags on all items', (tester) async {
      final board = Board(
        name: 'Todos',
        type: BoardType.todo,
        tableMode: true,
        items: [
          BoardItem(content: 'A', done: true),
          BoardItem(content: 'B', done: true),
          BoardItem(content: 'C', done: false),
        ],
      );
      var onChangedCalls = 0;
      await _pump(tester, board, onChanged: () => onChangedCalls++);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(board.items.every((i) => !i.done), isTrue,
          reason: 'R should clear done on every item');
      expect(onChangedCalls, greaterThan(0),
          reason: 'R resets persistent state → onChanged must fire');
    });

    testWidgets('R clears laps on timer boards', (tester) async {
      final board = Board(
        name: 'Flight Log',
        type: BoardType.timer,
        tableMode: true,
        items: [
          BoardItem(content: 'Start'),
          BoardItem(content: 'Takeoff', done: true),
        ],
        laps: [Lap(itemId: 'x', elapsedSeconds: 42, recordedAt: DateTime.now())],
      );
      await _pump(tester, board);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(board.laps, isEmpty, reason: 'R should clear recorded laps');
    });

    testWidgets('A opens the About dialog', (tester) async {
      final board = Board(
        name: 'Demo',
        type: BoardType.thoughts,
        tableMode: true,
        items: [BoardItem(content: 'x')],
      );
      await _pump(tester, board);

      // AlertDialog is the simplest platform-independent marker: the
      // "Keyboard shortcuts:" section is gated on desktop/web and the
      // widget-test default platform is android, which hides it.
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'precondition: no about dialog yet');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'A should open the About dialog');
    });

    testWidgets('N opens the new-item dialog', (tester) async {
      // Regression cover for the existing N shortcut alongside the new ones.
      final board = Board(
        name: 'Todos',
        type: BoardType.todo,
        tableMode: true,
        items: [BoardItem(content: 'x')],
      );
      await _pump(tester, board);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget,
          reason: 'New-item dialog shows an "Add" FilledButton');
    });

    testWidgets('S is a no-op in table mode (no marble board mounted)',
        (tester) async {
      final board = Board(
        name: 'Todos',
        type: BoardType.todo,
        tableMode: true,
        items: [BoardItem(content: 'x')],
      );
      await _pump(tester, board);

      // Just verify it doesn't throw; shake has no observable side-effects
      // when there's no MarbleBoardState (table mode).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('T toggles tableMode', (tester) async {
      final board = Board(
        name: 'Todos',
        type: BoardType.todo,
        tableMode: true,
        items: [BoardItem(content: 'x')],
      );
      await _pump(tester, board);
      expect(board.tableMode, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump();

      expect(board.tableMode, isFalse,
          reason: 'T should flip tableMode to false (marble view)');
    });
  });
}
