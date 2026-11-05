part of '../stats_screen.dart';

// ─── Activity (stacked correct / wrong + peak callout) ────────────────

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});
  final List<DailyActivity> days;

  @override
  Widget build(BuildContext context) {
    final total = days.fold<int>(0, (s, d) => s + d.total);
    if (total == 0) {
      return const _EmptyHint(
        text: "No reviews yet — swipe a few cards and they'll show up here.",
      );
    }
    final peak = days.fold<int>(0, (m, d) => math.max(m, d.total));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _LegendDot(color: IunaPalette.chartMintDeep, label: 'correct'),
            const SizedBox(width: 14),
            const _LegendDot(color: IunaPalette.bowPink, label: 'wrong'),
            const Spacer(),
            Text(
              'peak $peak/day',
              style: IunaText.chip.copyWith(
                color: IunaPalette.ink3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ChartCanvas(
          height: 130,
          summary:
              'Reviews over the last ${days.length} days: $total in all, '
              'at most $peak in a day.',
          painter: (scaler) =>
              _ActivityPainter(days: days, peak: peak, scaler: scaler),
        ),
      ],
    );
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter({
    required this.days,
    required this.peak,
    required this.scaler,
  });

  final List<DailyActivity> days;
  final int peak;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final labelGutter = scaler.scale(18);
    final chartH = size.height - labelGutter;

    final gridPaint = Paint()
      ..color = IunaPalette.chartGrid
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, chartH),
      Offset(size.width, chartH),
      Paint()
        ..color = IunaPalette.chartGridStrong
        ..strokeWidth = 0.5,
    );
    // Mid gridline.
    final midY = chartH / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, midY), Offset(x + 3, midY), gridPaint);
      x += 6;
    }

    if (days.isEmpty || peak == 0) return;
    final slot = size.width / days.length;
    final bw = math.max(2.0, slot * 0.78);
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      if (d.total == 0) continue;
      final h = (d.total / peak) * chartH;
      final correctH = h * (d.total == 0 ? 0.0 : d.correct / d.total);
      final wrongH = h - correctH;
      final left = i * slot + (slot - bw) / 2;
      final wrongTop = chartH - h;
      final correctTop = wrongTop + wrongH;
      if (wrongH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, wrongTop, bw, wrongH),
            const Radius.circular(1.5),
          ),
          Paint()..color = IunaPalette.bowPink,
        );
      }
      if (correctH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, correctTop, bw, correctH),
            const Radius.circular(1.5),
          ),
          Paint()..color = IunaPalette.chartMintDeep,
        );
      }
    }
    _chartLabel(
      '${days.length}d ago',
      scaler: scaler,
    ).paint(canvas, Offset(0, chartH + 4));
    final today = _chartLabel('today', scaler: scaler);
    today.paint(canvas, Offset(size.width - today.width, chartH + 4));
  }

  @override
  bool shouldRepaint(covariant _ActivityPainter old) =>
      old.days != days || old.peak != peak || old.scaler != scaler;
}

// ─── Year heatmap ─────────────────────────────────────────────────────

class _YearHeatmap extends StatelessWidget {
  const _YearHeatmap({required this.days});
  final List<DailyActivity> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(0, (m, d) => math.max(m, d.total));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartCanvas(
          height: 80,
          summary:
              'Study calendar: reviewed on '
              '${days.where((d) => d.total > 0).length} of the last '
              '${days.length} days.',
          painter: (_) => _HeatmapPainter(days: days, peak: peak),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: IunaText.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: IunaPalette.ink3,
              ),
            ),
            const SizedBox(width: 6),
            for (final c in const [
              IunaPalette.heatmap0,
              IunaPalette.heatmap1,
              IunaPalette.heatmap2,
              IunaPalette.heatmap3,
              IunaPalette.heatmap4,
            ])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              'More',
              style: IunaText.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: IunaPalette.ink3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({required this.days, required this.peak});

  final List<DailyActivity> days;
  final int peak;

  static Color _colorFor(double v) {
    if (v <= 0) return IunaPalette.heatmap0;
    if (v < 0.25) return IunaPalette.heatmap1;
    if (v < 0.50) return IunaPalette.heatmap2;
    if (v < 0.75) return IunaPalette.heatmap3;
    return IunaPalette.heatmap4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cols = math.max(1, (days.length / 7).ceil());
    final gap = 2.0;
    final cellW = math.max(1.0, (size.width - gap * (cols - 1)) / cols);
    final cellH = math.max(1.0, (size.height - gap * 6) / 7);
    final cell = math.min(cellW, cellH);
    final radius = Radius.circular(2);
    final eff = peak == 0 ? 1 : peak;
    for (var i = 0; i < days.length; i++) {
      final col = i ~/ 7;
      final row = i % 7;
      final v = days[i].total / eff;
      final r = Rect.fromLTWH(
        col * (cell + gap),
        row * (cell + gap),
        cell,
        cell,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, radius),
        Paint()..color = _colorFor(v),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.days != days || old.peak != peak;
}

// ─── Streak strip ─────────────────────────────────────────────────────

class _StreakStrip extends StatelessWidget {
  const _StreakStrip({required this.stats});
  final StreakStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'current',
                value: '${stats.current}',
                unit: stats.current == 1 ? 'day' : 'days',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'longest',
                value: '${stats.longest}',
                unit: stats.longest == 1 ? 'day' : 'days',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'total days',
                value: '${stats.totalDays}',
                unit: '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats.recent.isNotEmpty) ...[
          Row(
            children: [
              for (var i = 0; i < stats.recent.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: stats.recent[i]
                          ? IunaPalette.bellGold
                          : const Color.fromRGBO(74, 53, 32, 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '5 weeks ago',
                style: IunaText.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: IunaPalette.ink3,
                ),
              ),
              Text(
                'today',
                style: IunaText.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: IunaPalette.ink3,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
