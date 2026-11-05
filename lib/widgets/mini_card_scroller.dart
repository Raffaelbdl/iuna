import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/iuna_theme.dart';
import 'tappable.dart';
import 'vocab_card.dart';

/// A horizontal row of small cards, each opening its card: Home's
/// recently collected, or the recap's [compact] cards just reviewed.
class MiniCardScroller extends StatelessWidget {
  const MiniCardScroller({
    super.key,
    required this.cards,
    required this.onTap,
    this.compact = false,
  });

  final List<CardRow> cards;
  final ValueChanged<int> onTap;

  /// Smaller cards, flush with the panel, without Home's edge fades.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // A horizontal list needs a fixed height, so it grows with the text
    // size instead of reading it from the cards.
    final cardHeight = (compact ? 140 : 150) + 64 * context.textGrowth;
    final list = ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: compact
          ? null
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, i) => _MiniCard(
        card: cards[i],
        height: cardHeight,
        compact: compact,
        onTap: () => onTap(cards[i].id),
      ),
    );
    return SizedBox(
      height: cardHeight + (compact ? 10 : 8),
      child: compact
          ? list
          : Stack(
              children: [
                list,
                const Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: _EdgeFade(begin: Alignment.centerLeft),
                ),
                const Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: _EdgeFade(begin: Alignment.centerRight),
                ),
              ],
            ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.card,
    required this.height,
    required this.compact,
    required this.onTap,
  });

  final CardRow card;
  final double height;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = RarityChip(rarity: card.rarity, size: RarityChipSize.compact);
    return Tappable(
      onTap: onTap,
      child: SizedBox(
        width: compact ? 110 : 120,
        height: height,
        child: VocabCard(
          rarity: card.rarity,
          padding: EdgeInsets.all(compact ? 10 : 12),
          elevation: 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(fit: BoxFit.scaleDown, child: chip),
                )
              else
                chip,
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  card.kanji,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 26 : 30,
                    fontWeight: FontWeight.w700,
                    color: IunaPalette.ink,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                card.kana,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IunaText.caption.copyWith(color: IunaPalette.ink3),
              ),
              const Spacer(),
              Text(
                card.meaning,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IunaText.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: compact ? IunaPalette.ink3 : IunaPalette.ink2,
                  height: compact ? null : 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades the cards into the page at one edge of the row.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.begin});

  final Alignment begin;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 16,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: -begin,
            colors: const [IunaPalette.bg, Color(0x00FBF3E2)],
            stops: const [0.1, 1.0],
          ),
        ),
      ),
    );
  }
}
