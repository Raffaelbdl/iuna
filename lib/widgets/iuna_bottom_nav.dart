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
            child: Row(
              children: [
                Expanded(
                  child: _NavBtn(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    active: active == IunaNavTab.home,
                    onTap: () => onTap(IunaNavTab.home),
                  ),
                ),
                Expanded(
                  child: _NavBtn(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Today',
                    badge: todayCount,
                    active: active == IunaNavTab.today,
                    onTap: () => onTap(IunaNavTab.today),
                  ),
                ),
                Expanded(
                  child: _NavBtn(
                    icon: Icons.style_rounded,
                    label: 'Collection',
                    active: active == IunaNavTab.collection,
                    onTap: () => onTap(IunaNavTab.collection),
                  ),
                ),
                if (showLearn)
                  Expanded(
                    child: _NavBtn(
                      icon: Icons.school_rounded,
                      label: 'Learn',
                      active: active == IunaNavTab.learn,
                      onTap: () => onTap(IunaNavTab.learn),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
              Text(
                label,
                style: IunaText.chip.copyWith(
                  color: active ? IunaPalette.ink : IunaPalette.ink3,
                  height: 1,
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
