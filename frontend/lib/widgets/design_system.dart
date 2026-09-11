import 'package:flutter/material.dart';

/// Shared visual vocabulary for shopping and operating surfaces.
///
/// The aliases at the bottom of the color list keep existing functional
/// surfaces readable while they are migrated to the semantic token names.
abstract final class LamazonTheme {
  static const text = Color(0xFF17221D);
  static const muted = Color(0xFF66716A);
  static const strong = Color(0xFF1D4939);
  static const track = Color(0xFFE1E5DD);
  static const canvas = Color(0xFFF7F6F0);
  static const surface = Color(0xFFFFFDF8);
  static const forest = Color(0xFF143E32);
  static const lime = Color(0xFFC6EE63);
  static const peach = Color(0xFFF58268);
  static const danger = Color(0xFFB93643);

  /// Attention that is not yet a failure: a store waiting for review, stock
  /// running low, an order nobody has accepted.
  ///
  /// The admin panel used stock Material orange `#EF6C00`, which measured
  /// **2.85:1 on canvas** — under even the 3:1 floor for large text, on
  /// precisely the states that most need reading. This measures 5.33:1 on
  /// canvas and 5.00:1 on surface, and it is a warm ochre rather than a
  /// safety-cone orange, so it belongs to the same world as forest and ivory.
  static const warning = Color(0xFF9A5B12);

  // Compatibility names for existing routes. New UI should use semantic names.
  static const ink = text;
  static const accent = lime;
  static const green = strong;
  static const line = track;

  static const radius = 16.0;
  static const smallRadius = 12.0;
  static const featuredRadius = 18.0;
  static const touch = 44.0;

  /// Buttons are pills. ActionButton hardcoded a 23px radius — half of its
  /// 46px height, so a pill by arithmetic — while the Material button themes
  /// used featuredRadius and came out as rounded rectangles. Two primary
  /// buttons, two shapes, 50 call sites between them. StadiumBorder says
  /// "pill" at any height, so both now agree without a magic number.
  static const pill = StadiumBorder();

  /// Focus is an outline, not only a wash. The lime background alone measured
  /// 1.10:1 against the surface behind it, where WCAG 1.4.11 asks for 3:1 —
  /// and controls outside the handful that set focusColor painted nothing at
  /// all. `strong` on `surface` measures about 8:1.
  static const focusOutline = 2.0;
  static const focusColour = strong;
  static BorderSide get focusBorder =>
      const BorderSide(color: focusColour, width: focusOutline);

