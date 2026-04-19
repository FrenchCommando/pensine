import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/board.dart';
import '../models/workspace.dart';

import 'board_io_native.dart' if (dart.library.html) 'board_io_web.dart' as platform;

class ImportResult {
  final Workspace? workspace;
  final List<Board> boards;

  ImportResult({this.workspace, required this.boards});
}

String _safeFileName(String name) => name
    .replaceAll(RegExp(r'[^\w\s-]'), '')
    .replaceAll(RegExp(r'\s+'), '_');

String _envelope(int version, Map<String, dynamic> payload) => jsonEncode({
      'pensine_version': version,
      'exported_at': DateTime.now().toIso8601String(),
      ...payload,
    });

class BoardIO {
  static Future<void> exportBoard(Board board, BuildContext context) async {
    try {
      await platform.exportFile(
        '${_safeFileName(board.name)}.pensine',
        _envelope(1, {'board': board.toJson()}),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  static Future<void> exportWorkspace(Workspace workspace, List<Board> boards, BuildContext context) async {
    try {
      await platform.exportFile(
        '${_safeFileName(workspace.name)}.pensine',
        _envelope(2, {
          'workspace': {
            ...workspace.toJson(),
            'boards': boards.map((b) => b.toJson()).toList(),
          },
        }),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  /// Import a .pensine file via picker. Returns an ImportResult with either:
  /// - A workspace + boards (v2 format)
  /// - Just boards (v1 format, assigned to chosen workspace)
  static Future<ImportResult?> importFile(BuildContext context, List<Workspace> workspaces) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pensine'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return null;
      }

      if (!context.mounted) return null;
      return await importContent(utf8.decode(bytes), context, workspaces);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
      return null;
    }
  }

  /// Import from raw .pensine file contents (no picker). Used by PWA file handler
  /// and deep-link flows that deliver bytes directly to the app.
  static Future<ImportResult?> importContent(
    String content,
    BuildContext context,
    List<Workspace> workspaces,
  ) async {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final version = json['pensine_version'];

      if (version == 2 && json['workspace'] != null) {
        return _importV2(json);
      } else if (json['board'] != null) {
        if (!context.mounted) return null;
        return await _importV1(json, context, workspaces);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not a valid .pensine file')),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
      return null;
    }
  }

  static ImportResult _importV2(Map<String, dynamic> json) {
    final wsJson = json['workspace'] as Map<String, dynamic>;
    final boardsJson = wsJson['boards'] as List;

    final newWs = Workspace(
      name: wsJson['name'] ?? 'Imported',
      colorIndex: wsJson['colorIndex'] ?? -1,
    );

    final boards = boardsJson.map((b) {
      final board = Board.fromJson(b).copyWithNewIds();
      board.workspaceId = newWs.id;
      return board;
    }).toList();

    return ImportResult(workspace: newWs, boards: boards);
  }

  static Future<ImportResult?> _importV1(
    Map<String, dynamic> json,
    BuildContext context,
    List<Workspace> workspaces,
  ) async {
    final board = Board.fromJson(json['board']).copyWithNewIds();

    if (workspaces.length == 1) {
      board.workspaceId = workspaces.first.id;
      return ImportResult(boards: [board]);
    }

    // Let user pick workspace
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import to which workspace?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: workspaces.map((ws) {
            return ListTile(
              dense: true,
              leading: const Icon(Icons.folder),
              title: Text(ws.name),
              onTap: () => Navigator.pop(ctx, ws.id),
            );
          }).toList(),
        ),
      ),
    );

    if (chosen == null) return null;
    board.workspaceId = chosen;
    return ImportResult(boards: [board]);
  }
}
