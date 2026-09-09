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

  // Compatibility names for existing routes. New UI should use semantic names.
  static const ink = text;
  static const accent = lime;
  static const green = strong;
  static const line = track;

  static const radius = 16.0;
  static const smallRadius = 12.0;
  static const featuredRadius = 18.0;
  static const touch = 44.0;

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
          shape: rounded,
        ),
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
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: strong,
          textStyle: const TextStyle(
            fontFamily: 'InterTight',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(touch, touch),
          foregroundColor: strong,
        ),
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
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: DecoratedBox(
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
      ),
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
  const TactileIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.foreground,
    this.background,
    this.size = LamazonTheme.touch,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        background ?? (selected ? LamazonTheme.lime : LamazonTheme.surface);
    final color = foreground ?? LamazonTheme.strong;
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: SizedBox(
        width: size,
        height: size,
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
            boxShadow: LamazonTheme.tactileShadows,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Tooltip(
              message: label,
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                focusColor: LamazonTheme.lime.withValues(alpha: .42),
                child: Center(child: Icon(icon, size: 20, color: color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text action that shares the highlight and shadow language of icon actions.
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expand;
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expand = false,
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
        Flexible(fit: FlexFit.loose, child: labelText),
        if (icon != null) ...[
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: foreground),
        ],
      ],
    );
    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
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
          borderRadius: BorderRadius.circular(23),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            focusColor: LamazonTheme.lime.withValues(alpha: .4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46, minWidth: 46),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: body,
              ),
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
            Text(title, style: LamazonTheme.sectionText),
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
