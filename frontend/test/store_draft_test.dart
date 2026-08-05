import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lamazon/data/seller.dart';
import 'package:lamazon/screens/seller_onboarding_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Leaving the store form must not cost the seller the photo they picked and
/// the name they typed — that is a trip back to the camera roll.
void main() {
  setUp(StoreDraft.clear);
  tearDown(StoreDraft.clear);

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SellerOnboardingScreen()),
    );
    await tester.pump();
  }

  testWidgets('going back offers to keep what was filled in', (tester) async {
    await mockNetworkImagesFor(() async {
      await openForm(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Campus Snacks Corner'),
        'Campus Snacks',
      );
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();
      expect(find.text('Keep this for later?'), findsOneWidget);

      await tester.tap(find.text('Keep draft'));
      await tester.pump();
      // Kept, so the form can restore it — that restore is one controller
      // initialiser, and this is the state it reads.
      expect(StoreDraft.name, 'Campus Snacks');
    });
  });

  testWidgets('discarding really discards', (tester) async {
    await mockNetworkImagesFor(() async {
      await openForm(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Campus Snacks Corner'),
        'Gone',
      );
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(StoreDraft.isEmpty, isTrue);
      expect(StoreDraft.name, isEmpty);
      expect(StoreDraft.photo, isNull);
    });
  });

  testWidgets('an untouched form asks nothing', (tester) async {
    await mockNetworkImagesFor(() async {
      await openForm(tester);
      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();
      expect(find.text('Keep this for later?'), findsNothing);
    });
  });
}
