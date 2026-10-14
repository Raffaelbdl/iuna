part of '../stats_screen.dart';

// ─── Leech list with mini-bars ───────────────────────────────────────

class _LeechList extends StatelessWidget {
  const _LeechList({required this.entries});
  final List<LeechEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final maxFails = entries.fold<int>(0, (m, e) => math.max(m, e.failCount));
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i != 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: Color.fromRGBO(74, 53, 32, 0.08),
              ),
            ),
          _LeechRow(entry: entries[i], maxFails: maxFails),
        ],
      ],
    );
  }
}

class _LeechRow extends StatelessWidget {
  const _LeechRow({required this.entry, required this.maxFails});
  final LeechEntry entry;
  final int maxFails;

  @override
  Widget build(BuildContext context) {
    final c = entry.card;
    final pct = maxFails == 0 ? 0.0 : entry.failCount / maxFails;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              c.kanji.characters.first,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: IunaPalette.ink,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.kana,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: IunaPalette.ink2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.meaning,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: IunaPalette.ink3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 64,
              height: 6,
              child: Stack(
                children: [
                  Container(color: const Color.fromRGBO(74, 53, 32, 0.07)),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(color: _SP.pinkDeep),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              '${entry.failCount}× wrong',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _SP.pinkDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