  /// Wrap anything focusable that does not inherit a themed focus ring.
  static WidgetStateProperty<BorderSide?> focusSide(BorderSide? rest) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? focusBorder : rest,
      );

  static const surfaceShadows = <BoxShadow>[
    BoxShadow(
      color: Color(0x120D2119),
      offset: Offset(0, 2),
      blurRadius: 5,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x130D2119),
      offset: Offset(0, 13),
      blurRadius: 28,
      spreadRadius: -10,
    ),
  ];

  static const raisedShadows = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A0D2119),
      offset: Offset(0, 3),
      blurRadius: 6,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x180D2119),
      offset: Offset(0, 10),
      blurRadius: 22,
      spreadRadius: -10,
    ),
  ];

  static const tactileShadows = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0D2119),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x100D2119),
      offset: Offset(0, 10),
      blurRadius: 18,
      spreadRadius: -9,
    ),
  ];

  static const titleText = TextStyle(
    fontFamily: 'InterTight',
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.7,
    color: text,
  );
  static const sectionText = TextStyle(
    fontFamily: 'InterTight',
    fontSize: 19,
    height: 24 / 19,
    fontWeight: FontWeight.w600,
    // Negative, like every other heading. Positive tracking on a 19px
    // semi-bold loosens it into looking like a label rather than a heading.
    letterSpacing: -0.6,
    color: text,
  );
  static const bodyText = TextStyle(
    fontFamily: 'InterTight',
    fontSize: 14.5,
    height: 18 / 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: text,
  );
  static const mutedBodyText = TextStyle(
    fontFamily: 'InterTight',
    fontSize: 14.5,
    height: 18 / 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: muted,
  );

  static double gutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return 32;
    if (width >= 720) return 24;
    return 16;
  }

  static ThemeData get data {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: forest,
          brightness: Brightness.light,
        ).copyWith(
          primary: forest,
          onPrimary: Colors.white,
          secondary: lime,
          onSecondary: text,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: muted,
          outline: track,
          error: danger,
        );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(featuredRadius),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'InterTight',
      pageTransitionsTheme: PageTransitionsTheme(
        // Every platform, so the app does not change character with the
        // browser it is opened in.
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const _RisePageTransition(),
        },
      ),
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      focusColor: lime.withValues(alpha: .42),
      hoverColor: strong.withValues(alpha: .06),
      splashColor: strong.withValues(alpha: .10),
      textTheme: const TextTheme(
        headlineMedium: titleText,
        titleLarge: titleText,
        titleMedium: sectionText,
        titleSmall: TextStyle(
          fontFamily: 'InterTight',
          fontSize: 16,
          height: 20 / 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: text,
        ),
        bodyLarge: bodyText,
        bodyMedium: bodyText,
        bodySmall: TextStyle(
          fontFamily: 'InterTight',
          fontSize: 12.5,
          height: 16 / 12.5,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontFamily: 'InterTight',
          fontSize: 14,
          height: 18 / 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: mutedBodyText,
        hintStyle: mutedBodyText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(featuredRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(featuredRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(featuredRadius),
          borderSide: const BorderSide(color: strong, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(featuredRadius),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          backgroundColor: forest,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: forest.withValues(alpha: .26),
          textStyle: const TextStyle(
            fontFamily: 'InterTight',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: .15,
          ),
          shape: pill,
        ).copyWith(side: focusSide(null)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 46),
          foregroundColor: strong,
          side: BorderSide.none,
          textStyle: const TextStyle(
            fontFamily: 'InterTight',
            fontWeight: FontWeight.w600,
          ),
          shape: pill,
        ).copyWith(side: focusSide(BorderSide.none)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: strong,
          textStyle: const TextStyle(
            fontFamily: 'InterTight',
            fontWeight: FontWeight.w600,
          ),
          shape: pill,
        ).copyWith(side: focusSide(null)),
      ),
      iconButtonTheme: IconButtonThemeData(
        // touch x touch is the WCAG 2.5.8 minimum, applied here once rather
        // than per icon.
        style: IconButton.styleFrom(
          minimumSize: const Size(touch, touch),
          foregroundColor: strong,
        ).copyWith(side: focusSide(null)),
      ),
      // Chips are used as single-select choices in several places, so they
      // get the same visible focus as everything else.
      chipTheme: ChipThemeData(
        // WidgetStateBorderSide, because ChipThemeData.side is a BorderSide
        // rather than a property — this is the state-aware BorderSide.
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? focusBorder
              : const BorderSide(color: track),
        ),
        showCheckmark: false,
        backgroundColor: surface,
        selectedColor: lime,
        labelStyle: const TextStyle(
          fontFamily: 'InterTight',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      // Above the control, not below it. A tooltip below drops straight onto
      // whatever the control is sitting above — the stock cap's "That is all
      // the shop has" landed over the "About this product" heading on every
      // product page. Flutter still flips it back down when there is no room
      // overhead, so the only thing this changes is which side it prefers.
      tooltipTheme: const TooltipThemeData(
        preferBelow: false,
        verticalOffset: 22,
      ),
      cardTheme: CardThemeData(elevation: 0, color: surface, shape: rounded),
      dividerTheme: const DividerThemeData(color: track, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: lime.withValues(alpha: .74),
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'InterTight',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: text,
          ),
        ),
      ),
    );
  }
}

/// Every push, on every platform, arrives the same way: a short fade with a
/// small rise under it.
///
/// The defaults do not agree with each other — Android zooms the incoming page
/// behind a scrim, iOS and macOS slide the whole screen in from the right with
/// a parallax and an edge shadow — so opening the cart looked like a different
/// application depending on the browser it was opened in, and on a wide screen
/// a full-width horizontal slide reads as a phone gesture that wandered onto a
/// desktop. This is quieter than either and says the same thing: something new
/// is on top now.
class _RisePageTransition extends PageTransitionsBuilder {
  const _RisePageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        // A sixtieth of the screen. Enough to read as arriving, small enough
        // that nothing appears to move across the page.
        position: Tween(
          begin: const Offset(0, 1 / 60),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Raised, shadow-led material for cards and task panels. It deliberately uses
/// no visible outline so one elevation language works everywhere.
class ElevatedSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool prominent;
  const ElevatedSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = LamazonTheme.radius,
    this.color = LamazonTheme.surface,
    this.onTap,
    this.semanticLabel,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    // A label plus the labelled subtree is two announcements of the same
    // control, so a labelled surface silences its contents. It silences the
    // *contents*, not the InkWell above them: excludeSemantics on the whole
    // subtree took the focusable node with it and dropped the surface out of
    // the tab order altogether.
    final inner = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    final content = semanticLabel == null
        ? inner
        : ExcludeSemantics(child: inner);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: prominent
            ? LamazonTheme.raisedShadows
            : LamazonTheme.surfaceShadows,
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                customBorder: shape,
                focusColor: LamazonTheme.lime.withValues(alpha: .36),
                child: content,
              ),
      ),
    );
    // The app's focus ring, not the lime wash on its own. That wash measures
    // 1.10:1 against the surface behind it against a 3:1 requirement, and it
    // was all the home search field — the most-used control on the shop — had
    // to show for focus, while every icon button beside it got a 10:1 ring.
    // Drawn outside the Material so the clip does not eat the outline.
    final focusable = onTap == null
        ? surface
        : FocusRing(
            borderRadius: BorderRadius.circular(radius),
            child: surface,
          );

    // A card that is only a card says nothing about itself. Annotating
    // unconditionally — `button: false` counts as an annotation — collapsed
    // everything inside into one node, so a sign-in card announced its
    // heading, field, button and helper text as a single text field and the
    // button stopped being a button.
    if (onTap == null && semanticLabel == null) return focusable;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: focusable,
    );
  }
}

