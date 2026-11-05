import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../games/games_screen.dart';
import '../learn/learn.dart';
import '../services/drive_auth.dart';
import '../services/drive_sync.dart';
import '../theme/iuna_theme.dart';
import '../widgets/booster_pack.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_bottom_nav.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/section_header.dart';
import '../widgets/snack.dart';
import '../widgets/tappable.dart';
import '../widgets/vocab_card.dart';
import 'card_detail_screen.dart';
import 'app_nav.dart';
import 'collection_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'today_flow.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.db, this.kumaSeed});

  final AppDatabase db;

  /// Pin the Kuma variant for stable goldens / screenshots. Null in
  /// production so the bear randomizes black/white per mount.
  final int? kumaSeed;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final IunaRepository _repo = IunaRepository(widget.db);

  bool _loading = true;
  ({int packs, int newCards}) _booster = (packs: 0, newCards: 0);
  int _dueCount = 0;
  int _streak = 0;
  int _learned = 0;
  int _wishCount = 0;
  List<RecentLearned> _recent = const [];

  /// Whether a Google account is signed in for Drive backup. The home
  /// screen only exposes pull-to-refresh in that state — signed-out
  /// users would see a silent no-op otherwise (per spec: no nudge, but
  /// also no confusing dead gesture).
  bool _driveSignedIn = DriveAuth.instance.currentUser != null;
  StreamSubscription<GoogleSignInAccount?>? _driveSub;

  /// Wall-clock instant of the last completed pull-triggered backup.
  /// The data reload always runs on pull, but a fresh backup needs
  /// ≥ 60 s since the last to avoid hammering Drive on rapid pulls.
  DateTime? _lastPullBackupAt;

  @override
  void initState() {
    super.initState();
    _refresh();
    _driveSub = DriveAuth.instance.onUserChanged.listen((acc) {
      if (!mounted) return;
      setState(() => _driveSignedIn = acc != null);
    });
    DriveAuth.instance.signInSilently();
  }

  @override
  void dispose() {
    _driveSub?.cancel();
    super.dispose();
  }

  /// Reloads in place; only the first load shows the spinner, so a
  /// return from another screen doesn't swap the whole tree out.
  Future<void> _refresh() async {
    final (preview, due, streak, stats, wishCount, recent) = await (
      _repo.boosterPreview(),
      _repo.dueCountToday(),
      _repo.recordStreak(),
      _repo.collectionStats(),
      _repo.wishedCount(),
      _repo.recentlyObtained(limit: 10),
    ).wait;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _booster = preview;
      _dueCount = due;
      _streak = streak;
      _learned = stats.owned;
      _wishCount = wishCount;
      _recent = [
        for (final e in recent)
          RecentLearned(card: e.card, level: e.userCard!.level),
      ];
    });
  }

  Future<void> _openWishlist() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionScreen(db: widget.db, initialWishedOnly: true),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SettingsScreen(db: widget.db)));
    if (!mounted) return;
    await _refresh();
  }

  // Games only write their memory, which Home doesn't show: no refresh.
  void _openGames() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => GamesScreen(db: widget.db)));

  Future<void> _openStats() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StatsScreen(db: widget.db)));
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openCardDetail(int cardId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(
          db: widget.db,
          cardId: cardId,
          from: IunaNavTab.home,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  /// Pull-to-refresh handler. Only wired for signed-in users (the
  /// RefreshIndicator is omitted otherwise), so we can run both the
  /// data reload and a Drive backup unconditionally here. The backup
  /// half is throttled to once every 60 s so a flurry of pulls doesn't
  /// burn quota.
  Future<void> _onPullRefresh() async {
    await _refresh();
    if (!mounted) return;

    final last = _lastPullBackupAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 60) {
      return;
    }

    // Courses ride along, but only when they changed since their last
    // upload — see DriveSync.backupSource.
    final courses = await Learn.instance.snapshots();
    final result = await DriveSync(_repo).backupAll(alongside: courses);
    _lastPullBackupAt = DateTime.now();
    if (!mounted) return;

    // Signed out mid-call stays silent.
    final message = backupMessage(
      result,
      alongside: courses,
      quietWhenSignedOut: true,
    );
    if (message != null) showSnack(context, message);
  }

  Future<void> _openTodayFlow() async {
    await openTodayFlow(context, widget.db);
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg()),
            SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: const IgnorePointer(child: IunaNavFade()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNav(
                db: widget.db,
                active: IunaNavTab.home,
                onReturn: _refresh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wrap [child] in a [RefreshIndicator] only when the user is signed
  /// into Drive. Signed-out users get a plain scroll view — no
  /// pull-to-refresh affordance, no silent gesture failure.
  Widget _maybeWrapInRefresh(Widget child) {
    if (!_driveSignedIn) return child;
    return RefreshIndicator(
      onRefresh: _onPullRefresh,
      color: IunaPalette.pawBrown,
      child: child,
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _TopBar(onSettings: _openSettings, onStats: _openStats),
        Expanded(
          child: _maybeWrapInRefresh(
            ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: _Greeting(returning: _learned > 0),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _HeroPack(
                    booster: _booster,
                    dueCount: _dueCount,
                    onTap: _openTodayFlow,
                    kumaSeed: widget.kumaSeed,
                  ),
                ),
                const SizedBox(height: 14),
                _StatsRow(streak: _streak, due: _dueCount, learned: _learned),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: IunaEyebrow('Recently collected'),
                ),
                if (_recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 4, 18, 4),
                    child: Text(
                      'No cards yet — open a pack to start your collection.',
                      style: TextStyle(fontSize: 13, color: IunaPalette.ink3),
                    ),
                  )
                else
                  _RecentScroller(
                    cards: _recent,
                    onTap: (id) => _openCardDetail(id),
                  ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _LinkPanel(
                    icon: Icons.grid_view_rounded,
                    tint: IunaPalette.rarityCommonInk,
                    wash: IunaPalette.rarityCommon.withValues(alpha: 0.5),
                    title: 'Games',
                    subtitle: 'Practice the cards you find hard',
                    onTap: _openGames,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _LinkPanel(
                    icon: Icons.bookmark_rounded,
                    tint: IunaPalette.raritySuperRareInk,
                    wash: const Color(0x59C4B2E0),
                    title: switch (_wishCount) {
                      0 => 'Your wishlist is empty',
                      1 => '1 card on your wishlist',
                      final n => '$n cards on your wishlist',
                    },
                    subtitle: _wishCount == 0
                        ? 'Tap the bookmark on a card to add it. '
                              'It shows up in a pack soon.'
                        : 'They show up in a pack soon.',
                    onTap: _wishCount == 0 ? null : _openWishlist,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings, required this.onStats});
  final VoidCallback onSettings;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 2),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [IunaPalette.heroTop, IunaPalette.bowPink],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(120, 40, 60, 0.18),
                  blurRadius: 0,
                  offset: Offset(0, 0),
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'い',
                style: TextStyle(
                  color: Color(0xFF5A3210),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Iuna',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: IunaPalette.ink,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          IunaIconButton(
            icon: Icons.show_chart_rounded,
            tooltip: 'Stats',
            onTap: onStats,
          ),
          IunaIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.returning});

  /// Whether the learner has cards already; a first visit gets a plain
  /// welcome rather than a welcome back.
  final bool returning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          returning ? 'おかえり' : 'ようこそ',
          style: const TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: IunaPalette.ink3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          returning ? 'Welcome back.' : 'Welcome.',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: IunaPalette.ink,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _HeroPack extends StatelessWidget {
  const _HeroPack({
    required this.booster,
    required this.dueCount,
    required this.onTap,
    this.kumaSeed,
  });

  final ({int packs, int newCards}) booster;
  final int dueCount;
  final VoidCallback onTap;
  final int? kumaSeed;

  @override
  Widget build(BuildContext context) {
    final newCards = booster.newCards;
    final available = newCards > 0;
    final reviews = dueCount == 1 ? '1 review' : '$dueCount reviews';
    final String title, sub;
    if (available) {
      title = "Today's pack";
      sub = '${newCards == 1 ? "1 new card" : "$newCards new cards"} · '
          '$reviews due';
    } else {
      final outOfCards = booster.packs > 0;
      title = outOfCards ? 'No new cards left' : 'No pack today';
      sub = dueCount > 0
          ? '$reviews due today'
          : outOfCards
          ? 'You have every card in the draw pool.'
          : 'All caught up — come back tomorrow.';
    }
    final String? cta = available
        ? 'Open & review'
        : (dueCount > 0 ? 'Start review' : null);

    return Tappable(
      onTap: onTap,
      child: Container(
        // A floor, not a height: larger text grows the hero instead of
        // overflowing it.
        constraints: const BoxConstraints(minHeight: 178),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(IunaRadii.xl),
          gradient: const LinearGradient(
            begin: Alignment(-0.4, -1),
            end: Alignment(0.4, 1),
            colors: [IunaPalette.heroTop, IunaPalette.bowPink],
          ),
          boxShadow: panelShadow(),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(IunaRadii.xl),
          child: Stack(
            children: [
              // Soft top-right radial highlight.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.6, -0.5),
                      radius: 1.0,
                      colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              // Mini pack peeking from the right, rotated 8°. Sized so
              // the "TODAY" eyebrow + Kuma seal + "パック" footer all
              // read clearly against the hero gradient.
              Positioned(
                right: -4,
                top: 16,
                child: Transform.rotate(
                  angle: 8 * math.pi / 180,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 120,
                    height: 170,
                    child: BoosterPack(
                      width: 120,
                      height: 158,
                      label: 'TODAY',
                      kumaSize: 60,
                      elevation: 0.7,
                      variantSeed: kumaSeed,
                    ),
                  ),
                ),
              ),
              // Foreground copy. Reserved width keeps the title clear of
              // the rotated pack peek on the right.
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 122, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: IunaPalette.heroInk,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: IunaPalette.heroInk,
                      ),
                    ),
                    if (cta != null) ...[
                      const SizedBox(height: 14),
                      _HeroCta(label: cta),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hero's call to action, drawn as the honey primary button. The
/// whole hero takes the tap.
class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: ctaDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.card_giftcard_rounded, size: 16, color: kCtaInk),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kCtaInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.streak,
    required this.due,
    required this.learned,
  });

  final int streak;
  final int due;
  final int learned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // The streak tile's ring is taller than the plain-digit tiles, so
      // without IntrinsicHeight + stretch the cream backgrounds end up
      // mismatched even though the Row reserves the same row height.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _StreakStat(streak: streak)),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(value: '$due', label: 'due now'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(value: '$learned', label: 'collected'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: paperPanelDecoration(
        borderRadius: BorderRadius.circular(IunaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: IunaPalette.ink,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          _StatLabel(label),
        ],
      ),
    );
  }
}

