part of '../stats_screen.dart';

// ─── Headline trio ───────────────────────────────────────────────────

class _Headline extends StatelessWidget {
  const _Headline({
    required this.reviews,
    required this.trueRetention,
    required this.learned,
  });

  final int reviews;

  /// Review-kind only — null when there are no review-kind rows yet.
  final ({int correct, int total})? trueRetention;
  final int learned;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label, String? sub) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: IunaPalette.ink,
                  height: 1,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: IunaPalette.ink3,
                  height: 1,
                  letterSpacing: 0.3,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: IunaPalette.inkMute,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final divider = Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 14),
      color: _SP.grid,
    );

    final acc = trueRetention;
    final accValue = acc == null
        ? '—'
        : '${((acc.correct / acc.total) * 100).round()}%';
    final accSub = acc == null
        ? 'no mature reviews yet'
        : 'mature · n=${_compact(acc.total, threshold: 10000)}';

    return Container(
      decoration: paperPanelDecoration(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(_compact(reviews, threshold: 10000), 'reviews', 'lifetime'),
            divider,
            cell(accValue, 'accuracy', accSub),
            divider,
            cell(_compact(learned, threshold: 10000), 'learned', 'cards owned'),
          ],
        ),
      ),
    );
  }
}
