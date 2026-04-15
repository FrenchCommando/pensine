import 'dart:async';
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

  // Timer/countdown state
  DateTime? _timerStartTime;
  DateTime? _stepStartTime;
  Timer? _uiTicker;
  Timer? _countdownTimer;

  bool get _isSequential => const [BoardType.checklist, BoardType.timer, BoardType.countdown].contains(widget.board.type);

  @override
  void initState() {
    super.initState();
    _initTimerState();
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _initTimerState() {
    if (widget.board.type != BoardType.timer && widget.board.type != BoardType.countdown) return;
    final doneCount = widget.board.items.where((i) => i.done).length;
    if (doneCount > 0) {
      _timerStartTime = DateTime.now();
      _stepStartTime = DateTime.now();
      _startUiTicker();
      if (widget.board.type == BoardType.countdown) _startCountdown();
    }
  }

  void _startUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimers() {
    _uiTicker?.cancel();
    _uiTicker = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _timerStartTime = null;
    _stepStartTime = null;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final nextIndex = widget.board.items.indexWhere((i) => !i.done);
    if (nextIndex < 0) return; // all done
    final duration = widget.board.items[nextIndex].durationSeconds;
    if (duration == null || duration <= 0) return;
    _countdownTimer = Timer(Duration(seconds: duration), () {
      if (!mounted) return;
      // Auto-advance: complete current step
      setState(() => widget.board.items[nextIndex].done = true);
      widget.onChanged();
      _stepStartTime = DateTime.now();
      if (widget.board.items.every((i) => i.done)) {
        _countdownTimer = null;
      } else {
        _startCountdown();
      }
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  void _addItem() {
    final controller = TextEditingController();
    final descController = TextEditingController();
    final backController = TextEditingController();
    final isFlashcard = widget.board.type == BoardType.flashcards;
    final isThoughts = widget.board.type == BoardType.thoughts;
    final isCountdown = widget.board.type == BoardType.countdown;
    var size = 1.0;
    var colorIndex = _random.nextInt(PensineColors.bubbles.length);
    final durationController = TextEditingController(text: '60');

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
                if (isCountdown) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      hintText: 'Duration (seconds)',
                      labelText: 'Duration (seconds)',
                    ),
                    keyboardType: TextInputType.number,
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
                    durationSeconds: isCountdown ? int.tryParse(durationController.text) : null,
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
          if ((widget.board.type == BoardType.todo || widget.board.type == BoardType.flashcards || _isSequential) &&
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
                _stopTimers();
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
      body: Stack(
        children: [
          widget.board.items.isEmpty
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
          if ((widget.board.type == BoardType.timer || widget.board.type == BoardType.countdown) && _timerStartTime != null)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: _buildTimerOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerOverlay() {
    final now = DateTime.now();
    final total = now.difference(_timerStartTime!);
    final stepElapsed = _stepStartTime != null ? now.difference(_stepStartTime!) : Duration.zero;
    final allDone = widget.board.items.every((i) => i.done);
    final accentColor = widget.board.colorIndex >= 0
        ? PensineColors.boardAccent(widget.board.colorIndex)
        : Theme.of(context).colorScheme.primary;

    // For countdown: show remaining time on current step
    String? stepText;
    if (!allDone) {
      if (widget.board.type == BoardType.countdown) {
        final nextIndex = widget.board.items.indexWhere((i) => !i.done);
        final dur = widget.board.items[nextIndex].durationSeconds;
        if (dur != null && dur > 0) {
          final remaining = Duration(seconds: dur) - stepElapsed;
          final clamped = remaining.isNegative ? Duration.zero : remaining;
          stepText = _formatDuration(clamped);
        }
      } else {
        stepText = 'step ${_formatDuration(stepElapsed)}';
      }
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.board.type == BoardType.countdown ? Icons.hourglass_bottom : Icons.timer_outlined,
              size: 16,
              color: accentColor,
            ),
            const SizedBox(width: 6),
            Text(
              _formatDuration(total),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
            if (stepText != null) ...[
              Text(' · ', style: TextStyle(color: PensineColors.muted(context))),
              Text(
                stepText,
                style: TextStyle(
                  fontSize: 13,
                  color: PensineColors.muted(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleSequentialTap(BoardItem item) {
    final tappedIndex = widget.board.items.indexOf(item);
    final nextIndex = widget.board.items.indexWhere((i) => !i.done);
    final targetDone = (tappedIndex == nextIndex) ? tappedIndex + 1 : tappedIndex;
    setState(() {
      for (var i = 0; i < widget.board.items.length; i++) {
        widget.board.items[i].done = i < targetDone;
      }
    });
    // Timer/countdown management
    if (widget.board.type == BoardType.timer || widget.board.type == BoardType.countdown) {
      if (targetDone == 0) {
        _stopTimers();
      } else {
        _timerStartTime ??= DateTime.now();
        _stepStartTime = DateTime.now();
        if (_uiTicker == null) _startUiTicker();
        if (widget.board.type == BoardType.countdown) {
          _startCountdown();
        }
      }
    }
    widget.onChanged();
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
          case BoardType.timer:
          case BoardType.countdown:
            _handleSequentialTap(item);
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
    final isCountdown = widget.board.type == BoardType.countdown;
    var size = item.sizeMultiplier;
    var colorIndex = item.colorIndex;
    final durationController = TextEditingController(text: '${item.durationSeconds ?? 60}');

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
                if (isCountdown) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      hintText: 'Duration (seconds)',
                      labelText: 'Duration (seconds)',
                    ),
                    keyboardType: TextInputType.number,
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
                  if (isCountdown) item.durationSeconds = int.tryParse(durationController.text);
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
            min: 0.1,
            max: 5.0,
            onChanged: onChanged,
          ),
        ),
        Icon(Icons.circle, size: 24, color: PensineColors.muted(context)),
      ],
    );
  }

}
