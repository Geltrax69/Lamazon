import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:lamazon/screens/login_screen.dart';
import 'package:lamazon/widgets/design_system.dart';

/// The sign-in field.
///
/// QA saw a fast programmatic type drop nine leading characters and could not
/// establish why. It does not reproduce: a release build keeps every character
/// at zero typing delay, whether the field is reached by Tab or by click, and
/// real clipboard paste lands intact — measured on the build before these
/// changes as well as after. The likeliest explanation is a harness typing
/// into a Flutter canvas before the DOM input existed to receive it.
///
/// So these two assertions are not guarding a fixed bug. They guard the two
/// things that were genuinely missing or wasteful: a field that tells a
/// password manager what it is, and a keystroke that redraws three widgets
/// instead of the whole screen including its animated backdrop.
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(theme: null, home: LoginScreen()),
    );
    // Not pumpAndSettle: the backdrop animates forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('typing does not rebuild the animated backdrop', (tester) async {
    await mockNetworkImagesFor(() async {
      await open(tester);

      await tester.enterText(find.byType(TextField), 'qa3.buyer@lamazon.test');
      await tester.pump();

      expect(
        find.text('qa3.buyer@lamazon.test'),
        findsOneWidget,
        reason: 'every character typed has to survive the rebuild',
      );
      // The assertion that matters: a keystroke does not go through the
      // screen's setState any more. It goes to a builder listening to the
      // controller, which owns the field, the button and the line under them
      // and nothing else — the backdrop is outside it.
      expect(
        tester.widget<TextField>(find.byType(TextField)).onChanged,
        isNull,
        reason: 'onChanged: setState rebuilt the marquee once per character',
      );
      expect(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(ListenableBuilder),
        ),
        findsWidgets,
      );

      // And the button woke up, which is the only reason the rebuild exists.
      final button = tester.widget<ActionButton>(
        find.widgetWithText(ActionButton, 'Continue'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  testWidgets('the field tells a password manager what it is', (tester) async {
    await mockNetworkImagesFor(() async {
      await open(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.autofillHints,
        contains(AutofillHints.email),
        reason: 'without a hint there is nothing for autofill to aim at',
      );
      expect(
        field.key,
        isNotNull,
        reason: 'each step is its own field, not one field changing its mind',
      );
      expect(find.byType(AutofillGroup), findsOneWidget);
    });
  });
}
