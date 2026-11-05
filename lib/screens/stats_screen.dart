import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/iuna_bottom_nav.dart';
import '../widgets/iuna_page.dart';
import '../widgets/notice.dart';
import '../widgets/section_header.dart';
import '../widgets/tappable.dart';
import 'card_detail_screen.dart';

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

class _StatsScreenState extends State<StatsScreen> with LoadGate {
  late final IunaRepository _repo = IunaRepository(widget.db);

  late bool _detailsOpen = widget.detailsOpen;
  _RetWindow _retWindow = _RetWindow.d90;

  ({int reviews, int learned}) _totals = (reviews: 0, learned: 0);

  ({int total, int correct}) _trueRet = (total: 0, correct: 0);
  ({int total, int correct}) _newRet = (total: 0, correct: 0);
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
    load();
  }

  @override
  Future<void> load() async {
    // Launch in parallel; record `.wait` caps at 9 elements, so split.
    final loaded = await guardLoad('Stats', () async {
      final fBreakdown = _repo.reviewBreakdown();
      final fByJlpt = _repo.jlptProgress();
      final fHeatmap = _repo.dailyActivity(days: 364, now: widget.now);
      final fRetention = _repo.retentionCurve(
        windowDays: _retWindow.days,
        now: widget.now,
      );
      final fMaturity = _repo.maturityHistogram();
      final fForecast = _forecastQuery();
      final fTimeSpent = _repo.timeSpentSeries(days: 30, now: widget.now);
      final fHours = _repo.hourOfDayHistogram();
      final fStreak = _repo.streakStats(now: widget.now);
      final fLeeches = _leechesQuery();
      final fByPack = _repo.packProgress();
      return (
        await (fBreakdown, fByJlpt, fHeatmap, fRetention, fMaturity).wait,
        await (
          fForecast,
          fTimeSpent,
          fHours,
          fStreak,
          fLeeches,
          fByPack,
        ).wait,
      );
    });
    if (loaded == null || !mounted) return;
    final (r1, r2) = loaded;
    showLoaded(() {
      final breakdown = r1.$1;
      _totals = (reviews: breakdown.reviews, learned: breakdown.learned);
      _trueRet = breakdown.trueRetention;
      _newRet = breakdown.newRetention;
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
    });
  }

  Future<List<ForecastDay>> _forecastQuery() =>
      _repo.dueForecast(days: 14, now: widget.now);

  Future<List<LeechEntry>> _leechesQuery() => _repo.leeches(limit: 6);

  /// A card's screen can suspend it or reset it, which only the leeches
  /// and the forecast show.
  Future<void> _openCard(int cardId) async {
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
    final loaded = await guardLoad(
      'Stats',
      () => (_forecastQuery(), _leechesQuery()).wait,
    );
    if (loaded == null || !mounted) return;
    setState(() {
      _forecast = loaded.$1;
      _leeches = loaded.$2;
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
      body: gated(_body),
    );
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Headline(
          reviews: _totals.reviews,
          // None until a post-graduation review: no fallback to
          // lifetime accuracy, because the learn-phase pass rate
          // isn't comparable to SM-2's 90% target.
          trueRetention: _trueRet.total == 0 ? null : _trueRet,
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
              : 'Cards you keep missing. Tap one for a closer look.',
          child: _LeechList(entries: _leeches, onOpen: _openCard),
        ),
        const SizedBox(height: 14),
        _StatCard(
          title: 'JLPT progress',
          subtitle: 'Cards collected per level. 完 marks a complete '
              'one.',
          child: _JlptProgress(byLevel: _byJlpt),
        ),
        if (_byPack.isNotEmpty) ...[
          const SizedBox(height: 14),
          _StatCard(
            title: 'Themed packs',
            subtitle: 'Cards collected per pack. 完 marks a '
                'complete one.',
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
    );
  }

  /// The analytical charts, folded away under "More stats".
  List<Widget> _details() => [
    const SizedBox(height: 6),
    _StatCard(
      title: 'Your year',
      subtitle:
          'Every square is a day. Darker = more reviews. Quiet stretches show as light squares.',
      child: _YearHeatmap(days: _heatmap),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'How long you remember',
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
      title: 'New vs known cards',
      subtitle:
          'How often you get each right. Known cards, a day or more since '
          'their last review, show how well you remember; new ones are '
          'still settling.',
      child: _StageDonut(newCards: _newRet, knownCards: _trueRet),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'Accuracy by rarity',
      subtitle:
          'How well you remember each tier. The honey tick on each bar is '
          'the 90% goal.',
      child: _AccuracyByRarity(byRarity: _byRarity),
    ),
    const SizedBox(height: 14),
    _StatCard(
      title: 'How well you know them',
      subtitle:
          'How settled each card is, by its time between reviews: learning '
          'under 3 days, getting there under a month, well known beyond. '
          'Each right answer raises a card\'s memory level and stretches '
          'that time.',
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
      expanded: open,
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
