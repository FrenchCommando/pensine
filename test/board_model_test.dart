import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/models/board.dart';

void main() {
  group('Board serialization', () {
    test('round-trip toJson/fromJson preserves all fields', () {
      final board = Board(
        name: 'Test Board',
        type: BoardType.thoughts,
        tableMode: true,
        items: [
          BoardItem(
            content: 'Hello',
            description: 'Details here',
            colorIndex: 3,
            sizeMultiplier: 1.5,
          ),
          BoardItem(
            content: 'Flashcard front',
            backContent: 'Flashcard back',
            done: true,
            colorIndex: 7,
          ),
        ],
      );

      final json = board.toJson();
      final restored = Board.fromJson(json);

      expect(restored.id, board.id);
      expect(restored.name, 'Test Board');
      expect(restored.type, BoardType.thoughts);
      expect(restored.createdAt, board.createdAt);
      expect(restored.items.length, 2);

      expect(restored.items[0].content, 'Hello');
      expect(restored.items[0].description, 'Details here');
      expect(restored.items[0].backContent, isNull);
      expect(restored.items[0].colorIndex, 3);
      expect(restored.items[0].sizeMultiplier, 1.5);
      expect(restored.items[0].done, false);

      expect(restored.items[1].content, 'Flashcard front');
      expect(restored.items[1].backContent, 'Flashcard back');
      expect(restored.items[1].done, true);
      expect(restored.items[1].colorIndex, 7);
      expect(restored.tableMode, true);
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {
        'id': 'test-id',
        'name': 'Minimal',
        'type': 'todo',
        'createdAt': DateTime.now().toIso8601String(),
        'items': [
          {
            'id': 'item-1',
            'content': 'Just content',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
      };

      final board = Board.fromJson(json);
      final item = board.items[0];

      expect(item.description, isNull);
      expect(item.backContent, isNull);
      expect(item.done, false);
      expect(item.colorIndex, 0);
      expect(item.sizeMultiplier, 1.0);
      expect(board.tableMode, false);
    });

    test('all board types serialize correctly', () {
      for (final type in BoardType.values) {
        final board = Board(name: type.name, type: type);
        final restored = Board.fromJson(board.toJson());
        expect(restored.type, type);
      }
    });
  });

  group('Board.copyWithNewIds', () {
    test('generates new IDs for board and items', () {
      final original = Board(
        name: 'Original',
        type: BoardType.flashcards,
        items: [
          BoardItem(content: 'Q1', backContent: 'A1'),
          BoardItem(content: 'Q2', backContent: 'A2'),
        ],
      );

      final copy = original.copyWithNewIds();

      expect(copy.id, isNot(original.id));
      expect(copy.name, original.name);
      expect(copy.type, original.type);
      expect(copy.items.length, 2);
      expect(copy.items[0].id, isNot(original.items[0].id));
      expect(copy.items[1].id, isNot(original.items[1].id));
      expect(copy.items[0].content, 'Q1');
      expect(copy.items[0].backContent, 'A1');
    });

    test('preserves item data but resets done state is kept', () {
      final original = Board(
        name: 'Test',
        type: BoardType.todo,
        items: [
          BoardItem(content: 'Task', done: true, colorIndex: 5, sizeMultiplier: 0.8),
        ],
      );

      final copy = original.copyWithNewIds();

      expect(copy.items[0].done, true);
      expect(copy.items[0].colorIndex, 5);
      expect(copy.items[0].sizeMultiplier, 0.8);
    });
  });

  group('Board order', () {
    test('item order preserved through serialization', () {
      final board = Board(
        name: 'Steps',
        type: BoardType.checklist,
        items: [
          BoardItem(content: 'First'),
          BoardItem(content: 'Second'),
          BoardItem(content: 'Third'),
        ],
      );

      final restored = Board.fromJson(board.toJson());

      expect(restored.items[0].content, 'First');
      expect(restored.items[1].content, 'Second');
      expect(restored.items[2].content, 'Third');
    });
  });

  group('Board rename', () {
    test('name can be updated', () {
      final board = Board(name: 'Old Name', type: BoardType.thoughts);
      board.name = 'New Name';
      expect(board.name, 'New Name');

      // Persists through serialization
      final restored = Board.fromJson(board.toJson());
      expect(restored.name, 'New Name');
    });
  });

  group('Lap serialization', () {
    test('round-trip preserves all fields', () {
      final lap = Lap(itemId: 'item-42', elapsedSeconds: 17);
      final restored = Lap.fromJson(lap.toJson());
      expect(restored.id, lap.id);
      expect(restored.itemId, 'item-42');
      expect(restored.elapsedSeconds, 17);
      expect(restored.recordedAt, lap.recordedAt);
    });

    test('board with laps round-trips them', () {
      final board = Board(
        name: 'Timer',
        type: BoardType.timer,
        items: [BoardItem(content: 'Step 1')],
        laps: [
          Lap(itemId: 'a', elapsedSeconds: 5),
          Lap(itemId: 'b', elapsedSeconds: 12),
        ],
      );
      final restored = Board.fromJson(board.toJson());
      expect(restored.laps.length, 2);
      expect(restored.laps[0].itemId, 'a');
      expect(restored.laps[1].elapsedSeconds, 12);
    });
  });

  group('BoardItem.cloneWithNewId', () {
    test('preserves all fields except id', () {
      final item = BoardItem(
        content: 'Q',
        description: 'D',
        backContent: 'A',
        done: true,
        colorIndex: 3,
        sizeMultiplier: 1.7,
        durationSeconds: 60,
      );
      final clone = item.cloneWithNewId();
      expect(clone.id, isNot(item.id));
      expect(clone.content, 'Q');
      expect(clone.description, 'D');
      expect(clone.backContent, 'A');
      expect(clone.done, true);
      expect(clone.colorIndex, 3);
      expect(clone.sizeMultiplier, 1.7);
      expect(clone.durationSeconds, 60);
    });
  });

  group('Board.copyWithNewIds laps handling', () {
    test('drops laps because their itemIds would be stale', () {
      final original = Board(
        name: 'Timer',
        type: BoardType.timer,
        items: [BoardItem(content: 'Step')],
        laps: [Lap(itemId: 'old', elapsedSeconds: 1)],
      );
      final copy = original.copyWithNewIds();
      expect(copy.laps, isEmpty);
    });
  });

  group('Board list reorder', () {
    test('reorder logic matches ReorderableListView callback', () {
      final boards = [
        Board(name: 'A', type: BoardType.thoughts),
        Board(name: 'B', type: BoardType.todo),
        Board(name: 'C', type: BoardType.flashcards),
      ];

      // Simulate moving C (index 2) to position 0
      var oldIndex = 2;
      var newIndex = 0;
      final board = boards.removeAt(oldIndex);
      boards.insert(newIndex, board);

      expect(boards.map((b) => b.name).toList(), ['C', 'A', 'B']);

      // Simulate moving first item (C) to end (index 3, adjusted to 2)
      oldIndex = 0;
      newIndex = 3;
      if (newIndex > oldIndex) newIndex--;
      final board2 = boards.removeAt(oldIndex);
      boards.insert(newIndex, board2);

      expect(boards.map((b) => b.name).toList(), ['A', 'B', 'C']);
    });
  });
}
