import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/section_header.dart';
import '../widgets/vocab_card.dart';
import 'card_detail_screen.dart';
import 'collection_screen.dart';

/// End-of-session celebration. Tier copy keys off accuracy:
/// ≥90% / ≥70% / ≥50% / else, with kicker JP + headline + italic note.
class ReviewDoneScreen extends StatefulWidget {
  const ReviewDoneScreen({
    super.key,
    required this.db,
    required this.correct,
    required this.total,
    this.doneCardIds = const [],
  });

  final AppDatabase db;
  final int correct;
  final int total;
  final List<int> doneCardIds;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (streak, today, cards) = await (
      _repo.recordStreak(),
      _repo.todayStats(),
      _repo.cardsByIds(widget.doneCardIds),
    ).wait;
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _todayCorrect = today.correct;
      _todayTotal = today.total;
      _doneCards = cards.take(5).toList();
    });
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
      Color(0xFFF3A7B5),
      Color(0xFFB8D8C9),
      Color(0xFFFFD58A),
      Color(0xFFC4B2E0),
      Color(0xFFB4D6EA),
      Color(0xFFFFC49E),
      Color(0xFFE8B96B),
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
    final todayPct = _todayTotal == 0
        ? 0
        : ((_todayCorrect / _todayTotal) * 100).round();
    // Today's accuracy drives the tier copy: split-session users don't
    // want their last-batch dip ("Every review counts") to overshadow
    // the day's actual performance. Falls back to session pct on the
    // very first session of the day before the daily_stats bump lands.
    final tierPct = _todayTotal > 0 ? todayPct : sessionPct;
    final tier = _tierFor(tierPct);

    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 9)),
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
                    onClose: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: IunaPalette.ink3,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tier.headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: IunaPalette.ink,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tier.note,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
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
                          todayCorrect: _todayCorrect,
                          todayTotal: _todayTotal,
                          todayPct: todayPct,
                          streak: _streak,
                        ),
                        if (_doneCards.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 10),
                            child: IunaEyebrow('Added to collection'),
                          ),
                          _DoneScroller(
                            cards: _doneCards,
                            onTap: (id) async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CardDetailScreen(
                                    db: widget.db,
                                    cardId: id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        IunaCtaButton(
                          label: 'See in collection',
                          leadingIcon: Icons.style_rounded,
                          onTap: () async {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => CollectionScreen(db: widget.db),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _GhostButton(
                          label: 'Back home',
                          onTap: () =>
                              Navigator.of(context).popUntil((r) => r.isFirst),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _TierCopy _tierFor(int pct) {
    if (pct >= 90) {
      return const _TierCopy(
        kicker: 'くまくま！',
        headline: "That's a perfect run.",
        note: 'Iuna is proud of you.',
      );
    } else if (pct >= 70) {
      return const _TierCopy(
        kicker: 'よくできました',
        headline: 'Great session.',
        note: 'A few tricky ones — they\'ll come back tomorrow.',
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
  const _TopBar({required this.label, required this.onClose});
  final String label;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return IunaTopBar(
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: IunaPalette.ink2,
          letterSpacing: 0.6,
        ),
      ),
      trailing: IunaIconButton(icon: Icons.close_rounded, onTap: onClose),
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
          colors: [Color(0xFFFFE9A8), Color(0xFFF3C97A), Color(0xFFC87A3A)],
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
          _StatsRow(
            label: 'TODAY',
            correct: todayCorrect,
            total: todayTotal,
            pct: todayPct,
          ),
          divider,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: Color(0xFFD97A3A),
              ),
              const SizedBox(width: 6),
              Text(
                '$streak',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: IunaPalette.ink,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'DAY STREAK',
                style: TextStyle(
                  fontSize: 10,
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: IunaPalette.ink,
                  height: 1,
                ),
                children: [
                  TextSpan(
                    text: '/$total',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.inkMute,
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
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
          return GestureDetector(
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
                      style: const TextStyle(
                        fontSize: 10,
                        color: IunaPalette.ink3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      c.meaning,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
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

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: ghostPillDecoration(
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(74, 53, 32, 0.25),
              blurRadius: 14,
              offset: Offset(0, 6),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: IunaPalette.ink2,
            ),
          ),
        ),
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