/// A 38–46px circular tactile control with a small upper-left highlight.
class TactileIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? foreground;
  final Color? background;
  final double size;

  /// Shrinks the drawn disc inside an unchanged tap target. A control can be
  /// quieter without becoming harder to hit, and across a grid of nine cards
  /// that difference is the difference between a shop and a control panel.
  final double inset;

  /// Drops the layered shadow. Elevation is for a control floating above the
  /// page; one sitting on a photograph inside a card is already there.
  final bool flat;
  const TactileIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.foreground,
    this.background,
    this.size = LamazonTheme.touch,
    this.inset = 0,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    // A disabled control has to look disabled. Without this a capped "+" in
    // the cart kept its full lime fill and simply did nothing when pressed,
    // which reads as a broken button rather than as a limit — and the tooltip
    // saying why is only available to a mouse that happens to hover.
    //
    // The out-of-stock card already does this properly: grey plus a text
    // label, never colour alone. This brings every other icon button in the
    // app up to that standard.
    final enabled = onPressed != null;
    final base = enabled
        ? (background ?? (selected ? LamazonTheme.lime : LamazonTheme.surface))
        : LamazonTheme.track;
    final color = enabled
        ? (foreground ?? LamazonTheme.strong)
        : LamazonTheme.muted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      selected: selected,
      child: SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: FocusRing(
            shape: BoxShape.circle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(Colors.white.withValues(alpha: .52), base),
                    base,
                  ],
                ),
                // Nothing raised about a control that cannot be pressed.
                boxShadow: enabled && !flat
                    ? LamazonTheme.tactileShadows
                    : const <BoxShadow>[],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                // excludeFromSemantics because the Semantics above already
                // names this control. Without it every icon button announced
                // its label twice — "Back Back", "Open account Open account".
                child: Tooltip(
                  message: label,
                  excludeFromSemantics: true,
                  child: InkWell(
                    onTap: onPressed,
                    customBorder: const CircleBorder(),
                    focusColor: LamazonTheme.lime.withValues(alpha: .42),
                    child: Center(
                      child: Icon(
                        icon,
                        size: inset > 0 ? 17 : 20,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text action that shares the highlight and shadow language of icon actions.
/// Paints the focus outline WCAG 1.4.11 asks for around whatever is focused
/// inside it.
///
/// The app's focus state was a lime background wash and nothing else, which
/// measured 1.10:1 against the surface behind it against a 3:1 requirement —
/// and only five code paths set it at all, so most controls showed no focus
/// whatsoever. This draws over the top of the child rather than around it, so
/// nothing moves when focus arrives.
class FocusRing extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  const FocusRing({
    super.key,
    required this.child,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // canRequestFocus: false keeps this node out of the tab order; hasFocus
    // is still true whenever a descendant holds focus, which is the whole
    // point — the ring belongs to whatever the InkWell inside is doing.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (has) {
        if (has != _focused) setState(() => _focused = has);
      },
      child: Stack(
        children: [
          widget.child,
          if (_focused)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: widget.shape,
                    borderRadius: widget.shape == BoxShape.circle
                        ? null
                        : widget.borderRadius ??
                              BorderRadius.circular(LamazonTheme.radius),
                    border: Border.fromBorderSide(LamazonTheme.focusBorder),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expand;

  /// Shows a spinner in place of the icon and marks the control busy to
  /// assistive technology. Async actions changed only their label ("Placing
  /// your order…"), which is nothing to look at during the seconds that
  /// matter most — and nothing at all if you are not reading the button.
  ///
  /// Setting this does not disable the button; pass `onPressed: null` too.
  /// Keeping them separate means a caller can show progress on a control
  /// that is still legitimately pressable.
  final bool loading;
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expand = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = primary ? LamazonTheme.forest : LamazonTheme.surface;
    final foreground = primary ? Colors.white : LamazonTheme.strong;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'InterTight',
        color: foreground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: .15,
      ),
    );
    final body = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(foreground),
            ),
          ),
          const SizedBox(width: 9),
        ],
        Flexible(fit: FlexFit.loose, child: labelText),
        // The spinner replaces the icon rather than crowding in beside it.
        if (icon != null && !loading) ...[
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: foreground),
        ],
      ],
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      // Announced as busy, so the wait is not silent to a screen reader.
      liveRegion: loading,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: FocusRing(
          borderRadius: BorderRadius.circular(999),
          child: _material(body, base),
        ),
      ),
    );
  }

  Widget _material(Widget body, Color base) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: primary ? .14 : .60),
              base,
            ),
            base,
          ],
        ),
        boxShadow: LamazonTheme.tactileShadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          focusColor: LamazonTheme.lime.withValues(alpha: .4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46, minWidth: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const ActionIcon({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) =>
      TactileIconButton(icon: icon, label: label, onPressed: onPressed);
}

class TrackDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  const TrackDivider({super.key, this.indent = 0, this.endIndent = 0});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
    child: const ColoredBox(
      color: LamazonTheme.track,
      child: SizedBox(height: 1),
    ),
  );
}

