import 'package:flutter/material.dart';
import '../models/board.dart';
import '../theme.dart';

/// Tabular view of a board's items. Alternative to MarbleBoard — shows the
/// same content as rows with columns relevant to the board type.
class ItemsTable extends StatelessWidget {
  final Board board;
  final void Function(BoardItem) onTap;
  final void Function(BoardItem) onLongPress;
  final VoidCallback onLongPressEmpty;

  const ItemsTable({
    super.key,
    required this.board,
    required this.onTap,
    required this.onLongPress,
    required this.onLongPressEmpty,
  });

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final type = board.type;
    final hasDetails = type == BoardType.thoughts || type.isSequential;
    final hasBack = type == BoardType.flashcards;
    final hasDuration = type == BoardType.countdown;
    final hasDone = type.hasNet;
    final muted = PensineColors.muted(context);

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
            bottom: BorderSide(color: muted.withAlpha(60)),
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
                child: Text('DONE', style: headerStyle, textAlign: TextAlign.center),
              ),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text('SIZE', style: headerStyle, textAlign: TextAlign.right),
            ),
          ],
        ),
      );
    }

    Widget row(BoardItem item) {
      final color = PensineColors.bubbles[
          item.colorIndex.abs() % PensineColors.bubbles.length];
      final contentStyle = TextStyle(
        fontSize: 14,
        decoration: item.done ? TextDecoration.lineThrough : null,
        color: item.done ? muted : null,
      );
      final mutedStyle = TextStyle(fontSize: 13, color: muted);

      return InkWell(
        onTap: () => onTap(item),
        onLongPress: () => onLongPress(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(40), width: 1),
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
                    style: item.backContent == null ? mutedStyle : contentStyle,
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
                    style: item.description == null ? mutedStyle : contentStyle,
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
                    style: item.durationSeconds == null ? mutedStyle : contentStyle,
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
            ],
          ),
        ),
      );
    }

    if (board.items.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPressEmpty,
        child: Center(
          child: Text(
            'Empty board.\nLong-press to add something.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: [
        header(),
        Expanded(
          child: ListView.separated(
            itemCount: board.items.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: muted.withAlpha(30)),
            itemBuilder: (_, i) => row(board.items[i]),
          ),
        ),
      ],
    );
  }
}
