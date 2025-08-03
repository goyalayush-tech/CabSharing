import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/app.dart';

void main() {
  testWidgets('RideLink app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RideLinkApp());

    // Verify that the app starts with the splash screen
    expect(find.text('RideLink'), findsOneWidget);
    expect(find.text('Share the journey, split the cost'), findsOneWidget);
  });
}