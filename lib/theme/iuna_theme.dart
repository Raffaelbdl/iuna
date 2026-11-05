import 'package:flutter/material.dart';

import '../db/database.dart';

/// Warm cream "Kuma cozy" palette from the redesign handoff.
class IunaPalette {
  // ── Surfaces ──
  static const bg = Color(0xFFFBF3E2);
  static const bg2 = Color(0xFFF7E9D0);
  static const paper = Color(0xFFFFFDF6);
  static const paper2 = Color(0xFFFDF6E6);

  // ── Ink (text) ──
  static const ink = Color(0xFF4A3520);
  static const ink2 = Color(0xFF6B4F33);
  // ink3 clears 4.5:1 on bg, bg2, paper and paper2; inkMute does not,
  // so it is for disabled and decorative marks only, never for text.
  static const ink3 = Color(0xFF766250);
  static const inkMute = Color(0xFFB9A285);

  // ── Signal accents ──
  static const bowPink = Color(0xFFF3A7B5);
  static const bowMint = Color(0xFFB8D8C9);
  static const bellGold = Color(0xFFE8B96B);
  static const bowPinkDeep = Color(0xFFD97A8C);
  // The deep honey of the Collection progress bar and active chips.
  static const honey = Color(0xFFF0B66C);
  // The fill of a picked answer or option.
  static const optionPicked = Color(0xFFFDE9C9);

  // Status text that must clear 4.5:1 on paper and bg ("Review again",
  // "Continue", the stats goal line). The pastel accents above do not.
  static const mintInk = Color(0xFF3F6A52);
  static const honeyInk = Color(0xFF8A5A14);
  static const pinkInk = Color(0xFFA8455A);
  // Destructive actions: "Remove key", "Delete course", "Replace".
  static const danger = Color(0xFF9E3B33);

  // ── Right / wrong (review grades, swipe tints) ──
  static const rightFill = Color(0xFFD9EEE2);
  static const rightFillDeep = Color(0xFFB6DCC6);
  static const rightInk = Color(0xFF1F5A40);
  static const rightWash = Color(0x997BC47F);
  static const wrongFill = Color(0xFFFDE2E7);
  static const wrongFillDeep = Color(0xFFF7C0CB);
  static const wrongInk = Color(0xFF7A2A3A);
  static const wrongWash = Color(0x99E57373);

  // ── Ink washes for borders and rules ──
  static const hairline = Color.fromRGBO(74, 53, 32, 0.06);
  static const divider = Color.fromRGBO(74, 53, 32, 0.08);
  static const outline = Color.fromRGBO(74, 53, 32, 0.12);

  // ── Misc. tints ──
  static const lilacWash = Color(0x59C4B2E0);
  static const honeyPale = Color(0xFFFFE9A8);
  // Paper laid over a tinted ground: a section on a sheet, a
  // suspended tile.
  static const paperGlass = Color(0x66FFFDF6);
  static const flame = Color(0xFFD97A3A);

  // ── Chart fills (Stats) ──
  static const chartMint = Color(0xFFA9D4C2);
  static const chartMintDeep = Color(0xFF7FBFA3);
  static const chartHoney = Color(0xFFF0C168);
  static const chartHoneyDeep = Color(0xFFD49A3A);
  static const chartBlue = Color(0xFFBCD3DF);
  static const chartBlueDeep = Color(0xFF7FAABE);
  static const chartLilac = Color(0xFFC4B2E0);
  static const chartLilacDeep = Color(0xFF9A7EC5);
  static const chartLearning = Color(0xFFDFE8D8);
  static const chartLearningInk = Color(0xFF4F6E4B);
  static const chartMatureInk = Color(0xFF4A6F82);
  static const chartGrid = Color.fromRGBO(74, 53, 32, 0.08);
  static const chartGridStrong = Color.fromRGBO(74, 53, 32, 0.14);
  static const chipBg = Color.fromRGBO(74, 53, 32, 0.06);
  static const heatmap0 = Color.fromRGBO(74, 53, 32, 0.05);
  static const heatmap1 = Color(0xFFDFE8D8);
  static const heatmap2 = Color(0xFFBDD9C4);
  static const heatmap3 = Color(0xFF92C4A8);
  static const heatmap4 = Color(0xFF5FA982);

