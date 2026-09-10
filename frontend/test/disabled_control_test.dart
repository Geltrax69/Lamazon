import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lamazon/widgets/design_system.dart';

/// A disabled control has to look disabled.
///
/// The cart's "+" at the stock cap was correctly inert — pressing it did
/// nothing — but it kept its full lime fill and raised shadow, so it read as
/// a broken button rather than as a limit. The reason it was inert was only
/// available as a tooltip, which is to say only to a mouse that happened to
/// hover.
Widget _wrap(Widget child) =>
    MaterialApp(theme: LamazonTheme.data, home: Scaffold(body: Center(child: child)));

Color _fillOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(TactileIconButton),
      matching: find.byType(DecoratedBox),
    ).first,
  );
  final decoration = box.decoration as BoxDecoration;
  // The button paints a two-stop gradient; the second stop is the base colour.
  return (decoration.gradient! as LinearGradient).colors.last;
}

List<BoxShadow> _shadowOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(TactileIconButton),
      matching: find.byType(DecoratedBox),
    ).first,
  );
  return (box.decoration as BoxDecoration).boxShadow ?? const [];
}

void main() {
  testWidgets('an enabled icon button keeps its fill and its lift', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TactileIconButton(
          icon: LucideIcons.plus,
          label: 'Increase quantity',
          selected: true,
          onPressed: () {},
        ),
      ),
    );
    expect(_fillOf(tester), LamazonTheme.lime);
    expect(_shadowOf(tester), isNotEmpty);
    expect(
      tester.getSemantics(find.byType(TactileIconButton)),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        isSelected: true,
        hasSelectedState: true,
        label: 'Increase quantity',
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
  });

  testWidgets('a disabled icon button is visibly, not just functionally, off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const TactileIconButton(
          icon: LucideIcons.plus,
          // The label carries the reason, so it is not colour alone.
          label: 'That is all the shop has',
          selected: true,
          onPressed: null,
        ),
      ),
    );
    expect(
      _fillOf(tester),
      LamazonTheme.track,
      reason: 'a capped control must not keep the lime of a live one',
    );
    expect(
      _shadowOf(tester),
      isEmpty,
      reason: 'nothing raised about a control that cannot be pressed',
    );
    expect(
      tester.getSemantics(find.byType(TactileIconButton)),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isSelected: true,
        hasSelectedState: true,
        label: 'That is all the shop has',
      ),
      reason: 'and it says why, for anyone who cannot see the colour',
    );
  });
}
