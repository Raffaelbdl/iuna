import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../learn/screens/tutor_settings_section.dart';
import '../theme/iuna_theme.dart';
import '../widgets/section_header.dart';
import 'settings/about_section.dart';
import 'settings/backup_section.dart';
import 'settings/card_packs_section.dart';
import 'settings/dictionary_section.dart';
import 'stats_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final IunaRepository _repo = IunaRepository(widget.db);

  bool _loading = true;
  int _boostersPerDay = kDefaultBoostersPerDay;
  int _resetHour = kDefaultResetHour;
  int _reviewTimeCap = kDefaultReviewTimeCapSeconds;
  bool _jlptOnly = false;
  List<String> _packs = const [];
  Map<String, String> _packLabels = const {};
  String? _packFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (
      perDay,
      reset,
      cap,
      jlptOnly,
      packs,
      packLabels,
      packFilter,
    ) = await (
      _repo.getBoostersPerDay(),
      _repo.getResetHour(),
      _repo.getReviewTimeCapSeconds(),
      _repo.getJlptOnly(),
      _repo.availablePacks(),
      _repo.packLabels(),
      _repo.getBoosterPackFilter(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _boostersPerDay = perDay;
      _resetHour = reset;
      _reviewTimeCap = cap;
      _jlptOnly = jlptOnly;
      _packs = packs;
      _packLabels = packLabels;
      _packFilter = packFilter;
      _loading = false;
    });
  }

  Future<void> _setBoostersPerDay(int value) async {
    setState(() => _boostersPerDay = value);
    await _repo.setBoostersPerDay(value);
  }

  Future<void> _setResetHour(int value) async {
    setState(() => _resetHour = value);
    await _repo.setResetHour(value);
  }

  Future<void> _setReviewTimeCap(int value) async {
    setState(() => _reviewTimeCap = value);
    await _repo.setReviewTimeCapSeconds(value);
  }

  Future<void> _setJlptOnly(bool value) async {
    setState(() {
      _jlptOnly = value;
      if (value) _packFilter = null;
    });
    await _repo.setJlptOnly(value);
  }

  Future<void> _setPackFilter(String? pack) async {
    setState(() {
      _packFilter = pack;
      if (pack != null) _jlptOnly = false;
    });
    await _repo.setBoosterPackFilter(pack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          // Not a lazy list: the sections own installs, sign-in and
          // backups that must not be torn down by scrolling.
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const IunaSectionHeader('Progress'),
                ListTile(
                  leading: const Icon(
                    Icons.insights_rounded,
                    color: IunaPalette.pawBrown,
                  ),
                  title: const Text('Stats'),
                  subtitle: const Text(
                    'Activity, retention curve, maturity, and leeches.',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: IunaPalette.ink3,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StatsScreen(db: widget.db),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const IunaSectionHeader('Daily routine'),
                _Stepper(
                  icon: Icons.card_giftcard_rounded,
                  title: 'Booster packs per day',
                  subtitle: 'How many fresh packs you can claim each day.',
                  value: _boostersPerDay,
                  min: kMinBoostersPerDay,
                  max: kMaxBoostersPerDay,
                  onChanged: _setBoostersPerDay,
                ),
                SwitchListTile.adaptive(
                  secondary: const Icon(
                    Icons.school_rounded,
                    color: IunaPalette.pawBrown,
                  ),
                  title: const Text('JLPT only'),
                  subtitle: const Text(
                    'Only pull cards tagged with a JLPT level. Applies to '
                    'booster draws and suspend-and-replace. Wishlisted '
                    'cards still surface regardless.',
                  ),
                  value: _jlptOnly,
                  activeTrackColor: IunaPalette.bellGold,
                  onChanged: _setJlptOnly,
                ),
                if (_packs.isNotEmpty)
                  _PackFilterTile(
                    packs: _packs,
                    labels: _packLabels,
                    selected: _packFilter,
                    onChanged: _setPackFilter,
                  ),
                _ResetHourTile(hour: _resetHour, onChanged: _setResetHour),
                _Stepper(
                  icon: Icons.timer_outlined,
                  title: 'Review time cap',
                  subtitle:
                      'Max seconds counted toward response-time stats. '
                      'Reviews longer than this still record — only the '
                      'duration is clamped.',
                  value: _reviewTimeCap,
                  min: kMinReviewTimeCapSeconds,
                  max: kMaxReviewTimeCapSeconds,
                  step: 5,
                  unit: 's',
                  onChanged: _setReviewTimeCap,
                ),
                const SizedBox(height: 16),
                BackupSection(repo: _repo),
                const SizedBox(height: 16),
                const TutorSettingsSection(),
                CardPacksSection(repo: _repo, onInstalled: _load),
                const SizedBox(height: 16),
                const DictionarySection(),
                const SizedBox(height: 16),
                const AboutSection(),
                const SizedBox(height: 16),
                const IunaSectionHeader('Data sources'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _Attribution(
                    title: 'JMdict',
                    body:
                        'Vocabulary data is derived from JMdict — copyright '
                        '© James William Breen and the Electronic Dictionary '
                        'Research and Development Group, used under the '
                        'Creative Commons Attribution-ShareAlike 4.0 '
                        'International licence.\n\n'
                        'Licence: https://creativecommons.org/licenses/by-sa/4.0/\n'
                        'Source: https://www.edrdg.org/jmdict/j_jmdict.html',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _Attribution(
                    title: 'JLPT vocabulary lists',
                    body:
                        'JLPT level tags come from Jonathan Waller\'s lists '
                        '(www.tanos.co.uk), curated and re-emitted by '
                        'stephenmk/yomitan-jlpt-vocab. Used under the '
                        'Creative Commons Attribution-ShareAlike 4.0 '
                        'International licence.',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _Attribution(
                    title: 'Example sentences',
                    body:
                        'Example sentences come from the Tatoeba Project, '
                        'via JMdict\'s example index, used under the Creative '
                        'Commons Attribution 2.0 France licence.\n\n'
                        'Licence: https://creativecommons.org/licenses/by/2.0/fr/\n'
                        'Source: https://tatoeba.org',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: _Attribution(
                    title: 'Word frequency',
                    body:
                        'Rarity tiers are derived from the internet-jp word '
                        'frequency list by Serge Sharoff (University of Leeds '
                        'Centre for Translation Studies), mirrored by '
                        'hingston/japanese, used under the Creative Commons '
                        'Attribution 2.5 licence.\n\n'
                        'Licence: https://creativecommons.org/licenses/by/2.5/\n'
                        'Source: https://github.com/hingston/japanese',
                  ),
                ),
              ],
              ),
            ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.unit = '',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final atMin = value <= min;
    final atMax = value >= max;
    return ListTile(
      leading: Icon(icon, color: IunaPalette.pawBrown),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: IunaPalette.pawBrown,
            onPressed: atMin ? null : () => onChanged(value - step),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value$unit',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: IunaPalette.pawBrown,
            onPressed: atMax ? null : () => onChanged(value + step),
          ),
        ],
      ),
    );
  }
}

