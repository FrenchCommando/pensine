import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board.dart';
import '../models/workspace.dart';

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
    await saveBoardOrder(boards.map((b) => b.id).toList());
  }

  // --- Workspace CRUD ---

  static Future<List<Workspace>> loadWorkspaces() async {
    try {
      if (_isDesktop) {
        return await _loadWorkspacesDesktop();
      } else {
        return await _loadWorkspacesPrefs();
      }
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveWorkspace(Workspace workspace) async {
    final json = jsonEncode(workspace.toJson());
    if (_isDesktop) {
      await saveWorkspaceFile(workspace.id, json);
    } else {
      await _saveWorkspacePref(workspace);
    }
  }

  static Future<void> deleteWorkspace(String id) async {
    if (_isDesktop) {
      await deleteWorkspaceFile(id);
    } else {
      await _deleteWorkspacePref(id);
    }
  }

  static Future<void> saveAllWorkspaces(List<Workspace> workspaces) async {
    for (final ws in workspaces) {
      await saveWorkspace(ws);
    }
    await saveWorkspaceOrder(workspaces.map((w) => w.id).toList());
  }

  static Future<void> saveWorkspaceOrder(List<String> ids) async {
    if (_isDesktop) {
      await saveWorkspaceOrderFile(ids);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_workspaceListKey, ids);
    }
  }

  /// Persist board ordering.
  static Future<void> saveBoardOrder(List<String> ids) async {
    if (_isDesktop) {
      await saveBoardOrderFile(ids);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_boardListKey, ids);
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
    final boards = files.map((data) {
      final json = jsonDecode(data);
      return Board.fromJson(json);
    }).toList();

    final order = await loadBoardOrderFile();
    if (order != null) {
      boards.sort((a, b) {
        final ai = order.indexOf(a.id);
        final bi = order.indexOf(b.id);
        return (ai == -1 ? order.length : ai).compareTo(bi == -1 ? order.length : bi);
      });
    }
    return boards;
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

  // --- Workspace desktop ---

  static Future<List<Workspace>> _loadWorkspacesDesktop() async {
    final files = await loadAllWorkspaceFiles();
    final workspaces = files.map((data) {
      final json = jsonDecode(data);
      return Workspace.fromJson(json);
    }).toList();

    final order = await loadWorkspaceOrderFile();
    if (order != null) {
      workspaces.sort((a, b) {
        final ai = order.indexOf(a.id);
        final bi = order.indexOf(b.id);
        return (ai == -1 ? order.length : ai).compareTo(bi == -1 ? order.length : bi);
      });
    }
    return workspaces;
  }

  // --- Workspace prefs ---

  static const _workspaceListKey = 'pensine_workspace_ids';

  static Future<List<Workspace>> _loadWorkspacesPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_workspaceListKey) ?? [];
    final workspaces = <Workspace>[];
    for (final id in ids) {
      final data = prefs.getString('pensine_workspace_$id');
      if (data != null) {
        workspaces.add(Workspace.fromJson(jsonDecode(data)));
      }
    }
    return workspaces;
  }

  static Future<void> _saveWorkspacePref(Workspace workspace) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_workspaceListKey) ?? [];
    if (!ids.contains(workspace.id)) {
      ids.add(workspace.id);
      await prefs.setStringList(_workspaceListKey, ids);
    }
    await prefs.setString('pensine_workspace_${workspace.id}', jsonEncode(workspace.toJson()));
  }

  static Future<void> _deleteWorkspacePref(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_workspaceListKey) ?? [];
    ids.remove(id);
    await prefs.setStringList(_workspaceListKey, ids);
    await prefs.remove('pensine_workspace_$id');
  }
}
