import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/board.dart';
import '../models/workspace.dart';
import '../services/board_io.dart';
import '../storage/local_storage.dart';
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
  List<Workspace> _workspaces = [];
  List<Board> _boards = [];
  Map<String, List<Board>> _byWorkspace = {};
  Set<String> _collapsed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _rebuildIndex() {
    _byWorkspace = {};
    for (final b in _boards) {
      (_byWorkspace[b.workspaceId] ??= []).add(b);
    }
  }

  Future<void> _load() async {
    final results = await Future.wait([
      LocalStorage.loadWorkspaces(),
      LocalStorage.loadBoards(),
    ]);
    var workspaces = results[0].cast<Workspace>();
    var boards = results[1].cast<Board>();

    // Migration: if no workspaces exist, create defaults or migrate existing boards
    if (workspaces.isEmpty) {
      if (boards.isEmpty) {
        final defaults = _defaults();
        workspaces = defaults.workspaces;
        boards = defaults.boards;
      } else {
        // Existing boards from before workspaces — put them in "General"
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

    setState(() {
      _workspaces = workspaces;
      _boards = boards;
      _collapsed = collapsedList.toSet();
      _loading = false;
      _rebuildIndex();
    });
  }

  ({List<Workspace> workspaces, List<Board> boards}) _defaults() {
    final welcome = Workspace(name: 'Welcome', colorIndex: 4);
    final cooking = Workspace(name: 'Cooking Recipes', colorIndex: 0);
    final workout = Workspace(name: 'Workout Routines', colorIndex: 3);
    final french = Workspace(name: 'French Vocab', colorIndex: 5);
    final pilot = Workspace(name: 'Pilot Checklists', colorIndex: 7);

    final workspaces = [welcome, cooking, workout, french, pilot];
    final boards = <Board>[
      // --- Welcome ---
      Board(name: 'Getting Started', type: BoardType.thoughts, workspaceId: welcome.id, items: [
        BoardItem(content: 'Welcome', description: 'A place for your thoughts, tasks, and memories. Tap a marble to peek inside.', colorIndex: 0, sizeMultiplier: 1.5),
        BoardItem(content: 'Fling me!', description: 'Drag marbles around and let them go — they bounce off the walls.', colorIndex: 1),
        BoardItem(content: 'Long-press', description: 'Hold down on any marble to edit or delete it.', colorIndex: 2, sizeMultiplier: 0.8),
        BoardItem(content: 'Workspaces', description: 'Boards are grouped into workspaces. Collapse a workspace by tapping its header. Use the folder icon to create new ones.', colorIndex: 3, sizeMultiplier: 0.6),
        BoardItem(content: 'Penser', description: 'French for "to think". That\'s what this app is for.', colorIndex: 4, sizeMultiplier: 1.2),
      ]),
      Board(name: 'Weekend', type: BoardType.todo, workspaceId: welcome.id, items: [
        BoardItem(content: 'Water the plants', colorIndex: 5),
        BoardItem(content: 'Call grandma', colorIndex: 6),
        BoardItem(content: 'Finish that book', colorIndex: 7),
        BoardItem(content: 'Try a new recipe', colorIndex: 0),
      ]),

      // --- Cooking Recipes ---
      Board(name: 'Pancakes', type: BoardType.checklist, workspaceId: cooking.id, items: [
        BoardItem(content: 'Mix dry ingredients', description: '1 cup flour, 2 tbsp sugar, pinch of salt.', colorIndex: 0),
        BoardItem(content: 'Add wet ingredients', description: '1 egg, 3/4 cup milk, 2 tbsp melted butter.', colorIndex: 1),
        BoardItem(content: 'Whisk until smooth', description: 'A few lumps are fine — don\'t overmix!', colorIndex: 2),
        BoardItem(content: 'Heat the pan', description: 'Medium heat, small knob of butter. Wait until it sizzles.', colorIndex: 3),
        BoardItem(content: 'Cook pancakes', description: 'Pour 1/4 cup batter. Flip when bubbles pop on the surface.', colorIndex: 4),
        BoardItem(content: 'Serve', description: 'Stack them up. Maple syrup, berries, whatever you like.', colorIndex: 5),
      ]),
      Board(name: 'Pasta Aglio e Olio', type: BoardType.checklist, workspaceId: cooking.id, items: [
        BoardItem(content: 'Boil pasta', description: 'Salt the water generously. Cook spaghetti until al dente.', colorIndex: 1),
        BoardItem(content: 'Slice garlic', description: '6 cloves, thinly sliced. The thinner, the crispier.', colorIndex: 2),
        BoardItem(content: 'Toast garlic in oil', description: 'Low heat, olive oil, until just golden. Don\'t burn it!', colorIndex: 3),
        BoardItem(content: 'Add chili flakes', description: 'A good pinch of red pepper flakes. Off the heat to avoid burning.', colorIndex: 0),
        BoardItem(content: 'Toss with pasta', description: 'Add pasta + a splash of pasta water. Toss until glossy.', colorIndex: 4),
        BoardItem(content: 'Finish', description: 'Fresh parsley, more olive oil, and parmesan if you like.', colorIndex: 5),
      ]),
      Board(name: 'Grocery List', type: BoardType.todo, workspaceId: cooking.id, items: [
        BoardItem(content: 'Eggs', colorIndex: 1),
        BoardItem(content: 'Flour', colorIndex: 2),
        BoardItem(content: 'Olive oil', colorIndex: 3),
        BoardItem(content: 'Garlic', colorIndex: 0),
        BoardItem(content: 'Parsley', colorIndex: 4),
      ]),

      // --- Workout Routines ---
      Board(name: 'Morning Stretch', type: BoardType.checklist, workspaceId: workout.id, items: [
        BoardItem(content: 'Neck rolls', description: '30 seconds each direction. Slow and gentle.', colorIndex: 3),
        BoardItem(content: 'Shoulder shrugs', description: '10 reps. Squeeze at the top.', colorIndex: 4),
        BoardItem(content: 'Cat-cow stretch', description: '8 reps. Sync with your breath.', colorIndex: 5),
        BoardItem(content: 'Forward fold', description: 'Hold for 30 seconds. Let gravity do the work.', colorIndex: 6),
        BoardItem(content: 'Hip circles', description: '10 each direction. Loosen up those hips.', colorIndex: 7),
      ]),
      Board(name: 'Push Day', type: BoardType.todo, workspaceId: workout.id, items: [
        BoardItem(content: 'Bench press 4x8', colorIndex: 0),
        BoardItem(content: 'Overhead press 3x10', colorIndex: 1),
        BoardItem(content: 'Incline dumbbell press 3x12', colorIndex: 2),
        BoardItem(content: 'Lateral raises 3x15', colorIndex: 3),
        BoardItem(content: 'Tricep dips 3x12', colorIndex: 4),
      ]),
      Board(name: 'Running Log', type: BoardType.thoughts, workspaceId: workout.id, items: [
        BoardItem(content: 'Mon 5K', description: '27:12 — felt good, new route through the park.', colorIndex: 3),
        BoardItem(content: 'Wed 3K', description: '16:45 — easy recovery run. Legs still sore from push day.', colorIndex: 4),
        BoardItem(content: 'Sat 8K', description: '42:30 — long run PB! Negative split in the last 2K.', colorIndex: 5),
      ]),

      // --- French Vocab ---
      Board(name: 'Essentials', type: BoardType.flashcards, workspaceId: french.id, items: [
        BoardItem(content: 'Penser', backContent: 'To think', colorIndex: 0),
        BoardItem(content: 'Souvenir', backContent: 'Memory', colorIndex: 1),
        BoardItem(content: 'Oublier', backContent: 'To forget', colorIndex: 2),
        BoardItem(content: 'Comprendre', backContent: 'To understand', colorIndex: 3),
        BoardItem(content: 'Savoir', backContent: 'To know (a fact)', colorIndex: 4),
        BoardItem(content: 'Pouvoir', backContent: 'To be able to / can', colorIndex: 5),
      ]),
      Board(name: 'Nature', type: BoardType.flashcards, workspaceId: french.id, items: [
        BoardItem(content: 'Nuage', backContent: 'Cloud', colorIndex: 7),
        BoardItem(content: 'Lune', backContent: 'Moon', colorIndex: 5),
        BoardItem(content: 'Fleuve', backContent: 'River (large)', colorIndex: 4),
        BoardItem(content: 'Feuille', backContent: 'Leaf', colorIndex: 3),
      ]),
      Board(name: 'Faux Amis', type: BoardType.flashcards, workspaceId: french.id, items: [
        BoardItem(content: 'Actuellement', backContent: 'Currently (NOT actually)', colorIndex: 0),
        BoardItem(content: 'Bras', backContent: 'Arm (NOT bra)', colorIndex: 1),
        BoardItem(content: 'Chair', backContent: 'Flesh (NOT chair)', colorIndex: 2),
        BoardItem(content: 'Monnaie', backContent: 'Change/coins (NOT money)', colorIndex: 6),
        BoardItem(content: 'Raisin', backContent: 'Grape (NOT raisin)', colorIndex: 7),
      ]),

      // --- Pilot Checklists ---
      Board(name: 'Pre-Flight', type: BoardType.checklist, workspaceId: pilot.id, items: [
        BoardItem(content: 'Weather briefing', description: 'Check METAR, TAF, NOTAMs for departure, en-route, and destination.', colorIndex: 7),
        BoardItem(content: 'Weight & balance', description: 'Calculate total weight, CG position. Verify within limits.', colorIndex: 4),
        BoardItem(content: 'Fuel check', description: 'Visual inspection of fuel level. Confirm sufficient for flight + reserves.', colorIndex: 3),
        BoardItem(content: 'Walk-around', description: 'Inspect control surfaces, tires, pitot tube, oil level, antennas.', colorIndex: 0),
        BoardItem(content: 'Instruments check', description: 'Altimeter set, heading indicator aligned, radios tuned.', colorIndex: 1),
      ]),
      Board(name: 'Before Takeoff', type: BoardType.checklist, workspaceId: pilot.id, items: [
        BoardItem(content: 'Seats & belts', description: 'Seats locked, belts fastened, shoulder harness secured.', colorIndex: 7),
        BoardItem(content: 'Flight controls', description: 'Free and correct. Full deflection all axes.', colorIndex: 0),
        BoardItem(content: 'Fuel selector', description: 'Set to BOTH (or fullest tank as appropriate).', colorIndex: 3),
        BoardItem(content: 'Trim', description: 'Set for takeoff.', colorIndex: 4),
        BoardItem(content: 'Transponder', description: 'Set to ALT. Squawk assigned code.', colorIndex: 1),
        BoardItem(content: 'Lights', description: 'Landing light ON, strobes ON, nav lights ON.', colorIndex: 5),
      ]),
      Board(name: 'Emergency: Engine Failure', type: BoardType.checklist, workspaceId: pilot.id, items: [
        BoardItem(content: 'Airspeed', description: 'Best glide speed immediately. Pitch for Vg.', colorIndex: 0),
        BoardItem(content: 'Best field', description: 'Pick a landing spot. Fly toward it. Commit early.', colorIndex: 1),
        BoardItem(content: 'Restart attempt', description: 'Fuel selector BOTH, mixture RICH, carb heat ON, mags BOTH, primer IN & LOCKED.', colorIndex: 2),
        BoardItem(content: 'Mayday call', description: '121.5 MHz — "Mayday, Mayday, Mayday" + callsign, position, intentions.', colorIndex: 0),
        BoardItem(content: 'Secure engine', description: 'If no restart: mixture CUTOFF, fuel selector OFF, mags OFF, master OFF (flaps last).', colorIndex: 7),
      ]),
      Board(name: 'Flight Log', type: BoardType.timer, workspaceId: pilot.id, items: [
        BoardItem(content: 'Taxi', description: 'Ground movement to runway holding point.', colorIndex: 4),
        BoardItem(content: 'Takeoff & Climb', description: 'Departure and climb to cruise altitude.', colorIndex: 0),
        BoardItem(content: 'Cruise', description: 'En-route level flight.', colorIndex: 1),
        BoardItem(content: 'Descent & Approach', description: 'Arrival procedures and approach.', colorIndex: 3),
        BoardItem(content: 'Landing & Taxi', description: 'Touchdown to parking and shutdown.', colorIndex: 7),
      ]),

      // --- Workout countdown ---
      Board(name: 'Tabata', type: BoardType.countdown, workspaceId: workout.id, items: [
        BoardItem(content: 'Jumping Jacks', durationSeconds: 20, colorIndex: 0),
        BoardItem(content: 'Rest', durationSeconds: 10, colorIndex: 7),
        BoardItem(content: 'Squats', durationSeconds: 20, colorIndex: 1),
        BoardItem(content: 'Rest', durationSeconds: 10, colorIndex: 7),
        BoardItem(content: 'Push-ups', durationSeconds: 20, colorIndex: 3),
        BoardItem(content: 'Rest', durationSeconds: 10, colorIndex: 7),
        BoardItem(content: 'Burpees', durationSeconds: 20, colorIndex: 5),
        BoardItem(content: 'Rest', durationSeconds: 10, colorIndex: 7),
      ]),
    ];

    return (workspaces: workspaces, boards: boards);
  }

  Future<void> _saveCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(PrefKeys.collapsedWorkspaces, _collapsed.toList());
  }

  List<Board> _boardsForWorkspace(String workspaceId) =>
      _byWorkspace[workspaceId] ?? const [];

  List<String> _boardIds() => _boards.map((b) => b.id).toList();

  List<String> _workspaceIds() => _workspaces.map((w) => w.id).toList();

  Future<void> _saveBoard(Board board) => LocalStorage.saveBoard(board);

  Future<void> _addBoard(Board board) async {
    setState(() {
      _boards.add(board);
      _rebuildIndex();
    });
    await LocalStorage.saveBoard(board);
    await LocalStorage.saveBoardOrder(_boardIds());
  }

  Future<void> _deleteBoard(String id) async {
    await LocalStorage.deleteBoard(id);
    await LocalStorage.saveBoardOrder(_boardIds());
  }

  Future<String?> _promptName({
    required String title,
    String initial = '',
    String hint = 'Name',
    String submitLabel = 'OK',
  }) async {
    final controller = TextEditingController(text: initial);
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) {
        void submit() {
          final name = controller.text.trim();
          if (name.isEmpty) return;
          result = name;
          Navigator.pop(ctx);
        }
        return AlertDialog(
          backgroundColor: PensineColors.surface(context),
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: submit, child: Text(submitLabel)),
          ],
        );
      },
    );
    return result;
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
        content: PensineColorPicker(
          selected: current,
          allowDefault: true,
          size: 36,
          onChanged: (i) {
            onPicked(i);
            Navigator.pop(ctx);
          },
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
    final ws = Workspace(name: name);
    setState(() => _workspaces.add(ws));
    await LocalStorage.saveWorkspace(ws);
    await LocalStorage.saveWorkspaceOrder(_workspaceIds());
  }

  Future<void> _renameWorkspace(Workspace ws) async {
    final name = await _promptName(
      title: 'Rename Workspace',
      initial: ws.name,
      hint: 'Workspace name',
      submitLabel: 'Rename',
    );
    if (name == null) return;
    setState(() => ws.name = name);
    await LocalStorage.saveWorkspace(ws);
  }

  Future<void> _changeWorkspaceColor(Workspace ws) {
    return _pickColor(
      title: 'Workspace Color',
      current: ws.colorIndex,
      onPicked: (i) {
        setState(() => ws.colorIndex = i);
        LocalStorage.saveWorkspace(ws);
      },
    );
  }

  void _confirmDeleteWorkspace(Workspace ws) async {
    final wsBoards = _boardsForWorkspace(ws.id);
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

    final toDelete = List<Board>.from(wsBoards);
    setState(() {
      _boards.removeWhere((b) => b.workspaceId == ws.id);
      _workspaces.remove(ws);
      _rebuildIndex();
    });
    await Future.wait([
      LocalStorage.deleteWorkspace(ws.id),
      ...toDelete.map((b) => LocalStorage.deleteBoard(b.id)),
    ]);
    await Future.wait([
      LocalStorage.saveWorkspaceOrder(_workspaceIds()),
      LocalStorage.saveBoardOrder(_boardIds()),
    ]);
  }

  void _exportWorkspace(Workspace ws) {
    final wsBoards = _boardsForWorkspace(ws.id);
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
    final nameController = TextEditingController();
    var selectedType = BoardType.thoughts;
    var selectedWorkspaceId = workspaceId ?? _workspaces.first.id;

    void submit(BuildContext ctx) {
      final name = nameController.text.trim();
      if (name.isEmpty) return;
      _addBoard(Board(name: name, type: selectedType, workspaceId: selectedWorkspaceId));
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: PensineColors.surface(context),
          title: const Text('New Board'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Board name'),
                  onSubmitted: (_) => submit(ctx),
                ),
                if (_workspaces.length > 1) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedWorkspaceId,
                    decoration: const InputDecoration(labelText: 'Workspace'),
                    items: _workspaces.map((ws) {
                      return DropdownMenuItem(value: ws.id, child: Text(ws.name));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedWorkspaceId = v);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                _boardTypeList(selectedType, (t) => setDialogState(() => selectedType = t)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => submit(ctx),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _duplicateBoard(Board board) {
    final copy = board.copyWithNewIds();
    copy.name = '${board.name} (copy)';
    _addBoard(copy);
  }

  void _changeBoardType(Board board) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Change Type'),
        content: _boardTypeList(board.type, (type) {
          setState(() => board.type = type);
          _saveBoard(board);
          Navigator.pop(ctx);
        }),
      ),
    );
  }

  Future<void> _changeBoardColor(Board board) {
    return _pickColor(
      title: 'Board Color',
      current: board.colorIndex,
      onPicked: (i) {
        setState(() => board.colorIndex = i);
        _saveBoard(board);
      },
    );
  }

  void _moveBoardToWorkspace(Board board) {
    if (_workspaces.length < 2) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Move to Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _workspaces.map((ws) {
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
                setState(() => board.workspaceId = ws.id);
                _saveBoard(board);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
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
    setState(() {
      _boards.remove(board);
      _rebuildIndex();
    });
    _deleteBoard(board.id);
  }

  Future<void> _renameBoard(Board board) async {
    final name = await _promptName(
      title: 'Rename Board',
      initial: board.name,
      hint: 'Board name',
      submitLabel: 'Rename',
    );
    if (name == null) return;
    setState(() => board.name = name);
    await _saveBoard(board);
  }

  void _showAbout() {
    final totalItems = _boards.fold<int>(0, (sum, b) => sum + b.items.length);
    showPensineAbout(
      context,
      workspaceCount: _workspaces.length,
      boardCount: _boards.length,
      itemCount: totalItems,
      onReset: () async {
        await Future.wait([
          ..._boards.map((b) => LocalStorage.deleteBoard(b.id)),
          ..._workspaces.map((w) => LocalStorage.deleteWorkspace(w.id)),
        ]);
        final defaults = _defaults();
        await Future.wait([
          LocalStorage.saveAllWorkspaces(defaults.workspaces),
          LocalStorage.saveAllBoards(defaults.boards),
        ]);
        setState(() {
          _workspaces = defaults.workspaces;
          _boards = defaults.boards;
          _collapsed = {};
          _rebuildIndex();
        });
        _saveCollapsed();
      },
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

  Widget _buildBoardTile(Board board) {
    return Card(
      color: PensineColors.card(context),
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 0),
      child: ListTile(
        leading: Icon(board.type.icon, color: PensineColors.boardAccent(board.colorIndex)),
        title: Text(board.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          pluralize(board.items.length, 'item'),
          style: TextStyle(color: PensineColors.muted(context)),
        ),
        trailing: PopupMenuButton<_BoardAction>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => _handleBoardAction(action, board),
          itemBuilder: (_) => [
            const PopupMenuItem(value: _BoardAction.rename, child: Text('Rename')),
            const PopupMenuItem(value: _BoardAction.changeType, child: Text('Change type')),
            const PopupMenuItem(value: _BoardAction.changeColor, child: Text('Board color')),
            if (_workspaces.length > 1)
              const PopupMenuItem(value: _BoardAction.move, child: Text('Move to workspace')),
            const PopupMenuItem(value: _BoardAction.duplicate, child: Text('Duplicate')),
            const PopupMenuItem(value: _BoardAction.export, child: Text('Export')),
            const PopupMenuItem(value: _BoardAction.delete, child: Text('Delete')),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BoardScreen(
                board: board,
                onChanged: () => _saveBoard(board),
              ),
            ),
          );
          setState(() {});
        },
      ),
    );
  }

  Widget _buildWorkspaceSection(Workspace ws) {
    final wsBoards = _boardsForWorkspace(ws.id);
    final isCollapsed = _collapsed.contains(ws.id);

    return Column(
      key: Key('ws_${ws.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isCollapsed) {
                _collapsed.remove(ws.id);
              } else {
                _collapsed.add(ws.id);
              }
            });
            _saveCollapsed();
          },
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
        if (!isCollapsed)
          ...wsBoards.map(_buildBoardTile),
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
    return Scaffold(
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
              final result = await BoardIO.importFile(context, _workspaces);
              if (result == null) return;
              setState(() {
                if (result.workspace != null) {
                  _workspaces.add(result.workspace!);
                }
                _boards.addAll(result.boards);
                _rebuildIndex();
              });
              await Future.wait([
                if (result.workspace != null) ...[
                  LocalStorage.saveWorkspace(result.workspace!),
                  LocalStorage.saveWorkspaceOrder(_workspaceIds()),
                ],
                ...result.boards.map(LocalStorage.saveBoard),
                LocalStorage.saveBoardOrder(_boardIds()),
              ]);
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _workspaces.isEmpty
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
                  children: _workspaces.map(_buildWorkspaceSection).toList(),
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
    );
  }
}
