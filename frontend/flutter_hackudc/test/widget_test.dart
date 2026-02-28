import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hackudc/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Administrador de becas'), findsOneWidget);
  });
}
