
import 'package:flutter_test/flutter_test.dart';
import 'package:mg_leave/main.dart';

void main() {
  testWidgets('MG Leave Management app test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MGLeaveApp());

    expect(find.text('MG LEAVE MANAGEMENT'), findsOneWidget);
    expect(find.text('ระบบจัดการการลางาน'), findsOneWidget);
  });
}
