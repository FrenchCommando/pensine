import 'package:flutter/material.dart';
import '../theme.dart';

/// Grid of color swatches matching `PensineColors.bubbles`. If [allowDefault]
/// is true, the first swatch represents "no accent" and maps to index `-1`.
class PensineColorPicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allowDefault) _swatch(PensineColors.accent, -1),
        for (var i = 0; i < PensineColors.bubbles.length; i++)
          _swatch(PensineColors.bubbles[i], i),
      ],
    );
  }

  Widget _swatch(Color color, int index) {
    final isSelected = index == selected;
    final borderWidth = allowDefault ? 3.0 : 2.5;
    return GestureDetector(
      onTap: () => onChanged(index),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: borderWidth)
              : null,
        ),
      ),
    );
  }
}
