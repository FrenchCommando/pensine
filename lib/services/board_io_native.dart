import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportFile(String filename, String content) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop: save file dialog
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export board',
      fileName: filename,
    );
    if (path != null) {
      await File(path).writeAsString(content);
    }
  } else {
    // Mobile: share sheet
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }
}
