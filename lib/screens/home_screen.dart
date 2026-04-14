import 'package:flutter/material.dart';
import '../models/board.dart';
import '../storage/local_storage.dart';
import '../theme.dart';
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
        BoardItem(content: 'Welcome to Pensine', description: 'A place for your thoughts, tasks, and memories. Tap a marble to peek inside.', colorIndex: 0, sizeMultiplier: 1.5),
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
          backgroundColor: PensineColors.surface,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PensineColors.surface,
        title: const Text('Pensine'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A place for your thoughts.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Text('Tap a marble to interact with it.\n'
                'Long-press empty space to create.\n'
                'Long-press a marble to edit.\n'
                'Drag marbles around for fun.'),
            SizedBox(height: 12),
            Text('Board types:'),
            SizedBox(height: 4),
            Text('  Thoughts — tap to expand, long-press to edit'),
            Text('  To-do — tap to catch in the net'),
            Text('  Flashcards — tap to flip'),
            SizedBox(height: 16),
            Text(
              'Penser = to think',
              style: TextStyle(fontStyle: FontStyle.italic, color: PensineColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.info_outline),
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
                      Icon(Icons.water_drop, size: 64, color: PensineColors.muted),
                      const SizedBox(height: 16),
                      Text(
                        'No boards yet.\nTap + to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PensineColors.muted, fontSize: 16),
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
                        color: PensineColors.card,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(_iconForType(board.type), color: PensineColors.accent),
                          title: Text(board.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${board.items.length} item${board.items.length == 1 ? '' : 's'}',
                            style: TextStyle(color: PensineColors.muted),
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
