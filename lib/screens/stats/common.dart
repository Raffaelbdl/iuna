part of '../stats_screen.dart';

// ─── Stats palette (warm cream tuned to the design) ───────────────────

class _SP {
  static const mint = Color(0xFFA9D4C2);
  static const mintDeep = Color(0xFF7FBFA3);
  static const pink = Color(0xFFF3A7B5);
  static const pinkDeep = Color(0xFFD97A8C);
  static const honey = Color(0xFFF0C168);
  static const honeyDeep = Color(0xFFD49A3A);
  static const blue = Color(0xFFBCD3DF);
  static const blueDeep = Color(0xFF7FAABE);
  static const lilac = Color(0xFFC4B2E0);
  static const lilacDeep = Color(0xFF9A7EC5);

  static const grid = Color.fromRGBO(74, 53, 32, 0.08);
  static const gridStrong = Color.fromRGBO(74, 53, 32, 0.14);
  static const chipBg = Color.fromRGBO(74, 53, 32, 0.06);

  static const heatmap0 = Color.fromRGBO(74, 53, 32, 0.05);
  static const heatmap1 = Color(0xFFDFE8D8);
  static const heatmap2 = Color(0xFFBDD9C4);
  static const heatmap3 = Color(0xFF92C4A8);
  static const heatmap4 = Color(0xFF5FA982);

  static const learning = Color(0xFFDFE8D8);
  static const learningInk = Color(0xFF7A9B76);
  static const matureInk = Color(0xFF5B8398);

  // Painter labels need an explicit family or test-font goldens go blank.
  static const labelFont = 'Roboto';
}

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: IunaPalette.ink,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
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
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _SP.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            _ChipButton(
              label: labels[o] ?? o.toString(),
              selected: o == value,
              compact: compact,
              onTap: () => onChange(o),
            ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
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
            fontSize: compact ? 10 : 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? IunaPalette.ink : IunaPalette.ink3,
            letterSpacing: 0.2,
          ),
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
        style: const TextStyle(
          fontSize: 12,
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

/// Lays out one chart label in the shared 9.5 pt painter style. With a
/// [width] the text is boxed to it so [align] applies.
TextPainter _chartLabel(
  String text, {
  Color color = IunaPalette.ink3,
  bool bold = false,
  double? width,
  TextAlign align = TextAlign.left,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color,
        fontFamily: _SP.labelFont,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
  );
  return width == null
      ? (tp..layout())
      : (tp..layout(minWidth: width, maxWidth: width));
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
            const TextSpan(
              text: '完 ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _SP.mintDeep,
              ),
            ),
          TextSpan(
            text: '$owned',
            style: TextStyle(
              fontSize: 11,
              fontWeight: done ? FontWeight.w700 : FontWeight.w600,
              color: done ? _SP.mintDeep : IunaPalette.ink2,
            ),
          ),
          TextSpan(
            text: '/$total',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: IunaPalette.inkMute,
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
    this.unitSize = 11,
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
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
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
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
