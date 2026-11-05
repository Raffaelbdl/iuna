import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/iuna_page.dart';
import '../widgets/tappable.dart';

part 'stats/common.dart';
part 'stats/headline.dart';
part 'stats/activity.dart';
part 'stats/accuracy.dart';
part 'stats/progress.dart';
part 'stats/schedule.dart';
part 'stats/time.dart';
part 'stats/leeches.dart';

/// Stats: headline numbers, then the everyday panels (activity, streak,
/// forecast, leeches, JLPT and pack progress), then the analytical
/// charts folded under "More stats" (heatmap, retention, accuracy by
/// stage and rarity, maturity, hour of day, time spent). Each chart
/// owns its own window (the retention card has an inline 30/90/all
/// switcher); there is no global window filter.
class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.db,
    this.now,
    this.detailsOpen = false,
  });

  final AppDatabase db;

  /// Pins "today" for every date-windowed query; goldens need it.
  final DateTime? now;

  /// Opens with the "More stats" charts unfolded.
  final bool detailsOpen;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

enum _RetWindow { d30, d90, all }

extension _RetWindowDays on _RetWindow {
  int? get days => switch (this) {
    _RetWindow.d30 => 30,
    _RetWindow.d90 => 90,
    _RetWindow.all => null,
  };
}

class _StatsScreenState extends State<StatsScreen> {
  late final IunaRepository _repo = IunaRepository(widget.db);

  bool _loading = true;
  late bool _detailsOpen = widget.detailsOpen;
  _RetWindow _retWindow = _RetWindow.d90;

  ({int reviews, int learned}) _totals = (reviews: 0, learned: 0);

  /// Null until at least one post-graduation review has happened; no
  /// fallback to lifetime accuracy, because the learn-phase pass rate
  /// isn't comparable to SM-2's 90% target.
  ({int total, int correct})? _trueRet;
  Map<ReviewKind, ({int total, int correct})> _byKind = const {};
  Map<Rarity, ({int total, int correct})> _byRarity = const {};
  Map<int, ({int owned, int total})> _byJlpt = const {};
  Map<String, ({String label, int owned, int total})> _byPack = const {};
  List<DailyActivity> _activity30 = const [];
  List<DailyActivity> _heatmap = const [];
  List<RetentionBin> _retention = const [];
  List<MaturityBin> _maturity = const [];
  List<ForecastDay> _forecast = const [];
  List<TimeSpentDay> _timeSpent = const [];
  List<int> _hoursOfDay = const [];
  StreakStats _streak = const StreakStats(
    current: 0,
    longest: 0,
    totalDays: 0,
    recent: [],
  );
  List<LeechEntry> _leeches = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Launch in parallel; record `.wait` caps at 9 elements, so split.
    final fBreakdown = _repo.reviewBreakdown();
    final fByJlpt = _repo.jlptProgress();
    final fHeatmap = _repo.dailyActivity(days: 364, now: widget.now);
    final fRetention = _repo.retentionCurve(
      windowDays: _retWindow.days,
      now: widget.now,
    );
    final fMaturity = _repo.maturityHistogram();
    final fForecast = _repo.dueForecast(days: 14, now: widget.now);
    final fTimeSpent = _repo.timeSpentSeries(days: 30, now: widget.now);
    final fHours = _repo.hourOfDayHistogram();
    final fStreak = _repo.streakStats(now: widget.now);
    final fLeeches = _repo.leeches(limit: 6);
    final fByPack = _repo.packProgress();

