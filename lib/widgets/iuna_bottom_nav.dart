import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

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
  });

  final IunaNavTab active;
  final ValueChanged<IunaNavTab> onTap;

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
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF8E5), Color(0xFFFDE9C9)],
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
            Icon(
              icon,
              size: 20,
              color: active ? IunaPalette.ink : IunaPalette.ink3,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? IunaPalette.ink : IunaPalette.ink3,
                height: 1,
              ),
            ),
          ],
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