  // ── Hero gradient (Home hero, logo, active chips) ──
  static const heroTop = Color(0xFFFFD994);
  static const heroInk = Color(0xFF3A2510);

  // ── CTA gradient stops ──
  static const ctaTop = Color(0xFFFFD58A);
  static const ctaMid = Color(0xFFF0B56A);
  static const ctaBottom = Color(0xFFD99550);

  // ── Rarity tints (approximate sRGB of the design's OkLCH values) ──
  static const rarityCommon = Color(0xFFC7E0CF); // sage 150
  static const rarityRare = Color(0xFFB8D2EA); // sky 230
  static const raritySuperRare = Color(0xFFE0B8DC); // orchid 320
  static const raritySsr = Color(0xFFF2BBA9); // coral 20
  static const rarityUr = Color(0xFFEED199); // gold 80

  // Lighter, fill-tinted variants used for hero tints / gradient bottoms.
  static const rarityCommonFill = Color(0xFFE5F2EA);
  static const rarityRareFill = Color(0xFFDFEBF7);
  static const raritySuperRareFill = Color(0xFFF1DEEF);
  static const raritySsrFill = Color(0xFFFADCD0);
  static const rarityUrFill = Color(0xFFF8E5C2);

  // Strong rarity foreground (chip text colour).
  static const rarityCommonInk = Color(0xFF3F6A52);
  static const rarityRareInk = Color(0xFF335678);
  static const raritySuperRareInk = Color(0xFF6B3672);
  static const raritySsrInk = Color(0xFF883A2A);
  static const rarityUrInk = Color(0xFF7A5418);

  // Pre-redesign names, still the spelling most Settings code uses.
  static const cream = bg;
  static const pawBrown = ink;
}

/// The type scale: seven sizes, 12 to 28. Every text style on screen
/// starts from one of these and may change its colour or weight, never
/// its size. They carry no colour, so text keeps the ink it inherits
/// unless a screen sets one. Japanese shown as content (a card's kanji,
/// a game's tiles) is sized to its layout instead.
abstract final class IunaText {
  /// A screen's one big line: the recap headline, a game's result.
  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Hero titles, tab titles and big numbers.
  static const headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// Sheet and panel titles.
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

  /// Row titles, top-bar titles and primary buttons.
  static const subtitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  /// Lead text: a greeting, a lesson's prose.
  static const bodyLarge = TextStyle(fontSize: 16);

  /// Running text.
  static const body = TextStyle(fontSize: 14);

  /// Secondary lines under a title, hints and notes.
  static const bodySmall = TextStyle(fontSize: 13);

  /// Metadata, legends and chart labels: the floor for readable text.
  static const caption = TextStyle(fontSize: 12);

  /// Button and control labels.
  static const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  /// Chips, badges and pills.
  static const chip = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  /// The upper-cased caption over a section.
  static const eyebrow = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );
}

/// Standard panel shadow (light, top-highlighted).
List<BoxShadow> panelShadow() => const [
  BoxShadow(color: Color(0x0F4A3520), blurRadius: 18, offset: Offset(0, 6)),
  BoxShadow(color: Color(0xB3FFFFFF), blurRadius: 0, offset: Offset(0, -1)),
];

/// Vocab-card shadow — wider diffuse drop for the "physical TCG" feel.
List<BoxShadow> cardShadow() => const [
  BoxShadow(color: Color(0x2E4A3520), blurRadius: 60, offset: Offset(0, 24)),
  BoxShadow(color: Color(0x2E4A3520), blurRadius: 24, offset: Offset(0, 8)),
];

/// Ink on the honey CTA gradient.
const kCtaInk = Color(0xFF2A1C0D);

const ctaGradient = RadialGradient(
  center: Alignment(-0.4, -0.8),
  radius: 1.4,
  colors: [IunaPalette.ctaTop, IunaPalette.ctaMid, IunaPalette.ctaBottom],
  stops: [0.0, 0.6, 1.0],
);

/// The honey pill behind every primary action.
BoxDecoration ctaDecoration() => BoxDecoration(
  gradient: ctaGradient,
  borderRadius: BorderRadius.circular(999),
  boxShadow: ctaShadow(),
);

