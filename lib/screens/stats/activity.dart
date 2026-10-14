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
            const _LegendDot(color: _SP.mintDeep, label: 'correct'),
            const SizedBox(width: 14),
            const _LegendDot(color: _SP.pink, label: 'wrong'),
            const Spacer(),
            Text(
              'peak $peak/day',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: IunaPalette.ink3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _ActivityPainter(days: days, peak: peak),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter({required this.days, required this.peak});

  final List<DailyActivity> days;
  final int peak;

  @override
  void paint(Canvas canvas, Size size) {
    const labelGutter = 18.0;
    final chartH = size.height - labelGutter;

    final gridPaint = Paint()
      ..color = _SP.grid
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, chartH),
      Offset(size.width, chartH),
      Paint()
        ..color = _SP.gridStrong
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
          Paint()..color = _SP.pink,
        );
      }
      if (correctH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, correctTop, bw, correctH),
            const Radius.circular(1.5),
          ),
          Paint()..color = _SP.mintDeep,
        );
      }
    }
    _chartLabel('${days.length}d ago').paint(canvas, Offset(0, chartH + 4));
    final today = _chartLabel('today');
    today.paint(canvas, Offset(size.width - today.width, chartH + 4));
  }

  @override
  bool shouldRepaint(covariant _ActivityPainter old) =>
      old.days != days || old.peak != peak;
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
        SizedBox(
          height: 80,
          child: CustomPaint(
            painter: _HeatmapPainter(days: days, peak: peak),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Less',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: IunaPalette.ink3,
              ),
            ),
            const SizedBox(width: 6),
            for (final c in const [
              _SP.heatmap0,
              _SP.heatmap1,
              _SP.heatmap2,
              _SP.heatmap3,
              _SP.heatmap4,
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
            const Text(
              'More',
              style: TextStyle(
                fontSize: 10,
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
    if (v <= 0) return _SP.heatmap0;
    if (v < 0.25) return _SP.heatmap1;
    if (v < 0.50) return _SP.heatmap2;
    if (v < 0.75) return _SP.heatmap3;
    return _SP.heatmap4;
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '5 weeks ago',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: IunaPalette.ink3,
                ),
              ),
              Text(
                'today',
                style: TextStyle(
                  fontSize: 10,
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
