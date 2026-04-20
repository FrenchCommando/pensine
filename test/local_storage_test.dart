import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/models/workspace.dart';
import 'package:pensine/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises `LocalStorage` on the SharedPreferences path (web/mobile).
/// Desktop (file-based) path isn't covered here — it goes through
/// `path_provider` which needs native platform channels.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('saveBoard / loadBoards round-trip (prefs)', () {
    test('saved board can be loaded back', () async {
      final board = Board(name: 'Roundtrip', type: BoardType.thoughts);
      await LocalStorage.saveBoard(board);
      await LocalStorage.saveBoardOrder([board.id]);

      final loaded = await LocalStorage.loadBoards();
      expect(loaded.length, 1);
      expect(loaded[0].id, board.id);
      expect(loaded[0].name, 'Roundtrip');
    });

    test('order is preserved via saveBoardOrder', () async {
      final a = Board(name: 'A', type: BoardType.todo);
      final b = Board(name: 'B', type: BoardType.todo);
      final c = Board(name: 'C', type: BoardType.todo);

      await LocalStorage.saveBoard(a);
      await LocalStorage.saveBoard(b);
      await LocalStorage.saveBoard(c);
      await LocalStorage.saveBoardOrder([c.id, a.id, b.id]);

      final loaded = await LocalStorage.loadBoards();
      expect(loaded.map((x) => x.name).toList(), ['C', 'A', 'B']);
    });
  });

  group('race regression: parallel saveBoard', () {
    // NOTES.md flags that `_saveBoardPref` does a read-modify-write on the
    // index key (`pensine_board_ids`). Parallel writes can drop ids because
    // the last setStringList wins. `saveAllBoards` works around this by
    // calling `saveBoardOrder` at the end. This test locks in that fix.
    test(
      'saveAllBoards writes an intact index after parallel per-board saves',
      () async {
        final boards = List.generate(
          10,
          (i) => Board(name: 'B$i', type: BoardType.todo),
        );

        await LocalStorage.saveAllBoards(boards);

        final loaded = await LocalStorage.loadBoards();
        expect(loaded.length, 10);
        final loadedIds = loaded.map((b) => b.id).toSet();
        final expectedIds = boards.map((b) => b.id).toSet();
        expect(loadedIds, expectedIds);
      },
    );

    test(
      'saveAllWorkspaces also maintains index integrity',
      () async {
        final workspaces = List.generate(
          8,
          (i) => Workspace(name: 'W$i'),
        );

        await LocalStorage.saveAllWorkspaces(workspaces);

        final loaded = await LocalStorage.loadWorkspaces();
        expect(loaded.length, 8);
        final loadedIds = loaded.map((w) => w.id).toSet();
        final expectedIds = workspaces.map((w) => w.id).toSet();
        expect(loadedIds, expectedIds);
      },
    );
  });

  group('corrupted-file resilience', () {
    // Locks in the fix in local_storage.dart: one malformed entry must not
    // wipe the whole list (previous behavior returned `[]` on any throw).
    test(
      'loadBoards skips malformed json and returns the rest',
      () async {
        final good = Board(name: 'Good', type: BoardType.thoughts);
        final goodJson = jsonEncode(good.toJson());

        SharedPreferences.setMockInitialValues({
          'pensine_board_ids': ['bad-id', good.id],
          'pensine_board_bad-id': 'not-valid-json-{{{',
          'pensine_board_${good.id}': goodJson,
        });

        final loaded = await LocalStorage.loadBoards();
        expect(loaded.length, 1);
        expect(loaded[0].name, 'Good');
      },
    );

    test(
      'loadBoards skips entries with missing required fields',
      () async {
        final good = Board(name: 'Good', type: BoardType.todo);
        final goodJson = jsonEncode(good.toJson());

        // Valid JSON but missing 'name' — Board.fromJson throws FormatException.
        final bad = jsonEncode({'id': 'bad', 'type': 'todo', 'items': []});

        SharedPreferences.setMockInitialValues({
          'pensine_board_ids': ['bad', good.id],
          'pensine_board_bad': bad,
          'pensine_board_${good.id}': goodJson,
        });

        final loaded = await LocalStorage.loadBoards();
        expect(loaded.length, 1);
        expect(loaded[0].id, good.id);
      },
    );

    test(
      'loadWorkspaces skips malformed entries',
      () async {
        final good = Workspace(name: 'Good');
        final goodJson = jsonEncode(good.toJson());

        SharedPreferences.setMockInitialValues({
          'pensine_workspace_ids': ['bad', good.id],
          'pensine_workspace_bad': '{"not":"a-workspace"}',
          'pensine_workspace_${good.id}': goodJson,
        });

        final loaded = await LocalStorage.loadWorkspaces();
        expect(loaded.length, 1);
        expect(loaded[0].id, good.id);
      },
    );

    test(
      'loadBoards handles dangling id (data missing entirely)',
      () async {
        final good = Board(name: 'Good', type: BoardType.todo);
        final goodJson = jsonEncode(good.toJson());

        // 'ghost' is in the index but has no data key.
        SharedPreferences.setMockInitialValues({
          'pensine_board_ids': ['ghost', good.id],
          'pensine_board_${good.id}': goodJson,
        });

        final loaded = await LocalStorage.loadBoards();
        expect(loaded.length, 1);
        expect(loaded[0].id, good.id);
      },
    );
  });

  group('deleteBoard', () {
    test('removes from index and data keys', () async {
      final a = Board(name: 'Keep', type: BoardType.todo);
      final b = Board(name: 'Delete', type: BoardType.todo);
      await LocalStorage.saveAllBoards([a, b]);

      await LocalStorage.deleteBoard(b.id);
      await LocalStorage.saveBoardOrder([a.id]);

      final loaded = await LocalStorage.loadBoards();
      expect(loaded.length, 1);
      expect(loaded[0].id, a.id);
    });
  });
}
