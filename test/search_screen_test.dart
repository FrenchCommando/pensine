import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/behavior/board_search.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/models/workspace.dart';
import 'package:pensine/screens/search_screen.dart';

/// Widget-level checks on SearchScreen — the unit tests in
/// `board_search_test.dart` cover the pure search; this file covers the
/// glue: debounce timing, instant clear, and hit tap → onSelect.

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  late Workspace ws;
  late Board board;

  setUp(() {
    ws = Workspace(name: 'Home');
    board = Board(
      name: 'Ideas',
      type: BoardType.thoughts,
      workspaceId: ws.id,
      items: [BoardItem(content: 'buy milk')],
    );
  });

  testWidgets('typed query is debounced before search runs',
      (tester) async {
    await tester.pumpWidget(_host(SearchScreen(
      workspaces: [ws],
      boards: [board],
      onSelect: (_) {},
    )));

    await tester.enterText(find.byType(TextField), 'milk');
    // Before the debounce expires, results haven't populated yet.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('buy milk'), findsNothing);
    expect(find.text('Type to search'), findsOneWidget);

    // After the debounce window, the hit appears.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('buy milk'), findsOneWidget);
  });

  testWidgets('clearing the query is instant (no debounce)',
      (tester) async {
    await tester.pumpWidget(_host(SearchScreen(
      workspaces: [ws],
      boards: [board],
      onSelect: (_) {},
    )));

    await tester.enterText(find.byType(TextField), 'milk');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('buy milk'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    // No extra pump past the debounce window — the empty state should
    // render on the same frame.
    await tester.pump();
    expect(find.text('buy milk'), findsNothing);
    expect(find.text('Type to search'), findsOneWidget);
  });

  testWidgets('intermediate keystrokes never surface their own results',
      (tester) async {
    await tester.pumpWidget(_host(SearchScreen(
      workspaces: [ws],
      boards: [board],
      onSelect: (_) {},
    )));

    // Each keystroke sits inside the previous debounce window, so the
    // intermediate queries ('m', 'mi', 'mil') must never fire a search.
    await tester.enterText(find.byType(TextField), 'm');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), 'mi');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), 'mil');
    await tester.pump(const Duration(milliseconds: 50));
    // Still inside the rolling debounce — no results yet.
    expect(find.text('buy milk'), findsNothing);

    await tester.enterText(find.byType(TextField), 'milk');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('buy milk'), findsOneWidget);
  });

  testWidgets('tapping a result invokes onSelect with that match',
      (tester) async {
    SearchMatch? picked;
    await tester.pumpWidget(_host(SearchScreen(
      workspaces: [ws],
      boards: [board],
      onSelect: (m) => picked = m,
    )));

    await tester.enterText(find.byType(TextField), 'milk');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('buy milk'));
    await tester.pump();

    expect(picked, isNotNull);
    expect(picked!.kind, SearchMatchKind.item);
    expect(picked!.board, board);
  });
}
