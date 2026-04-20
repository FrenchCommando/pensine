import 'package:flutter/material.dart';
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
}
