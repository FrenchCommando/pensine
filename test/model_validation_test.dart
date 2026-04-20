import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/models/workspace.dart';

void main() {
  final validCreatedAt = DateTime.now().toIso8601String();

  Matcher throwsFormat(String snippet) => throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(snippet),
        ),
      );

  group('Board.fromJson rejects malformed input', () {
    test('missing name', () {
      expect(
        () => Board.fromJson({
          'type': 'thoughts',
          'createdAt': validCreatedAt,
          'items': [],
        }),
        throwsFormat('name'),
      );
    });

    test('name wrong type', () {
      expect(
        () => Board.fromJson({
          'name': 42,
          'type': 'thoughts',
          'createdAt': validCreatedAt,
          'items': [],
        }),
        throwsFormat('name'),
      );
    });

    test('unknown type', () {
      expect(
        () => Board.fromJson({
          'name': 'X',
          'type': 'magical',
          'createdAt': validCreatedAt,
          'items': [],
        }),
        throwsFormat('unknown type'),
      );
    });

    test('items not a list', () {
      expect(
        () => Board.fromJson({
          'name': 'X',
          'type': 'todo',
          'createdAt': validCreatedAt,
          'items': 'oops',
        }),
        throwsFormat('items'),
      );
    });

    test('item entry not an object', () {
      expect(
        () => Board.fromJson({
          'name': 'X',
          'type': 'todo',
          'createdAt': validCreatedAt,
          'items': ['string-not-object'],
        }),
        throwsFormat('item'),
      );
    });

    test('laps wrong type (not list)', () {
      expect(
        () => Board.fromJson({
          'name': 'X',
          'type': 'timer',
          'createdAt': validCreatedAt,
          'items': [],
          'laps': 'oops',
        }),
        throwsFormat('laps'),
      );
    });

    test('invalid createdAt string', () {
      expect(
        () => Board.fromJson({
          'name': 'X',
          'type': 'todo',
          'createdAt': 'not-a-date',
          'items': [],
        }),
        throwsFormat('invalid ISO-8601'),
      );
    });

    test('missing createdAt', () {
      expect(
        () => Board.fromJson({
          'name': 'X',
          'type': 'todo',
          'items': [],
        }),
        throwsFormat('missing'),
      );
    });
  });

  group('BoardItem.fromJson edge cases', () {
    test('missing content throws', () {
      expect(
        () => BoardItem.fromJson({
          'id': 'x',
          'createdAt': validCreatedAt,
        }),
        throwsFormat('content'),
      );
    });

    test('sizeMultiplier clamped to [0.1, 5.0]', () {
      final tooSmall = BoardItem.fromJson({
        'content': 'x',
        'createdAt': validCreatedAt,
        'sizeMultiplier': 0.001,
      });
      expect(tooSmall.sizeMultiplier, 0.1);

      final tooLarge = BoardItem.fromJson({
        'content': 'x',
        'createdAt': validCreatedAt,
        'sizeMultiplier': 50.0,
      });
      expect(tooLarge.sizeMultiplier, 5.0);
    });

    test('sizeMultiplier non-numeric falls back to 1.0', () {
      final item = BoardItem.fromJson({
        'content': 'x',
        'createdAt': validCreatedAt,
        'sizeMultiplier': 'big',
      });
      expect(item.sizeMultiplier, 1.0);
    });

    test('durationSeconds zero or negative becomes null', () {
      final zero = BoardItem.fromJson({
        'content': 'x',
        'createdAt': validCreatedAt,
        'durationSeconds': 0,
      });
      expect(zero.durationSeconds, isNull);

      final neg = BoardItem.fromJson({
        'content': 'x',
        'createdAt': validCreatedAt,
        'durationSeconds': -5,
      });
      expect(neg.durationSeconds, isNull);
    });

    test('durationSeconds non-int becomes null', () {
      final item = BoardItem.fromJson({
        'content': 'x',
        'createdAt': validCreatedAt,
        'durationSeconds': '30',
      });
      expect(item.durationSeconds, isNull);
    });

    test('wrong-type optional fields ignored (description/back)', () {
      final item = BoardItem.fromJson({
        'content': 'x',
        'createdAt': validCreatedAt,
        'description': 42,
        'backContent': true,
      });
      expect(item.description, isNull);
      expect(item.backContent, isNull);
    });
  });

  group('Lap.fromJson rejects malformed input', () {
    test('missing itemId', () {
      expect(
        () => Lap.fromJson({
          'elapsedSeconds': 5,
          'recordedAt': validCreatedAt,
        }),
        throwsFormat('itemId'),
      );
    });

    test('elapsedSeconds wrong type', () {
      expect(
        () => Lap.fromJson({
          'itemId': 'x',
          'elapsedSeconds': '5',
          'recordedAt': validCreatedAt,
        }),
        throwsFormat('elapsedSeconds'),
      );
    });

    test('invalid recordedAt', () {
      expect(
        () => Lap.fromJson({
          'itemId': 'x',
          'elapsedSeconds': 5,
          'recordedAt': 'nope',
        }),
        throwsFormat('invalid'),
      );
    });
  });

  group('Workspace.fromJson rejects malformed input', () {
    test('missing name', () {
      expect(
        () => Workspace.fromJson({
          'id': 'ws',
          'createdAt': validCreatedAt,
        }),
        throwsFormat('name'),
      );
    });

    test('missing createdAt', () {
      expect(
        () => Workspace.fromJson({'id': 'ws', 'name': 'X'}),
        throwsFormat('createdAt'),
      );
    });

    test('invalid createdAt', () {
      expect(
        () => Workspace.fromJson({
          'id': 'ws',
          'name': 'X',
          'createdAt': 'bad',
        }),
        throwsFormat('invalid createdAt'),
      );
    });
  });
}
