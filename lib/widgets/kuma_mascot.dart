import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Two flavours of the Kuma seal — black bear with mint ribbon, white
/// bear with pink ribbon. Variants pick deterministically from a seed
/// (or randomly per mount when [seed] is null) so the same widget stays
/// stable across rebuilds.
enum KumaVariant { black, white }

class KumaMascot extends StatefulWidget {
  const KumaMascot({
    super.key,
    this.size = 80,
    this.variant,
    this.seed,
  });

  final double size;
  final KumaVariant? variant;
  final int? seed;

  @override
  State<KumaMascot> createState() => _KumaMascotState();
}

class _KumaMascotState extends State<KumaMascot> {
  late KumaVariant _variant;

  @override
  void initState() {
    super.initState();
    _variant = widget.variant ?? _pickVariant();
  }

  @override
  void didUpdateWidget(covariant KumaMascot old) {
    super.didUpdateWidget(old);
    if (old.variant != widget.variant || old.seed != widget.seed) {
      _variant = widget.variant ?? _pickVariant();
    }
  }

  KumaVariant _pickVariant() {
    final rng = widget.seed != null
        ? math.Random(widget.seed!)
        : math.Random();
    return rng.nextBool() ? KumaVariant.black : KumaVariant.white;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _KumaPainter(variant: _variant),
    );
  }
}

class _KumaPalette {
  const _KumaPalette({
    required this.body,
    required this.earIn,
    required this.muzzle,
    required this.eye,
    required this.ribbon,
    required this.ribbonShade,
  });

  final Color body;
  final Color earIn;
  final Color muzzle;
  final Color eye;
  final Color ribbon;
  final Color ribbonShade;
}

const _white = _KumaPalette(
  body: Color(0xFFF4EDE2),
  earIn: Color(0xFFF3A7B5),
  muzzle: Color(0xFFE8DCCB),
  eye: Color(0xFF1A0D04),
  ribbon: Color(0xFFF3A7B5),
  ribbonShade: Color(0xFFD97A8C),
);

const _black = _KumaPalette(
  body: Color(0xFF2A2530),
  earIn: Color(0xFFAEE0D8),
  muzzle: Color(0xFF3A3340),
  eye: Color(0xFF0A0500),
  ribbon: Color(0xFFAEE0D8),
  ribbonShade: Color(0xFF7FC4BA),
);

class _KumaPainter extends CustomPainter {
  _KumaPainter({required this.variant});
  final KumaVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final p = variant == KumaVariant.white ? _white : _black;
    // Draw on a 100×100 canvas, scaled to fit.
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final body = Paint()..color = p.body;
    final earIn = Paint()..color = p.earIn;
    final muzzle = Paint()..color = p.muzzle;
    final eye = Paint()..color = p.eye;
    final ribbon = Paint()..color = p.ribbon;
    final ribbonShade = Paint()
      ..color = p.ribbonShade
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final charm = Paint()..color = const Color(0xFFD4A85E);
    final charmStroke = Paint()
      ..color = p.ribbonShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Ears
    canvas.drawCircle(const Offset(26, 26), 11, body);
    canvas.drawCircle(const Offset(74, 26), 11, body);
    canvas.drawCircle(const Offset(26, 26), 5.5, earIn);
    canvas.drawCircle(const Offset(74, 26), 5.5, earIn);

    // Head
    canvas.drawCircle(const Offset(50, 54), 32, body);

    // Muzzle patch
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 62), width: 22, height: 16),
      muzzle,
    );

    // Eyes
    canvas.drawCircle(const Offset(40, 50), 2.6, eye);
    canvas.drawCircle(const Offset(60, 50), 2.6, eye);

    // Nose
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 58), width: 3.2, height: 2.4),
      eye,
    );

    // Ribbon collar
    final ribbonPath = Path()
      ..moveTo(30, 86)
      ..quadraticBezierTo(50, 80, 70, 86)
      ..lineTo(70, 92)
      ..quadraticBezierTo(50, 86, 30, 92)
      ..close();
    canvas.drawPath(ribbonPath, ribbon);
    final leftLoop = Path()
      ..moveTo(22, 88)
      ..quadraticBezierTo(30, 84, 36, 88)
      ..quadraticBezierTo(30, 92, 22, 92)
      ..close();
    canvas.drawPath(leftLoop, ribbon);
    final rightLoop = Path()
      ..moveTo(78, 88)
      ..quadraticBezierTo(70, 84, 64, 88)
      ..quadraticBezierTo(70, 92, 78, 92)
      ..close();
    canvas.drawPath(rightLoop, ribbon);

    // Charm disc with X
    canvas.drawCircle(const Offset(50, 88), 3.2, charm);
    canvas.drawCircle(const Offset(50, 88), 3.2, charmStroke);
    canvas.drawLine(
        const Offset(48, 86), const Offset(52, 90), ribbonShade);
    canvas.drawLine(
        const Offset(52, 86), const Offset(48, 90), ribbonShade);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KumaPainter old) => old.variant != variant;
}
