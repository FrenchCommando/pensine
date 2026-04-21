import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/board.dart';
import '../theme.dart';
import '../utils/platform.dart';

/// Tabular view of a board's items. Alternative to MarbleBoard — shows the
/// same content as rows with columns relevant to the board type. Rows can be
/// dragged by the trailing handle to reorder.
///
/// Keyboard UX (desktop): the table is one tab stop. Arrow Up/Down moves a
/// selection highlight; E opens the edit dialog on the selected row;
/// Enter/Space activates (same as a click). On mobile, long-press still
/// opens the edit dialog — keyboard nav is inert.
class ItemsTable extends StatefulWidget {
  final Board board;
  final void Function(BoardItem) onTap;
  final void Function(BoardItem) onLongPress;
  final VoidCallback onLongPressEmpty;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ItemsTable({
    super.key,
    required this.board,
    required this.onTap,
    required this.onLongPress,
    required this.onLongPressEmpty,
    required this.onReorder,
  });

  @override
  State<ItemsTable> createState() => _ItemsTableState();
}

class _ItemsTableState extends State<ItemsTable> {
  final _focus = FocusNode(debugLabel: 'ItemsTable');
  final _rowKeys = <int, GlobalKey>{};
  int _selected = 0;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _move(int delta) {
    final n = widget.board.items.length;
    if (n == 0) return;
    setState(() => _selected = (_selected + delta).clamp(0, n - 1));
    _scrollSelectedIntoView();
  }

  void _scrollSelectedIntoView() {
    final key = _rowKeys[_selected];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 120),
      alignment: 0.5,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final items = widget.board.items;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (items.isEmpty || _selected >= items.length) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyE) {
      widget.onLongPress(items[_selected]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      widget.onTap(items[_selected]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.board.type;
    final hasDetails = type == BoardType.thoughts || type.isSequential;
    final hasBack = type == BoardType.flashcards;
    final hasDuration = type == BoardType.countdown;
    final hasDone = type.hasNet;
    final muted = PensineColors.muted(context);

    // Clamp selection when items shrink (delete / reorder away).
    final n = widget.board.items.length;
    if (n > 0 && _selected >= n) _selected = n - 1;
    if (n == 0) _selected = 0;

    final headerStyle = TextStyle(
      color: muted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    Widget header() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: muted.withValues(alpha: 0.235)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 28, child: Text('●', style: headerStyle)),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: Text('TITLE', style: headerStyle)),
            if (hasBack) ...[
              const SizedBox(width: 8),
              Expanded(flex: 3, child: Text('BACK', style: headerStyle)),
            ],
            if (hasDetails) ...[
              const SizedBox(width: 8),
              Expanded(flex: 4, child: Text('DETAILS', style: headerStyle)),
            ],
            if (hasDuration) ...[
              const SizedBox(width: 8),
              SizedBox(width: 72, child: Text('DURATION', style: headerStyle)),
            ],
            if (hasDone) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text('DONE',
                    style: headerStyle, textAlign: TextAlign.center),
              ),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text('SIZE',
                  style: headerStyle, textAlign: TextAlign.right),
            ),
            const SizedBox(width: 8),
            const SizedBox(width: 32),
          ],
        ),
      );
    }

    Widget row(BoardItem item, int index, {required bool groupFocused}) {
      final color = PensineColors.bubbles[
          item.colorIndex.abs() % PensineColors.bubbles.length];
      final contentStyle = TextStyle(
        fontSize: 14,
        decoration: item.done ? TextDecoration.lineThrough : null,
        color: item.done ? muted : null,
      );
      final mutedStyle = TextStyle(fontSize: 13, color: muted);
      final isSelected = index == _selected && groupFocused;

      final rowKey = _rowKeys.putIfAbsent(index, () => GlobalKey());

      return Material(
        key: ValueKey(item.id),
        color: Colors.transparent,
        child: InkWell(
          key: rowKey,
          onTap: () {
            setState(() => _selected = index);
            _focus.requestFocus();
            widget.onTap(item);
          },
          // Long-press opens edit on touch; omitted on desktop where
          // right-click / E do the job without the awkward click-and-hold.
          onLongPress: isDesktopUX ? null : () => widget.onLongPress(item),
          onSecondaryTap: !isDesktopUX
              ? null
              : () {
                  setState(() => _selected = index);
                  _focus.requestFocus();
                  widget.onLongPress(item);
                },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? muted.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: muted.withValues(alpha: 0.118)),
                left: BorderSide(
                  color: isSelected ? color : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.157),
                        width: 1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    item.content,
                    style: contentStyle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasBack) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.backContent ?? '—',
                      style:
                          item.backContent == null ? mutedStyle : contentStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (hasDetails) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Text(
                      item.description ?? '—',
                      style:
                          item.description == null ? mutedStyle : contentStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (hasDuration) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      item.durationSeconds != null
                          ? _formatDuration(item.durationSeconds!)
                          : '—',
                      style: item.durationSeconds == null
                          ? mutedStyle
                          : contentStyle,
                    ),
                  ),
                ],
                if (hasDone) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Icon(
                      item.done ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: item.done ? color : muted,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(
                    '×${item.sizeMultiplier.toStringAsFixed(1)}',
                    style: mutedStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child:
                          Icon(Icons.drag_handle, color: muted, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.board.items.isEmpty) {
      final hint = isDesktopUX
          ? 'Empty board.\nRight-click to add something.'
          : 'Empty board.\nLong-press to add something.';
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: isDesktopUX ? null : widget.onLongPressEmpty,
        onSecondaryTap: !isDesktopUX ? null : widget.onLongPressEmpty,
        child: Center(
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 16),
          ),
        ),
      );
    }

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Builder(builder: (context) {
        final groupFocused = Focus.of(context).hasFocus;
        return Column(
          children: [
            header(),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: widget.board.items.length,
                onReorder: (oldIndex, newIndex) {
                  _rowKeys.clear();
                  // Keep selection anchored to the dragged row.
                  setState(() {
                    if (_selected == oldIndex) {
                      _selected = newIndex > oldIndex ? newIndex - 1 : newIndex;
                    } else if (oldIndex < _selected && newIndex > _selected) {
                      _selected -= 1;
                    } else if (oldIndex > _selected && newIndex <= _selected) {
                      _selected += 1;
                    }
                  });
                  widget.onReorder(oldIndex, newIndex);
                },
                buildDefaultDragHandles: false,
                itemBuilder: (_, i) => row(widget.board.items[i], i,
                    groupFocused: groupFocused),
              ),
            ),
          ],
        );
      }),
    );
  }
}
