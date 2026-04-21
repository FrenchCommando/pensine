import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/widgets/color_picker.dart';
import 'package:pensine/theme.dart';

/// Host widget that sandwiches the picker between two TextFields so we can
/// assert the picker occupies a single tab stop in the traversal chain
/// (Tab from the top field lands on the picker; Tab again moves past to
/// the bottom field, not through every swatch).
class _Host extends StatefulWidget {
  final int initial;
  final bool allowDefault;
  const _Host({required this.initial, this.allowDefault = false});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(
                key: const Key('top'),
                decoration: const InputDecoration(hintText: 'top')),
            PensineColorPicker(
              selected: _selected,
              allowDefault: widget.allowDefault,
              onChanged: (v) => setState(() => _selected = v),
            ),
            TextField(
                key: const Key('bottom'),
                decoration: const InputDecoration(hintText: 'bottom')),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('PensineColorPicker keyboard', () {
    testWidgets('Tab lands on the picker as a single stop (not per-swatch)',
        (tester) async {
      await tester.pumpWidget(const _Host(initial: 2));
      // Focus the top field explicitly, then Tab once.
      await tester.tap(find.byKey(const Key('top')));
      await tester.pump();
      expect(tester.binding.focusManager.primaryFocus?.debugLabel,
          isNot('PensineColorPicker'),
          reason: 'precondition: focus is on top text field');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.binding.focusManager.primaryFocus?.debugLabel,
          'PensineColorPicker',
          reason: 'One Tab from the top field lands on the picker group');

      // Second tab leaves the picker (does NOT cycle through swatches).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.binding.focusManager.primaryFocus?.debugLabel,
          isNot('PensineColorPicker'),
          reason: 'Second Tab exits the picker to the next field');
    });

    testWidgets('Arrow right advances selection, left retreats with wrap',
        (tester) async {
      await tester.pumpWidget(const _Host(initial: 0));
      await tester.tap(find.byKey(const Key('top')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Find the Host state to observe selection changes.
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state._selected, 0);

      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump(); // let Host rebuild + flow new selected into the picker
      }

      await press(LogicalKeyboardKey.arrowRight);
      expect(state._selected, 1);

      await press(LogicalKeyboardKey.arrowRight);
      expect(state._selected, 2);

      await press(LogicalKeyboardKey.arrowLeft);
      expect(state._selected, 1);

      // Wrap backwards past 0 → last bubble index.
      await press(LogicalKeyboardKey.arrowLeft); // 1 → 0
      await press(LogicalKeyboardKey.arrowLeft); // 0 → last
      expect(state._selected, PensineColors.bubbles.length - 1);
    });

    testWidgets('allowDefault: arrow from 0 wraps to -1 and back',
        (tester) async {
      await tester.pumpWidget(const _Host(initial: 0, allowDefault: true));
      await tester.tap(find.byKey(const Key('top')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final state = tester.state<_HostState>(find.byType(_Host));

      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      // Linear order is [-1, 0, 1, ..., n-1]; selected=0 is linear index 1.
      await press(LogicalKeyboardKey.arrowLeft);
      expect(state._selected, -1, reason: 'left from 0 lands on default (-1)');

      await press(LogicalKeyboardKey.arrowRight);
      expect(state._selected, 0, reason: 'right from -1 returns to bubble 0');
    });

    testWidgets('Click on a swatch still selects it and focuses the group',
        (tester) async {
      // Click is click on every platform — no platform override needed for
      // this behavior. The picker works identically on android/windows.
      await tester.pumpWidget(const _Host(initial: 0));
      final state = tester.state<_HostState>(find.byType(_Host));

      // Swatches are colored circles, so find by MouseRegion (each swatch
      // wraps its container in one for the cursor change) under the picker.
      final regions = find.descendant(
        of: find.byType(PensineColorPicker),
        matching: find.byType(MouseRegion),
      );
      expect(regions, findsWidgets);
      await tester.tap(regions.at(2));
      await tester.pump();
      expect(state._selected, 2);
      expect(tester.binding.focusManager.primaryFocus?.debugLabel,
          'PensineColorPicker',
          reason: 'Clicking a swatch focuses the picker group');
    });
  });
}
