import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_bottom_nav.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/iuna_page.dart';
import '../widgets/section_header.dart';
import '../widgets/tappable.dart';
import '../widgets/time_words.dart';
import '../widgets/vocab_card.dart';
import 'card_detail_screen.dart';
import 'collection_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'today_flow.dart';

/// End-of-session celebration. Tier copy keys off accuracy:
/// ≥90% / ≥70% / ≥50% / else, with kicker JP + headline + italic note.
class ReviewDoneScreen extends StatefulWidget {
  const ReviewDoneScreen({
    super.key,
    required this.db,
    required this.correct,
    required this.total,
    this.doneCardIds = const [],
    this.canUndo = false,
    this.now,
  });

  final AppDatabase db;
  final int correct;
  final int total;
  final List<int> doneCardIds;

  /// Pushed over a finished review, which takes the last card back when
  /// this pops with true.
  final bool canUndo;

  /// The clock for "Coming up"; goldens pin it.
  final DateTime? now;

  @override
  State<ReviewDoneScreen> createState() => _ReviewDoneScreenState();
}

class _ReviewDoneScreenState extends State<ReviewDoneScreen>
    with TickerProviderStateMixin {
  late final IunaRepository _repo = IunaRepository(widget.db);

  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..forward();

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  late final List<_ConfettiHex> _hexes = _buildConfetti();

  int _streak = 0;
  int _todayCorrect = 0;
  int _todayTotal = 0;
  List<CardRow> _doneCards = const [];
  ({DateTime nextDay, DateTime? nextReview})? _upcoming;
  bool _poolEmpty = false;
  String? _drawFilter;

  /// Cards due again before the day ends: the ones just missed, back
  /// after a short gap.
  int _dueAgain = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = widget.now;
    try {
      final (streak, today, cards, upcoming, booster, dueAgain, filter) =
          await (
            _repo.recordStreak(now: now),
            _repo.todayStats(now: now),
            _repo.cardsByIds(widget.doneCardIds),
            _repo.upcoming(now: now),
            _repo.boosterPreview(now: now),
            _repo.dueCountToday(now: now),
            _repo.drawFilterName(),
          ).wait;
      if (!mounted) return;
      setState(() {
        _streak = streak;
        _todayCorrect = today.correct;
        _todayTotal = today.total;
        _doneCards = cards.take(5).toList();
        _upcoming = upcoming;
        _poolEmpty = booster.packs > 0 && booster.newCards == 0;
        _dueAgain = dueAgain;
        _drawFilter = filter;
      });
    } catch (e, s) {
      // The recap still stands on the session's own numbers.
      debugPrint('Recap failed to load: $e\n$s');
    }
  }

  void _leave() => Navigator.of(context).popUntil((r) => r.isFirst);

  /// A fresh session over the cards due again, in place of this recap
  /// and the review under it.
  void _reviewAgain() => Navigator.of(context).pushAndRemoveUntil(
    todayRoute((_) => ReviewScreen(db: widget.db, now: widget.now)),
    (r) => r.isFirst,
  );

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SettingsScreen(db: widget.db)),
  );

  void _openCollection() {
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r.isFirst);
    navigator.push(
      MaterialPageRoute(builder: (_) => CollectionScreen(db: widget.db)),
    );
  }

  @override
  void dispose() {
    _confetti.dispose();
    _float.dispose();
    super.dispose();
  }

  List<_ConfettiHex> _buildConfetti() {
    final rng = math.Random(7);
    const cols = [
      IunaPalette.bowPink,
      IunaPalette.bowMint,
      IunaPalette.ctaTop,
      IunaPalette.chartLilac,
      Color(0xFFB4D6EA),
      Color(0xFFFFC49E),
      IunaPalette.bellGold,
    ];
    return List.generate(18, (i) {
      return _ConfettiHex(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.4,
        duration: 0.3 + rng.nextDouble() * 0.35,
        size: 14 + rng.nextDouble() * 22,
        rotation: (rng.nextDouble() - 0.5) * 2 * math.pi,
        color: cols[rng.nextInt(cols.length)],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = widget.total > 0;
    final sessionPct = hasSession
        ? ((widget.correct / widget.total) * 100).round()
        : 0;
    // The day's tally includes this session, so it never reads less,
    // even before it has loaded.
    final todayBehind = _todayTotal < widget.total;
    final todayCorrect = todayBehind ? widget.correct : _todayCorrect;
    final todayTotal = todayBehind ? widget.total : _todayTotal;
    final todayPct = todayTotal == 0
        ? 0
        : ((todayCorrect / todayTotal) * 100).round();
    // Today's accuracy drives the tier copy: split-session users don't
    // want their last-batch dip ("Every review counts") to overshadow
    // the day's actual performance. Falls back to session pct on the
    // very first session of the day before the daily_stats bump lands.
    final tierPct = todayTotal > 0 ? todayPct : sessionPct;
    final perfect = todayTotal > 0
        ? todayCorrect == todayTotal
        : hasSession && widget.correct == widget.total;
    final tier = hasSession
        ? _tierFor(tierPct, perfect: perfect)
        : _tallyCopy();

    // Under a finished review, Back leaves both rather than uncovering
    // it; only the undo arrow goes back to it.
    return PopScope<Object?>(
      canPop: !widget.canUndo,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: IunaPalette.bg,
        body: DecoratedBox(
          decoration: iunaPageBackground(),
          child: Stack(
            children: [
              const Positioned.fill(child: HexBg(seed: 9, calmTop: 0.6)),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confetti,
                    builder: (_, _) => CustomPaint(
                      painter: _ConfettiPainter(
                        hexes: _hexes,
                        progress: _confetti.value,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      label: hasSession ? 'Done' : 'Today',
                      onClose: _leave,
                      onUndo: widget.canUndo
                          ? () => Navigator.of(context).pop(true)
                          : null,
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _HeroMedallion(animation: _float),
                          const SizedBox(height: 18),
                          Text(
                            tier.kicker,
                            textAlign: TextAlign.center,
                            style: IunaText.caption.copyWith(
                              fontWeight: FontWeight.w500,
                              color: IunaPalette.ink3,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tier.headline,
                            textAlign: TextAlign.center,
                            style: IunaText.display.copyWith(
                              fontWeight: FontWeight.w600,
                              color: IunaPalette.ink,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tier.note,
                            textAlign: TextAlign.center,
                            style: IunaText.body.copyWith(
                              fontStyle: FontStyle.italic,
                              color: IunaPalette.ink3,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _StatsPanel(
                            hasSession: hasSession,
                            sessionCorrect: widget.correct,
                            sessionTotal: widget.total,
                            sessionPct: sessionPct,
                            todayCorrect: todayCorrect,
                            todayTotal: todayTotal,
                            todayPct: todayPct,
                            streak: _streak,
                          ),
                          if (_upcoming case final upcoming?) ...[
                            const SizedBox(height: 12),
                            _ComingUp(
                              nextDay: upcoming.nextDay,
                              nextReview: upcoming.nextReview,
                              poolEmpty: _poolEmpty,
                              drawFilter: _drawFilter,
                              onWidenDraw: _openSettings,
                              now: widget.now ?? DateTime.now(),
                            ),
                          ],
                          if (_doneCards.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 10),
                              child: IunaEyebrow('Reviewed this session'),
                            ),
                            _DoneScroller(
                              cards: _doneCards,
                              onTap: (id) async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CardDetailScreen(
                                      db: widget.db,
                                      cardId: id,
                                      from: IunaNavTab.today,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 20),
                          if (_dueAgain > 0) ...[
                            IunaCtaButton(
                              label: _dueAgain == 1
                                  ? 'Review again · 1 card'
                                  : 'Review again · $_dueAgain cards',
                              trailingIcon: Icons.arrow_forward_rounded,
                              onTap: _reviewAgain,
                            ),
                            const SizedBox(height: 10),
                            IunaGhostButton(label: 'Back home', onTap: _leave),
                          ] else ...[
                            IunaCtaButton(label: 'Back home', onTap: _leave),
                            const SizedBox(height: 10),
                            IunaGhostButton(
                              label: 'See in collection',
                              leadingIcon: Icons.style_rounded,
                              onTap: _openCollection,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opened from Today with no session behind it: about the day, not a
  /// run of cards.
  _TierCopy _tallyCopy() => _todayTotal == 0
      ? const _TierCopy(
          kicker: 'ひとやすみ',
          headline: 'Nothing to review yet.',
          note: 'Your next cards are on their way.',
        )
      : const _TierCopy(
          kicker: 'おつかれさま',
          headline: 'All done for today.',
          note: 'Kuma will have more for you soon.',
        );

  _TierCopy _tierFor(int pct, {required bool perfect}) {
    if (perfect) {
      return const _TierCopy(
        kicker: 'くまくま！',
        headline: "That's a perfect run.",
        note: 'Kuma is proud of you.',
      );
    } else if (pct >= 90) {
      return const _TierCopy(
        kicker: 'すごい！',
        headline: 'Excellent session.',
        note: 'Only a slip or two — Kuma is proud of you.',
      );
    } else if (pct >= 70) {
      return const _TierCopy(
        kicker: 'よくできました',
        headline: 'Great session.',
        note: 'A few tricky ones — they\'ll come back soon.',
      );
    } else if (pct >= 50) {
      return const _TierCopy(
        kicker: 'おつかれさま',
        headline: 'Nice work today.',
        note: 'Slow and steady wins the den.',
      );
    } else {
      return const _TierCopy(
        kicker: 'がんばって',
        headline: 'Every review counts.',
        note: 'You\'ve planted seeds — they\'ll sprout.',
      );
    }
  }
}

class _TierCopy {
  const _TierCopy({
    required this.kicker,
    required this.headline,
    required this.note,
  });
  final String kicker;
  final String headline;
  final String note;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.label, required this.onClose, this.onUndo});
  final String label;
  final VoidCallback onClose;

  /// Takes back the session's last card; null with nothing to take back.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    // Close on the left and undo on the right, as in the review.
    return IunaTopBar(
      leading: IunaIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Close',
        onTap: onClose,
      ),
      title: IunaTopBarTitle(label),
      trailing: onUndo == null
          ? null
          : IunaIconButton(
              icon: Icons.undo_rounded,
              tooltip: 'Undo last card',
              onTap: onUndo,
            ),
    );
  }
}

/// When the next pack and the next review come, so a finished day
/// doesn't end on a guess.
class _ComingUp extends StatelessWidget {
  const _ComingUp({
    required this.nextDay,
    required this.nextReview,
    required this.poolEmpty,
    required this.drawFilter,
    required this.onWidenDraw,
    required this.now,
  });

  final DateTime nextDay;
  final DateTime? nextReview;

  /// Every card in the draw pool is collected: no pack is coming.
  final bool poolEmpty;

  /// What the draw is narrowed to, which Settings can widen.
  final String? drawFilter;
  final VoidCallback onWidenDraw;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final nextReview = this.nextReview;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),
      decoration: paperPanelDecoration(),
      child: Column(
        children: [
          _ComingRow(
            icon: Icons.card_giftcard_rounded,
            label: 'Next pack',
            value: !poolEmpty
                ? _capitalized(whenWords(nextDay, now))
                : drawFilter != null
                ? 'Every $drawFilter card is collected'
                : 'Every card is collected',
          ),
          if (poolEmpty && drawFilter != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onWidenDraw,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Draw from more in Settings'),
              ),
            ),
          if (nextReview != null)
            _ComingRow(
              icon: Icons.schedule_rounded,
              label: 'Next review',
              value: _capitalized(whenWords(nextReview, now)),
            ),
        ],
      ),
    );
  }

  static String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _ComingRow extends StatelessWidget {
  const _ComingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: IunaPalette.ink3),
          const SizedBox(width: 10),
          Text(
            label,
            style: IunaText.bodySmall.copyWith(color: IunaPalette.ink3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: IunaText.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: IunaPalette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMedallion extends StatelessWidget {
  const _HeroMedallion({required this.animation});
  final AnimationController animation;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final dy = math.sin(animation.value * math.pi) * 6;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _MedallionPainter(),
                child: const Center(
                  child: Text(
                    '完',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5A3210),
                      shadows: [
                        Shadow(color: Color(0x66FFFFFF), offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MedallionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 - math.pi / 2;
      final x = c.dx + math.cos(a) * r;
      final y = c.dy + math.sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: [IunaPalette.honeyPale, Color(0xFFF3C97A), Color(0xFFC87A3A)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.hasSession,
    required this.sessionCorrect,
    required this.sessionTotal,
    required this.sessionPct,
    required this.todayCorrect,
    required this.todayTotal,
    required this.todayPct,
    required this.streak,
  });

  final bool hasSession;
  final int sessionCorrect;
  final int sessionTotal;
  final int sessionPct;
  final int todayCorrect;
  final int todayTotal;
  final int todayPct;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: IunaPalette.ink.withValues(alpha: 0.1),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: paperPanelDecoration(),
      child: Column(
        children: [
          if (hasSession) ...[
            _StatsRow(
              label: 'SESSION',
              correct: sessionCorrect,
              total: sessionTotal,
              pct: sessionPct,
            ),
            divider,
          ],
          // The day's first session would repeat itself as Today.
          if (!hasSession || todayTotal > sessionTotal) ...[
            _StatsRow(
              label: 'TODAY',
              correct: todayCorrect,
              total: todayTotal,
              pct: todayPct,
            ),
            divider,
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: IunaPalette.flame,
              ),
              const SizedBox(width: 6),
              Text(
                '$streak',
                style: IunaText.headline.copyWith(
                  color: IunaPalette.ink,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'DAY STREAK',
                style: IunaText.eyebrow.copyWith(
                  fontWeight: FontWeight.w600,
                  color: IunaPalette.ink3,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.label,
    required this.correct,
    required this.total,
    required this.pct,
  });
  final String label;
  final int correct;
  final int total;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: IunaText.eyebrow.copyWith(
              color: IunaPalette.ink3,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text.rich(
              TextSpan(
                text: '$correct',
                style: IunaText.headline.copyWith(
                  color: IunaPalette.ink,
                  height: 1,
                ),
                children: [
                  TextSpan(
                    text: '/$total',
                    style: IunaText.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 70,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: IunaText.headline.copyWith(
              color: IunaPalette.ink,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _DoneScroller extends StatelessWidget {
  const _DoneScroller({required this.cards, required this.onTap});
  final List<CardRow> cards;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cards[i];
          return Tappable(
            onTap: () => onTap(c.id),
            child: SizedBox(
              width: 110,
              height: 140,
              child: VocabCard(
                rarity: c.rarity,
                padding: const EdgeInsets.all(10),
                elevation: 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RarityChip(rarity: c.rarity, size: RarityChipSize.compact),
                    const Spacer(),
                    Text(
                      c.kanji,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: IunaPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.kana,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IunaText.caption.copyWith(
                        color: IunaPalette.ink3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      c.meaning,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IunaText.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: IunaPalette.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiHex {
  const _ConfettiHex({
    required this.x,
    required this.delay,
    required this.duration,
    required this.size,
    required this.rotation,
    required this.color,
  });
  final double x;
  final double delay;
  final double duration;
  final double size;
  final double rotation;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.hexes, required this.progress});
  final List<_ConfettiHex> hexes;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final h in hexes) {
      // Each hex fires once across the duration; 0..1 local progress.
      final local = ((progress - h.delay) / h.duration)
          .clamp(0.0, 1.0)
          .toDouble();
      if (local <= 0 || local >= 1) continue;
      final alpha = local < 0.1
          ? local * 10
          : (1 - (local - 0.9).clamp(0.0, 0.1) * 10);
      final cy = -40 + local * (size.height + 80);
      final cx = h.x * size.width;
      final rot = h.rotation + local * math.pi * 4;

      final path = Path();
      for (var i = 0; i < 6; i++) {
        final a = rot + i * math.pi / 3 - math.pi / 2;
        final x = cx + math.cos(a) * h.size / 2;
        final y = cy + math.sin(a) * h.size / 2;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = h.color.withValues(
            alpha: (alpha * 0.85).clamp(0.0, 1.0).toDouble(),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}