/// A section title, and the heading a screen reader jumps between.
///
/// The app had heading semantics in exactly two widgets, so most screens were
/// one flat run of text with no way to skip through it. Anywhere a title was
/// drawn as a bare Text in [LamazonTheme.sectionText] now draws it here
/// instead, which is the same pixels and one more piece of structure.
class SectionTitle extends StatelessWidget {
  final String text;
  final int level;
  final TextStyle? style;
  const SectionTitle(this.text, {super.key, this.level = 2, this.style});

  @override
  Widget build(BuildContext context) => Semantics(
    headingLevel: level,
    // Its own node, or the annotation merges into whatever sits beside it and
    // the heading announces the subtitle under it as part of its own name.
    container: true,
    child: Text(text, style: style ?? LamazonTheme.sectionText),
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String actionLabel;
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel = 'See all',
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // headingLevel 2: this is the widget every screen uses for its
            // section titles, so one change gives the whole app a heading
            // outline a screen reader can navigate.
            SectionTitle(title),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: LamazonTheme.mutedBodyText),
            ],
          ],
        ),
      ),
      // One control, not two. This used to be a "See all" text button with an
      // arrow button beside it doing the identical thing, and the pair took
      // enough width to wrap the heading it sat next to.
      if (onAction != null) ...[
        const SizedBox(width: 8),
        TextButton(
          onPressed: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ],
    ],
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message, action;
  final VoidCallback onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: ElevatedSurface(
      radius: LamazonTheme.featuredRadius,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: LamazonTheme.lime,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: LamazonTheme.strong),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: LamazonTheme.titleText,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: LamazonTheme.mutedBodyText,
          ),
          const SizedBox(height: 22),
          ActionButton(label: action, onPressed: onAction),
        ],
      ),
    ),
  );
}

class Skeleton extends StatelessWidget {
  final double? width, height;
  final double radius;
  const Skeleton({super.key, this.width, this.height, this.radius = 12});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F0E9), Color(0xFFE5E8DF)],
        ),
      ),
    ),
  );
}

class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading products',
    liveRegion: true,
    child: ListView(
      padding: EdgeInsets.all(LamazonTheme.gutter(context)),
      children: [
        const Skeleton(width: 132, height: 28, radius: 14),
        const SizedBox(height: 16),
        const Skeleton(height: 58, radius: 18),
        const SizedBox(height: 18),
        const Skeleton(height: 220, radius: 18),
        const SizedBox(height: 30),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: .68,
          ),
          itemBuilder: (_, _) => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Skeleton(radius: 16)),
              SizedBox(height: 10),
              Skeleton(height: 16, radius: 8),
              SizedBox(height: 7),
              Skeleton(width: 80, height: 16, radius: 8),
            ],
          ),
        ),
      ],
    ),
  );
}
