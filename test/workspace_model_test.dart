import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/models/workspace.dart';

void main() {
  group('Workspace serialization', () {
    test('round-trip preserves all fields', () {
      final ws = Workspace(name: 'Cooking', colorIndex: 2);
      final restored = Workspace.fromJson(ws.toJson());
      expect(restored.id, ws.id);
      expect(restored.name, 'Cooking');
      expect(restored.colorIndex, 2);
      expect(restored.createdAt, ws.createdAt);
    });

    test('default colorIndex is -1', () {
      final ws = Workspace(name: 'Default');
      expect(ws.colorIndex, -1);
    });

    test('fromJson accepts missing colorIndex and uses default', () {
      final json = {
        'id': 'ws-1',
        'name': 'Minimal',
        'createdAt': DateTime.now().toIso8601String(),
      };
      final ws = Workspace.fromJson(json);
      expect(ws.colorIndex, -1);
    });
  });

  group('Workspace.copyWithNewId', () {
    test('generates new id but preserves data', () {
      final original = Workspace(name: 'Original', colorIndex: 5);
      final copy = original.copyWithNewId();
      expect(copy.id, isNot(original.id));
      expect(copy.name, 'Original');
      expect(copy.colorIndex, 5);
    });
  });
}
