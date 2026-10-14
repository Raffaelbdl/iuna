part of '../stats_screen.dart';

// ─── Hour-of-day radial clock ────────────────────────────────────────

class _HourClock extends StatelessWidget {
  const _HourClock({required this.hours});
  final List<int> hours;

  @override
  Widget build(BuildContext context) {
    final total = hours.fold<int>(0, (s, v) => s + v);
    if (total == 0) {
      return const _EmptyHint(
        text: 'No reviews yet — your study clock will fill in over time.',
      );
    }
    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: _HourClockPainter(hours: hours),
        size: Size.infinite,
      ),
    );
  }
}

class _HourClockPainter extends CustomPainter {
  _HourClockPainter({required this.hours});
  final List<int> hours;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;
    final outerR = math.min(size.width, size.height) / 2 - 18;
    final innerR = outerR * 0.4;
    final maxV = hours.fold<int>(0, (m, v) => math.max(m, v));
    if (maxV == 0) return;
    canvas.drawCircle(
      Offset(cx, cy),
      outerR + 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _SP.grid
        ..strokeWidth = 0.6,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      innerR - 2,
      Paint()..color = IunaPalette.paper,
    );
    for (var h = 0; h < 24; h++) {
      final v = hours[h];
      final t = v / maxV;
      final r = innerR + (outerR - innerR) * t;
      final a0 = (h / 24) * math.pi * 2 - math.pi / 2;
      final a1 = ((h + 1) / 24) * math.pi * 2 - math.pi / 2;
      final p = Path()
        ..moveTo(cx + math.cos(a0) * innerR, cy + math.sin(a0) * innerR)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
          a0,
          a1 - a0,
          false,
        )
        ..lineTo(cx + math.cos(a1) * r, cy + math.sin(a1) * r)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          a1,
          a0 - a1,
          false,
        )
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..color = t > 0.7
              ? _SP.honeyDeep
              : t > 0.45
              ? _SP.honey
              : t > 0.2
              ? const Color(0xFFF0D2A0)
              : const Color(0xFFEADCB8),
      );
    }
    for (final l in const [
      (h: 0, label: '12a'),
      (h: 6, label: '6a'),
      (h: 12, label: '12p'),
      (h: 18, label: '6p'),
    ]) {
      final a = (l.h / 24) * math.pi * 2 - math.pi / 2;
      final tx = cx + math.cos(a) * (outerR + 12);
      final ty = cy + math.sin(a) * (outerR + 12);
      final tp = TextPainter(
        text: TextSpan(
          text: l.label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: IunaPalette.ink3,
            fontFamily: _SP.labelFont,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx - tp.width / 2, ty - tp.height / 2));
    }
    final peakH = hours.indexOf(maxV);
    final peakLabel = peakH == 0
        ? '12 am'
        : peakH < 12
        ? '$peakH am'
        : peakH == 12
        ? '12 pm'
        : '${peakH - 12} pm';
    final peakTitle = TextPainter(
      text: const TextSpan(
        text: 'peak',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: IunaPalette.ink,
          fontFamily: _SP.labelFont,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    peakTitle.paint(
      canvas,
      Offset(cx - peakTitle.width / 2, cy - peakTitle.height),
    );
    final peakSub = TextPainter(
      text: TextSpan(
        text: peakLabel,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _SP.honeyDeep,
          fontFamily: _SP.labelFont,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    peakSub.paint(canvas, Offset(cx - peakSub.width / 2, cy + 2));
  }

  @override
  bool shouldRepaint(covariant _HourClockPainter old) => old.hours != hours;
}

// ─── Time spent (bars + median line) ─────────────────────────────────

class _TimeSpentChart extends StatelessWidget {
  const _TimeSpentChart({required this.days});
  final List<TimeSpentDay> days;

  @override
  Widget build(BuildContext context) {
    final totalMs = days.fold<int>(0, (s, d) => s + d.totalMs);
    if (totalMs == 0) {
      return const _EmptyHint(
        text:
            "Enable response timing on a few reviews and time-spent stats will surface here.",
      );
    }
    final medians = days
        .where((d) => d.medianMs != null)
        .map((d) => d.medianMs!)
        .toList();
    final avgMedianMs = medians.isEmpty
        ? null
        : medians.reduce((a, b) => a + b) / medians.length;
    final totalMin = totalMs ~/ 60000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'this month',
                value: '${totalMin ~/ 60}h',
                unit: '${totalMin % 60}m',
                unitSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'median answer',
                value: avgMedianMs == null
                    ? '—'
                    : '${(avgMedianMs / 1000).toStringAsFixed(1)}s',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _TimeSpentPainter(days: days),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: const [
            _LegendDot(color: _SP.lilac, label: 'minutes / day'),
            SizedBox(width: 14),
            _LegendLine(color: _SP.lilacDeep, label: 'median answer (s)'),
          ],
        ),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 1.6, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: IunaPalette.ink3,
          ),
        ),
      ],
    );
  }
}

class _TimeSpentPainter extends CustomPainter {
  _TimeSpentPainter({required this.days});
  final List<TimeSpentDay> days;

  @override
  void paint(Canvas canvas, Size size) {
    const padT = 8.0, padB = 18.0;
    final chartH = size.height - padT - padB;
    final maxMin = days.fold<int>(0, (m, d) => math.max(m, d.totalMs ~/ 60000));
    if (days.isEmpty || maxMin == 0) {
      _paintEnds(canvas, size);
      return;
    }
    final slot = size.width / days.length;
    final bw = math.max(2.0, slot * 0.78);
    for (var i = 0; i < days.length; i++) {
      final mins = days[i].totalMs ~/ 60000;
      if (mins == 0) continue;
      final h = (mins / maxMin) * chartH;
      final left = i * slot + (slot - bw) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, padT + chartH - h, bw, h),
          const Radius.circular(2),
        ),
        Paint()..color = _SP.lilac,
      );
    }

    // Median answer line — overlay with a fixed 0..8s scale so the line
    // doesn't track the bar magnitudes.
    const medMaxSec = 8.0;
    Path? path;
    final pts = <Offset>[];
    for (var i = 0; i < days.length; i++) {
      final ms = days[i].medianMs;
      if (ms == null) continue;
      final sec = (ms / 1000).clamp(0.0, medMaxSec);
      final x = i * slot + slot / 2;
      final y = padT + (1 - sec / medMaxSec) * chartH;
      pts.add(Offset(x, y));
      path ??= Path()..moveTo(x, y);
      path.lineTo(x, y);
    }
    if (path != null && pts.length >= 2) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _SP.lilacDeep
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      for (var i = 0; i < pts.length; i += 5) {
        canvas.drawCircle(pts[i], 2.2, Paint()..color = _SP.lilacDeep);
      }
    }
    _paintEnds(canvas, size);
  }

  static void _paintEnds(Canvas canvas, Size size) {
    _chartLabel('30d ago').paint(canvas, Offset(0, size.height - 10));
    final today = _chartLabel('today');
    today.paint(canvas, Offset(size.width - today.width, size.height - 10));
  }

  @override
  bool shouldRepaint(covariant _TimeSpentPainter old) => old.days != days;
}
