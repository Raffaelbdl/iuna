import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/iuna_theme.dart';
import 'game_widgets.dart';
import 'pairs_screen.dart';
import 'sentence_screen.dart';
import 'sentences.dart';

/// The mini-games, opened from Home. They need no tutor key, so they
/// live outside the Learn tab.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return GamePage(
      title: 'Games',
      leadingIcon: Icons.arrow_back_rounded,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _GameTile(
            icon: Icons.grid_view_rounded,
            tint: IunaPalette.rarityCommonInk,
            wash: IunaPalette.rarityCommonFill,
            title: 'Pairs',
            subtitle: 'Match words to readings, meanings and sounds.',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PairsScreen(db: db))),
          ),
          const SizedBox(height: 12),
          _GameTile(
            icon: Icons.short_text_rounded,
            tint: IunaPalette.rarityRareInk,
            wash: IunaPalette.rarityRareFill,
            title: 'Sentences',
            subtitle: 'Rebuild a sentence from its English.',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => SentenceScreen(db: db))),
          ),
          const SizedBox(height: 12),
          _GameTile(
            icon: Icons.space_bar_rounded,
            tint: IunaPalette.raritySuperRareInk,
            wash: IunaPalette.raritySuperRareFill,
            title: 'Particles',
            subtitle: 'Fill in the missing particle.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SentenceScreen(db: db, game: SentenceGame.particles),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.icon,
    required this.tint,
    required this.wash,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color wash;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: paperPanelDecoration(),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: wash,
                borderRadius: BorderRadius.circular(IunaRadii.md),
              ),
              child: Icon(icon, color: tint, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: IunaPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.ink3,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3),
          ],
        ),
      ),
    );
  }
}
