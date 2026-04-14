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
