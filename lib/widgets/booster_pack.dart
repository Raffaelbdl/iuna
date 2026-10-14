import 'package:flutter/material.dart';

import 'kuma_mascot.dart';

/// The visual booster pack from the redesign — gold-gradient body with a
/// dashed inset border, a "TODAY" / "日本語" eyebrow, "パック" footer, and
/// the Kuma mascot centered as a wax seal. Used on the Home hero, the
/// Pack Intro splash and as a small ornament wherever the brand needs a
/// pack reference.
class BoosterPack extends StatelessWidget {
  const BoosterPack({
    super.key,
    this.width = 200,
    this.height = 280,
    this.label = 'TODAY',
    this.jpFooter = 'パック',
    this.kumaSize,
    this.variant,
    this.variantSeed,
    this.showKuma = true,
    this.elevation = 1.0,
  });

  final double width;
  final double height;
  final String label;
  final String jpFooter;
  final double? kumaSize;
  final KumaVariant? variant;
  final int? variantSeed;
  final bool showKuma;

  /// Multiplier for the drop shadow strength; <1 dampens it for inline
  /// previews (e.g. the home hero's mini pack), 1.0 is default.
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final radius = width * 0.13;
    final dashedPad = width * 0.04;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment(-0.4, -0.7),
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF3C97A),
            Color(0xFFE29A55),
            Color(0xFFC87A3A),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(120, 70, 20, 0.45 * elevation),
            blurRadius: 60,
            offset: const Offset(0, 30),
            spreadRadius: -20,
          ),
        ],
        border: Border.all(
          color: const Color.fromRGBO(120, 70, 20, 0.2),
          width: 0.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft top-left highlight (radial cream → transparent).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: const RadialGradient(
                  center: Alignment(-0.4, -0.5),
                  radius: 0.7,
                  colors: [Color(0xCCFFF2CF), Color(0x00FFF2CF)],
                ),
              ),
            ),
          ),
          // Dashed inset border.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(dashedPad),
              child: CustomPaint(
                painter: _DashedRectPainter(
                  color: const Color.fromRGBO(255, 255, 255, 0.55),
                  radius: radius - dashedPad * 0.6,
                ),
              ),
            ),
          ),
          // TODAY eyebrow at the top.
          Positioned(
            top: height * 0.07,
            left: 0,
            right: 0,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: width * 0.055,
                fontWeight: FontWeight.w700,
                letterSpacing: width * 0.012,
                color: const Color(0xFF5A3210),
              ),
            ),
          ),
          // Kuma seal.
          if (showKuma)
            KumaMascot(
              size: kumaSize ?? width * 0.54,
              variant: variant,
              // Null seed → KumaMascot picks black/white randomly per
              // mount, matching the handoff's per-route randomization.
              // Callers that need a stable variant (goldens, etc.) can
              // pin one via [variantSeed] or [variant].
              seed: variantSeed,
            ),
          // パック footer.
          Positioned(
            bottom: height * 0.075,
            left: 0,
            right: 0,
            child: Text(
              jpFooter,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: width * 0.07,
                letterSpacing: width * 0.009,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5A3210).withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dash = 4.5;
    const gap = 4.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, next),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}
