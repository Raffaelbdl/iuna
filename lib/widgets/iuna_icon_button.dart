import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// The 36 px tap target every top bar uses for back / close / actions.
class IunaIconButton extends StatelessWidget {
  const IunaIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: tint ?? IunaPalette.ink2),
      ),
    );
  }
}

/// A full-screen flow's top bar: [title] centred between a [leading] and
/// a [trailing] button, each slot keeping its 36 px when empty.
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          leading ?? const SizedBox(width: 36),
          const Spacer(),
          title,
          const Spacer(),
          trailing ?? const SizedBox(width: 36),
        ],
      ),
    );
  }
}
