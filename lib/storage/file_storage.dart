import 'dart:io';
import 'package:path_provider/path_provider.dart';

const _fileName = 'pensine_data.json';

Future<File> get _file async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/$_fileName');
}

Future<String?> loadFromFile() async {
  final file = await _file;
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> saveToFile(String data) async {
  final file = await _file;
  await file.writeAsString(data);
}
