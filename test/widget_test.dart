import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter host can render a Cupertino app', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(child: Text('拾页')),
      ),
    );

    expect(find.text('拾页'), findsOneWidget);
  });
}
