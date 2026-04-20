import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../main.dart';
import '../models/board.dart';
import '../theme.dart';
import '../widgets/about_dialog.dart';
import '../widgets/color_picker.dart';
import '../widgets/items_table.dart';
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

  DateTime? _timerStartTime;
  DateTime? _stepStartTime;
  final _overlayTick = ValueNotifier<int>(0);
  Timer? _uiTicker;
  Timer? _countdownTimer;
  bool _anyFlipped = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initTimerState();
  }

  void _setTableMode(bool value) {
    setState(() => widget.board.tableMode = value);
    widget.onChanged();
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _countdownTimer?.cancel();
    _overlayTick.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _initTimerState() {
    final t = widget.board.type;
    if (t != BoardType.timer && t != BoardType.countdown) return;
    if (widget.board.items.any((i) => i.done)) {
      _timerStartTime = DateTime.now();
      _stepStartTime = DateTime.now();
      _startUiTicker();
      if (t == BoardType.countdown) _startCountdown();
    }
  }

  void _startUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _overlayTick.value++;
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

  /// Cancel tickers but keep [_timerStartTime] so the overlay keeps showing
  /// the final total after the last step completes.
  void _freezeTimers() {
    _uiTicker?.cancel();
    _uiTicker = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final nextIndex = widget.board.items.indexWhere((i) => !i.done);
    if (nextIndex < 0) return;
    final duration = widget.board.items[nextIndex].durationSeconds;
    if (duration == null || duration <= 0) return;
    _countdownTimer = Timer(Duration(seconds: duration), () {
      if (!mounted) return;
      final completedItem = widget.board.items[nextIndex];
      setState(() {
        // Index 0 is the start marble — tapping it arms the clock but never
        // produces a lap. Keeps countdown symmetric with timer boards.
        if (_stepStartTime != null && nextIndex > 0) {
          widget.board.laps.add(Lap(
            itemId: completedItem.id,
            elapsedSeconds: DateTime.now().difference(_stepStartTime!).inSeconds,
          ));
        }
        completedItem.done = true;
      });
      widget.onChanged();
      final allDone = widget.board.items.every((i) => i.done);
      HapticFeedback.lightImpact();
      if (allDone) {
        _freezeTimers();
        HapticFeedback.mediumImpact();
      } else {
        _stepStartTime = DateTime.now();
        _startCountdown();
      }
    });
  }

  void _itemDialog({BoardItem? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _ItemDialog(
        boardType: widget.board.type,
        existing: existing,
        defaultColorIndex: _random.nextInt(PensineColors.bubbles.length),
        sizeSlider: _sizeSlider,
        onSubmit: (content, description, back, color, size, duration) {
          setState(() {
            if (existing != null) {
              existing.content = content;
              existing.description = description;
              existing.backContent = back;
              existing.sizeMultiplier = size;
              existing.colorIndex = color;
              if (widget.board.type == BoardType.countdown) {
                existing.durationSeconds = duration;
              }
            } else {
              widget.board.items.add(BoardItem(
                content: content,
                description: description,
                backContent: back,
                colorIndex: color,
                sizeMultiplier: size,
                durationSeconds: duration,
              ));
            }
          });
          widget.onChanged();
        },
        onDelete: existing == null
            ? null
            : () {
                setState(() => widget.board.items.remove(existing));
                widget.onChanged();
                HapticFeedback.lightImpact();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.board.type;
    final hasTimerOverlay =
        (type == BoardType.timer || type == BoardType.countdown) &&
            _timerStartTime != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): () => _itemDialog(),
        const SingleActivator(LogicalKeyboardKey.keyT): () => _setTableMode(!widget.board.tableMode),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.board.name,
          style: TextStyle(color: PensineColors.boardAccent(widget.board.colorIndex)),
        ),
        actions: [
          if (!widget.board.tableMode)
            IconButton(
              icon: const Icon(Icons.vibration),
              tooltip: 'Shake',
              onPressed: () => _marbleBoardKey.currentState?.shake(),
            ),
          if (!widget.board.tableMode && type == BoardType.flashcards)
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    RotationTransition(turns: animation, child: child),
                child: Icon(Icons.flip, key: ValueKey(_anyFlipped)),
              ),
              tooltip: 'Flip all',
              onPressed: () {
                final state = _marbleBoardKey.currentState;
                if (state == null) return;
                final next = !_anyFlipped;
                state.flipAll(next);
                setState(() => _anyFlipped = next);
              },
            ),
          if ((type == BoardType.todo || type == BoardType.flashcards || type.isSequential) &&
              (type == BoardType.timer ||
                  type == BoardType.countdown ||
                  widget.board.items.any((i) => i.done)))
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: () {
                setState(() {
                  for (final item in widget.board.items) {
                    item.done = false;
                  }
                  widget.board.laps.clear();
                  _anyFlipped = false;
                });
                _stopTimers();
                _marbleBoardKey.currentState?.resetSizes();
                widget.onChanged();
              },
            ),
          IconButton(
            icon: Icon(widget.board.tableMode ? Icons.bubble_chart : Icons.table_chart_outlined),
            tooltip: widget.board.tableMode ? 'Marble view' : 'Table view',
            onPressed: () => _setTableMode(!widget.board.tableMode),
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
                  onLongPress: () => _itemDialog(),
                  child: Center(
                    child: Text(
                      'Empty board.\nLong-press to add something.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PensineColors.muted(context), fontSize: 16),
                    ),
                  ),
                )
              : _buildContent(),
          if (hasTimerOverlay)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: _TimerOverlay(
                board: widget.board,
                startTime: _timerStartTime!,
                stepStartTime: _stepStartTime,
                tick: _overlayTick,
              ),
            ),
          if ((type == BoardType.timer || type == BoardType.countdown) &&
              widget.board.laps.isNotEmpty)
            Positioned(
              bottom: 16,
              right: 16,
              child: _LapSummary(board: widget.board),
            ),
        ],
      ),
      floatingActionButton: widget.board.tableMode && widget.board.items.isNotEmpty
          ? FloatingActionButton(
              tooltip: 'Add item',
              onPressed: () => _itemDialog(),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        ),
      ),
    );
  }

  void _handleSequentialTap(BoardItem item) {
    final tappedIndex = widget.board.items.indexOf(item);
    final nextIndex = widget.board.items.indexWhere((i) => !i.done);
    final targetDone = (tappedIndex == nextIndex) ? tappedIndex + 1 : tappedIndex;
    setState(() {
      // Only the active step had a real elapsed time — leapfrogged steps don't.
      // Index 0 is the start marble: tapping it arms the clock, never logs.
      if (targetDone > nextIndex && nextIndex > 0 && _stepStartTime != null) {
        final activeItem = widget.board.items[nextIndex];
        widget.board.laps.add(Lap(
          itemId: activeItem.id,
          elapsedSeconds: DateTime.now().difference(_stepStartTime!).inSeconds,
        ));
      }
      for (var i = 0; i < widget.board.items.length; i++) {
        widget.board.items[i].done = i < targetDone;
      }
    });
    HapticFeedback.selectionClick();
    if (targetDone == widget.board.items.length && targetDone > nextIndex) {
      HapticFeedback.mediumImpact();
    }
    final t = widget.board.type;
    if (t == BoardType.timer || t == BoardType.countdown) {
      if (targetDone == 0) {
        _stopTimers();
      } else if (targetDone == widget.board.items.length) {
        _freezeTimers();
      } else {
        _timerStartTime ??= DateTime.now();
        _stepStartTime = DateTime.now();
        if (_uiTicker == null) _startUiTicker();
        if (t == BoardType.countdown) _startCountdown();
      }
    }
    widget.onChanged();
  }

  void _handleItemTap(BoardItem item) {
    switch (widget.board.type) {
      case BoardType.thoughts:
      case BoardType.flashcards:
        break;
      case BoardType.todo:
        setState(() => item.done = !item.done);
        widget.onChanged();
      case BoardType.checklist:
      case BoardType.timer:
      case BoardType.countdown:
        _handleSequentialTap(item);
    }
  }

  Widget _buildContent() {
    if (widget.board.tableMode) {
      return ItemsTable(
        board: widget.board,
        onTap: _handleItemTap,
        onLongPress: (item) => _itemDialog(existing: item),
        onLongPressEmpty: () => _itemDialog(),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = widget.board.items.removeAt(oldIndex);
            widget.board.items.insert(newIndex, item);
          });
          widget.onChanged();
        },
      );
    }
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
      onTap: _handleItemTap,
      onLongPress: (item) => _itemDialog(existing: item),
      onLongPressEmpty: () => _itemDialog(),
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

