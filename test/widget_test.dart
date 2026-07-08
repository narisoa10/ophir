import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/app/app.dart';

void main() {
  testWidgets('Ophir app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const OphirApp());

    expect(find.text('Ophir'), findsOneWidget);
  });
}