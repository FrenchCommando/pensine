import 'dart:async';

import 'package:flutter/material.dart';
import '../behavior/board_search.dart';
import '../models/board.dart';
import '../models/workspace.dart';
import '../theme.dart';

/// Keystroke-to-search delay. Short enough that typing feels live; long
/// enough to coalesce bursts on slow devices and leave headroom for a
/// future indexed backend.
const _debounceDelay = Duration(milliseconds: 150);

/// Full-screen search overlay. Queries are evaluated synchronously against
/// the lists passed in on push — state is owned by `HomeScreen` and the
/// caller navigates via [onSelect]. Snapshot semantics: the lists are
/// captured at push time, which is fine because the user closes the
/// screen before mutating anything.
class SearchScreen extends StatefulWidget {
  final List<Workspace> workspaces;
  final List<Board> boards;
  final ValueChanged<SearchMatch> onSelect;

  const SearchScreen({
    super.key,
    required this.workspaces,
    required this.boards,
    required this.onSelect,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    if (_query == value) return;
    setState(() => _query = value);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Empty input short-circuits: clearing should feel instant, not lag
    // 150ms behind the tap on the X button.
    if (value.trim().isEmpty) {
      _setQuery(value);
      return;
    }
    _debounce = Timer(_debounceDelay, () => _setQuery(value));
  }

  void _handleTap(SearchMatch match) {
    Navigator.pop(context);
    widget.onSelect(match);
  }

  @override
  Widget build(BuildContext context) {
    final results = searchBoards(
      query: _query,
      workspaces: widget.workspaces,
      boards: widget.boards,
    );
    final muted = PensineColors.muted(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search workspaces, boards, items…',
            border: InputBorder.none,
            filled: false,
          ),
          style: const TextStyle(fontSize: 18),
          onChanged: _onChanged,
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _query.trim().isEmpty
          ? Center(
              child: Text(
                'Type to search',
                style: TextStyle(color: muted, fontSize: 16),
              ),
            )
          : results.isEmpty
              ? Center(
                  child: Text(
                    'No matches',
                    style: TextStyle(color: muted, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) =>
                      _SearchResultTile(match: results[i], onTap: _handleTap),
                ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchMatch match;
  final ValueChanged<SearchMatch> onTap;

  const _SearchResultTile({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _leadingIcon(match),
      title: _HighlightedText(
        text: match.primary,
        start: match.matchStart,
        length: match.matchLength,
      ),
      subtitle: match.secondary.isEmpty
          ? null
          : Text(
              match.secondary,
              style: TextStyle(
                color: PensineColors.muted(context),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () => onTap(match),
    );
  }

  Widget _leadingIcon(SearchMatch m) {
    switch (m.kind) {
      case SearchMatchKind.workspace:
        return Icon(
          Icons.folder,
          color: PensineColors.boardAccent(m.workspace?.colorIndex ?? -1),
        );
      case SearchMatchKind.board:
        return Icon(
          m.board!.type.icon,
          color: PensineColors.boardAccent(m.board!.colorIndex),
        );
      case SearchMatchKind.item:
        return Icon(
          Icons.fiber_manual_record,
          size: 14,
          color: PensineColors.boardAccent(m.board!.colorIndex),
        );
    }
  }
}

/// Renders `text` with the span `[start, start+length)` styled bold so the
/// matched portion stands out. Falls back to plain text if the range is
/// out of bounds (defensive — shouldn't happen given how the matches are
/// produced, but cheap insurance).
class _HighlightedText extends StatelessWidget {
  final String text;
  final int start;
  final int length;

  const _HighlightedText({
    required this.text,
    required this.start,
    required this.length,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;
    final end = start + length;
    if (start < 0 || end > text.length) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: PensineColors.accent,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
