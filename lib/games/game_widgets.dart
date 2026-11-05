import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/section_header.dart';
import 'pairs.dart' show shortGloss;

/// A games page: the background, a top bar with [leadingIcon] (it
/// pops) and, while something can be skipped, [onSkip], and [body]
/// under it.
class GamePage extends StatelessWidget {
  const GamePage({
    super.key,
    required this.title,
    required this.body,
    this.onSkip,
    this.skipLabel = 'Skip round',
    this.leadingIcon = Icons.close_rounded,
  });

  final String title;

  /// Close for a game, back for the list of games.
  final IconData leadingIcon;
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
                    leading: IunaIconButton(
                      icon: leadingIcon,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: IunaPalette.ink2,
                        letterSpacing: 0.6,
                      ),
                    ),
                    trailing: onSkip == null
                        ? null
                        : Tooltip(
                            message: skipLabel,
                            child: IunaIconButton(
                              icon: Icons.skip_next_rounded,
                              onTap: onSkip,
                            ),
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

/// The end of a round: a headline, its figures, the words missed, and
/// the way on.
class GameSummary extends StatelessWidget {
  const GameSummary({
    super.key,
    required this.kicker,
    required this.headline,
    required this.figures,
    required this.missed,
    required this.onNext,
    required this.onDone,
  });

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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: IunaPalette.ink3,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: IunaPalette.ink,
            letterSpacing: -0.3,
            height: 1.1,
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: paperPanelDecoration(),
            child: Column(
              children: [for (final c in missed) _MissedRow(card: c)],
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
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: IunaPalette.ink,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
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
  const _MissedRow({required this.card});
  final CardRow card;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            card.kanji,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: IunaPalette.ink,
            ),
          ),
          if (card.kana != card.kanji) ...[
            const SizedBox(width: 8),
            Text(
              card.kana,
              style: const TextStyle(fontSize: 13, color: IunaPalette.ink3),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              shortGloss(card.meaning),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: IunaPalette.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// A centred note in place of a game, with an optional way out.
class GameNotice extends StatelessWidget {
  const GameNotice({super.key, required this.text, this.action});

  final String text;
  final ({String label, VoidCallback onTap})? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: IunaPalette.ink3,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              IunaCtaButton(
                label: action.label,
                shrinkWrap: true,
                onTap: action.onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
