import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loudness bars, as in a voice message. With [fit] the whole trace is
/// squeezed into the width; without, the newest levels sit at the right
/// edge as they are recorded.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.levels,
    required this.color,
    this.fit = false,
    this.repaint,
    this.sweep,
    this.sweepColor,
  });

  /// 0..1.
  final List<double> levels;
  final Color color;
  final bool fit;

  /// Fires when [levels] has grown in place.
  final Listenable? repaint;

  /// A highlight passing over the bars, 0..1 across.
  final Animation<double>? sweep;
  final Color? sweepColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 26,
        child: CustomPaint(
          size: Size.infinite,
          painter: _WaveformPainter(
            levels: levels,
            color: color,
            fit: fit,
            sweep: sweep,
            sweepColor: sweepColor ?? color,
            repaint: Listenable.merge([repaint, sweep]),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.levels,
    required this.color,
    required this.fit,
    required this.sweep,
    required this.sweepColor,
    super.repaint,
  });

  static const _bar = 3.0;
  static const _gap = 2.0;

  final List<double> levels;
  final Color color;
  final bool fit;
  final Animation<double>? sweep;
  final Color sweepColor;

  @override
  void paint(Canvas canvas, Size size) {
    final slots = ((size.width + _gap) / (_bar + _gap)).floor();
    if (slots <= 0) return;
    final values = fit ? _squeeze(slots) : _tail(slots);
    // Runs past both ends, so the highlight enters and leaves whole.
    final at = sweep == null ? null : sweep!.value * 1.4 - 0.2;
    final paint = Paint();
    final mid = size.height / 2;
    for (var i = 0; i < slots; i++) {
      final h = math.max(_bar, values[i] * size.height);
      final x = slots == 1 ? 0.0 : i / (slots - 1);
      paint.color = at == null
          ? color
          : Color.lerp(color, sweepColor, 1 - ((x - at).abs() / 0.2).clamp(0.0, 1.0))!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (_bar + _gap), mid - h / 2, _bar, h),
          const Radius.circular(_bar / 2),
        ),
        paint,
      );
    }
  }

  /// The newest [slots] levels, right-aligned.
  List<double> _tail(int slots) {
    final n = math.min(slots, levels.length);
    return [...List.filled(slots - n, 0.0), ...levels.skip(levels.length - n)];
  }

  /// Every level, bucketed into [slots] bars by the loudest of each.
  List<double> _squeeze(int slots) {
    final n = levels.length;
    if (n == 0) return List.filled(slots, 0.0);
    return [
      for (var j = 0; j < slots; j++)
        levels
            .sublist(j * n ~/ slots, math.max(j * n ~/ slots + 1, (j + 1) * n ~/ slots))
            .reduce(math.max),
    ];
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      !identical(old.levels, levels) ||
      old.fit != fit ||
      old.color != color ||
      old.sweep != sweep ||
      old.sweepColor != sweepColor;
}

/// `m:ss`, for recording lengths.
String clockLabel(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
