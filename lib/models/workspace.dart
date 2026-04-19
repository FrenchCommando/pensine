import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Workspace {
  final String id;
  String name;
  int colorIndex;
  final DateTime createdAt;

  Workspace({
    String? id,
    required this.name,
    this.colorIndex = -1,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Workspace.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String) {
      throw const FormatException('Workspace: name missing or not a string');
    }
    final createdAtStr = json['createdAt'];
    if (createdAtStr is! String) {
      throw const FormatException('Workspace: createdAt missing');
    }
    final createdAt = DateTime.tryParse(createdAtStr);
    if (createdAt == null) {
      throw FormatException('Workspace: invalid createdAt "$createdAtStr"');
    }
    return Workspace(
      id: json['id'] is String ? json['id'] as String : null,
      name: name,
      colorIndex: json['colorIndex'] is int ? json['colorIndex'] as int : -1,
      createdAt: createdAt,
    );
  }

  Workspace copyWithNewId() => Workspace(
        name: name,
        colorIndex: colorIndex,
      );
}
