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
  static const ink3 = Color(0xFF9A8068);
  static const inkMute = Color(0xFFB9A285);

  // ── Signal accents ──
  static const bowPink = Color(0xFFF3A7B5);
  static const bowMint = Color(0xFFB8D8C9);
  static const bellGold = Color(0xFFE8B96B);

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

/// The frosted pill behind secondary actions (reveal hint, suspend,
/// "back home" on the recap).
BoxDecoration ghostPillDecoration({
  Color color = const Color(0xB3FFFDF6),
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

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: IunaPalette.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: IunaPalette.ink2,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 15,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
        color: IunaPalette.ink2,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: IunaPalette.ink,
      displayColor: IunaPalette.ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: IunaPalette.ctaMid,
        foregroundColor: const Color(0xFF2A1C0D),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
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
