import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lamazon/screens/campaign_manager.dart';
import 'package:lamazon/widgets/campaign_palette.dart';
import 'package:lamazon/widgets/design_system.dart';

/// The banner editor is where staff paste a link they found somewhere. It has
/// to say what it made of that link before they save it, because the thing
/// they most often paste — a Pinterest pin, an Instagram post — is a web page
/// and not a picture, and a banner pointed at one shows nothing at all.

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: LamazonTheme.data, home: const CampaignEditor()),
  );
  await tester.pump();
}

Future<void> _paste(WidgetTester tester, String url) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Artwork URL (optional)'),
    url,
  );
  // The preview trails the field on purpose, so let it settle.
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('the editor offers every theme, not three', (tester) async {
    await mockNetworkImagesFor(() async {
      await _open(tester);
      for (final palette in CampaignPalette.presets) {
        expect(
          find.bySemanticsLabel('Use ${palette.name}'),
          findsOneWidget,
          reason: '${palette.name} should be offered',
        );
      }
      expect(CampaignPalette.presets.length, 8);
    });
  });

  testWidgets('a pasted link is named for what it is', (tester) async {
    await mockNetworkImagesFor(() async {
      await _open(tester);

      // Exact strings: the hint above the field says "clip" too, and a finder
      // that matches either of them proves nothing about which one moved.
      Finder status(String text) =>
          find.descendant(of: find.byType(Row), matching: find.text(text));

      // Nothing pasted yet: say what may be pasted, including a page.
      expect(
        status(
          'Paste a link to a photo, GIF or clip — or a Pinterest, Instagram or '
          'blog page, then press Fetch and we will pull the picture out of it.',
        ),
        findsOneWidget,
      );

      await _paste(
        tester,
        'https://res.cloudinary.com/x/video/upload/v1/a.mp4',
      );
      expect(status('Clip — plays muted, loops, no sound.'), findsOneWidget);

      await _paste(
        tester,
        'https://res.cloudinary.com/x/image/upload/v1/a.gif',
      );
      expect(
        status('Animation — delivered as a clip, not as a GIF.'),
        findsOneWidget,
      );

      await _paste(
        tester,
        'https://res.cloudinary.com/x/image/upload/v1/a.jpg',
      );
      expect(
        status('Photo. If this is a page rather than a file, press Fetch.'),
        findsOneWidget,
      );

      // And the one mistake worth naming out loud.
      await _paste(tester, 'http://example.test/a.jpg');
      expect(status('Use a full https:// link.'), findsOneWidget);
    });
  });

  testWidgets('Fetch is offered only once there is a link to fetch', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await _open(tester);
      final fetch = find.widgetWithText(ActionButton, 'Fetch');
      expect(fetch, findsOneWidget);
      expect(
        tester.widget<ActionButton>(fetch).onPressed,
        isNull,
        reason: 'an empty field has nothing to fetch',
      );

      await _paste(tester, 'https://in.pinterest.com/pin/953496552383149749/');
      expect(tester.widget<ActionButton>(fetch).onPressed, isNotNull);
    });
  });
}