    final r1 = await (
      fBreakdown,
      fByJlpt,
      fHeatmap,
      fRetention,
      fMaturity,
    ).wait;
    final r2 = await (
      fForecast,
      fTimeSpent,
      fHours,
      fStreak,
      fLeeches,
      fByPack,
    ).wait;
    if (!mounted) return;
    setState(() {
      final breakdown = r1.$1;
      _totals = (reviews: breakdown.reviews, learned: breakdown.learned);
      _trueRet = breakdown.trueRetention.total == 0
          ? null
          : breakdown.trueRetention;
      _byKind = breakdown.byKind;
      _byRarity = breakdown.byRarity;
      _byJlpt = r1.$2;
      _heatmap = r1.$3;
      _activity30 = _heatmap.sublist(math.max(0, _heatmap.length - 30));
      _retention = r1.$4;
      _maturity = r1.$5;
      _forecast = r2.$1;
      _timeSpent = r2.$2;
      _hoursOfDay = r2.$3;
      _streak = r2.$4;
      _leeches = r2.$5;
      _byPack = r2.$6;
      _loading = false;
    });
  }

  Future<void> _setRetentionWindow(_RetWindow w) async {
    if (w == _retWindow) return;
    setState(() => _retWindow = w);
    final next = await _repo.retentionCurve(
      windowDays: w.days,
      now: widget.now,
    );
    if (!mounted) return;
    setState(() => _retention = next);
  }

  @override
  Widget build(BuildContext context) {
    return IunaPage(
      title: 'Stats',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Headline(
                  reviews: _totals.reviews,
                  trueRetention: _trueRet,
                  learned: _totals.learned,
                ),
                const SizedBox(height: 14),
                _StatCard(
                  title: 'Activity',
                  subtitle:
                      'Reviews per day · right and wrong over the last 30 days.',
                  child: _ActivityChart(days: _activity30),
                ),
                const SizedBox(height: 14),
                _StatCard(
                  title: 'Streak',
                  subtitle: "Days in a row you've reviewed at least one card.",
                  child: _StreakStrip(stats: _streak),
                ),
                const SizedBox(height: 14),
                _StatCard(
                  title: 'Next 14 days',
                  subtitle: 'How many reviews are coming up each day.',
                  child: _ForecastChart(days: _forecast),
                ),
                const SizedBox(height: 14),
                _StatCard(
                  title: 'Tricky cards',
                  subtitle: _leeches.isEmpty
                      ? "No tricky cards yet — they'll show up here once you miss the same word a few times."
                      : 'Cards you keep missing. Worth a closer look.',
                  child: _LeechList(entries: _leeches),
                ),
                const SizedBox(height: 14),
                _StatCard(
                  title: 'JLPT progress',
                  subtitle: 'Cards collected per level. 完 = complete.',
                  child: _JlptProgress(byLevel: _byJlpt),
                ),
                if (_byPack.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'Themed packs',
                    subtitle: 'Cards collected per pack. 完 = complete.',
                    child: _PackProgress(byPack: _byPack),
                  ),
                ],
                const SizedBox(height: 8),
                _MoreToggle(
                  open: _detailsOpen,
                  onTap: () => setState(() => _detailsOpen = !_detailsOpen),
                ),
                if (_detailsOpen) ..._details(),
              ],
            ),
    );
  }

  /// The analytical charts, folded away under "More stats".
  List<Widget> _details() => [
    const SizedBox(height: 6),
    _StatCard(
      title: 'Year heatmap',
      subtitle:
          'Every square is a day. Darker = more reviews. Quiet stretches show as light squares.',
      child: _YearHeatmap(days: _heatmap),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'Retention curve',
      subtitle:
          'How often you remember a card after each gap between reviews. '
          'Below the dashed line, that gap is too long for you.',
      trailing: _ChipRow<_RetWindow>(
        compact: true,
        value: _retWindow,
        options: const [_RetWindow.d30, _RetWindow.d90, _RetWindow.all],
        labels: const {
          _RetWindow.d30: '30d',
          _RetWindow.d90: '90d',
          _RetWindow.all: 'all',
        },
        onChange: _setRetentionWindow,
      ),
      child: _RetentionChart(bins: _retention),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'Pass rate by card stage',
      subtitle:
          'Known cards show how well you remember. New and relearning cards '
          'are still settling, so they swing more.',
      child: _KindBreakdownDonut(byKind: _byKind),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'Accuracy by rarity',
      subtitle: 'How well you remember each tier. Dotted mark = 90% goal.',
      child: _AccuracyByRarity(byRarity: _byRarity),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'How well you know them',
      subtitle: 'How settled each card is, from still learning to well known.',
      child: _MaturityChart(bins: _maturity),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'When you study',
      subtitle:
          'Reviews by hour of day, all-time. The dial points to your peak.',
      child: _HourClock(hours: _hoursOfDay),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'Time spent',
      subtitle: 'Minutes per day (bars) and median answer time (line).',
      child: _TimeSpentChart(days: _timeSpent),
    ),
  ];
}

/// The fold between the everyday panels and the detailed charts.
class _MoreToggle extends StatelessWidget {
  const _MoreToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      selected: open,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Text(
              open ? 'Fewer stats' : 'More stats',
              style: IunaText.label.copyWith(
                fontWeight: FontWeight.w700,
                color: IunaPalette.ink2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: IunaPalette.ink2,
            ),
            const SizedBox(width: 12),
            if (!open)
              Expanded(
                child: Text(
                  'Retention, accuracy, timing…',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IunaText.caption.copyWith(color: IunaPalette.ink3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
