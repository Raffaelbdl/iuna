import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Hex bokeh density level.
enum HexBgIntensity { subtle, moderate, rich }

/// Palette family used to tint the hexes.
enum HexBgPalette { pastel, warm, cool }

/// Animated hex bokeh background — outline rings + a few softly blurred
/// solid hexes drifting on a deterministic seeded loop. Lives behind a
/// `RepaintBoundary`; its `Ticker` drives the painter's repaint
/// listenable, so frames repaint without rebuilding anything.
class HexBg extends StatefulWidget {
  const HexBg({
    super.key,
    this.intensity = HexBgIntensity.rich,
    this.palette = HexBgPalette.pastel,
    this.seed = 7,
  });

  final HexBgIntensity intensity;
  final HexBgPalette palette;
  final int seed;

  @override
  State<HexBg> createState() => _HexBgState();
}

class _HexBgState extends State<HexBg> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _seconds = ValueNotifier(0);

  late List<_Hex> _hexes;

  @override
  void initState() {
    super.initState();
    _hexes = _build();
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant HexBg old) {
    super.didUpdateWidget(old);
    if (old.intensity != widget.intensity ||
        old.palette != widget.palette ||
        old.seed != widget.seed) {
      _hexes = _build();
    }
  }

  void _onTick(Duration elapsed) {
    _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  int get _count {
    switch (widget.intensity) {
      case HexBgIntensity.subtle:
        return 6;
      case HexBgIntensity.moderate:
        return 10;
      case HexBgIntensity.rich:
        return 16;
    }
  }

  List<Color> get _colors {
    switch (widget.palette) {
      case HexBgPalette.pastel:
        return const [
          Color(0x8CF3A7B5),
          Color(0x8CB8D8C9),
          Color(0x8CFFD58A),
          Color(0x8CC4B2E0),
          Color(0x8CB4D6EA),
          Color(0x80FFC49E),
        ];
      case HexBgPalette.warm:
        return const [
          Color(0x8CF3A7B5),
          Color(0x99FFD58A),
          Color(0x8CFFC49E),
          Color(0x73E8B96B),
        ];
      case HexBgPalette.cool:
        return const [Color(0x99B4D6EA), Color(0x8CB8D8C9), Color(0x80C4B2E0)];
    }
  }

  List<_Hex> _build() {
    final cols = _colors;
    final rng = math.Random(widget.seed);
    final out = <_Hex>[];
    for (var i = 0; i < _count; i++) {
      // Mostly outline (~75%), occasionally a soft solid blob.
      final isOutline = (i % 4) != 3;
      out.add(
        _Hex(
          kind: isOutline ? _HexKind.outline : _HexKind.solid,
          size: 50 + rng.nextDouble() * 120,
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          color: cols[rng.nextInt(cols.length)],
          // Float period 12..26s; phase offset so all hexes don't sync up.
          period: 12 + rng.nextDouble() * 14,
          phase: rng.nextDouble() * math.pi * 2,
          tx: (rng.nextDouble() - 0.5) * 40,
          ty: (rng.nextDouble() - 0.5) * 40,
          spin: (rng.nextDouble() - 0.5) * 16,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _HexBgPainter(hexes: _hexes, time: _seconds),
      ),
    );
  }
}

enum _HexKind { outline, solid }

class _Hex {
  _Hex({
    required this.kind,
    required this.size,
    required this.x,
    required this.y,
    required this.color,
    required this.period,
    required this.phase,
    required this.tx,
    required this.ty,
    required this.spin,
  });

  final _HexKind kind;
  final double size;
  final double x;
  final double y;
  final Color color;
  final double period;
  final double phase;
  final double tx;
  final double ty;
  final double spin;

  // Plain srcOver for the solids: Impeller (Android) renders a mask-blurred
  // path with an advanced blend like multiply as a hard-edged box. Over the
  // cream ground the two blends look nearly the same.
  late final Paint paint = switch (kind) {
    _HexKind.outline => Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.0, size / 2 * 0.06)
      ..color = color
      ..blendMode = BlendMode.multiply,
    _HexKind.solid => Paint()
      ..color = color.withValues(alpha: (color.a * 0.78).clamp(0.0, 1.0))
      ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 8),
  };
}

class _HexBgPainter extends CustomPainter {
  _HexBgPainter({required this.hexes, required this.time})
    : super(repaint: time);

  final List<_Hex> hexes;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final time = this.time.value;
    for (final h in hexes) {
      // Sinusoidal float — gentle ±20px wander, ±8° rotation.
      final t = math.sin((time / h.period) * math.pi * 2 + h.phase);
      final cx = h.x * size.width + h.tx * t;
      final cy = h.y * size.height + h.ty * t;
      final rot = h.spin * t * math.pi / 180;
      canvas.drawPath(_hexPath(Offset(cx, cy), h.size / 2, rot), h.paint);
    }
  }

  Path _hexPath(Offset c, double radius, double rotation) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = rotation + i * math.pi / 3 - math.pi / 6;
      final x = c.dx + math.cos(a) * radius;
      final y = c.dy + math.sin(a) * radius;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant _HexBgPainter old) =>
      old.time != time || old.hexes != hexes;
}
