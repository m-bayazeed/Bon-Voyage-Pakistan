import 'package:flutter_test/flutter_test.dart';
import 'package:bon_voyage_pakistan/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const BonVoyageApp());
  });
}
