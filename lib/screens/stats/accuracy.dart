part of '../stats_screen.dart';

// ─── Retention curve (line+area+target) ───────────────────────────────

class _RetentionChart extends StatelessWidget {
  const _RetentionChart({required this.bins});
  final List<RetentionBin> bins;

  @override
  Widget build(BuildContext context) {
    final total = bins.fold<int>(0, (s, b) => s + b.total);
    if (total == 0) {
      return const _EmptyHint(
        text:
            'No data in this window. Try "all" or come back after a few sessions.',
      );
    }
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _RetentionPainter(bins: bins),
        size: Size.infinite,
      ),
    );
  }
}

class _RetentionPainter extends CustomPainter {
  _RetentionPainter({required this.bins});
  final List<RetentionBin> bins;

  static const _yLow = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 28.0, padR = 12.0, padT = 16.0, padB = 32.0;
    final cw = size.width - padL - padR;
    final ch = size.height - padT - padB;
    if (cw <= 0 || ch <= 0) return;

    double xAt(int i) => padL + (i + 0.5) / bins.length * cw;
    double yAt(double v) => padT + (1 - (v - _yLow) / (1 - _yLow)) * ch;

    // Y gridlines + axis labels (60..100 by 10).
    final gridPaint = Paint()
      ..color = _SP.grid
      ..strokeWidth = 0.5;
    for (final v in const [0.6, 0.7, 0.8, 0.9, 1.0]) {
      final y = yAt(v);
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      _drawText(
        canvas,
        '${(v * 100).round()}',
        Offset(padL - 6, y - 5),
        align: TextAlign.right,
        width: 18,
      );
    }

    // SM-2 90% target — dashed honey line.
    final targetY = yAt(0.9);
    final dashPaint = Paint()
      ..color = _SP.honeyDeep
      ..strokeWidth = 1;
    var x = padL;
    while (x < size.width - padR) {
      canvas.drawLine(
        Offset(x, targetY),
        Offset(math.min(x + 3, size.width - padR), targetY),
        dashPaint,
      );
      x += 6;
    }
    _drawText(
      canvas,
      'SM-2 target · 90%',
      Offset(size.width - padR - 100, targetY - 12),
      color: _SP.honeyDeep,
      bold: true,
      width: 100,
      align: TextAlign.right,
    );

    // Build path for non-empty bins. Bins with 0 total just get a
    // skipped point — area connects only adjacent populated bins.
    final pts = <Offset>[];
    for (var i = 0; i < bins.length; i++) {
      final ret = bins[i].retention;
      if (ret == null) continue;
      pts.add(Offset(xAt(i), yAt(math.max(_yLow, math.min(1, ret)))));
    }
    if (pts.length >= 2) {
      final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        linePath.lineTo(pts[i].dx, pts[i].dy);
      }
      final areaPath = Path.from(linePath)
        ..lineTo(pts.last.dx, yAt(_yLow))
        ..lineTo(pts.first.dx, yAt(_yLow))
        ..close();
      canvas.drawPath(
        areaPath,
        Paint()..color = _SP.mint.withValues(alpha: 0.45),
      );
      canvas.drawPath(
        linePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _SP.mintDeep
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Points + per-bin labels.
    for (var i = 0; i < bins.length; i++) {
      final b = bins[i];
      final ret = b.retention;
      final cx = xAt(i);
      if (ret != null) {
        final cy = yAt(math.max(_yLow, math.min(1, ret)));
        final below = ret < 0.9;
        canvas.drawCircle(
          Offset(cx, cy),
          3.4,
          Paint()..color = below ? _SP.pinkDeep : _SP.mintDeep,
        );
        canvas.drawCircle(
          Offset(cx, cy),
          3.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white
            ..strokeWidth = 1,
        );
        _drawText(
          canvas,
          '${(ret * 100).round()}',
          Offset(cx - 16, cy - 14),
          color: below ? _SP.pinkDeep : IunaPalette.ink2,
          bold: true,
          width: 32,
          align: TextAlign.center,
        );
      }
      _drawText(
        canvas,
        b.label,
        Offset(cx - 24, size.height - padB + 4),
        width: 48,
        align: TextAlign.center,
      );
      _drawText(
        canvas,
        '${b.total}',
        Offset(cx - 24, size.height - padB + 16),
        width: 48,
        align: TextAlign.center,
        color: IunaPalette.inkMute,
      );
    }
  }

  static void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    Color color = IunaPalette.ink3,
    bool bold = false,
    double width = 60,
    TextAlign align = TextAlign.left,
  }) {
    _chartLabel(
      text,
      color: color,
      bold: bold,
      width: width,
      align: align,
    ).paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RetentionPainter old) => old.bins != bins;
}

// ─── Pass rate by review kind (donut) ─────────────────────────────────

class _KindBreakdownDonut extends StatelessWidget {
  const _KindBreakdownDonut({required this.byKind});
  final Map<ReviewKind, ({int total, int correct})> byKind;

