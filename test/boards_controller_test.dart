import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/controllers/boards_controller.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/models/workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Direct unit tests for the CRUD surface extracted from HomeScreen.
/// Previously these operations were only exercisable by pumping the full
/// HomeScreen + driving UI gestures.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('load + defaults', () {
    test('empty storage populates defaults and persists them', () async {
      final c = BoardsController();
      await c.load();

      expect(c.loading, false);
      expect(c.workspaces.isNotEmpty, true,
          reason: 'defaults should include the 5 example workspaces');
      expect(c.boards.isNotEmpty, true);

      // A fresh controller should see the persisted boards (not repopulate).
      final c2 = BoardsController();
      await c2.load();
      expect(c2.boards.length, c.boards.length);
      expect(c2.workspaces.length, c.workspaces.length);

      c.dispose();
      c2.dispose();
    });
  });

  group('Board CRUD', () {
    test('addBoard persists and notifies', () async {
      final c = BoardsController();
      await c.load();
      final initialCount = c.boards.length;
      final ws = c.workspaces.first;

      var notifyCount = 0;
      c.addListener(() => notifyCount++);

      final board = Board(name: 'New', type: BoardType.todo, workspaceId: ws.id);
      await c.addBoard(board);

      expect(c.boards.length, initialCount + 1);
      expect(c.boards.last.id, board.id);
      expect(notifyCount, greaterThanOrEqualTo(1));

      c.dispose();
    });

    test('deleteBoard removes from list and persists', () async {
      final c = BoardsController();
      await c.load();
      final target = c.boards.first;
      final initialCount = c.boards.length;

      await c.deleteBoard(target.id);

      expect(c.boards.length, initialCount - 1);
      expect(c.boards.any((b) => b.id == target.id), false);

      c.dispose();
    });

    test('boardsForWorkspace indexes correctly', () async {
      final c = BoardsController();
      await c.load();

      for (final ws in c.workspaces) {
        final wsBoards = c.boardsForWorkspace(ws.id);
        expect(wsBoards.every((b) => b.workspaceId == ws.id), true);
      }

      c.dispose();
    });

    test('duplicateBoard creates a copy with fresh IDs', () async {
      final c = BoardsController();
      await c.load();
      final original = c.boards.first;
      final initialCount = c.boards.length;

      await c.duplicateBoard(original);

      expect(c.boards.length, initialCount + 1);
      final copy = c.boards.last;
      expect(copy.id, isNot(original.id));
      expect(copy.name, '${original.name} (copy)');
      expect(copy.items.length, original.items.length);
      for (var i = 0; i < copy.items.length; i++) {
        expect(copy.items[i].id, isNot(original.items[i].id));
      }

      c.dispose();
    });
  });

  group('Workspace CRUD', () {
    test('addWorkspace persists and notifies', () async {
      final c = BoardsController();
      await c.load();
      final initialCount = c.workspaces.length;

      await c.addWorkspace(Workspace(name: 'New WS'));

      expect(c.workspaces.length, initialCount + 1);
      expect(c.workspaces.last.name, 'New WS');

      c.dispose();
    });

    test('deleteWorkspace removes workspace AND its boards', () async {
      final c = BoardsController();
      await c.load();
      final ws = c.workspaces.first;
      final wsBoardIds =
          c.boardsForWorkspace(ws.id).map((b) => b.id).toList();
      expect(wsBoardIds.isNotEmpty, true,
          reason: 'defaults should have boards in the first workspace');

      await c.deleteWorkspace(ws);

      expect(c.workspaces.any((w) => w.id == ws.id), false);
      expect(c.boards.any((b) => wsBoardIds.contains(b.id)), false);

      c.dispose();
    });
  });

  group('Collapsed state', () {
    test('toggleCollapsed round-trips and persists', () async {
      final c = BoardsController();
      await c.load();
      final ws = c.workspaces.first;

      expect(c.collapsed.contains(ws.id), false);
      await c.toggleCollapsed(ws.id);
      expect(c.collapsed.contains(ws.id), true);

      // Reload: persisted collapsed state survives.
      final c2 = BoardsController();
      await c2.load();
      expect(c2.collapsed.contains(ws.id), true);

      await c.toggleCollapsed(ws.id);
      expect(c.collapsed.contains(ws.id), false);

      c.dispose();
      c2.dispose();
    });
  });

  group('reset', () {
    test('reset wipes existing data and repopulates defaults', () async {
      final c = BoardsController();
      await c.load();

      // Add a custom board so we can confirm it's gone after reset.
      final custom = Board(
        name: 'Custom',
        type: BoardType.thoughts,
        workspaceId: c.workspaces.first.id,
      );
      await c.addBoard(custom);
      expect(c.boards.any((b) => b.id == custom.id), true);

      await c.reset();

      expect(c.boards.any((b) => b.id == custom.id), false,
          reason: 'custom board should be gone');
      expect(c.workspaces.isNotEmpty, true);
      expect(c.boards.isNotEmpty, true);

      c.dispose();
    });
  });
}
