part of '../stats_screen.dart';

// Painter labels need an explicit family or test-font goldens go blank.
const _kChartLabelFont = 'Roboto';

// ─── Reusable building blocks ────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: paperPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: IunaPanelTitle(title)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: IunaText.caption.copyWith(
              height: 1.4,
              color: IunaPalette.ink3,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.value,
    required this.options,
    required this.labels,
    required this.onChange,
    this.compact = false,
  });

  final T value;
  final List<T> options;
  final Map<T, String> labels;
  final ValueChanged<T> onChange;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Each option carries its slice of the track, so its tap target
    // can run the full 48 px above and below the slim pill.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, o) in options.indexed)
          Tappable(
            onTap: () => onChange(o),
            selected: o == value,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 3 : 0,
                    right: i == options.length - 1 ? 3 : 0,
                    top: 3,
                    bottom: 3,
                  ),
                  decoration: BoxDecoration(
                    color: IunaPalette.chipBg,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(i == 0 ? 999 : 0),
                      right: Radius.circular(
                        i == options.length - 1 ? 999 : 0,
                      ),
                    ),
                  ),
                  child: _ChipButton(
                    label: labels[o] ?? o.toString(),
                    selected: o == value,
                    compact: compact,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.compact,
  });

  final String label;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: selected ? IunaPalette.bellGold : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: IunaText.caption.fontSize,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? IunaPalette.ink : IunaPalette.ink3,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Empty hint ──────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: IunaText.caption.copyWith(
          color: IunaPalette.ink3,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: IunaText.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: IunaPalette.ink3,
          ),
        ),
      ],
    );
  }
}

/// How much a chart's painted labels follow the system text size: up
/// to [_kChartMaxTextScale], past which they would collide inside the
/// fixed-height canvas.
const _kChartMaxTextScale = 1.3;

TextScaler _chartScaler(BuildContext context) => MediaQuery.textScalerOf(
  context,
).clamp(maxScaleFactor: _kChartMaxTextScale);

/// Lays out one chart label in the shared painter style. With a
/// [width] the text is boxed to it so [align] applies.
TextPainter _chartLabel(
  String text, {
  required TextScaler scaler,
  Color color = IunaPalette.ink3,
  bool bold = false,
  double? width,
  TextAlign align = TextAlign.left,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: IunaText.caption.copyWith(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color,
        fontFamily: _kChartLabelFont,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
    textScaler: scaler,
  );
  return width == null
      ? (tp..layout())
      : (tp..layout(minWidth: width, maxWidth: width));
}

/// Paints [tp] centred on [centerX], shrunk to [maxWidth] when it is
/// wider: an axis label never runs into its neighbour.
void _paintFitted(
  Canvas canvas,
  TextPainter tp, {
  required double centerX,
  required double top,
  required double maxWidth,
}) {
  final scale = tp.width > maxWidth ? maxWidth / tp.width : 1.0;
  canvas.save();
  canvas.translate(centerX - tp.width * scale / 2, top);
  canvas.scale(scale);
  tp.paint(canvas, Offset.zero);
  canvas.restore();
}

/// A painted chart of [height]. A screen reader hears [summary] in
/// place of the pixels.
class _ChartCanvas extends StatelessWidget {
  const _ChartCanvas({
    required this.summary,
    required this.painter,
    this.height,
  });

  final String summary;
  final CustomPainter Function(TextScaler scaler) painter;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: summary,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: painter(_chartScaler(context)),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// 12345 → "12.3k"; counts under [threshold] stay whole.
String _compact(int n, {int threshold = 1000}) {
  if (n >= 100000) return '${(n / 1000).toStringAsFixed(0)}k';
  if (n >= threshold) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}

/// The 10 px rounded fill bar under JLPT levels and themed packs.
class _FillBar extends StatelessWidget {
  const _FillBar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Container(color: const Color.fromRGBO(74, 53, 32, 0.07)),
            FractionallySizedBox(
              widthFactor: fraction,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// "owned/total", prefixed with 完 once complete.
class _OwnedCount extends StatelessWidget {
  const _OwnedCount({required this.owned, required this.total});
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final done = total > 0 && owned >= total;
    return Text.rich(
      TextSpan(
        children: [
          if (done)
            TextSpan(
              text: '完 ',
              style: IunaText.chip.copyWith(
                fontWeight: FontWeight.w700,
                color: IunaPalette.mintInk,
              ),
            ),
          TextSpan(
            text: '$owned',
            style: IunaText.caption.copyWith(
              fontWeight: done ? FontWeight.w700 : FontWeight.w600,
              color: done ? IunaPalette.mintInk : IunaPalette.ink2,
            ),
          ),
          TextSpan(
            text: '/$total',
            style: IunaText.caption.copyWith(
              fontWeight: FontWeight.w500,
              color: IunaPalette.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small label-over-number tile in the streak and time-spent cards.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.unit = '',
    this.unitSize = 12,
  });

  final String label;
  final String value;
  final String unit;
  final double unitSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(74, 53, 32, 0.05),
        borderRadius: BorderRadius.circular(IunaRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: IunaText.caption.copyWith(
              fontWeight: FontWeight.w500,
              color: IunaPalette.ink3,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: IunaText.title.copyWith(
                    color: IunaPalette.ink,
                    height: 1,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: unitSize,
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.ink3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
