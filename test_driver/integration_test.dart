import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart' show Response;

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  final jsonResult =
      await driver.requestData(null, timeout: const Duration(minutes: 20));
  final response = Response.fromJson(jsonResult);
  await driver.close();

  // Extract screenshots to build/screenshots/
  final data = response.data;
  if (data != null && data.containsKey('screenshots')) {
    final dir = Directory('build/screenshots');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final screenshots = data['screenshots'] as List<dynamic>;
    for (final screenshot in screenshots) {
      final name = screenshot['screenshotName'] as String;
      final bytes = base64Decode(screenshot['bytes'] as String);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      // ignore: avoid_print
      print('Saved $name.png');
    }
  }

  if (response.allTestsPassed) {
    // ignore: avoid_print
    print('All tests passed.');
    exit(0);
  } else {
    // ignore: avoid_print
    print('Failure Details:\n${response.formattedFailureDetails}');
    exit(1);
  }
}
