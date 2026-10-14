import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';

/// The paper panel every Learn screen is built from (the Stats card
/// without its title row).
class LearnPanel extends StatelessWidget {
  const LearnPanel({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(IunaRadii.lg);
    return Container(
      decoration: paperPanelDecoration(borderRadius: radius),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class LearnProgressBar extends StatelessWidget {
  const LearnProgressBar({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(color: const Color.fromRGBO(74, 53, 32, 0.07)),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0, 1),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [IunaPalette.bowMint, Color(0xFF7FBFA3)]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
