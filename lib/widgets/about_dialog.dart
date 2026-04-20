import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/board.dart';
import '../theme.dart';
import '../utils/pluralize.dart';

const String _siteUrl = 'https://frenchcommando.github.io/pensine/site/';

bool _hasKeyboardShortcuts() {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

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

Widget _shortcutRow(String keyLabel, String desc) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            keyLabel,
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(desc)),
      ],
    ),
  );
}

const String _buildDate = String.fromEnvironment('BUILD_DATE', defaultValue: 'dev');

Future<PackageInfo>? _packageInfoFuture;

void showPensineAbout(BuildContext context, {VoidCallback? onReset, int workspaceCount = 0, int boardCount = 0, int itemCount = 0}) async {
  final info = await (_packageInfoFuture ??= PackageInfo.fromPlatform());

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
          Center(child: Image.asset('assets/app_icon.png', width: 80, height: 80)),
          SizedBox(height: 12),
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
          _boardTypeRow(BoardType.thoughts.icon, 'Thoughts — tap to expand'),
          _boardTypeRow(BoardType.todo.icon, 'To-do — tap to catch in the net'),
          _boardTypeRow(BoardType.flashcards.icon, 'Flashcards — tap to flip, again to retry, double-tap for correct'),
          _boardTypeRow(BoardType.checklist.icon, 'Steps — tap to complete in order'),
          _boardTypeRow(BoardType.timer.icon, 'Timer — steps with elapsed time tracking'),
          _boardTypeRow(BoardType.countdown.icon, 'Countdown — steps auto-advance when time runs out'),
          if (_hasKeyboardShortcuts()) ...[
            SizedBox(height: 12),
            Text('Keyboard shortcuts:'),
            SizedBox(height: 4),
            _shortcutRow('N', 'New item (on a board)'),
            _shortcutRow('T', 'Toggle marble / table view'),
            _shortcutRow('Ctrl + N', 'New board (home screen)'),
          ],
          if (boardCount > 0) ...[
            SizedBox(height: 12),
            Text(
              '${pluralize(workspaceCount, 'workspace')}, '
              '${pluralize(boardCount, 'board')}, '
              '${pluralize(itemCount, 'marble')}',
              style: TextStyle(fontSize: 13, color: PensineColors.muted(context)),
            ),
          ],
          SizedBox(height: 16),
          Text(
            'Penser = to think',
            style: TextStyle(fontStyle: FontStyle.italic, color: PensineColors.muted(context)),
          ),
          SizedBox(height: 8),
          Text(
            'Build ${info.buildNumber} · $_buildDate',
            style: TextStyle(fontSize: 12, color: PensineColors.muted(context)),
          ),
          SizedBox(height: 8),
          InkWell(
            onTap: () => launchUrl(Uri.parse(_siteUrl), mode: LaunchMode.externalApplication),
            child: Text(
              'frenchcommando.github.io/pensine',
              style: TextStyle(
                fontSize: 12,
                color: PensineColors.accent,
                decoration: TextDecoration.underline,
              ),
            ),
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
