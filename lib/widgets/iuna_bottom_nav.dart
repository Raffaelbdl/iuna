import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';
import 'tappable.dart';

enum IunaNavTab { home, today, collection, learn }

/// Floating glass-pill bottom navigation. Sits as an overlay on top of
/// scrolling content; pair with [IunaNavFade] above it so content
/// dissolves into the navbar instead of being clipped sharply.
class IunaBottomNav extends StatelessWidget {
  const IunaBottomNav({
    super.key,
    required this.active,
    required this.onTap,
    this.showLearn = false,
    this.todayCount = 0,
  });

  final IunaNavTab active;
  final ValueChanged<IunaNavTab> onTap;

  /// What waits behind Today (new cards and due reviews), shown as a
  /// badge so the tab reads as something to do.
  final int todayCount;

  /// The Learn tab exists only while an OpenRouter key is saved.
  final bool showLearn;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + inset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xC7FFFDF6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color.fromRGBO(74, 53, 32, 0.08),
                width: 0.5,
              ),
              boxShadow: panelShadow(),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final labels = [
                  'Home',
                  'Today',
                  'Collection',
                  if (showLearn) 'Learn',
                ];
                final scaler = _labelScaler(
                  context,
                  labels,
                  constraints.maxWidth / labels.length -
                      _NavBtn.padding.horizontal,
                );
                Widget button(
                  IunaNavTab tab,
                  IconData icon,
                  String label, {
                  int badge = 0,
                }) =>
                    Expanded(
                      child: _NavBtn(
                        icon: icon,
                        label: label,
                        badge: badge,
                        labelScaler: scaler,
                        active: active == tab,
                        onTap: () => onTap(tab),
                      ),
                    );
                return Row(
                  children: [
                    button(IunaNavTab.home, Icons.home_rounded, 'Home'),
                    button(
                      IunaNavTab.today,
                      Icons.card_giftcard_rounded,
                      'Today',
                      badge: todayCount,
                    ),
                    button(
                      IunaNavTab.collection,
                      Icons.style_rounded,
                      'Collection',
                    ),
                    if (showLearn)
                      button(IunaNavTab.learn, Icons.school_rounded, 'Learn'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The last [_labelScaler] answer: the nav rebuilds on every screen
  /// and badge change, and its inputs hardly ever do.
  static ({
    double width,
    double factor,
    int count,
    TextStyle style,
    TextScaler scaler,
  })? _lastScaler;

  /// One text size for every label: the largest at which the longest
  /// still fits its tab, so "Collection" doesn't shrink alone.
  static TextScaler _labelScaler(
    BuildContext context,
    List<String> labels,
    double width,
  ) {
    final style = DefaultTextStyle.of(context).style.merge(_NavBtn.labelStyle);
    final size = style.fontSize!;
    final base = MediaQuery.textScalerOf(context).scale(size) / size;
    final last = _lastScaler;
    if (last != null &&
        last.width == width &&
        last.factor == base &&
        last.count == labels.length &&
        last.style == style) {
      return last.scaler;
    }
    var factor = base;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(factor),
        maxLines: 1,
      )..layout();
      if (painter.width > width) factor *= width / painter.width;
      painter.dispose();
    }
    final scaler = TextScaler.linear(factor);
    _lastScaler = (
      width: width,
      factor: base,
      count: labels.length,
      style: style,
      scaler: scaler,
    );
    return scaler;
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.labelScaler,
    this.badge = 0,
  });

  static const padding = EdgeInsets.symmetric(vertical: 8, horizontal: 6);
  static final labelStyle = IunaText.chip.copyWith(height: 1);

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final TextScaler labelScaler;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(
      icon,
      size: 20,
      color: active ? IunaPalette.ink : IunaPalette.ink3,
    );
    return Tappable(
      onTap: onTap,
      selected: active,
      label: badge > 0 ? '$label, $badge waiting' : null,
      child: ExcludeSemantics(
        excluding: badge > 0,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: padding,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF8E5), IunaPalette.optionPicked],
                  )
                : null,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(232, 185, 107, 0.6),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                      spreadRadius: -8,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge == 0)
                glyph
              else
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    glyph,
                    Positioned(
                      left: 13,
                      top: -5,
                      child: _Badge(count: badge),
                    ),
                  ],
                ),
              const SizedBox(height: 2),
              // The bar's shared size; the box only catches rounding.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  textScaler: labelScaler,
                  style: labelStyle.copyWith(
                    color: active ? IunaPalette.ink : IunaPalette.ink3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small honey count on a nav icon.
class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: IunaPalette.honey,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: IunaPalette.paper, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        // Fixed, not scaled: it rides on a 20 px icon.
        textScaler: TextScaler.noScaling,
        style: IunaText.chip.copyWith(
          fontWeight: FontWeight.w800,
          color: IunaPalette.heroInk,
          height: 1.1,
        ),
      ),
    );
  }
}

/// 120-px tall vertical fade above the navbar so scrolling content
/// dissolves into the cream rather than being clipped sharply.
class IunaNavFade extends StatelessWidget {
  const IunaNavFade({super.key, this.height = 120});
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xFF000000)],
            stops: [0.0, 0.4],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00FBF3E2),
                  Color(0xB3FBF3E2),
                  Color(0xF2FBF3E2),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
