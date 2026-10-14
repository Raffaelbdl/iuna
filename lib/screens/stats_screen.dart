import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';

part 'stats/common.dart';
part 'stats/headline.dart';
part 'stats/activity.dart';
part 'stats/accuracy.dart';
part 'stats/progress.dart';
part 'stats/schedule.dart';
part 'stats/time.dart';
part 'stats/leeches.dart';

/// Comprehensive stats screen — headline numbers, activity, retention,
/// accuracy by rarity / JLPT / kind, maturity, hour-of-day, time spent,
/// forecast, streak, and leeches. Each chart owns its own window (e.g.
/// the retention card has an inline 30/90/all switcher); there is no
/// global window filter.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.db, this.now});

  final AppDatabase db;

  /// Pins "today" for every date-windowed query; goldens need it.
  final DateTime? now;

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
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      appBar: AppBar(title: const Text('Stats')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : DecoratedBox(
              decoration: iunaPageBackground(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                        'Reviews per day · correct vs wrong over the last 30 days.',
                    child: _ActivityChart(days: _activity30),
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'Year heatmap',
                    subtitle:
                        'Every square is a day. Darker = more reviews. Quiet stretches show as light squares.',
                    child: _YearHeatmap(days: _heatmap),
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'Streak',
                    subtitle:
                        "Days in a row you've reviewed at least one card.",
                    child: _StreakStrip(stats: _streak),
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'Retention curve',
                    subtitle:
                        'Accuracy at each interval. Points below the dashed line are leaking — interval is too long.',
                    trailing: _ChipRow<_RetWindow>(
                      compact: true,
                      value: _retWindow,
                      options: const [
                        _RetWindow.d30,
                        _RetWindow.d90,
                        _RetWindow.all,
                      ],
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
                    title: 'Pass rate by review kind',
                    subtitle:
                        'True retention only counts review-type answers. Learn and relearn are noisier.',
                    child: _KindBreakdownDonut(byKind: _byKind),
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'Accuracy by rarity',
                    subtitle:
                        'How well you remember each tier. Dotted mark = 90% target.',
                    child: _AccuracyByRarity(byRarity: _byRarity),
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'JLPT progress',
                    subtitle: 'Cards owned per level. 完 = complete.',
                    child: _JlptProgress(byLevel: _byJlpt),
                  ),
                  if (_byPack.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _StatCard(
                      title: 'Themed packs',
                      subtitle: 'Cards owned per pack. 完 = complete.',
                      child: _PackProgress(byPack: _byPack),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'Maturity',
                    subtitle:
                        'Where every card sits on the forgetting curve right now.',
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
                    subtitle:
                        'Minutes per day (bars) and median answer time (line).',
                    child: _TimeSpentChart(days: _timeSpent),
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'Next 14 days',
                    subtitle:
                        'Forecast review load — what your future self has signed up for.',
                    child: _ForecastChart(days: _forecast),
                  ),
                  const SizedBox(height: 14),
                  _StatCard(
                    title: 'Leeches',
                    subtitle: _leeches.isEmpty
                        ? "No stubborn cards yet — they'll show up here once you miss the same word a few times."
                        : 'Cards you keep failing. Worth a manual cooldown.',
                    child: _LeechList(entries: _leeches),
                  ),
                ],
              ),
            ),
    );
  }
}
