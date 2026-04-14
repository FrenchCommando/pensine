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
      if (_isDesktop) {
        return await _loadDesktop();
      } else {
        return await _loadPrefs();
      }
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBoard(Board board) async {
    final json = jsonEncode(board.toJson());
    if (_isDesktop) {
      await saveBoardFile(board.id, json);
    } else {
      await _saveBoardPref(board);
    }
  }

  static Future<void> deleteBoard(String id) async {
    if (_isDesktop) {
      await deleteBoardFile(id);
    } else {
      await _deleteBoardPref(id);
    }
  }

  /// Save all boards (convenience for bulk operations like migration).
  static Future<void> saveAllBoards(List<Board> boards) async {
    for (final board in boards) {
      await saveBoard(board);
    }
  }

  // --- Desktop (file-based, one file per board) ---

  static Future<List<Board>> _loadDesktop() async {
    // Migrate legacy single-file format
    final legacy = await loadLegacyFile();
    if (legacy != null) {
      final json = jsonDecode(legacy);
      final boards = (json['boards'] as List).map((b) => Board.fromJson(b)).toList();
      for (final board in boards) {
        await saveBoardFile(board.id, jsonEncode(board.toJson()));
      }
      return boards;
    }

    final files = await loadAllBoardFiles();
    return files.map((data) {
      final json = jsonDecode(data);
      return Board.fromJson(json);
    }).toList();
  }

  // --- Web/Mobile (shared_preferences, one key per board) ---

  static const _boardListKey = 'pensine_board_ids';

  static Future<List<Board>> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate legacy single-key format
    final legacy = prefs.getString('pensine_boards');
    if (legacy != null) {
      final json = jsonDecode(legacy);
      final boards = (json['boards'] as List).map((b) => Board.fromJson(b)).toList();
      for (final board in boards) {
        await _saveBoardPref(board);
      }
      await prefs.remove('pensine_boards');
      return boards;
    }

    final ids = prefs.getStringList(_boardListKey) ?? [];
    final boards = <Board>[];
    for (final id in ids) {
      final data = prefs.getString('pensine_board_$id');
      if (data != null) {
        boards.add(Board.fromJson(jsonDecode(data)));
      }
    }
    return boards;
  }

  static Future<void> _saveBoardPref(Board board) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_boardListKey) ?? [];
    if (!ids.contains(board.id)) {
      ids.add(board.id);
      await prefs.setStringList(_boardListKey, ids);
    }
    await prefs.setString('pensine_board_${board.id}', jsonEncode(board.toJson()));
  }

  static Future<void> _deleteBoardPref(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_boardListKey) ?? [];
    ids.remove(id);
    await prefs.setStringList(_boardListKey, ids);
    await prefs.remove('pensine_board_$id');
  }
}