/// Restricts booster draws to one themed pack. Rendered from whatever
/// `cards.pack` values exist, so shipping another pack needs no change
/// here.
class _PackFilterTile extends StatelessWidget {
  const _PackFilterTile({
    required this.packs,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> packs;
  final Map<String, String> labels;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.category_rounded, color: IunaPalette.pawBrown),
      title: const Text('Themed pack only'),
      // Pack names are long enough that a trailing dropdown starves the
      // title column, so it sits under the description at full width.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Draw boosters from a single pack instead of the whole deck. '
            'Clears "JLPT only"; wishlisted cards still surface.',
          ),
          DropdownButton<String>(
            value: selected ?? '',
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: '', child: Text('All cards')),
              for (final pack in packs)
                DropdownMenuItem(
                  value: pack,
                  child: Text(labels[pack] ?? pack),
                ),
            ],
            onChanged: (v) => onChanged((v == null || v.isEmpty) ? null : v),
          ),
        ],
      ),
    );
  }
}

class _ResetHourTile extends StatelessWidget {
  const _ResetHourTile({required this.hour, required this.onChanged});

  final int hour;
  final ValueChanged<int> onChanged;

  static String _label(int h) => DateFormat.j().format(DateTime(2000, 1, 1, h));

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.schedule_rounded, color: IunaPalette.pawBrown),
      title: const Text('Daily reset'),
      subtitle: const Text('When the new-pack timer and streak roll over.'),
      trailing: DropdownButton<int>(
        value: hour,
        underline: const SizedBox.shrink(),
        items: [
          for (var h = 0; h < 24; h++)
            DropdownMenuItem(value: h, child: Text(_label(h))),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: IunaPalette.pawBrown.withValues(alpha: 0.85),
      height: 1.45,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IunaPalette.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IunaPalette.pawBrown.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SelectableText(body, style: bodyStyle),
        ],
      ),
    );
  }
}
