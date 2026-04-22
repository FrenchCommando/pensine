import '../models/board.dart';
import '../models/workspace.dart';

enum SearchMatchKind { workspace, board, item }

/// A hit from [searchBoards]. [primary] is the text to render prominently
/// with the match span (`matchStart`..`matchStart+matchLength`) highlighted.
/// [secondary] is the breadcrumb shown underneath.
///
/// Exactly one of [workspace] / [board] / [item] is non-null depending on
/// [kind]; item hits also set [board] so the caller can navigate.
class SearchMatch {
  final SearchMatchKind kind;
  final String primary;
  final int matchStart;
  final int matchLength;
  final String secondary;
  final Workspace? workspace;
  final Board? board;
  final BoardItem? item;

  const SearchMatch({
    required this.kind,
    required this.primary,
    required this.matchStart,
    required this.matchLength,
    required this.secondary,
    this.workspace,
    this.board,
    this.item,
  });
}

/// Case-insensitive substring search across workspaces, boards and items.
/// Pure — no state, no I/O. Results are grouped by kind (workspaces →
/// boards → items) and within each group ordered by how early the match
/// lands in the field, so prefix hits float to the top naturally.
///
/// For items, all text fields are searched (content, description,
/// backContent) and the first field that matches is the one returned as
/// [SearchMatch.primary]. One hit per item, even if multiple fields match.
List<SearchMatch> searchBoards({
  required String query,
  required List<Workspace> workspaces,
  required List<Board> boards,
  int limit = 200,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final wsById = {for (final w in workspaces) w.id: w};

  int? indexOf(String haystack) {
    final i = haystack.toLowerCase().indexOf(q);
    return i < 0 ? null : i;
  }

  final wsMatches = <SearchMatch>[];
  for (final w in workspaces) {
    final idx = indexOf(w.name);
    if (idx != null) {
      wsMatches.add(SearchMatch(
        kind: SearchMatchKind.workspace,
        primary: w.name,
        matchStart: idx,
        matchLength: q.length,
        secondary: '',
        workspace: w,
      ));
    }
  }
  wsMatches.sort((a, b) => a.matchStart.compareTo(b.matchStart));

  final boardMatches = <SearchMatch>[];
  for (final b in boards) {
    final idx = indexOf(b.name);
    if (idx != null) {
      boardMatches.add(SearchMatch(
        kind: SearchMatchKind.board,
        primary: b.name,
        matchStart: idx,
        matchLength: q.length,
        secondary: wsById[b.workspaceId]?.name ?? '',
        board: b,
      ));
    }
  }
  boardMatches.sort((a, b) => a.matchStart.compareTo(b.matchStart));

  final itemMatches = <SearchMatch>[];
  for (final b in boards) {
    final wsName = wsById[b.workspaceId]?.name ?? '';
    final breadcrumb = wsName.isEmpty ? b.name : '$wsName › ${b.name}';
    for (final it in b.items) {
      final fields = <String>[
        it.content,
        if (it.description != null && it.description!.isNotEmpty)
          it.description!,
        if (it.backContent != null && it.backContent!.isNotEmpty)
          it.backContent!,
      ];
      for (final field in fields) {
        final idx = indexOf(field);
        if (idx != null) {
          itemMatches.add(SearchMatch(
            kind: SearchMatchKind.item,
            primary: field,
            matchStart: idx,
            matchLength: q.length,
            secondary: breadcrumb,
            board: b,
            item: it,
          ));
          break;
        }
      }
    }
  }
  itemMatches.sort((a, b) => a.matchStart.compareTo(b.matchStart));

  final all = [...wsMatches, ...boardMatches, ...itemMatches];
  return all.length > limit ? all.sublist(0, limit) : all;
}
