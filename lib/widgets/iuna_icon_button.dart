import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// The bare icon every top bar uses for back / close / actions, on a
/// 48 px tap target. [tooltip] is also what a screen reader says.
class IunaIconButton extends StatelessWidget {
  const IunaIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tint,
    this.selected,
    this.disc = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? tint;

  /// For a toggle (the wishlist bookmark): announced as its state.
  final bool? selected;

  /// A smaller icon on a raised paper disc, for a button on a card face.
  final bool disc;

  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: disc ? 24 : 22,
          child: SizedBox.square(
            dimension: size,
            child: disc
                ? Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: IunaPalette.paper,
                        shape: BoxShape.circle,
                        boxShadow: panelShadow(),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 16, color: tint ?? IunaPalette.ink2),
                    ),
                  )
                : Icon(icon, size: 22, color: tint ?? IunaPalette.ink2),
          ),
        ),
      ),
    );
  }
}

/// A screen's top bar: [title] centred between a [leading] and a
/// [trailing] button, each slot keeping a button's width when empty. A
/// long title shrinks between them rather than overflowing.
class IunaTopBar extends StatelessWidget {
  const IunaTopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final Widget title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Taller with large text, so a two-line title still fits.
    final height = math.max(
      IunaIconButton.size,
      MediaQuery.textScalerOf(context).scale(40),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: SizedBox(
        height: height,
        child: NavigationToolbar(
          leading: leading ?? const SizedBox(width: IunaIconButton.size),
          middle: title,
          trailing: trailing ?? const SizedBox(width: IunaIconButton.size),
          middleSpacing: 8,
        ),
      ),
    );
  }
}
