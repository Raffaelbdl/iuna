part of '../stats_screen.dart';

// ─── Maturity histogram with stage tags ───────────────────────────────

class _MaturityChart extends StatelessWidget {
  const _MaturityChart({required this.bins});
  final List<MaturityBin> bins;

  @override
  Widget build(BuildContext context) {
    final total = bins.fold<int>(0, (s, b) => s + b.count);
    if (total == 0) {
      return const _EmptyHint(
        text: 'Nothing to show yet — cards settle as you review them.',
      );
    }
    // The same groups card detail names beside a card's memory level.
    final stages = [
      for (final b in bins) MemoryStage.ofInterval(b.minMinutes),
    ];
    final stageTotals = {for (final s in MemoryStage.values) s: 0};
    for (var i = 0; i < bins.length; i++) {
      stageTotals[stages[i]] = stageTotals[stages[i]]! + bins[i].count;
    }
    final maturePct = total == 0
        ? 0
        : ((stageTotals[MemoryStage.wellKnown]! / total) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A legend, not filters: dots like the other charts', in the
        // bars' own colours.
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final stage in MemoryStage.values)
              _LegendDot(
                color: _MaturityPainter._color(stage),
                label: '${stage.label} ${stageTotals[stage]}',
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$maturePct% of $total ${MemoryStage.wellKnown.label}',
          style: IunaText.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: IunaPalette.ink3,
          ),
        ),
        const SizedBox(height: 8),
        _ChartCanvas(
          height: 130,
          summary:
              'Cards by time until their next review: '
              '${[for (final b in bins) '${b.label}: ${b.count}'].join(', ')}.',
          painter: (scaler) => _MaturityPainter(bins: bins, scaler: scaler),
        ),
      ],
    );
  }
}

class _MaturityPainter extends CustomPainter {
  _MaturityPainter({required this.bins, required this.scaler});
  final List<MaturityBin> bins;
  final TextScaler scaler;

  static Color _color(MemoryStage stage) => switch (stage) {
    MemoryStage.wellKnown => IunaPalette.chartMatureInk,
    MemoryStage.gettingThere => IunaPalette.chartBlue,
    MemoryStage.learning => IunaPalette.chartLearning,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final padT = scaler.scale(16), padB = scaler.scale(22);
    final chartH = size.height - padT - padB;
    final maxV = bins.fold<int>(0, (m, b) => math.max(m, b.count));
    if (maxV == 0) return;
    final slot = size.width / bins.length;
    final bw = math.max(2.0, slot * 0.78);
    canvas.drawLine(
      Offset(0, padT + chartH),
      Offset(size.width, padT + chartH),
      Paint()
        ..color = IunaPalette.chartGridStrong
        ..strokeWidth = 0.5,
    );
    for (var i = 0; i < bins.length; i++) {
      final b = bins[i];
      final left = i * slot + (slot - bw) / 2;
      final stage = MemoryStage.ofInterval(b.minMinutes);
      final h = (b.count / maxV) * chartH;
      final top = padT + chartH - h;
      if (b.count > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, bw, h),
            const Radius.circular(3),
          ),
          Paint()..color = _color(stage),
        );
        final n = _chartLabel(
          '${b.count}',
          scaler: scaler,
          color: IunaPalette.ink2,
          bold: true,
        );
        n.paint(canvas, Offset(left + (bw - n.width) / 2, top - n.height));
      }
      _paintFitted(
        canvas,
        _chartLabel(b.label, scaler: scaler),
        centerX: left + bw / 2,
        top: padT + chartH + 4,
        maxWidth: slot - 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MaturityPainter old) =>
      old.bins != bins || old.scaler != scaler;
}

// ─── Forecast (next 14 days) with summary ─────────────────────────────

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.days});
  final List<ForecastDay> days;

  @override
  Widget build(BuildContext context) {
    final total = days.fold<int>(0, (s, d) => s + d.due);
    if (total == 0) {
      return const _EmptyHint(
        text: 'Nothing due in the next two weeks. Sit back, kuma.',
      );
    }
    const secPerCard = 6;
    final totalMin = (total * secPerCard / 60).round();
    final duration = totalMin < 60
        ? '$totalMin min'
        : '${totalMin ~/ 60}h ${totalMin % 60}m';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$total ',
                    style: IunaText.chip.copyWith(
                      fontWeight: FontWeight.w700,
                      color: IunaPalette.ink,
                    ),
                  ),
                  TextSpan(
                    text: 'reviews',
                    style: IunaText.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '≈ ',
                    style: IunaText.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.ink3,
                    ),
                  ),
                  TextSpan(
                    text: duration,
                    style: IunaText.chip.copyWith(
                      fontWeight: FontWeight.w700,
                      color: IunaPalette.ink,
                    ),
                  ),
                  TextSpan(
                    text: ' total · ${secPerCard}s/card',
                    style: IunaText.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ChartCanvas(
          height: 110,
          summary:
              '$total reviews due over the next ${days.length} days, '
              '${days.first.due} of them today.',
          painter: (scaler) => _ForecastPainter(days: days, scaler: scaler),
        ),
      ],
    );
  }
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter({required this.days, required this.scaler});
  final List<ForecastDay> days;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final padT = 12.0, padB = scaler.scale(22);
    final chartH = size.height - padT - padB;
    final maxV = days.fold<int>(0, (m, d) => math.max(m, d.due));
    if (maxV == 0) return;
    final slot = size.width / days.length;
    final bw = math.max(2.0, slot * 0.78);
    final gridPaint = Paint()
      ..color = IunaPalette.chartGrid
      ..strokeWidth = 0.5;
    for (final v in const [0.5, 1.0]) {
      final y = padT + (1 - v) * chartH;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(x + 3, y), gridPaint);
        x += 6;
      }
    }
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final h = (d.due / maxV) * chartH;
      final left = i * slot + (slot - bw) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, padT + chartH - h, bw, h),
          const Radius.circular(3),
        ),
        Paint()..color = IunaPalette.chartHoney,
      );
      if (i == 0 || i == 7 || i == days.length - 1) {
        final label = i == 0
            ? 'today'
            : i == 7
            ? '+7d'
            : '+${days.length - 1}d';
        final tp = _chartLabel(label, scaler: scaler);
        tp.paint(canvas, Offset(left + (bw - tp.width) / 2, padT + chartH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter old) =>
      old.days != days || old.scaler != scaler;
}
