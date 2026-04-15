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

Future<List<String>> loadAllBoardFiles() async {
  final dir = await _boardsDir;
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pensine'));
  final results = <String>[];
  for (final file in files) {
    results.add(await file.readAsString());
  }
  return results;
}

Future<void> saveBoardFile(String id, String data) async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/$id.pensine');
  await file.writeAsString(data);
}

Future<void> deleteBoardFile(String id) async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/$id.pensine');
  if (await file.exists()) {
    await file.delete();
  }
}

Future<void> saveBoardOrderFile(List<String> ids) async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/_order.json');
  await file.writeAsString(ids.join('\n'));
}

Future<List<String>?> loadBoardOrderFile() async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/_order.json');
  if (await file.exists()) {
    final data = await file.readAsString();
    return data.split('\n').where((s) => s.isNotEmpty).toList();
  }
  return null;
}

// --- Workspace files ---

Future<List<String>> loadAllWorkspaceFiles() async {
  final dir = await _boardsDir;
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.workspace'));
  final results = <String>[];
  for (final file in files) {
    results.add(await file.readAsString());
  }
  return results;
}

Future<void> saveWorkspaceFile(String id, String data) async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/$id.workspace');
  await file.writeAsString(data);
}

Future<void> deleteWorkspaceFile(String id) async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/$id.workspace');
  if (await file.exists()) {
    await file.delete();
  }
}

Future<void> saveWorkspaceOrderFile(List<String> ids) async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/_workspace_order.json');
  await file.writeAsString(ids.join('\n'));
}

Future<List<String>?> loadWorkspaceOrderFile() async {
  final dir = await _boardsDir;
  final file = File('${dir.path}/_workspace_order.json');
  if (await file.exists()) {
    final data = await file.readAsString();
    return data.split('\n').where((s) => s.isNotEmpty).toList();
  }
  return null;
}

// Legacy support — migrate old single-file storage
Future<String?> loadLegacyFile() async {
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/pensine_data.json');
  if (await file.exists()) {
    final data = await file.readAsString();
    await file.delete();
    return data;
  }
  return null;
}
