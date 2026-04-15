import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/board.dart';
import '../theme.dart';
import '../widgets/about_dialog.dart';
import '../widgets/marble_board.dart';

class BoardScreen extends StatefulWidget {
  final Board board;
  final VoidCallback onChanged;

  const BoardScreen({super.key, required this.board, required this.onChanged});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _random = Random();
  final _marbleBoardKey = GlobalKey<MarbleBoardState>();

  void _addItem() {
    final controller = TextEditingController();
    final descController = TextEditingController();
    final backController = TextEditingController();
    final isFlashcard = widget.board.type == BoardType.flashcards;
    final isThoughts = widget.board.type == BoardType.thoughts;
    var size = 1.0;
    var colorIndex = _random.nextInt(PensineColors.bubbles.length);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: PensineColors.surface(context),
          title: Text(isFlashcard ? 'New Flashcard' : 'New Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isFlashcard ? 'Front side' : 'Title',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                if (isThoughts) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(hintText: 'Details (tap to expand)'),
                    maxLines: 5,
                    minLines: 2,
                  ),
                ],
                if (isFlashcard) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: backController,
                    decoration: const InputDecoration(hintText: 'Back side (answer)'),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ],
                const SizedBox(height: 16),
                _colorPicker(colorIndex, (v) => setDialogState(() => colorIndex = v)),
                const SizedBox(height: 12),
                _sizeSlider(size, (v) => setDialogState(() => size = v)),
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
                final text = controller.text.trim();
                if (text.isEmpty) return;
                setState(() {
                  widget.board.items.add(BoardItem(
                    content: text,
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    backContent: backController.text.trim().isEmpty
                        ? null
                        : backController.text.trim(),
                    colorIndex: colorIndex,
                    sizeMultiplier: size,
                  ));
                });
                widget.onChanged();
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.board.name,
          style: TextStyle(color: PensineColors.boardAccent(widget.board.colorIndex)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vibration),
            tooltip: 'Shake',
            onPressed: () => _marbleBoardKey.currentState?.shake(),
          ),
          if (widget.board.type == BoardType.flashcards)
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    RotationTransition(turns: animation, child: child),
                child: Icon(
                  Icons.flip,
                  key: ValueKey(_marbleBoardKey.currentState?.marbles.any((m) => m.flipped) ?? false),
                ),
              ),
              tooltip: 'Flip all',
              onPressed: () {
                final state = _marbleBoardKey.currentState;
                if (state != null) {
                  final anyFlipped = state.marbles.any((m) => m.flipped);
                  state.flipAll(!anyFlipped);
                  setState(() {});
                }
              },
            ),
          if ((widget.board.type == BoardType.todo || widget.board.type == BoardType.flashcards || widget.board.type == BoardType.checklist) &&
              widget.board.items.any((i) => i.done))
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: () {
                setState(() {
                  for (final item in widget.board.items) {
                    item.done = false;
                  }
                });
                _marbleBoardKey.currentState?.resetSizes();
                widget.onChanged();
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
            onPressed: () => showPensineAbout(context),
          ),
        ],
      ),
      body: widget.board.items.isEmpty
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _addItem,
              child: Center(
                child: Text(
                  'Empty board.\nLong-press to add something.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PensineColors.muted(context), fontSize: 16),
                ),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return MarbleBoard(
      key: _marbleBoardKey,
      items: widget.board.items,
      boardType: widget.board.type,
      accentColor: widget.board.colorIndex >= 0 ? PensineColors.boardAccent(widget.board.colorIndex) : null,
      onChanged: () {
        setState(() {});
        widget.onChanged();
      },
      onRemove: (item) {
        setState(() => widget.board.items.remove(item));
        widget.onChanged();
      },
      onTap: (item) {
        switch (widget.board.type) {
          case BoardType.thoughts:
            // Expand is handled inside MarbleBoard
            break;
          case BoardType.todo:
            setState(() => item.done = !item.done);
            widget.onChanged();
          case BoardType.flashcards:
            // Flip is handled inside MarbleBoard
            break;
          case BoardType.checklist:
            // Only allow catching the next unchecked item in order
            final nextIndex = widget.board.items.indexWhere((i) => !i.done);
            if (nextIndex >= 0 && widget.board.items[nextIndex].id == item.id) {
              setState(() => item.done = true);
              widget.onChanged();
            }
        }
      },
      onLongPress: (item) => _editItem(item),
      onLongPressEmpty: _addItem,
    );
  }

  void _editItem(BoardItem item) {
    final controller = TextEditingController(text: item.content);
    final descController = TextEditingController(text: item.description ?? '');
    final backController = TextEditingController(text: item.backContent ?? '');
    final isFlashcard = widget.board.type == BoardType.flashcards;
    final isThoughts = widget.board.type == BoardType.thoughts;
    var size = item.sizeMultiplier;
    var colorIndex = item.colorIndex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: PensineColors.surface(context),
          title: const Text('Edit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isFlashcard ? 'Front side' : 'Title',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                if (isThoughts) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(hintText: 'Details (tap to expand)'),
                    maxLines: 5,
                    minLines: 2,
                  ),
                ],
                if (isFlashcard) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: backController,
                    decoration: const InputDecoration(hintText: 'Back side (answer)'),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ],
                const SizedBox(height: 16),
                _colorPicker(colorIndex, (v) => setDialogState(() => colorIndex = v)),
                const SizedBox(height: 12),
                _sizeSlider(size, (v) => setDialogState(() => size = v)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => widget.board.items.remove(item));
                widget.onChanged();
                Navigator.pop(ctx);
              },
              style: TextButton.styleFrom(foregroundColor: PensineColors.accent),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                setState(() {
                  item.content = text;
                  item.description = descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim();
                  item.backContent = backController.text.trim().isEmpty
                      ? null
                      : backController.text.trim();
                  item.sizeMultiplier = size;
                  item.colorIndex = colorIndex;
                });
                widget.onChanged();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorPicker(int selected, ValueChanged<int> onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(PensineColors.bubbles.length, (i) {
        final isSelected = i == selected;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: PensineColors.bubbles[i],
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _sizeSlider(double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Icon(Icons.circle, size: 12, color: PensineColors.muted(context)),
        Expanded(
          child: Slider(
            value: value,
            min: 0.5,
            max: 2.0,
            onChanged: onChanged,
          ),
        ),
        Icon(Icons.circle, size: 24, color: PensineColors.muted(context)),
      ],
    );
  }

}