class _TimerOverlay extends StatelessWidget {
  final Board board;
  final DateTime startTime;
  final DateTime? stepStartTime;
  final ValueListenable<int> tick;

  const _TimerOverlay({
    required this.board,
    required this.startTime,
    required this.stepStartTime,
    required this.tick,
  });

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = board.colorIndex >= 0
        ? PensineColors.boardAccent(board.colorIndex)
        : Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<int>(
      valueListenable: tick,
      builder: (context, _, _) {
        final now = DateTime.now();
        final total = now.difference(startTime);
        final stepElapsed = stepStartTime != null ? now.difference(stepStartTime!) : Duration.zero;
        final allDone = board.items.every((i) => i.done);

        String? stepText;
        if (!allDone) {
          if (board.type == BoardType.countdown) {
            final nextIndex = board.items.indexWhere((i) => !i.done);
            final dur = board.items[nextIndex].durationSeconds;
            if (dur != null && dur > 0) {
              final remaining = Duration(seconds: dur) - stepElapsed;
              final clamped = remaining.isNegative ? Duration.zero : remaining;
              stepText = _format(clamped);
            }
          } else {
            stepText = 'step ${_format(stepElapsed)}';
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
                  board.type == BoardType.countdown ? Icons.hourglass_bottom : Icons.timer_outlined,
                  size: 16,
                  color: accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _format(total),
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
      },
    );
  }
}

class _LapSummary extends StatelessWidget {
  final Board board;

