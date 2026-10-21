import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remoteflow_max/main.dart';

void main() {
  testWidgets('RemoteFlowMaxApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RemoteFlowMaxApp()));
    expect(find.byType(RemoteFlowMaxApp), findsOneWidget);
  });
}
