part of '../stats_screen.dart';

// ─── Maturity histogram with stage tags ───────────────────────────────

class _MaturityChart extends StatelessWidget {
  const _MaturityChart({required this.bins});
  final List<MaturityBin> bins;

  static const _stages = [
    'learn',
    'learn',
    'young',
    'young',
    'young',
    'mature',
    'mature',
    'mature',
  ];

  @override
  Widget build(BuildContext context) {
    final total = bins.fold<int>(0, (s, b) => s + b.count);
    if (total == 0) {
      return const _EmptyHint(
        text: 'No mature cards yet — review a few times to grow intervals.',
      );
    }
    final stageTotals = {'learn': 0, 'young': 0, 'mature': 0};
    for (var i = 0; i < bins.length; i++) {
      final s = _stages[math.min(i, _stages.length - 1)];
      stageTotals[s] = (stageTotals[s] ?? 0) + bins[i].count;
    }
    final maturePct = total == 0
        ? 0
        : ((stageTotals['mature']! / total) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StageTag(
              color: _SP.learning,
              dark: _SP.learningInk,
              label: 'learning ${stageTotals['learn']}',
            ),
            _StageTag(
              color: _SP.blue,
              dark: _SP.blueDeep,
              label: 'young ${stageTotals['young']}',
            ),
            _StageTag(
              color: _SP.blueDeep,
              dark: _SP.matureInk,
              label: 'mature ${stageTotals['mature']}',
              solid: true,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'mature $maturePct% of $total',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: IunaPalette.ink3,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _MaturityPainter(bins: bins, stages: _stages),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _StageTag extends StatelessWidget {
  const _StageTag({
    required this.color,
    required this.dark,
    required this.label,
    this.solid = false,
  });

  final Color color;
  final Color dark;
  final String label;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : Colors.transparent,
        border: solid ? null : Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: solid ? Colors.white : color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: solid ? Colors.white : dark,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaturityPainter extends CustomPainter {
  _MaturityPainter({required this.bins, required this.stages});
  final List<MaturityBin> bins;
  final List<String> stages;

  static Color _color(String stage) => switch (stage) {
    'mature' => _SP.blueDeep,
    'young' => _SP.blue,
    _ => _SP.learning,
  };

  @override
  void paint(Canvas canvas, Size size) {
    const padT = 16.0, padB = 22.0;
    final chartH = size.height - padT - padB;
    final maxV = bins.fold<int>(0, (m, b) => math.max(m, b.count));
    if (maxV == 0) return;
    final slot = size.width / bins.length;
    final bw = math.max(2.0, slot * 0.78);
    canvas.drawLine(
      Offset(0, padT + chartH),
      Offset(size.width, padT + chartH),
      Paint()
        ..color = _SP.gridStrong
        ..strokeWidth = 0.5,
    );
    for (var i = 0; i < bins.length; i++) {
      final b = bins[i];
      final left = i * slot + (slot - bw) / 2;
      final stage = stages[math.min(i, stages.length - 1)];
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
          color: IunaPalette.ink2,
          bold: true,
        );
        n.paint(canvas, Offset(left + (bw - n.width) / 2, top - 12));
      }
      final l = _chartLabel(b.label);
      l.paint(canvas, Offset(left + (bw - l.width) / 2, padT + chartH + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _MaturityPainter old) =>
      old.bins != bins || old.stages != stages;
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
    const minPerCard = 6;
    final totalMin = (total * minPerCard / 60).round();
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IunaPalette.ink,
                    ),
                  ),
                  const TextSpan(
                    text: 'reviews',
                    style: TextStyle(
                      fontSize: 11,
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
                  const TextSpan(
                    text: '≈ ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.ink3,
                    ),
                  ),
                  TextSpan(
                    text: '${totalMin}h',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IunaPalette.ink,
                    ),
                  ),
                  const TextSpan(
                    text: ' total · ${minPerCard}s/card',
                    style: TextStyle(
                      fontSize: 11,
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
        SizedBox(
          height: 110,
          child: CustomPaint(
            painter: _ForecastPainter(days: days),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter({required this.days});
  final List<ForecastDay> days;

  @override
  void paint(Canvas canvas, Size size) {
    const padT = 12.0, padB = 22.0;
    final chartH = size.height - padT - padB;
    final maxV = days.fold<int>(0, (m, d) => math.max(m, d.due));
    if (maxV == 0) return;
    final slot = size.width / days.length;
    final bw = math.max(2.0, slot * 0.78);
    final gridPaint = Paint()
      ..color = _SP.grid
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
        Paint()..color = _SP.honey,
      );
      if (i == 0 || i == 7 || i == days.length - 1) {
        final label = i == 0
            ? 'today'
            : i == 7
            ? '+7d'
            : '+${days.length - 1}d';
        final tp = _chartLabel(label);
        tp.paint(canvas, Offset(left + (bw - tp.width) / 2, padT + chartH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter old) => old.days != days;
}