  static const _palette = <ReviewKind, Color>{
    ReviewKind.review: _SP.mintDeep,
    ReviewKind.learn: _SP.honey,
    ReviewKind.relearn: _SP.pink,
  };

  @override
  Widget build(BuildContext context) {
    final entries = ReviewKind.values
        .map((k) => (k, byKind[k] ?? (total: 0, correct: 0)))
        .toList();
    final total = entries.fold<int>(0, (s, e) => s + e.$2.total);
    if (total == 0) {
      return const _EmptyHint(
        text: 'No reviews yet — pass-rate breakdown will appear here.',
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CustomPaint(
            painter: _DonutPainter(
              entries: [
                for (final e in entries)
                  if (e.$2.total > 0)
                    (color: _palette[e.$1] ?? _SP.mintDeep, value: e.$2.total),
              ],
              centerLabel: _compact(total),
              centerSub: 'reviews',
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _KindRow(
                    color: _palette[e.$1] ?? _SP.mintDeep,
                    label: _kindLabel(e.$1),
                    total: e.$2.total,
                    correct: e.$2.correct,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _kindLabel(ReviewKind k) => switch (k) {
    ReviewKind.review => 'review',
    ReviewKind.learn => 'learn',
    ReviewKind.relearn => 'relearn',
  };
}

class _KindRow extends StatelessWidget {
  const _KindRow({
    required this.color,
    required this.label,
    required this.total,
    required this.correct,
  });

  final Color color;
  final String label;
  final int total;
  final int correct;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? null : ((correct / total) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: IunaPalette.ink2,
                ),
              ),
            ),
            Text(
              _compact(total),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: IunaPalette.ink2,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 2),
          child: Text(
            pct == null ? 'no data' : '$pct% pass',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: IunaPalette.ink3,
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.entries,
    required this.centerLabel,
    required this.centerSub,
  });

  final List<({Color color, int value})> entries;
  final String centerLabel;
  final String centerSub;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = math.min(size.width, size.height) / 2 - 2;
    final inner = outer * 0.62;
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    var acc = 0.0;
    for (final e in entries) {
      final a0 = acc / total * math.pi * 2 - math.pi / 2;
      acc += e.value;
      final a1 = acc / total * math.pi * 2 - math.pi / 2;
      final path = Path()
        ..moveTo(cx + math.cos(a0) * inner, cy + math.sin(a0) * inner)
        ..lineTo(cx + math.cos(a0) * outer, cy + math.sin(a0) * outer)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: outer),
          a0,
          a1 - a0,
          false,
        )
        ..lineTo(cx + math.cos(a1) * inner, cy + math.sin(a1) * inner)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: inner),
          a1,
          a0 - a1,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = e.color);
    }
    final big = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: IunaPalette.ink,
          fontFamily: _SP.labelFont,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    big.paint(canvas, Offset(cx - big.width / 2, cy - big.height));
    final sub = TextPainter(
      text: TextSpan(
        text: centerSub,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: IunaPalette.ink3,
          fontFamily: _SP.labelFont,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sub.paint(canvas, Offset(cx - sub.width / 2, cy + 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.entries != entries ||
      old.centerLabel != centerLabel ||
      old.centerSub != centerSub;
}

// ─── Accuracy by rarity (horizontal bars) ─────────────────────────────

class _AccuracyByRarity extends StatelessWidget {
  const _AccuracyByRarity({required this.byRarity});
  final Map<Rarity, ({int total, int correct})> byRarity;

  @override
  Widget build(BuildContext context) {
    final entries = Rarity.values
        .map((r) => (r, byRarity[r] ?? (total: 0, correct: 0)))
        .toList();
    final hasData = entries.any((e) => e.$2.total > 0);
    if (!hasData) {
      return const _EmptyHint(
        text:
            "No reviews yet — accuracy by rarity will appear once you've reviewed a few cards.",
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RarityBar(
              rarity: e.$1,
              total: e.$2.total,
              correct: e.$2.correct,
            ),
          ),
        const SizedBox(height: 2),
        const Text(
          'The dotted line marks the 90% target.',
          style: TextStyle(
            fontSize: 10.5,
            color: IunaPalette.inkMute,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RarityBar extends StatelessWidget {
  const _RarityBar({
    required this.rarity,
    required this.total,
    required this.correct,
  });

  final Rarity rarity;
  final int total;
  final int correct;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : correct / total;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rarityColor(rarity),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  rarityCode(rarity),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: rarityInk(rarity),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: IunaPalette.ink3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Container(color: const Color.fromRGBO(74, 53, 32, 0.07)),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      color: rarityColor(rarity).withValues(alpha: 0.85),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -2,
                    bottom: -2,
                    child: FractionallySizedBox(
                      widthFactor: 0.9,
                      alignment: Alignment.centerLeft,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 1.5,
                          color: _SP.honeyDeep.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            total == 0 ? '—' : '${(pct * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: IunaPalette.ink,
            ),
          ),
        ),
      ],
    );
  }
}
