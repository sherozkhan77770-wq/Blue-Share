import 'package:flutter_test/flutter_test.dart';
import 'package:blueshare/main.dart';

void main() {
  testWidgets('BlueShare app opens successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BlueShareApp());

    expect(find.text('BlueShare'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Calls'), findsOneWidget);
  });
}