/// A stat tile's caption: one line, shrunk rather than broken when the
/// text is large.
class _StatLabel extends StatelessWidget {
  const _StatLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: IunaPalette.ink3,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final pct = (streak / 14).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: paperPanelDecoration(
        borderRadius: BorderRadius.circular(IunaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StreakRing(progress: pct, value: streak),
          const SizedBox(height: 4),
          const _StatLabel('day streak'),
        ],
      ),
    );
  }
}

class _StreakRing extends StatelessWidget {
  const _StreakRing({required this.progress, required this.value});
  final double progress;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
        painter: _RingPainter(progress: progress),
        child: Center(
          child: Text(
            '$value',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: IunaPalette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color.fromRGBO(74, 53, 32, 0.08),
    );
    if (progress > 0) {
      final sweep = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        true,
        Paint()..color = IunaPalette.bellGold,
      );
    }
    canvas.drawCircle(center, radius - 3, Paint()..color = IunaPalette.paper);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class RecentLearned {
  const RecentLearned({required this.card, required this.level});
  final CardRow card;
  final int level;
}

class _RecentScroller extends StatelessWidget {
  const _RecentScroller({required this.cards, required this.onTap});
  final List<RecentLearned> cards;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // A horizontal list needs a fixed height, so it grows with the
    // text size instead of reading it from the cards.
    final textGrowth =
        (MediaQuery.textScalerOf(context).scale(100) / 100 - 1).clamp(0.0, 1.0);
    final cardHeight = 150 + 64 * textGrowth;
    return SizedBox(
      height: cardHeight + 8,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = cards[i].card;
              return Tappable(
                onTap: () => onTap(c.id),
                child: SizedBox(
                  width: 120,
                  height: cardHeight,
                  child: VocabCard(
                    rarity: c.rarity,
                    padding: const EdgeInsets.all(12),
                    elevation: 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RarityChip(
                          rarity: c.rarity,
                          size: RarityChipSize.compact,
                        ),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            c.kanji,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: IunaPalette.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.kana,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: IunaPalette.ink2,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: IgnorePointer(
              child: Container(
                width: 16,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [IunaPalette.bg, Color(0x00FBF3E2)],
                    stops: [0.1, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                width: 16,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [IunaPalette.bg, Color(0x00FBF3E2)],
                    stops: [0.1, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row on Home: a tinted icon, a title and a line under it. Without
/// [onTap] it is a plain tip, with no chevron.
class _LinkPanel extends StatelessWidget {
  const _LinkPanel({
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: paperPanelDecoration(
        borderRadius: BorderRadius.circular(IunaRadii.md),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: wash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: IunaPalette.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: IunaPalette.ink3,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3),
        ],
      ),
    );
    return onTap == null ? panel : Tappable(onTap: onTap, child: panel);
  }
}
