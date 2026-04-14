import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/main.dart';

void main() {
  testWidgets('App renders', (tester) async {
    await tester.pumpWidget(const PensineApp());
    expect(find.text('Pensine'), findsOneWidget);
  });
}
