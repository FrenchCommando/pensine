import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum BoardType { thoughts, todo, flashcards, checklist, timer, countdown }

extension BoardTypeX on BoardType {
  bool get isSequential =>
      this == BoardType.checklist ||
      this == BoardType.timer ||
      this == BoardType.countdown;

  bool get hasNet =>
      this == BoardType.todo || this == BoardType.flashcards || isSequential;

  IconData get icon => switch (this) {
        BoardType.thoughts => Icons.cloud,
        BoardType.todo => Icons.check_circle_outline,
        BoardType.flashcards => Icons.style,
        BoardType.checklist => Icons.format_list_numbered,
        BoardType.timer => Icons.timer,
        BoardType.countdown => Icons.hourglass_bottom,
      };

  String get displayName => name[0].toUpperCase() + name.substring(1);
}

class Board {
  final String id;
  String name;
  BoardType type;
  int colorIndex;
  String workspaceId;
  final DateTime createdAt;
  List<BoardItem> items;
  List<Lap> laps;
  bool tableMode;

  Board({
    String? id,
    required this.name,
    required this.type,
    this.colorIndex = -1,
    this.workspaceId = '',
    DateTime? createdAt,
    List<BoardItem>? items,
    List<Lap>? laps,
    this.tableMode = false,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        items = items ?? [],
        laps = laps ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'colorIndex': colorIndex,
        'workspaceId': workspaceId,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'laps': laps.map((l) => l.toJson()).toList(),
        'tableMode': tableMode,
      };

  factory Board.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String) {
      throw const FormatException('Board: name missing or not a string');
    }
    final typeName = json['type'];
    final type = BoardType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => throw FormatException('Board: unknown type "$typeName"'),
    );
    final itemsJson = json['items'];
    if (itemsJson is! List) {
      throw const FormatException('Board: items must be a list');
    }
    final lapsJson = json['laps'];
    if (lapsJson != null && lapsJson is! List) {
      throw const FormatException('Board: laps must be a list');
    }
    return Board(
      id: json['id'] is String ? json['id'] as String : null,
      name: name,
      type: type,
      colorIndex: json['colorIndex'] is int ? json['colorIndex'] as int : -1,
      workspaceId:
          json['workspaceId'] is String ? json['workspaceId'] as String : '',
      createdAt: _parseDate(json['createdAt'], 'Board.createdAt'),
      items: itemsJson.map((i) {
        if (i is! Map<String, dynamic>) {
          throw const FormatException('Board: item must be an object');
        }
        return BoardItem.fromJson(i);
      }).toList(),
      laps: (lapsJson as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Lap.fromJson)
              .toList() ??
          [],
      tableMode: json['tableMode'] is bool ? json['tableMode'] as bool : false,
    );
  }

  /// Creates a copy with fresh IDs (for import). Laps are dropped because
  /// they reference item IDs that get regenerated.
  Board copyWithNewIds() => Board(
        name: name,
        type: type,
        colorIndex: colorIndex,
        workspaceId: workspaceId,
        items: items.map((i) => i.cloneWithNewId()).toList(),
        tableMode: tableMode,
      );
}

class Lap {
  final String id;
  final String itemId;
  final int elapsedSeconds;
  final DateTime recordedAt;

  Lap({
    String? id,
    required this.itemId,
    required this.elapsedSeconds,
    DateTime? recordedAt,
  })  : id = id ?? _uuid.v4(),
        recordedAt = recordedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'elapsedSeconds': elapsedSeconds,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory Lap.fromJson(Map<String, dynamic> json) {
    final itemId = json['itemId'];
    if (itemId is! String) {
      throw const FormatException('Lap: itemId missing or not a string');
    }
    final elapsed = json['elapsedSeconds'];
    if (elapsed is! int) {
      throw const FormatException('Lap: elapsedSeconds must be an int');
    }
    return Lap(
      id: json['id'] is String ? json['id'] as String : null,
      itemId: itemId,
      elapsedSeconds: elapsed,
      recordedAt: _parseDate(json['recordedAt'], 'Lap.recordedAt'),
    );
  }
}

DateTime _parseDate(Object? raw, String field) {
  if (raw is! String) {
    throw FormatException('$field: missing or not a string');
  }
  final dt = DateTime.tryParse(raw);
  if (dt == null) {
    throw FormatException('$field: invalid ISO-8601 "$raw"');
  }
  return dt;
}

class BoardItem {
  final String id;
  String content;
  String? description; // expanded content for thoughts
  String? backContent; // for flashcards
  bool done; // for todo
  int colorIndex;
  double sizeMultiplier; // 0.1 to 5.0, default 1.0
  int? durationSeconds; // for countdown items
  final DateTime createdAt;

  BoardItem({
    String? id,
    required this.content,
    this.description,
    this.backContent,
    this.done = false,
    this.colorIndex = 0,
    this.sizeMultiplier = 1.0,
    this.durationSeconds,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'description': description,
        'backContent': backContent,
        'done': done,
        'colorIndex': colorIndex,
        'sizeMultiplier': sizeMultiplier,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BoardItem.fromJson(Map<String, dynamic> json) {
    final content = json['content'];
    if (content is! String) {
      throw const FormatException('BoardItem: content missing or not a string');
    }
    final rawSize = json['sizeMultiplier'];
    final size = (rawSize is num) ? rawSize.toDouble().clamp(0.1, 5.0) : 1.0;
    final rawDur = json['durationSeconds'];
    final duration = (rawDur is int && rawDur > 0) ? rawDur : null;
    return BoardItem(
      id: json['id'] is String ? json['id'] as String : null,
      content: content,
      description:
          json['description'] is String ? json['description'] as String : null,
      backContent:
          json['backContent'] is String ? json['backContent'] as String : null,
      done: json['done'] is bool ? json['done'] as bool : false,
      colorIndex: json['colorIndex'] is int ? json['colorIndex'] as int : 0,
      sizeMultiplier: size,
      durationSeconds: duration,
      createdAt: _parseDate(json['createdAt'], 'BoardItem.createdAt'),
    );
  }

  BoardItem cloneWithNewId() =>
      BoardItem.fromJson({...toJson(), 'id': _uuid.v4()});
}
