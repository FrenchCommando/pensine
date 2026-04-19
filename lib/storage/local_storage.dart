import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board.dart';
import '../models/workspace.dart';

import 'file_storage.dart' if (dart.library.html) 'file_storage_stub.dart';

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
     defaultTargetPlatform == TargetPlatform.macOS ||
     defaultTargetPlatform == TargetPlatform.linux);

class PrefKeys {
  static const boardIds = 'pensine_board_ids';
  static const workspaceIds = 'pensine_workspace_ids';
  static const collapsedWorkspaces = 'pensine_collapsed_workspaces';
  static const tableModeBoards = 'pensine_table_mode_boards';
  static const darkMode = 'dark_mode';
  static const legacyBoards = 'pensine_boards';
  static String boardData(String id) => 'pensine_board_$id';
  static String workspaceData(String id) => 'pensine_workspace_$id';
}

void _applyOrder<T>(List<T> items, List<String> order, String Function(T) idOf) {
  items.sort((a, b) {
    final ai = order.indexOf(idOf(a));
    final bi = order.indexOf(idOf(b));
    return (ai == -1 ? order.length : ai)
        .compareTo(bi == -1 ? order.length : bi);
  });
}

class LocalStorage {
  static Future<List<Board>> loadBoards() async {
    try {
      return _isDesktop ? await _loadDesktop() : await _loadPrefs();
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

  static Future<void> saveAllBoards(List<Board> boards) async {
    await Future.wait(boards.map(saveBoard));
    await saveBoardOrder(boards.map((b) => b.id).toList());
  }

  static Future<List<Workspace>> loadWorkspaces() async {
    try {
      return _isDesktop
          ? await _loadWorkspacesDesktop()
          : await _loadWorkspacesPrefs();
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
    await Future.wait(workspaces.map(saveWorkspace));
    await saveWorkspaceOrder(workspaces.map((w) => w.id).toList());
  }

  static Future<void> saveWorkspaceOrder(List<String> ids) async {
    if (_isDesktop) {
      await saveWorkspaceOrderFile(ids);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(PrefKeys.workspaceIds, ids);
    }
  }

  static Future<void> saveBoardOrder(List<String> ids) async {
    if (_isDesktop) {
      await saveBoardOrderFile(ids);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(PrefKeys.boardIds, ids);
    }
  }

  static Future<List<Board>> _loadDesktop() async {
    final legacy = await loadLegacyFile();
    if (legacy != null) {
      final json = jsonDecode(legacy);
      final boards =
          (json['boards'] as List).map((b) => Board.fromJson(b)).toList();
      await Future.wait(boards.map(
          (b) => saveBoardFile(b.id, jsonEncode(b.toJson()))));
      return boards;
    }

    final files = await loadAllBoardFiles();
    final boards = files.map((data) => Board.fromJson(jsonDecode(data))).toList();

    final order = await loadBoardOrderFile();
    if (order != null) _applyOrder(boards, order, (b) => b.id);
    return boards;
  }

  static Future<List<Board>> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final legacy = prefs.getString(PrefKeys.legacyBoards);
    if (legacy != null) {
      final json = jsonDecode(legacy);
      final boards =
          (json['boards'] as List).map((b) => Board.fromJson(b)).toList();
      await Future.wait(boards.map(_saveBoardPref));
      await prefs.remove(PrefKeys.legacyBoards);
      return boards;
    }

    final ids = prefs.getStringList(PrefKeys.boardIds) ?? [];
    final boards = <Board>[];
    for (final id in ids) {
      final data = prefs.getString(PrefKeys.boardData(id));
      if (data != null) boards.add(Board.fromJson(jsonDecode(data)));
    }
    return boards;
  }

  static Future<void> _saveBoardPref(Board board) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(PrefKeys.boardIds) ?? [];
    if (!ids.contains(board.id)) {
      ids.add(board.id);
      await prefs.setStringList(PrefKeys.boardIds, ids);
    }
    await prefs.setString(
        PrefKeys.boardData(board.id), jsonEncode(board.toJson()));
  }

  static Future<void> _deleteBoardPref(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(PrefKeys.boardIds) ?? [];
    ids.remove(id);
    await prefs.setStringList(PrefKeys.boardIds, ids);
    await prefs.remove(PrefKeys.boardData(id));
  }

  static Future<List<Workspace>> _loadWorkspacesDesktop() async {
    final files = await loadAllWorkspaceFiles();
    final workspaces =
        files.map((data) => Workspace.fromJson(jsonDecode(data))).toList();

    final order = await loadWorkspaceOrderFile();
    if (order != null) _applyOrder(workspaces, order, (w) => w.id);
    return workspaces;
  }

  static Future<List<Workspace>> _loadWorkspacesPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(PrefKeys.workspaceIds) ?? [];
    final workspaces = <Workspace>[];
    for (final id in ids) {
      final data = prefs.getString(PrefKeys.workspaceData(id));
      if (data != null) workspaces.add(Workspace.fromJson(jsonDecode(data)));
    }
    return workspaces;
  }

  static Future<void> _saveWorkspacePref(Workspace workspace) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(PrefKeys.workspaceIds) ?? [];
    if (!ids.contains(workspace.id)) {
      ids.add(workspace.id);
      await prefs.setStringList(PrefKeys.workspaceIds, ids);
    }
    await prefs.setString(
        PrefKeys.workspaceData(workspace.id), jsonEncode(workspace.toJson()));
  }

  static Future<void> _deleteWorkspacePref(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(PrefKeys.workspaceIds) ?? [];
    ids.remove(id);
    await prefs.setStringList(PrefKeys.workspaceIds, ids);
    await prefs.remove(PrefKeys.workspaceData(id));
  }
}
