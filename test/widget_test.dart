import 'package:flutter_test/flutter_test.dart';

import 'package:vango/main.dart';

void main() {
  testWidgets('VanGo inicializa sem falhar', (tester) async {
    await tester.pumpWidget(const VanGoApp());
    expect(find.byType(VanGoApp), findsOneWidget);
  });
}
