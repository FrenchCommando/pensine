import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board.dart';

// Conditional import for file-based storage
import 'file_storage.dart' if (dart.library.html) 'file_storage_stub.dart';

/// Returns true for desktop platforms (Windows, macOS, Linux).
bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
     defaultTargetPlatform == TargetPlatform.macOS ||
     defaultTargetPlatform == TargetPlatform.linux);

class LocalStorage {
  static Future<List<Board>> loadBoards() async {
    try {
      final data = _isDesktop ? await loadFromFile() : await _loadPrefs();
      if (data == null) return [];
      final json = jsonDecode(data);
      return (json['boards'] as List).map((b) => Board.fromJson(b)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBoards(List<Board> boards) async {
    final json = jsonEncode({'boards': boards.map((b) => b.toJson()).toList()});
    if (_isDesktop) {
      await saveToFile(json);
    } else {
      await _savePrefs(json);
    }
  }

  static Future<String?> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pensine_boards');
  }

  static Future<void> _savePrefs(String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pensine_boards', data);
  }
}
