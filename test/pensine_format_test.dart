import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/models/board.dart';
import 'package:pensine/models/workspace.dart';

/// Golden fixtures of the `.pensine` wire format. Change detection here is
/// the guardrail for backwards-compat: bumping the format requires deleting
/// or versioning the fixture deliberately.

// V1: single-board envelope. Written by `BoardIO.exportBoard`.
const _v1Envelope = '''
{
  "pensine_version": 1,
  "exported_at": "2026-04-15T12:00:00.000Z",
  "board": {
    "id": "b-1",
    "name": "Weekend",
    "type": "todo",
    "colorIndex": 3,
    "workspaceId": "ws-0",
    "createdAt": "2026-04-10T09:00:00.000Z",
    "items": [
      {
        "id": "i-1",
        "content": "Groceries",
        "done": false,
        "colorIndex": 2,
        "sizeMultiplier": 1.0,
        "createdAt": "2026-04-10T09:00:00.000Z"
      },
      {
        "id": "i-2",
        "content": "Call mom",
        "done": true,
        "colorIndex": 4,
        "sizeMultiplier": 1.2,
        "createdAt": "2026-04-10T09:05:00.000Z"
      }
    ],
    "tableMode": false
  }
}
''';

// V2: workspace envelope (nested boards). Written by `BoardIO.exportWorkspace`.
const _v2Envelope = '''
{
  "pensine_version": 2,
  "exported_at": "2026-04-15T12:00:00.000Z",
  "workspace": {
    "id": "ws-1",
    "name": "Cooking Recipes",
    "colorIndex": 0,
    "createdAt": "2026-04-10T09:00:00.000Z",
    "boards": [
      {
        "id": "b-a",
        "name": "Pasta",
        "type": "checklist",
        "colorIndex": -1,
        "workspaceId": "ws-1",
        "createdAt": "2026-04-10T09:00:00.000Z",
        "items": [
          {
            "id": "i-1",
            "content": "Boil water",
            "done": false,
            "colorIndex": 0,
            "sizeMultiplier": 1.0,
            "createdAt": "2026-04-10T09:00:00.000Z"
          }
        ],
        "laps": [],
        "tableMode": false
      }
    ]
  }
}
''';

void main() {
  group('V1 envelope (single board)', () {
    test('board parses from fixture', () {
      final json = jsonDecode(_v1Envelope) as Map<String, dynamic>;
      expect(json['pensine_version'], 1);
      final board = Board.fromJson(json['board'] as Map<String, dynamic>);
      expect(board.name, 'Weekend');
      expect(board.type, BoardType.todo);
      expect(board.items.length, 2);
      expect(board.items[0].content, 'Groceries');
      expect(board.items[1].done, true);
    });

    test('v1 fixture round-trips through toJson/fromJson', () {
      final json = jsonDecode(_v1Envelope) as Map<String, dynamic>;
      final board = Board.fromJson(json['board'] as Map<String, dynamic>);
      final restored = Board.fromJson(board.toJson());
      expect(restored.name, board.name);
      expect(restored.type, board.type);
      expect(restored.items.length, board.items.length);
      expect(restored.items[1].colorIndex, 4);
    });
  });

  group('V2 envelope (workspace)', () {
    test('workspace + nested boards parse', () {
      final json = jsonDecode(_v2Envelope) as Map<String, dynamic>;
      expect(json['pensine_version'], 2);
      final wsJson = json['workspace'] as Map<String, dynamic>;
      final workspace = Workspace.fromJson(wsJson);
      expect(workspace.name, 'Cooking Recipes');

      final boardsJson = wsJson['boards'] as List;
      final boards = boardsJson
          .map((b) => Board.fromJson(b as Map<String, dynamic>))
          .toList();
      expect(boards.length, 1);
      expect(boards[0].name, 'Pasta');
      expect(boards[0].type, BoardType.checklist);
    });

    test('imported v2 workspace regenerates IDs without collision', () {
      final json = jsonDecode(_v2Envelope) as Map<String, dynamic>;
      final wsJson = json['workspace'] as Map<String, dynamic>;

      final ws1 = Workspace.fromJson(wsJson).copyWithNewId();
      final ws2 = Workspace.fromJson(wsJson).copyWithNewId();
      expect(ws1.id, isNot(ws2.id));

      final boardsJson = wsJson['boards'] as List;
      final board1 = Board.fromJson(boardsJson[0] as Map<String, dynamic>)
          .copyWithNewIds();
      final board2 = Board.fromJson(boardsJson[0] as Map<String, dynamic>)
          .copyWithNewIds();
      expect(board1.id, isNot(board2.id));
      expect(board1.items[0].id, isNot(board2.items[0].id));
    });
  });

  group('Envelope malformed cases', () {
    test('v1: envelope with non-map board payload fails', () {
      final json = jsonDecode(_v1Envelope) as Map<String, dynamic>;
      json['board'] = 'not-an-object';
      expect(json['board'] is Map<String, dynamic>, isFalse);
    });

    test('v2: board entry with unknown type throws FormatException', () {
      final json = jsonDecode(_v2Envelope) as Map<String, dynamic>;
      final wsJson = json['workspace'] as Map<String, dynamic>;
      final boards = wsJson['boards'] as List;
      (boards[0] as Map<String, dynamic>)['type'] = 'not-a-real-type';
      expect(
        () => Board.fromJson(boards[0] as Map<String, dynamic>),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
