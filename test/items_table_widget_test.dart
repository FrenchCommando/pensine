import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/widgets/items_table.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 1200, height: 800, child: child)));

void main() {
  group('ItemsTable', () {
    testWidgets('renders empty state with long-press hint', (tester) async {
      final board = Board(name: 'Empty', type: BoardType.thoughts);
      await tester.pumpWidget(_wrap(ItemsTable(
        board: board,
        onTap: (_) {},
        onLongPress: (_) {},
        onLongPressEmpty: () {},
        onReorder: (_, _) {},
      )));
      expect(find.textContaining('Empty board'), findsOneWidget);
    });

    testWidgets('renders rows for each item', (tester) async {
      final board = Board(name: 'Todos', type: BoardType.todo, items: [
        BoardItem(content: 'Groceries'),
        BoardItem(content: 'Call mom'),
        BoardItem(content: 'Fix bike'),
      ]);
      await tester.pumpWidget(_wrap(ItemsTable(
        board: board,
        onTap: (_) {},
        onLongPress: (_) {},
        onLongPressEmpty: () {},
        onReorder: (_, _) {},
      )));
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Call mom'), findsOneWidget);
      expect(find.text('Fix bike'), findsOneWidget);
    });

    testWidgets('tap on row fires onTap with the right item', (tester) async {
      final board = Board(name: 'Todos', type: BoardType.todo, items: [
        BoardItem(content: 'First'),
        BoardItem(content: 'Second'),
      ]);
      BoardItem? tapped;
      await tester.pumpWidget(_wrap(ItemsTable(
        board: board,
        onTap: (item) => tapped = item,
        onLongPress: (_) {},
        onLongPressEmpty: () {},
        onReorder: (_, _) {},
      )));

      await tester.tap(find.text('Second'));
      expect(tapped?.content, 'Second');
    });

    testWidgets('header columns adapt to board type', (tester) async {
      // flashcards: BACK column present, DETAILS too (flashcards have description)
      final flash = Board(name: 'F', type: BoardType.flashcards, items: [
        BoardItem(content: 'Q'),
      ]);
      await tester.pumpWidget(_wrap(ItemsTable(
        board: flash,
        onTap: (_) {},
        onLongPress: (_) {},
        onLongPressEmpty: () {},
        onReorder: (_, _) {},
      )));
      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('DURATION'), findsNothing);

      // thoughts: no BACK, no DONE, no DURATION
      final thoughts = Board(name: 'T', type: BoardType.thoughts, items: [
        BoardItem(content: 'Idea'),
      ]);
      await tester.pumpWidget(_wrap(ItemsTable(
        board: thoughts,
        onTap: (_) {},
        onLongPress: (_) {},
        onLongPressEmpty: () {},
        onReorder: (_, _) {},
      )));
      expect(find.text('BACK'), findsNothing);
      expect(find.text('DONE'), findsNothing);
      expect(find.text('DURATION'), findsNothing);

      // countdown: DURATION + DONE
      final countdown = Board(name: 'C', type: BoardType.countdown, items: [
        BoardItem(content: 'Step', durationSeconds: 30),
      ]);
      await tester.pumpWidget(_wrap(ItemsTable(
        board: countdown,
        onTap: (_) {},
        onLongPress: (_) {},
        onLongPressEmpty: () {},
        onReorder: (_, _) {},
      )));
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
    });

    testWidgets('done items render with strike-through-equivalent style',
        (tester) async {
      final board = Board(name: 'Todos', type: BoardType.todo, items: [
        BoardItem(content: 'Caught fish', done: true),
        BoardItem(content: 'Still floating', done: false),
      ]);
      await tester.pumpWidget(_wrap(ItemsTable(
        board: board,
        onTap: (_) {},
        onLongPress: (_) {},
        onLongPressEmpty: () {},
        onReorder: (_, _) {},
      )));

      final doneText = tester.widget<Text>(find.text('Caught fish'));
      final undoneText = tester.widget<Text>(find.text('Still floating'));
      expect(doneText.style?.decoration, TextDecoration.lineThrough);
      expect(undoneText.style?.decoration, isNot(TextDecoration.lineThrough));
    });
  });

  group('ItemsTable keyboard nav', () {
    // Widget-test default platform is android, so `isDesktopUX` is false and
    // long-press still fires. The desktop cases below flip this via
    // `debugDefaultTargetPlatformOverride`.

    Future<_RecordingHost> mount(WidgetTester tester, Board board) async {
      final host = _RecordingHost(board: board);
      await tester.pumpWidget(_wrap(host));
      // Focus the table so arrow/E keys reach the onKeyEvent handler.
      await tester.tap(find.text(board.items.first.content));
      await tester.pump();
      // tap also fires onTap; clear the recorded value so assertions below
      // only see the action we're testing.
      host.clear();
      return host;
    }

    testWidgets('Arrow Down then E fires onLongPress on the next row',
        (tester) async {
      final board = Board(name: 'T', type: BoardType.todo, items: [
        BoardItem(content: 'First'),
        BoardItem(content: 'Second'),
        BoardItem(content: 'Third'),
      ]);
      final host = await mount(tester, board);

      // Tap on First selected index 0; advance to 1 (Second), then edit.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();

      expect(host.edited?.content, 'Second',
          reason: 'E edits the selected row (index 1 after ArrowDown)');
    });

    testWidgets('Arrow Up retreats selection', (tester) async {
      final board = Board(name: 'T', type: BoardType.todo, items: [
        BoardItem(content: 'A'),
        BoardItem(content: 'B'),
      ]);
      final host = await mount(tester, board);

      // Move down then up — net zero, edit A.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();

      expect(host.edited?.content, 'A');
    });

    testWidgets('Enter activates selected row (same as tap)', (tester) async {
      final board = Board(name: 'T', type: BoardType.todo, items: [
        BoardItem(content: 'First'),
        BoardItem(content: 'Second'),
      ]);
      final host = await mount(tester, board);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(host.tapped?.content, 'Second');
    });

    testWidgets('ArrowDown past the last row clamps (no wrap)',
        (tester) async {
      final board = Board(name: 'T', type: BoardType.todo, items: [
        BoardItem(content: 'A'),
        BoardItem(content: 'B'),
      ]);
      final host = await mount(tester, board);

      // Press Down 5 times on a 2-row board — should stop at B, not wrap.
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();

      expect(host.edited?.content, 'B',
          reason: 'Selection clamps at last row; does not wrap around.');
    });
  });

  group('ItemsTable pointer gestures', () {
    testWidgets('right-click on a row fires onLongPress (desktop override)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final board = Board(name: 'T', type: BoardType.todo, items: [
          BoardItem(content: 'A'),
          BoardItem(content: 'B'),
        ]);
        final host = _RecordingHost(board: board);
        await tester.pumpWidget(_wrap(host));

        await tester.tap(find.text('B'), buttons: kSecondaryButton);
        await tester.pump();

        expect(host.edited?.content, 'B');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('long-press on desktop is disabled (no edit fired)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final board = Board(name: 'T', type: BoardType.todo, items: [
          BoardItem(content: 'A'),
        ]);
        final host = _RecordingHost(board: board);
        await tester.pumpWidget(_wrap(host));

        await tester.longPress(find.text('A'));
        await tester.pump();

        expect(host.edited, isNull,
            reason: 'Long-press is wired only on touch platforms.');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('long-press on mobile still fires onLongPress',
        (tester) async {
      // Default platform (android) represents mobile — no override.
      final board = Board(name: 'T', type: BoardType.todo, items: [
        BoardItem(content: 'A'),
      ]);
      final host = _RecordingHost(board: board);
      await tester.pumpWidget(_wrap(host));

      await tester.longPress(find.text('A'));
      await tester.pump();

      expect(host.edited?.content, 'A');
    });

    testWidgets('empty-state hint switches to "Right-click" on desktop',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final board = Board(name: 'Empty', type: BoardType.thoughts);
        await tester.pumpWidget(_wrap(ItemsTable(
          board: board,
          onTap: (_) {},
          onLongPress: (_) {},
          onLongPressEmpty: () {},
          onReorder: (_, _) {},
        )));
        expect(find.textContaining('Right-click'), findsOneWidget);
        expect(find.textContaining('Long-press'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

/// Renders ItemsTable and records which item was tapped / long-pressed.
class _RecordingHost extends StatelessWidget {
  final Board board;
  final _state = _Record();

  _RecordingHost({required this.board});

  BoardItem? get tapped => _state.tapped;
  BoardItem? get edited => _state.edited;
  void clear() => _state.clear();

  @override
  Widget build(BuildContext context) {
    return ItemsTable(
      board: board,
      onTap: (item) => _state.tapped = item,
      onLongPress: (item) => _state.edited = item,
      onLongPressEmpty: () {},
      onReorder: (_, _) {},
    );
  }
}

class _Record {
  BoardItem? tapped;
  BoardItem? edited;
  void clear() {
    tapped = null;
    edited = null;
  }
}
