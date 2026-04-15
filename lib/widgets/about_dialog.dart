import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme.dart';

Widget _boardTypeRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: PensineColors.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

const String _buildDate = String.fromEnvironment('BUILD_DATE', defaultValue: 'dev');

void showPensineAbout(BuildContext context, {VoidCallback? onReset}) async {
  final info = await PackageInfo.fromPlatform();

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: PensineColors.surface(context),
      title: Text('Pensine v${info.version}'),
      content: SingleChildScrollView(child: Column(
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
          _boardTypeRow(Icons.cloud, 'Thoughts — tap to expand'),
          _boardTypeRow(Icons.check_circle_outline, 'To-do — tap to catch in the net'),
          _boardTypeRow(Icons.style, 'Flashcards — tap to flip, again to retry, double-tap for correct'),
          _boardTypeRow(Icons.format_list_numbered, 'Steps — tap to complete in order'),
          SizedBox(height: 16),
          Text(
            'Penser = to think',
            style: TextStyle(fontStyle: FontStyle.italic, color: PensineColors.muted(context)),
          ),
          SizedBox(height: 8),
          Text(
            'Build: $_buildDate',
            style: TextStyle(fontSize: 12, color: PensineColors.muted(context)),
          ),
        ],
      )),
      actions: [
        TextButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: ctx,
              builder: (c) => AlertDialog(
                title: const Text('Reset all data?'),
                content: const Text('This will delete all boards and settings.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                ],
              ),
            );
            if (confirm == true) {
              if (ctx.mounted) Navigator.pop(ctx);
              onReset?.call();
            }
          },
          style: TextButton.styleFrom(foregroundColor: PensineColors.accent),
          child: const Text('Reset data'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
