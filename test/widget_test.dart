import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/main.dart';

void main() {
  testWidgets('App smoke test loads login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PosApp());

    // Verify that the login screen header text is rendered
    expect(find.text('POS Mobile App'), findsOneWidget);
  });
}
