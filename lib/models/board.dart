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

  Board({
    String? id,
    required this.name,
    required this.type,
    this.colorIndex = -1,
    this.workspaceId = '',
    DateTime? createdAt,
    List<BoardItem>? items,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'colorIndex': colorIndex,
        'workspaceId': workspaceId,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory Board.fromJson(Map<String, dynamic> json) => Board(
        id: json['id'],
        name: json['name'],
        type: BoardType.values.byName(json['type']),
        colorIndex: json['colorIndex'] ?? -1,
        workspaceId: json['workspaceId'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
        items: (json['items'] as List).map((i) => BoardItem.fromJson(i)).toList(),
      );

  /// Creates a copy with fresh IDs (for import).
  Board copyWithNewIds() => Board(
        name: name,
        type: type,
        colorIndex: colorIndex,
        workspaceId: workspaceId,
        items: items.map((i) => i.cloneWithNewId()).toList(),
      );
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

  factory BoardItem.fromJson(Map<String, dynamic> json) => BoardItem(
        id: json['id'],
        content: json['content'],
        description: json['description'],
        backContent: json['backContent'],
        done: json['done'] ?? false,
        colorIndex: json['colorIndex'] ?? 0,
        sizeMultiplier: (json['sizeMultiplier'] ?? 1.0).toDouble(),
        durationSeconds: json['durationSeconds'],
        createdAt: DateTime.parse(json['createdAt']),
      );

  BoardItem cloneWithNewId() =>
      BoardItem.fromJson({...toJson(), 'id': _uuid.v4()});
}
