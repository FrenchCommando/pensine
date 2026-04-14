import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board.dart';

// Conditional import for file-based storage
import 'file_storage.dart' if (dart.library.html) 'file_storage_stub.dart';

class LocalStorage {
  static Future<List<Board>> loadBoards() async {
    try {
      final data = kIsWeb ? await _loadWeb() : await loadFromFile();
      if (data == null) return [];
      final json = jsonDecode(data);
      return (json['boards'] as List).map((b) => Board.fromJson(b)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBoards(List<Board> boards) async {
    final json = jsonEncode({'boards': boards.map((b) => b.toJson()).toList()});
    if (kIsWeb) {
      await _saveWeb(json);
    } else {
      await saveToFile(json);
    }
  }

  static Future<String?> _loadWeb() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pensine_boards');
  }

  static Future<void> _saveWeb(String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pensine_boards', data);
  }
}
