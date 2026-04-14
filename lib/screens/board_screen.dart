import 'dart:math';
import 'package:flutter/material.dart';
import '../models/board.dart';
import '../theme.dart';
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

  void _addItem() {
    final controller = TextEditingController();
    final descController = TextEditingController();
    final backController = TextEditingController();
    final isFlashcard = widget.board.type == BoardType.flashcards;
    final isThoughts = widget.board.type == BoardType.thoughts;
    var size = 1.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: PensineColors.surface,
          title: Text(isFlashcard ? 'New Flashcard' : 'New Item'),
          content: Column(
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
              _sizeSlider(size, (v) => setDialogState(() => size = v)),
            ],
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
                    colorIndex: _random.nextInt(PensineColors.bubbles.length),
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
      appBar: AppBar(title: Text(widget.board.name)),
      body: widget.board.items.isEmpty
          ? Center(
              child: Text(
                'Empty board.\nLong-press to add something.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PensineColors.muted, fontSize: 16),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return MarbleBoard(
      items: widget.board.items,
      boardType: widget.board.type,
      onChanged: widget.onChanged,
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: PensineColors.surface,
          title: const Text('Edit'),
          content: Column(
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
              _sizeSlider(size, (v) => setDialogState(() => size = v)),
            ],
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
            const Spacer(),
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

  Widget _sizeSlider(double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 12, color: PensineColors.muted),
        Expanded(
          child: Slider(
            value: value,
            min: 0.5,
            max: 2.0,
            onChanged: onChanged,
          ),
        ),
        const Icon(Icons.circle, size: 24, color: PensineColors.muted),
      ],
    );
  }

}
