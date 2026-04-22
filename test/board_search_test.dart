import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/behavior/board_search.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/models/workspace.dart';

/// Unit tests for the pure search function. Mirrors the testing style of
/// `board_tap_test.dart` — no widgets, no storage, just data in → matches
/// out.

Workspace _ws(String name) => Workspace(name: name);

Board _board(
  String name,
  String workspaceId, {
  BoardType type = BoardType.thoughts,
  List<BoardItem> items = const [],
}) =>
    Board(name: name, type: type, workspaceId: workspaceId, items: items);

void main() {
  group('empty input', () {
    test('empty query returns no results', () {
      final ws = _ws('Home');
      final b = _board('Ideas', ws.id, items: [BoardItem(content: 'hello')]);
      expect(
        searchBoards(query: '', workspaces: [ws], boards: [b]),
        isEmpty,
      );
    });

    test('whitespace-only query returns no results', () {
      final ws = _ws('Home');
      final b = _board('Ideas', ws.id, items: [BoardItem(content: 'hello')]);
      expect(
        searchBoards(query: '   ', workspaces: [ws], boards: [b]),
        isEmpty,
      );
    });

    test('no data returns no results', () {
      expect(
        searchBoards(query: 'x', workspaces: const [], boards: const []),
        isEmpty,
      );
    });
  });

  group('match kinds', () {
    test('matches workspace by name', () {
      final home = _ws('Home');
      final work = _ws('Work');
      final result = searchBoards(
        query: 'wor',
        workspaces: [home, work],
        boards: const [],
      );
      expect(result, hasLength(1));
      expect(result.first.kind, SearchMatchKind.workspace);
      expect(result.first.workspace, work);
      expect(result.first.primary, 'Work');
    });

    test('matches board by name, with workspace in breadcrumb', () {
      final ws = _ws('Home');
      final ideas = _board('Ideas', ws.id);
      final recipes = _board('Recipes', ws.id);
      final result = searchBoards(
        query: 'ide',
        workspaces: [ws],
        boards: [ideas, recipes],
      );
      expect(result, hasLength(1));
      expect(result.first.kind, SearchMatchKind.board);
      expect(result.first.board, ideas);
      expect(result.first.secondary, 'Home');
    });

    test('matches item content', () {
      final ws = _ws('Home');
      final b = _board('Ideas', ws.id, items: [
        BoardItem(content: 'buy milk'),
        BoardItem(content: 'call mom'),
      ]);
      final result = searchBoards(
        query: 'mom',
        workspaces: [ws],
        boards: [b],
      );
      expect(result, hasLength(1));
      expect(result.first.kind, SearchMatchKind.item);
      expect(result.first.item, b.items[1]);
      expect(result.first.primary, 'call mom');
      expect(result.first.secondary, 'Home › Ideas');
    });

    test('matches flashcard back content', () {
      final ws = _ws('Study');
      final b = _board('French', ws.id, type: BoardType.flashcards, items: [
        BoardItem(content: 'bonjour', backContent: 'hello'),
      ]);
      final result = searchBoards(
        query: 'hell',
        workspaces: [ws],
        boards: [b],
      );
      expect(result, hasLength(1));
      expect(result.first.kind, SearchMatchKind.item);
      expect(result.first.primary, 'hello');
    });

    test('matches thought description', () {
      final ws = _ws('Journal');
      final b = _board('Notes', ws.id, items: [
        BoardItem(content: 'short', description: 'longer elaboration'),
      ]);
      final result = searchBoards(
        query: 'elabor',
        workspaces: [ws],
        boards: [b],
      );
      expect(result, hasLength(1));
      expect(result.first.primary, 'longer elaboration');
    });

    test('one hit per item even when multiple fields match', () {
      final ws = _ws('Study');
      final b = _board('French', ws.id, type: BoardType.flashcards, items: [
        BoardItem(content: 'cat', description: 'cat family', backContent: 'chat'),
      ]);
      final result = searchBoards(
        query: 'cat',
        workspaces: [ws],
        boards: [b],
      );
      expect(result, hasLength(1));
      expect(result.first.primary, 'cat');
    });
  });

  group('ordering & ranking', () {
    test('workspaces come before boards before items', () {
      final test = _ws('Test workspace');
      final b = _board('Test board', test.id, items: [
        BoardItem(content: 'test item'),
      ]);
      final result = searchBoards(
        query: 'test',
        workspaces: [test],
        boards: [b],
      );
      expect(result.map((m) => m.kind), [
        SearchMatchKind.workspace,
        SearchMatchKind.board,
        SearchMatchKind.item,
      ]);
    });

    test('earlier matches outrank later within the same kind', () {
      final ws = _ws('W');
      final b1 = _board('apple pie', ws.id);
      final b2 = _board('pie chart', ws.id);
      final result = searchBoards(
        query: 'pie',
        workspaces: [ws],
        boards: [b1, b2],
      );
      expect(result.map((m) => m.board), [b2, b1]);
    });
  });

  group('case & highlighting', () {
    test('search is case-insensitive', () {
      final ws = _ws('Home');
      final b = _board('Ideas', ws.id, items: [
        BoardItem(content: 'Buy MILK'),
      ]);
      final result = searchBoards(
        query: 'milk',
        workspaces: [ws],
        boards: [b],
      );
      expect(result, hasLength(1));
    });

    test('match indices preserve original casing in primary', () {
      final ws = _ws('Home');
      final b = _board('Ideas', ws.id, items: [
        BoardItem(content: 'Buy MILK today'),
      ]);
      final result = searchBoards(
        query: 'milk',
        workspaces: [ws],
        boards: [b],
      );
      final m = result.single;
      expect(m.primary, 'Buy MILK today');
      expect(m.primary.substring(m.matchStart, m.matchStart + m.matchLength),
          'MILK');
    });
  });

  test('limit caps result count', () {
    final ws = _ws('W');
    final boards = List.generate(5, (i) => _board('board $i', ws.id));
    final result = searchBoards(
      query: 'board',
      workspaces: [ws],
      boards: boards,
      limit: 3,
    );
    expect(result, hasLength(3));
  });
}
