import 'package:flutter/material.dart';
import '../main.dart';
import '../models/board.dart';
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
  List<Board> _boards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var boards = await LocalStorage.loadBoards();
    if (boards.isEmpty) {
      boards = _defaultBoards();
      await LocalStorage.saveBoards(boards);
    }
    setState(() {
      _boards = boards;
      _loading = false;
    });
  }

  List<Board> _defaultBoards() {
    return [
      Board(name: 'Welcome', type: BoardType.thoughts, items: [
        BoardItem(content: 'Welcome', description: 'A place for your thoughts, tasks, and memories. Tap a marble to peek inside.', colorIndex: 0, sizeMultiplier: 1.5),
        BoardItem(content: 'Fling me!', description: 'Drag marbles around and let them go — they bounce off the walls.', colorIndex: 1),
        BoardItem(content: 'Long-press', description: 'Hold down on any marble to edit or delete it.', colorIndex: 2, sizeMultiplier: 0.8),
        BoardItem(content: '💡', description: 'Create your own boards from the home screen. Thoughts, to-dos, or flashcards.', colorIndex: 3, sizeMultiplier: 0.6),
        BoardItem(content: 'Penser', description: 'French for "to think". That\'s what this app is for.', colorIndex: 4, sizeMultiplier: 1.2),
      ]),
      Board(name: 'Weekend', type: BoardType.todo, items: [
        BoardItem(content: 'Water the plants', colorIndex: 5),
        BoardItem(content: 'Call grandma', colorIndex: 6),
        BoardItem(content: 'Finish that book', colorIndex: 7),
        BoardItem(content: 'Try a new recipe 🍳', colorIndex: 0),
      ]),
      Board(name: 'Vocab', type: BoardType.flashcards, items: [
        BoardItem(content: 'Penser', backContent: 'To think', colorIndex: 0),
        BoardItem(content: 'Souvenir', backContent: 'Memory', colorIndex: 1),
        BoardItem(content: 'Oublier', backContent: 'To forget', colorIndex: 2),
        BoardItem(content: 'Rêver', backContent: 'To dream', colorIndex: 3),
        BoardItem(content: 'Lumière', backContent: 'Light', colorIndex: 4),
        BoardItem(content: 'Étoile', backContent: 'Star', colorIndex: 5),
        BoardItem(content: 'Cœur', backContent: 'Heart', colorIndex: 6),
        BoardItem(content: 'Nuage', backContent: 'Cloud', colorIndex: 7),
      ]),
    ];
  }

  Future<void> _save() async {
    await LocalStorage.saveBoards(_boards);
  }

  void _createBoard() {
    final nameController = TextEditingController();
    var selectedType = BoardType.thoughts;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: PensineColors.surface(context),
          title: const Text('New Board'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Board name'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<BoardType>(
                segments: const [
                  ButtonSegment(
                    value: BoardType.thoughts,
                    label: Text('Thoughts'),
                    icon: Icon(Icons.cloud),
                  ),
                  ButtonSegment(
                    value: BoardType.todo,
                    label: Text('To-do'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment(
                    value: BoardType.flashcards,
                    label: Text('Cards'),
                    icon: Icon(Icons.style),
                  ),
                ],
                selected: {selectedType},
                onSelectionChanged: (v) {
                  setDialogState(() => selectedType = v.first);
                },
              ),
            ],
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
                setState(() {
                  _boards.add(Board(name: name, type: selectedType));
                });
                _save();
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showPensineAbout(context);
  }

  IconData _iconForType(BoardType type) => switch (type) {
        BoardType.thoughts => Icons.cloud,
        BoardType.todo => Icons.check_circle_outline,
        BoardType.flashcards => Icons.style,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pensine'),
        actions: [
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
          : _boards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water_drop, size: 64, color: PensineColors.muted(context)),
                      const SizedBox(height: 16),
                      Text(
                        'No boards yet.\nTap + to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PensineColors.muted(context), fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _boards.length,
                  itemBuilder: (ctx, i) {
                    final board = _boards[i];
                    return Dismissible(
                      key: Key(board.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: PensineColors.accent),
                      ),
                      onDismissed: (_) {
                        setState(() => _boards.removeAt(i));
                        _save();
                      },
                      child: Card(
                        color: PensineColors.card(context),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(_iconForType(board.type), color: PensineColors.accent),
                          title: Text(board.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${board.items.length} item${board.items.length == 1 ? '' : 's'}',
                            style: TextStyle(color: PensineColors.muted(context)),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BoardScreen(
                                  board: board,
                                  onChanged: _save,
                                ),
                              ),
                            );
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createBoard,
        child: const Icon(Icons.add),
      ),
    );
  }
}
