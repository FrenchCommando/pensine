import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/board.dart';
import '../models/workspace.dart';
import '../services/board_io.dart';
import '../storage/local_storage.dart';
import '../theme.dart';
import '../widgets/about_dialog.dart';
import 'board_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Workspace> _workspaces = [];
  List<Board> _boards = [];
  Set<String> _collapsed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var workspaces = await LocalStorage.loadWorkspaces();
    var boards = await LocalStorage.loadBoards();

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

    // Load collapsed state
    final prefs = await SharedPreferences.getInstance();
    final collapsedList = prefs.getStringList('pensine_collapsed_workspaces') ?? [];

    setState(() {
      _workspaces = workspaces;
      _boards = boards;
      _collapsed = collapsedList.toSet();
      _loading = false;
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
    ];

    return (workspaces: workspaces, boards: boards);
  }

  Future<void> _saveCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pensine_collapsed_workspaces', _collapsed.toList());
  }

  List<Board> _boardsForWorkspace(String workspaceId) {
    return _boards.where((b) => b.workspaceId == workspaceId).toList();
  }

  Future<void> _saveBoard(Board board) async {
    await LocalStorage.saveBoard(board);
  }

  Future<void> _deleteBoard(String id) async {
    await LocalStorage.deleteBoard(id);
    await LocalStorage.saveBoardOrder(_boards.map((b) => b.id).toList());
  }

  // --- Workspace operations ---

  void _createWorkspace() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('New Workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workspace name'),
          onSubmitted: (_) => _submitNewWorkspace(ctx, controller),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitNewWorkspace(ctx, controller),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _submitNewWorkspace(BuildContext ctx, TextEditingController controller) {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final ws = Workspace(name: name);
    setState(() => _workspaces.add(ws));
    LocalStorage.saveWorkspace(ws);
    LocalStorage.saveWorkspaceOrder(_workspaces.map((w) => w.id).toList());
    Navigator.pop(ctx);
  }

  void _renameWorkspace(Workspace ws) {
    final controller = TextEditingController(text: ws.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Rename Workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workspace name'),
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            setState(() => ws.name = name);
            LocalStorage.saveWorkspace(ws);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              setState(() => ws.name = name);
              LocalStorage.saveWorkspace(ws);
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _changeWorkspaceColor(Workspace ws) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Workspace Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => ws.colorIndex = -1);
                LocalStorage.saveWorkspace(ws);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PensineColors.accent,
                  border: ws.colorIndex == -1
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
              ),
            ),
            ...List.generate(PensineColors.bubbles.length, (i) {
              return GestureDetector(
                onTap: () {
                  setState(() => ws.colorIndex = i);
                  LocalStorage.saveWorkspace(ws);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PensineColors.bubbles[i],
                    border: ws.colorIndex == i
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteWorkspace(Workspace ws) async {
    final wsBoards = _boardsForWorkspace(ws.id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete workspace?'),
        content: Text(
          'Delete "${ws.name}" and its ${wsBoards.length} board${wsBoards.length == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        for (final board in wsBoards) {
          _boards.remove(board);
          LocalStorage.deleteBoard(board.id);
        }
        _workspaces.remove(ws);
      });
      await LocalStorage.deleteWorkspace(ws.id);
      await LocalStorage.saveWorkspaceOrder(_workspaces.map((w) => w.id).toList());
      await LocalStorage.saveBoardOrder(_boards.map((b) => b.id).toList());
    }
  }

  void _exportWorkspace(Workspace ws) {
    final wsBoards = _boardsForWorkspace(ws.id);
    BoardIO.exportWorkspace(ws, wsBoards, context);
  }

  // --- Board operations ---

  void _createBoard({String? workspaceId}) {
    final nameController = TextEditingController();
    var selectedType = BoardType.thoughts;
    var selectedWorkspaceId = workspaceId ?? _workspaces.first.id;

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
                  onSubmitted: (_) {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final newBoard = Board(name: name, type: selectedType, workspaceId: selectedWorkspaceId);
                    setState(() => _boards.add(newBoard));
                    _saveBoard(newBoard);
                    LocalStorage.saveBoardOrder(_boards.map((b) => b.id).toList());
                    Navigator.pop(ctx);
                  },
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
                Column(
                  children: BoardType.values.map((type) {
                    final isSelected = type == selectedType;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _iconForType(type),
                        color: isSelected ? PensineColors.accent : null,
                      ),
                      title: Text(
                        type.name[0].toUpperCase() + type.name.substring(1),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? PensineColors.accent : null,
                        ),
                      ),
                      selected: isSelected,
                      onTap: () => setDialogState(() => selectedType = type),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final newBoard = Board(name: name, type: selectedType, workspaceId: selectedWorkspaceId);
                setState(() => _boards.add(newBoard));
                _saveBoard(newBoard);
                LocalStorage.saveBoardOrder(_boards.map((b) => b.id).toList());
                Navigator.pop(ctx);
              },
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
    setState(() => _boards.add(copy));
    _saveBoard(copy);
    LocalStorage.saveBoardOrder(_boards.map((b) => b.id).toList());
  }

  void _changeBoardType(Board board) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Change Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BoardType.values.map((type) {
            final isSelected = type == board.type;
            return ListTile(
              dense: true,
              leading: Icon(
                _iconForType(type),
                color: isSelected ? PensineColors.accent : null,
              ),
              title: Text(
                type.name[0].toUpperCase() + type.name.substring(1),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? PensineColors.accent : null,
                ),
              ),
              selected: isSelected,
              onTap: () {
                setState(() => board.type = type);
                _saveBoard(board);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _changeBoardColor(Board board) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Board Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => board.colorIndex = -1);
                _saveBoard(board);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PensineColors.accent,
                  border: board.colorIndex == -1
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
              ),
            ),
            ...List.generate(PensineColors.bubbles.length, (i) {
              return GestureDetector(
                onTap: () {
                  setState(() => board.colorIndex = i);
                  _saveBoard(board);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PensineColors.bubbles[i],
                    border: board.colorIndex == i
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
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
    if (confirm == true) {
      setState(() => _boards.remove(board));
      _deleteBoard(board.id);
    }
  }

  void _renameBoard(Board board) {
    final controller = TextEditingController(text: board.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: const Text('Rename Board'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Board name'),
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            setState(() => board.name = name);
            _saveBoard(board);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              setState(() => board.name = name);
              _saveBoard(board);
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    final totalItems = _boards.fold<int>(0, (sum, b) => sum + b.items.length);
    showPensineAbout(
      context,
      workspaceCount: _workspaces.length,
      boardCount: _boards.length,
      itemCount: totalItems,
      onReset: () async {
        for (final board in _boards) {
          await LocalStorage.deleteBoard(board.id);
        }
        for (final ws in _workspaces) {
          await LocalStorage.deleteWorkspace(ws.id);
        }
        final defaults = _defaults();
        await LocalStorage.saveAllWorkspaces(defaults.workspaces);
        await LocalStorage.saveAllBoards(defaults.boards);
        setState(() {
          _workspaces = defaults.workspaces;
          _boards = defaults.boards;
          _collapsed = {};
        });
        _saveCollapsed();
      },
    );
  }

  IconData _iconForType(BoardType type) => switch (type) {
        BoardType.thoughts => Icons.cloud,
        BoardType.todo => Icons.check_circle_outline,
        BoardType.flashcards => Icons.style,
        BoardType.checklist => Icons.format_list_numbered,
      };

  Widget _buildBoardTile(Board board) {
    return Card(
      color: PensineColors.card(context),
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 0),
      child: ListTile(
        leading: Icon(_iconForType(board.type), color: PensineColors.boardAccent(board.colorIndex)),
        title: Text(board.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${board.items.length} item${board.items.length == 1 ? '' : 's'}',
          style: TextStyle(color: PensineColors.muted(context)),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'rename') {
              _renameBoard(board);
            } else if (value == 'change_type') {
              _changeBoardType(board);
            } else if (value == 'change_color') {
              _changeBoardColor(board);
            } else if (value == 'move') {
              _moveBoardToWorkspace(board);
            } else if (value == 'duplicate') {
              _duplicateBoard(board);
            } else if (value == 'export') {
              BoardIO.exportBoard(board, context);
            } else if (value == 'delete') {
              _confirmDeleteBoard(board);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'rename', child: Text('Rename')),
            const PopupMenuItem(value: 'change_type', child: Text('Change type')),
            const PopupMenuItem(value: 'change_color', child: Text('Board color')),
            if (_workspaces.length > 1)
              const PopupMenuItem(value: 'move', child: Text('Move to workspace')),
            const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
            const PopupMenuItem(value: 'export', child: Text('Export')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                      '${wsBoards.length} board${wsBoards.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: PensineColors.muted(context)),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'rename') {
                      _renameWorkspace(ws);
                    } else if (value == 'color') {
                      _changeWorkspaceColor(ws);
                    } else if (value == 'add_board') {
                      _createBoard(workspaceId: ws.id);
                    } else if (value == 'export') {
                      _exportWorkspace(ws);
                    } else if (value == 'delete') {
                      _confirmDeleteWorkspace(ws);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'add_board', child: Text('Add board')),
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'color', child: Text('Color')),
                    const PopupMenuItem(value: 'export', child: Text('Export workspace')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
        title: const Text('Pensine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: 'Import',
            onPressed: () async {
              final result = await BoardIO.importFile(context, _workspaces);
              if (result != null) {
                setState(() {
                  if (result.workspace != null) {
                    _workspaces.add(result.workspace!);
                    _boards.addAll(result.boards);
                    LocalStorage.saveWorkspace(result.workspace!);
                    LocalStorage.saveWorkspaceOrder(_workspaces.map((w) => w.id).toList());
                  } else {
                    _boards.addAll(result.boards);
                  }
                  for (final board in result.boards) {
                    LocalStorage.saveBoard(board);
                  }
                  LocalStorage.saveBoardOrder(_boards.map((b) => b.id).toList());
                });
              }
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
                      Icon(Icons.water_drop, size: 64, color: PensineColors.muted(context)),
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