  const _LapSummary({required this.board});

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = board.colorIndex >= 0
        ? PensineColors.boardAccent(board.colorIndex)
        : Theme.of(context).colorScheme.primary;
    final itemsById = {for (final i in board.items) i.id: i};

    return Container(
      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: board.laps.map((lap) {
            final item = itemsById[lap.itemId];
            final label = item?.content ?? '(removed)';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: PensineColors.muted(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _format(lap.elapsedSeconds),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Stateful dialog: owns its four TextEditingControllers so `dispose()`
/// fires when the route is fully torn down — the canonical Flutter pattern.
/// A naive `.whenComplete(dispose)` races the exit-transition rebuild and
/// triggers "used after disposed" on heavy parent widget trees.
class _ItemDialog extends StatefulWidget {
  final BoardType boardType;
  final BoardItem? existing;
  final int defaultColorIndex;
  final Widget Function(double, ValueChanged<double>) sizeSlider;
  final void Function(String content, String? description, String? back,
      int colorIndex, double sizeMultiplier, int? durationSeconds) onSubmit;
  final VoidCallback? onDelete;

  const _ItemDialog({
    required this.boardType,
    required this.existing,
    required this.defaultColorIndex,
    required this.sizeSlider,
    required this.onSubmit,
    required this.onDelete,
  });

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final _content = TextEditingController(text: widget.existing?.content ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _back =
      TextEditingController(text: widget.existing?.backContent ?? '');
  late final _duration = TextEditingController(
      text: '${widget.existing?.durationSeconds ?? 60}');
  late double _size = widget.existing?.sizeMultiplier ?? 1.0;
  late int _colorIndex =
      widget.existing?.colorIndex ?? widget.defaultColorIndex;

  bool get _isFlashcard => widget.boardType == BoardType.flashcards;
  bool get _isThoughts => widget.boardType == BoardType.thoughts;
  bool get _isCountdown => widget.boardType == BoardType.countdown;

  @override
  void dispose() {
    _content.dispose();
    _description.dispose();
    _back.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _content.text.trim();
    if (text.isEmpty) return;
    final desc = _description.text.trim().isEmpty ? null : _description.text.trim();
    final back = _back.text.trim().isEmpty ? null : _back.text.trim();
    final duration = _isCountdown ? int.tryParse(_duration.text) : null;
    widget.onSubmit(text, desc, back, _colorIndex, _size, duration);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing != null
        ? 'Edit'
        : (_isFlashcard ? 'New Flashcard' : 'New Item');
    final submitLabel = widget.existing != null ? 'Save' : 'Add';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
            _submit,
      },
      child: AlertDialog(
        backgroundColor: PensineColors.surface(context),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _content,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _isFlashcard ? 'Front side' : 'Title',
                ),
              ),
              if (_isThoughts || widget.boardType.isSequential || _isFlashcard) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  decoration: InputDecoration(
                    hintText: _isThoughts
                        ? 'Details (tap to expand)'
                        : _isFlashcard
                            ? 'Details (shown with the answer)'
                            : 'Details (shown when active)',
                  ),
                  maxLines: 5,
                  minLines: 2,
                ),
              ],
              if (_isFlashcard) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _back,
                  decoration: const InputDecoration(hintText: 'Back side (answer)'),
                ),
              ],
              if (_isCountdown) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _duration,
                  decoration: const InputDecoration(
                    hintText: 'Duration (seconds)',
                    labelText: 'Duration (seconds)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              PensineColorPicker(
                selected: _colorIndex,
                onChanged: (v) => setState(() => _colorIndex = v),
              ),
              const SizedBox(height: 12),
              widget.sizeSlider(_size, (v) => setState(() => _size = v)),
            ],
          ),
        ),
        actions: [
          if (widget.onDelete != null)
            TextButton(
              onPressed: () {
                widget.onDelete!();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: PensineColors.accent),
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(submitLabel),
          ),
        ],
      ),
    );
  }
}
