import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> get _boardsDir async {
  final dir = await getApplicationSupportDirectory();
  final boardsDir = Directory('${dir.path}/boards');
  if (!await boardsDir.exists()) {
    await boardsDir.create(recursive: true);
  }
  return boardsDir;
}

Future<List<String>> _loadAllByExtension(String extension) async {
  final dir = await _boardsDir;
  final files = await dir
      .list()
      .where((e) => e is File && e.path.endsWith(extension))
      .cast<File>()
      .toList();
  return Future.wait(files.map((f) => f.readAsString()));
}

Future<void> _deleteIfExists(File file) async {
  try {
    await file.delete();
  } on FileSystemException {
    // Already gone or never existed.
  }
}

Future<List<String>> loadAllBoardFiles() => _loadAllByExtension('.pensine');

Future<void> saveBoardFile(String id, String data) async {
  final dir = await _boardsDir;
  await File('${dir.path}/$id.pensine').writeAsString(data);
}

Future<void> deleteBoardFile(String id) async {
  final dir = await _boardsDir;
  await _deleteIfExists(File('${dir.path}/$id.pensine'));
}

Future<void> saveBoardOrderFile(List<String> ids) async {
  final dir = await _boardsDir;
  await File('${dir.path}/_order.json').writeAsString(ids.join('\n'));
}

Future<List<String>?> loadBoardOrderFile() async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/_order.json');
  if (!await file.exists()) return null;
  final data = await file.readAsString();
  return data.split('\n').where((s) => s.isNotEmpty).toList();
}

Future<List<String>> loadAllWorkspaceFiles() => _loadAllByExtension('.workspace');

Future<void> saveWorkspaceFile(String id, String data) async {
  final dir = await _boardsDir;
  await File('${dir.path}/$id.workspace').writeAsString(data);
}

Future<void> deleteWorkspaceFile(String id) async {
  final dir = await _boardsDir;
  await _deleteIfExists(File('${dir.path}/$id.workspace'));
}

Future<void> saveWorkspaceOrderFile(List<String> ids) async {
  final dir = await _boardsDir;
  await File('${dir.path}/_workspace_order.json').writeAsString(ids.join('\n'));
}

Future<List<String>?> loadWorkspaceOrderFile() async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/_workspace_order.json');
  if (!await file.exists()) return null;
  final data = await file.readAsString();
  return data.split('\n').where((s) => s.isNotEmpty).toList();
}

Future<String?> loadLegacyFile() async {
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/pensine_data.json');
  if (!await file.exists()) return null;
  final data = await file.readAsString();
  await file.delete();
  return data;
}
