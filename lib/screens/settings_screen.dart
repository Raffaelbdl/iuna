import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../learn/screens/tutor_settings_section.dart';
import '../theme/iuna_theme.dart';
import '../widgets/iuna_page.dart';
import '../widgets/section_header.dart';
import 'settings/about_section.dart';
import 'settings/backup_section.dart';
import 'settings/card_packs_section.dart';
import 'settings/dictionary_section.dart';
import 'stats_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.db, this.showTutor = false});

  final AppDatabase db;

  /// Opens scrolled to the AI tutor, for a tutor error about the key.
  final bool showTutor;

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
    if (widget.showTutor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tutor = _tutorKey.currentContext;
        if (tutor != null && tutor.mounted) {
          Scrollable.ensureVisible(tutor, alignment: 0.1);
        }
      });
    }
  }

  final _tutorKey = GlobalKey();

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
    return IunaPage(
      title: 'Settings',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          // Not a lazy list: the sections own installs, sign-in and
          // backups that must not be torn down by scrolling.
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IunaGroup(
                  'Progress',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.insights_rounded),
                      title: const Text('Stats'),
                      subtitle: const Text(
                        'Activity, streak, upcoming reviews and the cards '
                        'you keep missing.',
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
                    _Stepper(
                      icon: Icons.timer_outlined,
                      title: 'Review time cap',
                      subtitle:
                          'Stats count at most this long per answer, so a '
                          'card left open doesn\'t inflate your time spent.',
                      value: _reviewTimeCap,
                      min: kMinReviewTimeCapSeconds,
                      max: kMaxReviewTimeCapSeconds,
                      step: 5,
                      unit: 's',
                      lessTooltip: 'Shorter cap',
                      moreTooltip: 'Longer cap',
                      onChanged: _setReviewTimeCap,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                IunaGroup(
                  'Daily routine',
                  children: [
                    _Stepper(
                      icon: Icons.card_giftcard_rounded,
                      title: 'Packs per day',
                      subtitle: 'How many fresh packs you can open each day.',
                      value: _boostersPerDay,
                      min: kMinBoostersPerDay,
                      max: kMaxBoostersPerDay,
                      lessTooltip: 'Fewer packs per day',
                      moreTooltip: 'More packs per day',
                      onChanged: _setBoostersPerDay,
                    ),
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.school_rounded),
                      title: const Text('JLPT only'),
                      subtitle: const Text(
                        'Only draw cards tagged with a JLPT level, in packs '
                        'and when a suspended card is swapped out. Wishlist '
                        'cards still show up.',
                      ),
                      value: _jlptOnly,
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
                  ],
                ),
                const SizedBox(height: 16),
                BackupSection(repo: _repo),
                const SizedBox(height: 16),
                TutorSettingsSection(key: _tutorKey),
                CardPacksSection(repo: _repo, onInstalled: _load),
                const SizedBox(height: 16),
                const DictionarySection(),
                const SizedBox(height: 16),
                const AboutSection(),
                const SizedBox(height: 16),
                const IunaSectionHeader('Data sources'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _Attribution(
                    title: 'Example sentences',
                    body:
                        'Example sentences and their English translations come '
                        'from the Tatoeba Project, via JMdict\'s example index, '
                        'used under the Creative '
                        'Commons Attribution 2.0 France licence.\n\n'
                        'Licence: https://creativecommons.org/licenses/by/2.0/fr/\n'
                        'Source: https://tatoeba.org',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
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
    required this.lessTooltip,
    required this.moreTooltip,
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
  final String lessTooltip;
  final String moreTooltip;

  @override
  Widget build(BuildContext context) {
    final atMin = value <= min;
    final atMax = value >= max;
    // The control sits under the description: beside it, it squeezed
    // the title into a narrow column.
    return ListTile(
      leading: Icon(icon, color: IunaPalette.pawBrown),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Row(
            children: [
              IconButton(
                tooltip: lessTooltip,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: IunaPalette.pawBrown,
                onPressed: atMin ? null : () => onChanged(value - step),
              ),
              // A floor, not a width: large text widens the value
              // rather than breaking "10 s" over two lines.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44),
                child: Text(
                  '$value$unit',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: IunaPalette.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: moreTooltip,
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: IunaPalette.pawBrown,
                onPressed: atMax ? null : () => onChanged(value + step),
              ),
            ],
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
            'Draw packs from a single themed pack instead of all cards. '
            'Turns off "JLPT only"; wishlist cards still show up.',
          ),
          const SizedBox(height: 8),
          _DropdownBox(
            child: DropdownButton<String>(
              value: selected ?? '',
              isExpanded: true,
              dropdownColor: IunaPalette.paper,
              borderRadius: BorderRadius.circular(IunaRadii.sm),
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
          ),
          const SizedBox(height: 4),
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
    final dropdown = _DropdownBox(
      child: DropdownButton<int>(
        value: hour,
        dropdownColor: IunaPalette.paper,
        borderRadius: BorderRadius.circular(IunaRadii.sm),
        items: [
          for (var h = 0; h < 24; h++)
            DropdownMenuItem(value: h, child: Text(_label(h))),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
    return IunaControlTile(
      leading: const Icon(Icons.schedule_rounded, color: IunaPalette.pawBrown),
      title: const Text('Daily reset'),
      subtitle: const Text('When the new-pack timer and streak roll over.'),
      control: dropdown,
    );
  }
}

/// A dropdown drawn as a rounded field instead of an underline.
class _DropdownBox extends StatelessWidget {
  const _DropdownBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: IunaPalette.paper2,
        borderRadius: BorderRadius.circular(IunaRadii.sm),
        border: Border.all(color: IunaPalette.outline),
      ),
      child: DropdownButtonHideUnderline(child: child),
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
      color: IunaPalette.ink2,
      height: 1.45,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: paperPanelDecoration(
        borderRadius: BorderRadius.circular(IunaRadii.md),
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
