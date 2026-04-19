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