/// The paper pill behind secondary actions (reveal hint, suspend,
/// "back home" on the recap). Keep [color] opaque when passing a
/// [boxShadow]: a see-through fill shows the shadow under it as a grey
/// slab.
BoxDecoration ghostPillDecoration({
  Color color = IunaPalette.paper,
  List<BoxShadow>? boxShadow,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(999),
  border: Border.all(color: const Color.fromRGBO(74, 53, 32, 0.12), width: 0.5),
  boxShadow: boxShadow,
);

/// CTA pill shadow.
List<BoxShadow> ctaShadow() => const [
  BoxShadow(color: Color(0x66D99550), blurRadius: 16, offset: Offset(0, 6)),
  BoxShadow(color: Color(0x664A3520), blurRadius: 40, offset: Offset(0, 18)),
];

/// The paper card every panel is built on: Stats cards, Learn panels,
/// quiz cards, tutor bubbles.
BoxDecoration paperPanelDecoration({
  Color? color = IunaPalette.paper,
  Gradient? gradient,
  BorderRadiusGeometry? borderRadius,
  BoxBorder? border,
}) => BoxDecoration(
  color: gradient == null ? color : null,
  gradient: gradient,
  borderRadius: borderRadius ?? BorderRadius.circular(IunaRadii.lg),
  border:
      border ??
      Border.all(color: const Color.fromRGBO(74, 53, 32, 0.06), width: 0.5),
  boxShadow: panelShadow(),
);

/// Radii from the handoff.
class IunaRadii {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

Color rarityColor(Rarity r) {
  switch (r) {
    case Rarity.common:
      return IunaPalette.rarityCommon;
    case Rarity.rare:
      return IunaPalette.rarityRare;
    case Rarity.superRare:
      return IunaPalette.raritySuperRare;
    case Rarity.ssr:
      return IunaPalette.raritySsr;
    case Rarity.ur:
      return IunaPalette.rarityUr;
  }
}

/// Lighter "fill" colour for hero gradients and chip backgrounds.
Color rarityFill(Rarity r) {
  switch (r) {
    case Rarity.common:
      return IunaPalette.rarityCommonFill;
    case Rarity.rare:
      return IunaPalette.rarityRareFill;
    case Rarity.superRare:
      return IunaPalette.raritySuperRareFill;
    case Rarity.ssr:
      return IunaPalette.raritySsrFill;
    case Rarity.ur:
      return IunaPalette.rarityUrFill;
  }
}

/// Strong rarity foreground (used for chip text + sense numbers).
Color rarityInk(Rarity r) {
  switch (r) {
    case Rarity.common:
      return IunaPalette.rarityCommonInk;
    case Rarity.rare:
      return IunaPalette.rarityRareInk;
    case Rarity.superRare:
      return IunaPalette.raritySuperRareInk;
    case Rarity.ssr:
      return IunaPalette.raritySsrInk;
    case Rarity.ur:
      return IunaPalette.rarityUrInk;
  }
}

/// Short gacha code shown on cards: C / R / SR / SSR / UR.
String rarityCode(Rarity r) {
  switch (r) {
    case Rarity.common:
      return 'C';
    case Rarity.rare:
      return 'R';
    case Rarity.superRare:
      return 'SR';
    case Rarity.ssr:
      return 'SSR';
    case Rarity.ur:
      return 'UR';
  }
}

int rarityStars(Rarity r) => Rarity.values.indexOf(r) + 1;

String rarityName(Rarity r) {
  switch (r) {
    case Rarity.common:
      return 'Common';
    case Rarity.rare:
      return 'Rare';
    case Rarity.superRare:
      return 'Super Rare';
    case Rarity.ssr:
      return 'Ultra Rare';
    case Rarity.ur:
      return 'Legendary';
  }
}

ThemeData buildIunaTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: IunaPalette.bellGold,
        brightness: Brightness.light,
      ).copyWith(
        primary: IunaPalette.ink,
        secondary: IunaPalette.bellGold,
        surface: IunaPalette.bg,
      );

  // Every style below derives from the platform typography so it keeps
  // its font family and fallbacks; a bare TextStyle on a theme slot
  // (AppBar title, button label) would lose them. Sizes follow
  // [IunaText].
  final t = base.textTheme;
  final textTheme = t
      .copyWith(
        headlineSmall: t.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: t.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: t.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.35),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.35),
        bodySmall: t.bodySmall?.copyWith(fontSize: 12, height: 1.4),
        labelLarge: t.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: t.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: t.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      )
      .apply(bodyColor: IunaPalette.ink, displayColor: IunaPalette.ink);
  final buttonLabel = textTheme.labelLarge!;
  const pill = StadiumBorder();
  final hairline = BorderSide(
    color: IunaPalette.ink.withValues(alpha: 0.18),
    width: 1,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: IunaPalette.bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: IunaPalette.ink2,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleMedium!.copyWith(
        letterSpacing: 0.6,
        color: IunaPalette.ink2,
      ),
    ),
    iconTheme: const IconThemeData(color: IunaPalette.ink2),
    listTileTheme: ListTileThemeData(
      iconColor: IunaPalette.ink2,
      textColor: IunaPalette.ink,
      titleTextStyle: textTheme.bodyLarge!.copyWith(
        fontWeight: FontWeight.w600,
        color: IunaPalette.ink,
      ),
      subtitleTextStyle: textTheme.bodyMedium!.copyWith(
        fontSize: 13,
        color: IunaPalette.ink3,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: IunaPalette.ctaMid,
        foregroundColor: kCtaInk,
        disabledBackgroundColor: IunaPalette.ink.withValues(alpha: 0.08),
        disabledForegroundColor: IunaPalette.ink3,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: buttonLabel,
        shape: pill,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: IunaPalette.ink2,
        backgroundColor: IunaPalette.paper,
        side: hairline,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: textTheme.labelLarge,
        shape: pill,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: IunaPalette.ink2,
        textStyle: textTheme.labelLarge,
        shape: pill,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: IunaPalette.ink2),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? IunaPalette.bellGold : null,
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(textStyle: textTheme.bodyLarge),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: textTheme.bodyMedium!.copyWith(color: IunaPalette.ink3),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: IunaPalette.ink,
      unselectedLabelColor: IunaPalette.ink3,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
      indicatorColor: IunaPalette.ctaBottom,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: IunaPalette.ink.withValues(alpha: 0.08),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: IunaPalette.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: IunaPalette.ink.withValues(alpha: 0.25),
      textStyle: textTheme.bodyMedium,
      labelTextStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IunaRadii.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: IunaPalette.paper,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleMedium!.copyWith(fontSize: 18),
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: IunaPalette.ink2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IunaRadii.lg),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: IunaPalette.paper,
      surfaceTintColor: Colors.transparent,
    ),
    // Floating and lifted clear of the bottom nav, which every tab
    // overlays on its content rather than giving to the Scaffold.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, kSnackNavClearance),
      backgroundColor: IunaPalette.ink,
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: IunaPalette.paper,
      ),
      actionTextColor: IunaPalette.ctaTop,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IunaRadii.md),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: IunaPalette.ctaBottom,
    ),
    cardTheme: CardThemeData(
      color: IunaPalette.paper,
      elevation: 4,
      shadowColor: IunaPalette.ink.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IunaRadii.lg),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _IunaPageTransitions(),
        TargetPlatform.iOS: _IunaPageTransitions(),
        TargetPlatform.fuchsia: _IunaPageTransitions(),
        TargetPlatform.linux: _IunaPageTransitions(),
        TargetPlatform.macOS: _IunaPageTransitions(),
        TargetPlatform.windows: _IunaPageTransitions(),
      },
    ),
  );
}

/// How far a floating snack bar sits above the screen bottom: clear of
/// the bottom nav pill.
const double kSnackNavClearance = 92;

/// Page-wide warm-cream backdrop with two soft radial highlights.
/// Drop behind a `Stack` to give every screen the same "lit cream"
/// feel without each one repeating the gradient inline.
BoxDecoration iunaPageBackground() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [IunaPalette.bg, IunaPalette.bg2],
    ),
  );
}

/// App-wide page transition: soft fade with a gentle upward slide.
class _IunaPageTransitions extends PageTransitionsBuilder {
  const _IunaPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
