import 'package:flutter/material.dart';
import '../theme.dart';

void showPensineAbout(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: PensineColors.surface(context),
      title: const Text('Pensine'),
      content: Column(
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
          Text('  Thoughts — tap to expand'),
          Text('  To-do — tap to catch in the net'),
          Text('  Flashcards — tap to flip, again to retry, double-tap for correct'),
          Text('  Steps — tap to complete in order'),
          SizedBox(height: 16),
          Text(
            'Penser = to think',
            style: TextStyle(fontStyle: FontStyle.italic, color: PensineColors.muted(context)),
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
