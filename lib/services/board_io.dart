import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/board.dart';

import 'board_io_native.dart' if (dart.library.html) 'board_io_web.dart' as platform;

class BoardIO {
  static Future<void> exportBoard(Board board, BuildContext context) async {
    try {
      final envelope = jsonEncode({
        'pensine_version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'board': board.toJson(),
      });
      final safeName = board.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
      await platform.exportFile('$safeName.pensine', envelope);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  static Future<Board?> importBoard(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
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

      final content = utf8.decode(bytes);
      final json = jsonDecode(content) as Map<String, dynamic>;

      if (json['pensine_version'] == null || json['board'] == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not a valid .pensine file')),
          );
        }
        return null;
      }

      final board = Board.fromJson(json['board']);
      return board.copyWithNewIds();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
      return null;
    }
  }
}
