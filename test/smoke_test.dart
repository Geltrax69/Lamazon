import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/main.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  testWidgets('home screen renders', (tester) async {
    await mockNetworkImagesFor(() => tester.pumpWidget(const LamazonApp()));
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('New Arrival'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('₹'), findsWidgets);
  });
}
