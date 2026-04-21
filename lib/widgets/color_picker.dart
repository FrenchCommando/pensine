import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Grid of color swatches matching `PensineColors.bubbles`. If [allowDefault]
/// is true, the first swatch represents "no accent" and maps to index `-1`.
///
/// Keyboard UX: the whole picker is one tab stop (radio-group convention).
/// Tab enters the group, arrow keys move through swatches changing the
/// selection, Tab leaves to the next field. Mouse click still works and
/// focuses the group, so arrows work immediately after.
class PensineColorPicker extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final bool allowDefault;
  final double size;

  const PensineColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.allowDefault = false,
    this.size = 28,
  });

  @override
  State<PensineColorPicker> createState() => _PensineColorPickerState();
}

class _PensineColorPickerState extends State<PensineColorPicker> {
  final _focus = FocusNode(debugLabel: 'PensineColorPicker');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  int get _count => widget.allowDefault
      ? PensineColors.bubbles.length + 1
      : PensineColors.bubbles.length;

  // Storage uses -1 for "default" + 0..n for bubbles; the linear arrow-nav
  // space collapses that to 0..n (+1 if allowDefault), which the visuals
  // render in the same order.
  int _toLinear(int stored) =>
      widget.allowDefault ? (stored == -1 ? 0 : stored + 1) : stored;
  int _fromLinear(int linear) =>
      widget.allowDefault ? (linear == 0 ? -1 : linear - 1) : linear;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final current = _toLinear(widget.selected).clamp(0, _count - 1);
    int next;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      next = (current + 1) % _count;
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      next = (current - 1 + _count) % _count;
    } else {
      return KeyEventResult.ignored;
    }
    widget.onChanged(_fromLinear(next));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Builder(builder: (context) {
        final groupFocused = Focus.of(context).hasFocus;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.allowDefault)
              _swatch(PensineColors.accent, -1, groupFocused),
            for (var i = 0; i < PensineColors.bubbles.length; i++)
              _swatch(PensineColors.bubbles[i], i, groupFocused),
          ],
        );
      }),
    );
  }

  Widget _swatch(Color color, int index, bool groupFocused) {
    final isSelected = index == widget.selected;
    final baseBorder = widget.allowDefault ? 3.0 : 2.5;
    // Focus ring: only the selected swatch shows it, and only while the
    // group has focus. Matches radio-group convention.
    final showFocusRing = isSelected && groupFocused;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          widget.onChanged(index);
          _focus.requestFocus();
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(
                    color: Colors.white,
                    width: showFocusRing ? baseBorder + 1.5 : baseBorder,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
