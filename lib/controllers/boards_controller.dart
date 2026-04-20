import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/defaults.dart';
import '../models/board.dart';
import '../models/workspace.dart';
import '../services/board_io.dart';
import '../storage/local_storage.dart';

/// Owns the boards + workspaces + collapsed-workspace state, plus all the
/// persistence calls. Extracted from `HomeScreen` so the screen is UI only.
///
/// Use it as a `ChangeNotifier`: `AnimatedBuilder(animation: ctrl, ...)` or
/// `listen` → `setState`. Every mutation persists itself via `LocalStorage`
/// and then calls `notifyListeners()`. Do NOT mutate the returned lists
/// directly — they're `unmodifiable` views.
class BoardsController extends ChangeNotifier {
  List<Workspace> _workspaces = [];
  List<Board> _boards = [];
  Map<String, List<Board>> _byWorkspace = {};
  Set<String> _collapsed = {};
  bool _loading = true;

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);
  List<Board> get boards => List.unmodifiable(_boards);
  Set<String> get collapsed => Set.unmodifiable(_collapsed);
  bool get loading => _loading;

  List<Board> boardsForWorkspace(String workspaceId) =>
      _byWorkspace[workspaceId] ?? const [];

  List<String> _boardIds() => _boards.map((b) => b.id).toList();
  List<String> _workspaceIds() => _workspaces.map((w) => w.id).toList();

  void _rebuildIndex() {
    _byWorkspace = {};
    for (final b in _boards) {
      (_byWorkspace[b.workspaceId] ??= []).add(b);
    }
  }

  // --- Load / reset ---

  Future<void> load() async {
    final results = await Future.wait([
      LocalStorage.loadWorkspaces(),
      LocalStorage.loadBoards(),
    ]);
    var workspaces = results[0].cast<Workspace>();
    var boards = results[1].cast<Board>();

    // Migration: no workspaces → populate defaults, or wrap legacy boards
    // in a "General" workspace.
    if (workspaces.isEmpty) {
      if (boards.isEmpty) {
        final defaults = buildDefaults();
        workspaces = defaults.workspaces;
        boards = defaults.boards;
      } else {
        final general = Workspace(name: 'General');
        for (final board in boards) {
          board.workspaceId = general.id;
        }
        workspaces = [general];
      }
      await LocalStorage.saveAllWorkspaces(workspaces);
      await LocalStorage.saveAllBoards(boards);
    }

    final prefs = await SharedPreferences.getInstance();
    final collapsedList = prefs.getStringList(PrefKeys.collapsedWorkspaces) ?? [];

    _workspaces = workspaces;
    _boards = boards;
    _collapsed = collapsedList.toSet();
    _loading = false;
    _rebuildIndex();
    notifyListeners();
  }

  Future<void> reset() async {
    // Delete everything currently stored.
    await Future.wait([
      ..._boards.map((b) => LocalStorage.deleteBoard(b.id)),
      ..._workspaces.map((w) => LocalStorage.deleteWorkspace(w.id)),
    ]);
    final defaults = buildDefaults();
    await Future.wait([
      LocalStorage.saveAllWorkspaces(defaults.workspaces),
      LocalStorage.saveAllBoards(defaults.boards),
    ]);
    _workspaces = defaults.workspaces;
    _boards = defaults.boards;
    _rebuildIndex();
    notifyListeners();
  }

  // --- Board CRUD ---

  Future<void> addBoard(Board board) async {
    _boards.add(board);
    _rebuildIndex();
    notifyListeners();
    await LocalStorage.saveBoard(board);
    await LocalStorage.saveBoardOrder(_boardIds());
  }

  Future<void> saveBoard(Board board) => LocalStorage.saveBoard(board);

  Future<void> deleteBoard(String id) async {
    _boards.removeWhere((b) => b.id == id);
    _rebuildIndex();
    notifyListeners();
    await LocalStorage.deleteBoard(id);
    await LocalStorage.saveBoardOrder(_boardIds());
  }

  Future<void> reorderBoards(List<String> newOrder) async {
    final byId = {for (final b in _boards) b.id: b};
    _boards = [for (final id in newOrder) if (byId[id] != null) byId[id]!];
    _rebuildIndex();
    notifyListeners();
    await LocalStorage.saveBoardOrder(_boardIds());
  }

  /// For in-place renames, color changes, duplicates, etc. Caller mutates
  /// the board and calls this to persist + notify.
  Future<void> boardChanged(Board board) async {
    _rebuildIndex();
    notifyListeners();
    await LocalStorage.saveBoard(board);
  }

  Future<void> duplicateBoard(Board original) async {
    final copy = original.copyWithNewIds()
      ..name = '${original.name} (copy)';
    await addBoard(copy);
  }

  // --- Workspace CRUD ---

  Future<void> addWorkspace(Workspace ws) async {
    _workspaces.add(ws);
    _rebuildIndex();
    notifyListeners();
    await LocalStorage.saveWorkspace(ws);
    await LocalStorage.saveWorkspaceOrder(_workspaceIds());
  }

  Future<void> saveWorkspace(Workspace ws) async {
    notifyListeners();
    await LocalStorage.saveWorkspace(ws);
  }

  Future<void> deleteWorkspace(Workspace ws) async {
    final wsBoards = boardsForWorkspace(ws.id).toList();
    _boards.removeWhere((b) => b.workspaceId == ws.id);
    _workspaces.remove(ws);
    _rebuildIndex();
    notifyListeners();
    await Future.wait([
      LocalStorage.deleteWorkspace(ws.id),
      ...wsBoards.map((b) => LocalStorage.deleteBoard(b.id)),
    ]);
    await Future.wait([
      LocalStorage.saveWorkspaceOrder(_workspaceIds()),
      LocalStorage.saveBoardOrder(_boardIds()),
    ]);
  }

  Future<void> reorderWorkspaces(List<String> newOrder) async {
    final byId = {for (final w in _workspaces) w.id: w};
    _workspaces = [for (final id in newOrder) if (byId[id] != null) byId[id]!];
    notifyListeners();
    await LocalStorage.saveWorkspaceOrder(_workspaceIds());
  }

  // --- Collapsed state ---

  Future<void> toggleCollapsed(String workspaceId) async {
    if (_collapsed.contains(workspaceId)) {
      _collapsed.remove(workspaceId);
    } else {
      _collapsed.add(workspaceId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        PrefKeys.collapsedWorkspaces, _collapsed.toList());
  }

  // --- Import ---

  Future<void> applyImport(ImportResult? result) async {
    if (result == null) return;
    if (result.workspace != null) {
      _workspaces.add(result.workspace!);
    }
    _boards.addAll(result.boards);
    _rebuildIndex();
    notifyListeners();
    await Future.wait([
      if (result.workspace != null) ...[
        LocalStorage.saveWorkspace(result.workspace!),
        LocalStorage.saveWorkspaceOrder(_workspaceIds()),
      ],
      ...result.boards.map(LocalStorage.saveBoard),
      LocalStorage.saveBoardOrder(_boardIds()),
    ]);
  }
}
