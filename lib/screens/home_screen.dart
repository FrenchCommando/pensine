import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/boards_controller.dart';
import '../main.dart';
import '../models/board.dart';
import '../models/workspace.dart';
import '../services/board_io.dart';
import '../services/pending_import.dart';
import '../theme.dart';
import '../utils/pluralize.dart';
import '../widgets/about_dialog.dart';
import '../widgets/color_picker.dart';
import 'board_screen.dart';

enum _BoardAction { rename, changeType, changeColor, move, duplicate, export, delete }

enum _WorkspaceAction { addBoard, rename, color, export, delete }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = BoardsController();

  // Local UI state only — view-level, not persisted/shared.
  // (Everything else now lives on `_ctrl`.)

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onControllerChanged);
    _ctrl.load().then((_) {
      if (!mounted) return;
      listenForPendingImports(_handlePendingImport);
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handlePendingImport(String content) async {
    if (!mounted) return;
    final result =
        await BoardIO.importContent(content, context, _ctrl.workspaces);
    if (!mounted) return;
    await _ctrl.applyImport(result);
  }

  Future<String?> _promptName({
    required String title,
    String initial = '',
    String hint = 'Name',
    String submitLabel = 'OK',
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _PromptNameDialog(
        title: title,
        initial: initial,
        hint: hint,
        submitLabel: submitLabel,
      ),
    );
  }

  Future<void> _pickColor({
    required String title,
    required int current,
    required ValueChanged<int> onPicked,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: Text(title),
        content: SingleChildScrollView(
          child: PensineColorPicker(
            selected: current,
            allowDefault: true,
            size: 36,
            onChanged: (i) {
              onPicked(i);
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }

  // --- Workspace operations ---

  Future<void> _createWorkspace() async {
    final name = await _promptName(
      title: 'New Workspace',
      hint: 'Workspace name',
      submitLabel: 'Create',
    );
    if (name == null) return;
    await _ctrl.addWorkspace(Workspace(name: name));
  }

  Future<void> _renameWorkspace(Workspace ws) async {
    final name = await _promptName(
      title: 'Rename Workspace',
      initial: ws.name,
      hint: 'Workspace name',
      submitLabel: 'Rename',
    );
    if (name == null) return;
    ws.name = name;
    await _ctrl.saveWorkspace(ws);
  }

  Future<void> _changeWorkspaceColor(Workspace ws) {
    return _pickColor(
      title: 'Workspace Color',
      current: ws.colorIndex,
      onPicked: (i) {
        ws.colorIndex = i;
        _ctrl.saveWorkspace(ws);
      },
    );
  }

  void _confirmDeleteWorkspace(Workspace ws) async {
    final wsBoards = _ctrl.boardsForWorkspace(ws.id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete workspace?'),
        content: Text('Delete "${ws.name}" and its ${pluralize(wsBoards.length, 'board')}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await _ctrl.deleteWorkspace(ws);
  }

  void _exportWorkspace(Workspace ws) {
    final wsBoards = _ctrl.boardsForWorkspace(ws.id);
    BoardIO.exportWorkspace(ws, wsBoards, context);
  }

  // --- Board operations ---

  Widget _boardTypeList(BoardType selected, ValueChanged<BoardType> onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: BoardType.values.map((type) {
        final isSelected = type == selected;
        return ListTile(
          dense: true,
          leading: Icon(type.icon, color: isSelected ? PensineColors.accent : null),
          title: Text(
            type.displayName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? PensineColors.accent : null,
            ),
          ),
          selected: isSelected,
          onTap: () => onTap(type),
        );
      }).toList(),
    );
  }

  void _createBoard({String? workspaceId}) {
    showDialog(
      context: context,
      builder: (ctx) => _NewBoardDialog(
        workspaces: _ctrl.workspaces,
        initialWorkspaceId: workspaceId ?? _ctrl.workspaces.first.id,
        boardTypeList: _boardTypeList,
        onCreate: (name, type, wsId) {
          _ctrl.addBoard(Board(name: name, type: type, workspaceId: wsId));
        },
      ),
    );
  }

  void _duplicateBoard(Board board) {
    _ctrl.duplicateBoard(board);
  }

  void _changeBoardType(Board board) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Change Type'),
        content: SingleChildScrollView(
          child: _boardTypeList(board.type, (type) {
            board.type = type;
            _ctrl.boardChanged(board);
            Navigator.pop(ctx);
          }),
        ),
      ),
    );
  }

  Future<void> _changeBoardColor(Board board) {
    return _pickColor(
      title: 'Board Color',
      current: board.colorIndex,
      onPicked: (i) {
        board.colorIndex = i;
        _ctrl.boardChanged(board);
      },
    );
  }

  void _moveBoardToWorkspace(Board board) {
    if (_ctrl.workspaces.length < 2) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Move to Workspace'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _ctrl.workspaces.map((ws) {
              final isSelected = ws.id == board.workspaceId;
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.folder,
                  color: isSelected ? PensineColors.accent : PensineColors.boardAccent(ws.colorIndex),
                ),
                title: Text(
                  ws.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? PensineColors.accent : null,
                  ),
                ),
                selected: isSelected,
                onTap: () {
                  board.workspaceId = ws.id;
                  _ctrl.boardChanged(board);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteBoard(Board board) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete board?'),
        content: Text('Delete "${board.name}" and all its items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await _ctrl.deleteBoard(board.id);
  }

  Future<void> _renameBoard(Board board) async {
    final name = await _promptName(
      title: 'Rename Board',
      initial: board.name,
      hint: 'Board name',
      submitLabel: 'Rename',
    );
    if (name == null) return;
    board.name = name;
    await _ctrl.boardChanged(board);
  }

  void _showAbout() {
    final totalItems = _ctrl.boards.fold<int>(0, (sum, b) => sum + b.items.length);
    showPensineAbout(
      context,
      workspaceCount: _ctrl.workspaces.length,
      boardCount: _ctrl.boards.length,
      itemCount: totalItems,
      onReset: _ctrl.reset,
    );
  }

  void _handleBoardAction(_BoardAction action, Board board) {
    switch (action) {
      case _BoardAction.rename:
        _renameBoard(board);
      case _BoardAction.changeType:
        _changeBoardType(board);
      case _BoardAction.changeColor:
        _changeBoardColor(board);
      case _BoardAction.move:
        _moveBoardToWorkspace(board);
      case _BoardAction.duplicate:
        _duplicateBoard(board);
      case _BoardAction.export:
        BoardIO.exportBoard(board, context);
      case _BoardAction.delete:
        _confirmDeleteBoard(board);
    }
  }

  Widget _buildBoardTile(Board board, int indexInWorkspace) {
    final muted = PensineColors.muted(context);
    return Card(
      key: ValueKey(board.id),
      color: PensineColors.boardCard(context, board.colorIndex),
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 0),
      child: ListTile(
        leading: Icon(board.type.icon, color: PensineColors.boardAccent(board.colorIndex)),
        title: Text(board.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          pluralize(board.items.length, 'item'),
          style: TextStyle(color: muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Explicit drag handle — tap-and-drag, no long-press. Matches
            // the items_table pattern (`ReorderableDragStartListener`) so
            // `ListTile.onTap` stays free to open the board.
            ReorderableDragStartListener(
              index: indexInWorkspace,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_handle, color: muted, size: 20),
                ),
              ),
            ),
            PopupMenuButton<_BoardAction>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => _handleBoardAction(action, board),
              itemBuilder: (_) => [
                const PopupMenuItem(value: _BoardAction.rename, child: Text('Rename')),
                const PopupMenuItem(value: _BoardAction.changeType, child: Text('Change type')),
                const PopupMenuItem(value: _BoardAction.changeColor, child: Text('Board color')),
                if (_ctrl.workspaces.length > 1)
                  const PopupMenuItem(value: _BoardAction.move, child: Text('Move to workspace')),
                const PopupMenuItem(value: _BoardAction.duplicate, child: Text('Duplicate')),
                const PopupMenuItem(value: _BoardAction.export, child: Text('Export')),
                const PopupMenuItem(value: _BoardAction.delete, child: Text('Delete')),
              ],
            ),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BoardScreen(
                board: board,
                onChanged: () => _ctrl.saveBoard(board),
              ),
            ),
          );
          setState(() {});
        },
      ),
    );
  }

  /// Apply a drag-reorder within one workspace to the global board order
  /// that `BoardsController.reorderBoards` expects. Preserves the positions
  /// of boards in OTHER workspaces; shuffles only this workspace's slots.
  void _reorderBoardsWithinWorkspace(
      String workspaceId, int oldIndex, int newIndex) {
    final wsBoards = _ctrl.boardsForWorkspace(workspaceId);
    final reordered = List<Board>.from(wsBoards);
    // ReorderableListView callback convention: newIndex is post-removal.
    if (newIndex > oldIndex) newIndex--;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    // Walk the global board list; at each slot owned by this workspace,
    // emit the next id from the reordered list instead.
    final globalIds = <String>[];
    var wsIdx = 0;
    for (final b in _ctrl.boards) {
      if (b.workspaceId == workspaceId) {
        globalIds.add(reordered[wsIdx].id);
        wsIdx++;
      } else {
        globalIds.add(b.id);
      }
    }
    _ctrl.reorderBoards(globalIds);
  }

  Widget _buildWorkspaceSection(Workspace ws) {
    final wsBoards = _ctrl.boardsForWorkspace(ws.id);
    final isCollapsed = _ctrl.collapsed.contains(ws.id);

    return Column(
      key: Key('ws_${ws.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _ctrl.toggleCollapsed(ws.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isCollapsed ? Icons.chevron_right : Icons.expand_more,
                  color: PensineColors.boardAccent(ws.colorIndex),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ws.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: PensineColors.boardAccent(ws.colorIndex),
                    ),
                  ),
                ),
                if (isCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      pluralize(wsBoards.length, 'board'),
                      style: TextStyle(fontSize: 12, color: PensineColors.muted(context)),
                    ),
                  ),
                PopupMenuButton<_WorkspaceAction>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) {
                    switch (action) {
                      case _WorkspaceAction.addBoard:
                        _createBoard(workspaceId: ws.id);
                      case _WorkspaceAction.rename:
                        _renameWorkspace(ws);
                      case _WorkspaceAction.color:
                        _changeWorkspaceColor(ws);
                      case _WorkspaceAction.export:
                        _exportWorkspace(ws);
                      case _WorkspaceAction.delete:
                        _confirmDeleteWorkspace(ws);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: _WorkspaceAction.addBoard, child: Text('Add board')),
                    const PopupMenuItem(value: _WorkspaceAction.rename, child: Text('Rename')),
                    const PopupMenuItem(value: _WorkspaceAction.color, child: Text('Color')),
                    const PopupMenuItem(value: _WorkspaceAction.export, child: Text('Export workspace')),
                    const PopupMenuItem(value: _WorkspaceAction.delete, child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isCollapsed && wsBoards.isNotEmpty)
          ReorderableListView.builder(
            // Nested inside the outer ListView of workspace sections, so we
            // must not self-scroll and must size to children.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Our own drag handle (`ReorderableDragStartListener` in each
            // tile) starts the drag — no long-press, no whole-row drag.
            buildDefaultDragHandles: false,
            itemCount: wsBoards.length,
            itemBuilder: (context, i) => _buildBoardTile(wsBoards[i], i),
            onReorder: (oldIndex, newIndex) =>
                _reorderBoardsWithinWorkspace(ws.id, oldIndex, newIndex),
          ),
        if (!isCollapsed && wsBoards.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: Text(
              'No boards yet',
              style: TextStyle(color: PensineColors.muted(context), fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _createBoard(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () => _createBoard(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/app_icon.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text('Pensine'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: 'Import',
            onPressed: () async {
              final result = await BoardIO.importFile(context, _ctrl.workspaces);
              if (!context.mounted) return;
              await _ctrl.applyImport(result);
            },
          ),
          IconButton(
            icon: Icon(
              PensineApp.of(context)?.brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle theme',
            onPressed: () => PensineApp.of(context)?.toggleBrightness(),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: _showAbout,
          ),
        ],
      ),
      body: _ctrl.loading
          ? const Center(child: CircularProgressIndicator())
          : _ctrl.workspaces.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/app_icon.png', width: 64, height: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No workspaces yet.\nTap the folder icon to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PensineColors.muted(context), fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _ctrl.workspaces.map(_buildWorkspaceSection).toList(),
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'new_workspace',
            tooltip: 'New workspace',
            onPressed: _createWorkspace,
            child: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'new_board',
            tooltip: 'New board',
            onPressed: () => _createBoard(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// Stateful dialog: owns its TextEditingController so `dispose()` fires
/// when the route is fully torn down (canonical Flutter pattern). A naive
/// `try { await showDialog } finally { controller.dispose() }` races the
/// exit transition and triggers "used after disposed" on heavy parent
/// widget trees like the full home screen.
class _PromptNameDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String hint;
  final String submitLabel;

  const _PromptNameDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.submitLabel,
  });

  @override
  State<_PromptNameDialog> createState() => _PromptNameDialogState();
}

class _PromptNameDialogState extends State<_PromptNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PensineColors.surface(context),
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

/// Dialog for creating a new board. Same StatefulWidget pattern as
/// `_PromptNameDialog` — see that class for the rationale.
class _NewBoardDialog extends StatefulWidget {
  final List<Workspace> workspaces;
  final String initialWorkspaceId;
  final Widget Function(BoardType, ValueChanged<BoardType>) boardTypeList;
  final void Function(String name, BoardType type, String workspaceId) onCreate;

  const _NewBoardDialog({
    required this.workspaces,
    required this.initialWorkspaceId,
    required this.boardTypeList,
    required this.onCreate,
  });

  @override
  State<_NewBoardDialog> createState() => _NewBoardDialogState();
}

class _NewBoardDialogState extends State<_NewBoardDialog> {
  final _nameController = TextEditingController();
  BoardType _selectedType = BoardType.thoughts;
  late String _selectedWorkspaceId = widget.initialWorkspaceId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onCreate(name, _selectedType, _selectedWorkspaceId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PensineColors.surface(context),
      title: const Text('New Board'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Board name'),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.workspaces.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedWorkspaceId,
                decoration: const InputDecoration(labelText: 'Workspace'),
                items: widget.workspaces.map((ws) {
                  return DropdownMenuItem(value: ws.id, child: Text(ws.name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedWorkspaceId = v);
                },
              ),
            ],
            const SizedBox(height: 16),
            widget.boardTypeList(
              _selectedType,
              (t) => setState(() => _selectedType = t),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
