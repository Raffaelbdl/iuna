part of '../stats_screen.dart';

// ─── JLPT progress (segmented bars) ──────────────────────────────────

class _JlptProgress extends StatelessWidget {
  const _JlptProgress({required this.byLevel});
  final Map<int, ({int owned, int total})> byLevel;

  static const _levelOrder = [5, 4, 3, 2, 1];
  static const _levelColors = <int, Color>{
    5: _SP.mint,
    4: _SP.blue,
    3: _SP.lilac,
    2: _SP.honey,
    1: _SP.pink,
  };

  @override
  Widget build(BuildContext context) {
    final hasAny = byLevel.values.any((v) => v.total > 0);
    if (!hasAny) {
      return const _EmptyHint(text: 'No JLPT-tagged cards in your deck yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final lvl in _levelOrder)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _JlptRow(
              level: lvl,
              owned: byLevel[lvl]?.owned ?? 0,
              total: byLevel[lvl]?.total ?? 0,
              color: _levelColors[lvl] ?? _SP.mint,
            ),
          ),
      ],
    );
  }
}

class _JlptRow extends StatelessWidget {
  const _JlptRow({
    required this.level,
    required this.owned,
    required this.total,
    required this.color,
  });

  final int level;
  final int owned;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (owned / total).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          width: 36,
          padding: const EdgeInsets.symmetric(vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(74, 53, 32, 0.07),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'N$level',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: IunaPalette.ink,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FillBar(fraction: pct, color: color),
        ),
        const SizedBox(width: 10),
        _OwnedCount(owned: owned, total: total),
      ],
    );
  }
}

// ─── Themed pack progress ─────────────────────────────────────────────

/// Same bar as [_JlptRow], but pack names are too long for the level
/// chip so the label sits above its bar. Driven entirely by the keys in
/// [byPack] — a new pack charts itself.
class _PackProgress extends StatelessWidget {
  const _PackProgress({required this.byPack});
  final Map<String, ({String label, int owned, int total})> byPack;

  static const _colors = <Color>[
    _SP.lilac,
    _SP.mint,
    _SP.honey,
    _SP.blue,
    _SP.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final packs = byPack.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, pack) in packs.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: i == packs.length - 1 ? 0 : 12),
            child: _PackRow(
              label: byPack[pack]?.label ?? pack,
              owned: byPack[pack]?.owned ?? 0,
              total: byPack[pack]?.total ?? 0,
              color: _colors[i % _colors.length],
            ),
          ),
      ],
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.label,
    required this.owned,
    required this.total,
    required this.color,
  });

  final String label;
  final int owned;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (owned / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: IunaPalette.ink,
                ),
              ),
            ),
            _OwnedCount(owned: owned, total: total),
          ],
        ),
        const SizedBox(height: 5),
        _FillBar(fraction: pct, color: color),
      ],
    );
  }
}
