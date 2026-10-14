import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../db/database.dart';
import '../db/repository.dart';
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
  bool _packAvailable = false;
  int _remainingPacks = 0;
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
    final (remaining, due, streak, stats, wishCount, recent) = await (
      _repo.remainingBoostersToday(),
      _repo.dueCountToday(),
      _repo.recordStreak(),
      _repo.collectionStats(),
      _repo.wishedCount(),
      _repo.recentlyObtained(limit: 10),
    ).wait;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _packAvailable = remaining > 0;
      _remainingPacks = remaining;
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

  Future<void> _openCollection() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CollectionScreen(db: widget.db)));
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
        builder: (_) => CardDetailScreen(db: widget.db, cardId: cardId),
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: _Greeting(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _HeroPack(
                    available: _packAvailable,
                    dueCount: _dueCount,
                    newCardCount: _remainingPacks * kDefaultPackSize,
                    onTap: _openTodayFlow,
                    kumaSeed: widget.kumaSeed,
                  ),
                ),
                const SizedBox(height: 14),
                _StatsRow(streak: _streak, due: _dueCount, learned: _learned),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: IunaEyebrow('Recently learned'),
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
                  child: _WishlistNudge(
                    count: _wishCount,
                    onTap: _openCollection,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD994), Color(0xFFF3A7B5)],
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
          IunaIconButton(icon: Icons.show_chart_rounded, onTap: onStats),
          IunaIconButton(icon: Icons.settings_rounded, onTap: onSettings),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'おかえり',
          style: TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: IunaPalette.ink3,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Welcome back, kuma.',
          style: TextStyle(
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
    required this.available,
    required this.dueCount,
    required this.newCardCount,
    required this.onTap,
    this.kumaSeed,
  });

  final bool available;
  final int dueCount;
  final int newCardCount;
  final VoidCallback onTap;
  final int? kumaSeed;

  @override
  Widget build(BuildContext context) {
    final title = available ? "Today's pack" : 'No pack today';
    final sub = available
        ? '$newCardCount new cards · ${dueCount == 1 ? "1 review" : "$dueCount reviews"} due'
        : (dueCount == 0
              ? 'All caught up — come back tomorrow.'
              : '${dueCount == 1 ? "1 review" : "$dueCount reviews"} due today');
    final cta = available
        ? 'Open & review'
        : (dueCount == 0 ? 'Up to date' : 'Start review');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 178,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(IunaRadii.xl),
          gradient: const LinearGradient(
            begin: Alignment(-0.4, -1),
            end: Alignment(0.4, 1),
            colors: [Color(0xFFFFD994), Color(0xFFF3A7B5)],
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
                bottom: -8,
                child: Transform.rotate(
                  angle: 8 * math.pi / 180,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 120,
                    height: 158,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: Color(0xFF3A2510),
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
                        color: Color(0xCC3A2510),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _HeroPill(label: cta),
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xD9FFFDF6),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(74, 53, 32, 0.25),
            blurRadius: 16,
            offset: Offset(0, 6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 16,
            color: IunaPalette.ink,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: IunaPalette.ink,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFD97A8C),
              shape: BoxShape.circle,
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
              child: _Stat(value: '$learned', label: 'learned'),
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
          const Text(
            'day streak',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: IunaPalette.ink3,
              letterSpacing: 0.4,
            ),
          ),
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
    return SizedBox(
      height: 158,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = cards[i].card;
              return GestureDetector(
                onTap: () => onTap(c.id),
                child: SizedBox(
                  width: 120,
                  height: 150,
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
                        Text(
                          c.kanji,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 30,
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
                            fontSize: 11,
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

class _WishlistNudge extends StatelessWidget {
  const _WishlistNudge({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = count == 0
        ? 'Bookmark a kanji to bias future packs'
        : '$count cards in your wishlist';
    final sub = count == 0
        ? 'Open a card detail and tap the bookmark.'
        : 'Pin words you want to learn next';
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                color: const Color(0x59C4B2E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: IunaPalette.raritySuperRareInk,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: IunaPalette.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
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
            const Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3),
          ],
        ),
      ),
    );
  }
}
