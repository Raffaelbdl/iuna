import 'package:flutter/material.dart';

import '../db/database.dart';
import '../screens/card_detail_screen.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_bottom_nav.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/iuna_page.dart';
import '../widgets/section_header.dart';
import '../widgets/tappable.dart';
import 'pairs.dart' show shortGloss;

/// A games page: the background, a top bar with a close (or [back])
/// button and, while something can be skipped, [onSkip], and [body]
/// under it.
class GamePage extends StatelessWidget {
  const GamePage({
    super.key,
    required this.title,
    required this.body,
    this.onSkip,
    this.skipLabel = 'Skip round',
    this.back = false,
  });

  final String title;

  /// Back for the list of games, where a game has Close.
  final bool back;
  final Widget body;
  final VoidCallback? onSkip;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 5)),
            SafeArea(
              child: Column(
                children: [
                  IunaTopBar(
                    leading: back
                        ? const IunaBackButton()
                        : IunaIconButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Close game',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                    title: Text(
                      title,
                      style: IunaText.subtitle.copyWith(
                        color: IunaPalette.ink2,
                        letterSpacing: 0.6,
                      ),
                    ),
                    trailing: onSkip == null
                        ? null
                        : IunaIconButton(
                            icon: Icons.skip_next_rounded,
                            tooltip: skipLabel,
                            onTap: onSkip,
                          ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The end of a round: a headline, its figures, the words missed (each
/// opens its card), and the way on.
class GameSummary extends StatelessWidget {
  const GameSummary({
    super.key,
    required this.db,
    required this.kicker,
    required this.headline,
    required this.figures,
    required this.missed,
    required this.onNext,
    required this.onDone,
  });

  final AppDatabase db;
  final String kicker;
  final String headline;
  final List<({String value, String label})> figures;
  final List<CardRow> missed;
  final VoidCallback onNext;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Text(
          kicker,
          textAlign: TextAlign.center,
          style: IunaText.kicker.copyWith(color: IunaPalette.ink3),
        ),
        const SizedBox(height: 6),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: IunaText.banner.copyWith(color: IunaPalette.ink),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: paperPanelDecoration(),
          child: Row(
            children: [
              for (final f in figures)
                Expanded(
                  child: _Figure(value: f.value, label: f.label),
                ),
            ],
          ),
        ),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: IunaEyebrow('Worth another look'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: paperPanelDecoration(),
            child: Column(
              children: [
                for (final c in missed)
                  _MissedRow(
                    card: c,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CardDetailScreen(
                          db: db,
                          cardId: c.id,
                          from: IunaNavTab.home,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        IunaCtaButton(
          label: 'Next round',
          trailingIcon: Icons.arrow_forward_rounded,
          onTap: onNext,
        ),
        const SizedBox(height: 10),
        IunaGhostButton(label: 'Done', onTap: onDone),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: IunaText.headline.copyWith(
            color: IunaPalette.ink,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: IunaText.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: IunaPalette.ink3,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _MissedRow extends StatelessWidget {
  const _MissedRow({required this.card, required this.onTap});
  final CardRow card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    card.kanji,
                    style: IunaText.title.copyWith(color: IunaPalette.ink),
                  ),
                  if (card.kana != card.kanji) ...[
                    const SizedBox(width: 8),
                    Text(
                      card.kana,
                      style: IunaText.bodySmall.copyWith(
                        color: IunaPalette.ink3,
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shortGloss(card.meaning),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IunaText.bodySmall.copyWith(
                        color: IunaPalette.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: IunaPalette.ink3,
            ),
          ],
        ),
      ),
    );
  }
}
