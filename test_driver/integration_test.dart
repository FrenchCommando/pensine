import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        if (data == null) return;
        final screenshots = data['screenshots'] as List<dynamic>?;
        if (screenshots == null) return;
        final dir = Directory('build/screenshots');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        for (final screenshot in screenshots) {
          final name = screenshot['screenshotName'] as String;
          final bytes = (screenshot['bytes'] as List<dynamic>).cast<int>();
          File('${dir.path}/$name.png').writeAsBytesSync(bytes);
        }
      },
    );
