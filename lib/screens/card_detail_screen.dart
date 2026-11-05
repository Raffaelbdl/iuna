import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../learn/agent/example_writer.dart';
import '../learn/deck.dart';
import '../learn/learn.dart';
import '../learn/learn_settings.dart';
import '../learn/widgets/ask_bar.dart';
import '../services/tts.dart';
import '../theme/iuna_theme.dart';
import '../widgets/example_line.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_bottom_nav.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/section_header.dart';
import '../widgets/sense_row.dart';
import '../widgets/snack.dart';
import '../widgets/vocab_card.dart';
import 'app_nav.dart';

class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({
    super.key,
    required this.db,
    required this.cardId,
    this.learn,
  });

  final AppDatabase db;
  final int cardId;

  /// The tutor behind the card's chat bar, which shows only while
  /// [LearnSettings.available]; tests pass their own.
  final LearnEnv? learn;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late final IunaRepository _repo = IunaRepository(widget.db);

  bool _loading = true;
  CardRow? _card;
  UserCardRow? _userCard;
  List<CardSenseRow> _senses = const [];
  List<ExampleRow> _examples = const [];
  bool _wished = false;

  late final LearnEnv _learn = widget.learn ?? LearnEnv.live(widget.db);

  /// What Kuma-sensei is doing for this card, if anything. Writing shows
  /// only on a card without examples and translating only on one with
  /// some, so one at a time is all there is.
  _TutorJob? _job;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (entry, senses, examples, wished) = await (
      _repo.cardWithState(widget.cardId),
      _repo.sensesForCard(widget.cardId),
      _repo.examplesForCard(widget.cardId),
      _repo.isWished(widget.cardId),
    ).wait;
    if (!mounted) return;
    setState(() {
      _card = entry?.card;
      _userCard = entry?.userCard;
      _senses = senses;
      _examples = examples;
      _wished = wished;
      _loading = false;
    });
  }

  Future<void> _onWishlistTap() async {
    final next = await _repo.toggleWishlist(widget.cardId);
    if (!mounted) return;
    setState(() => _wished = next);
    final card = _card;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          next
              ? 'Added ${card?.kanji ?? "card"} to your wishlist'
              : 'Removed from wishlist',
        ),
      ),
    );
  }

  Future<void> _onSuspendTap() async {
    final user = _userCard;
    if (user == null) return;
    final next = !user.suspended;
    await _repo.setSuspended(widget.cardId, next);
    if (!mounted) return;
    setState(() => _userCard = user.copyWith(suspended: next));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          next
              ? 'Suspended — this card won\'t appear in review.'
              : 'Unsuspended — back in your review queue.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _repo.setSuspended(widget.cardId, !next);
            if (!mounted) return;
            setState(() {
              final current = _userCard;
              if (current != null) {
                _userCard = current.copyWith(suspended: !next);
              }
            });
          },
        ),
      ),
    );
  }

  /// Runs [work] for the card and reloads it; the result is saved even
  /// if the learner left meanwhile.
  Future<void> _runTutor(_TutorJob job, Future<void> Function(FocusCard card) work) async {
    final card = _card;
    if (card == null || _job != null) return;
    setState(() => _job = job);
    try {
      await work(_focusCard(card));
      if (mounted) await _load();
    } on ExampleWriterError catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _job = null);
    }
  }

  void _writeExamples() => _runTutor(_TutorJob.write, (card) async {
        await _repo.addGeneratedExamples(widget.cardId, await _learn.writeExamples(card));
      });

  void _translateExamples() => _runTutor(_TutorJob.translate, (card) async {
        final missing = [for (final e in _examples) if (e.translation == null) e];
        final english = await _learn.translateExamples(card, [for (final e in missing) e.sentence]);
        await _repo.addExampleTranslations({
          for (final (i, e) in missing.indexed) e.id: ?english[i],
        });
      });

  Future<void> _clearExamples() async {
    final removed = await _repo.clearGeneratedExamples(widget.cardId);
    await _load();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: const Text("Cleared Kuma-sensei's examples"),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _repo.addGeneratedExamples(widget.cardId, removed);
            await _load();
          },
        ),
      ),
    );
  }

  FocusCard _focusCard(CardRow card) =>
      FocusCard.fromDeck(card, _senses, userCard: _userCard, wished: _wished);

  Widget _examplesButton({bool round = false}) {
    final writing = _job == _TutorJob.write;
    return AskBarButton(
        icon: Icons.auto_awesome_rounded,
        label: round ? null : (writing ? 'Writing examples…' : 'Give me examples'),
        tooltip: round ? 'Give me examples' : null,
        busy: writing,
        onTap: _writeExamples,
      );
  }

  /// On a card without examples, two buttons until Kuma teach opens the
  /// chat bar; on one with examples, the plain chat bar.
  Widget _askBar(CardRow card, Widget nav) {
    final missing = _examples.isEmpty;
    return AskBar(
      env: _learn,
      hint: missing ? 'Ask about ${card.kanji}…' : 'Ask Kuma-sensei about ${card.kanji}…',
      nav: nav,
      card: () => _focusCard(card),
      // The tutor may have bookmarked this very card.
      onReturn: _load,
      leading: missing ? _examplesButton(round: true) : null,
      folded: missing
          ? (open) => Row(
                children: [
                  Expanded(child: _examplesButton()),
                  const SizedBox(width: 8),
                  AskBarButton(icon: Icons.school_rounded, label: 'Kuma teach', onTap: open),
                ],
              )
          : null,
    );
  }

  void _onSpeakerTap() {
    final card = _card;
    if (card == null) return;
    TtsService.instance.speak(card.kana);
  }

  /// Today-tab from the bottom nav. Routes in priority order:
  /// 1. `PackIntroScreen` if any packs remain unclaimed,
  /// 2. `ReviewScreen` if any cards are due,
  /// 3. `ReviewDoneScreen` (no-session mode) if today already has
  ///    reviews logged,
  /// 4. snackbar otherwise.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LearnSettings.instance.available,
      builder: (context, tutor, _) => _buildPage(context, tutor: tutor && _card != null),
    );
  }

  Widget _buildPage(BuildContext context, {required bool tutor}) {
    final nav = AppBottomNav(
      db: widget.db,
      // Detail is reached from Collection, so the Collection tab stays
      // highlighted.
      active: IunaNavTab.collection,
      atTabRoot: false,
    );
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 13)),
            SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _card == null
                  ? const Center(
                      child: Text(
                        'Card not found.',
                        style: TextStyle(color: IunaPalette.ink3),
                      ),
                    )
                  : _buildBody(_card!, tutor: tutor),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(child: IunaNavFade(height: tutor ? AskBar.inset : 120)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: tutor ? _askBar(_card!, nav) : nav,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CardRow card, {required bool tutor}) {
    final untranslated = tutor && _examples.any((e) => e.translation == null);
    return Column(
      children: [
        _TopBar(
          onBack: () => Navigator.of(context).maybePop(),
          wished: _wished,
          onWishlistTap: _onWishlistTap,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, 4, 0, tutor ? AskBar.inset : 110),
            children: [
              _Hero(card: card, onSpeak: _onSpeakerTap),
              const SizedBox(height: 14),
              _Section(
                title: 'Senses',
                child: _senses.isEmpty
                    ? Text(
                        card.meaning,
                        style: const TextStyle(
                          fontSize: 14,
                          color: IunaPalette.ink,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _senses.length; i++)
                            SenseRow(
                              ordinal: _senses[i].ordinal,
                              gloss: _senses[i].gloss,
                              pos: _senses[i].pos,
                              definition: _senses[i].definition,
                              showDivider: i > 0,
                            ),
                        ],
                      ),
              ),
              if (_examples.isNotEmpty || _job == _TutorJob.write) ...[
                const SizedBox(height: 14),
                _Section(
                  title: 'Examples',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (untranslated)
                        _PanelAction(
                          label: _job == _TutorJob.translate ? 'Translating…' : 'Translate',
                          onPressed: _job == null ? _translateExamples : null,
                        ),
                      if (_examples.any((e) => e.generated))
                        _PanelAction(label: 'Clear', onPressed: _clearExamples),
                    ],
                  ),
                  child: _examples.isEmpty
                      ? const Row(
                          children: [
                            SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Kuma-sensei is writing some…',
                              style: TextStyle(fontSize: 13, color: IunaPalette.ink3),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final ex in _examples) ExampleLine(example: ex),
                          ],
                        ),
                ),
              ],
              if (_userCard != null) ...[
                const SizedBox(height: 14),
                _Section(
                  title: 'Review state',
                  child: Column(
                    children: [
                      _Kv(label: 'Level', value: 'Lv ${_userCard!.level}'),
                      _Kv(
                        label: 'Interval',
                        value: _formatInterval(_userCard!.intervalMinutes),
                      ),
                      _Kv(
                        label: 'Ease',
                        value: _userCard!.ease.toStringAsFixed(2),
                      ),
                      _Kv(
                        label: 'Last reviewed',
                        value: _formatDate(_userCard!.lastReviewed) ?? 'Never',
                      ),
                      _Kv(
                        label: 'Next due',
                        value: _formatDate(_userCard!.nextDue) ?? '—',
                      ),
                      _Kv(
                        label: 'Obtained',
                        value: _formatDate(_userCard!.obtainedAt) ?? '—',
                      ),
                      _SuspendRow(
                        suspended: _userCard!.suspended,
                        onTap: _onSuspendTap,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _formatInterval(int minutes) {
    if (minutes <= 0) return 'Not yet scheduled';
    if (minutes < 60) return '${minutes}m';
    if (minutes < 60 * 24) {
      final hours = (minutes / 60).round();
      return '${hours}h';
    }
    final days = (minutes / (60 * 24)).round();
    return '${days}d';
  }

  static String? _formatDate(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('MMM d, y · HH:mm').format(dt);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.wished,
    required this.onWishlistTap,
  });
  final VoidCallback onBack;
  final bool wished;
  final VoidCallback onWishlistTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IunaIconButton(icon: Icons.chevron_left_rounded, onTap: onBack),
          const Spacer(),
          const Text(
            'Card detail',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IunaPalette.ink2,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          IunaIconButton(
            icon: wished
                ? Icons.bookmark_rounded
                : Icons.bookmark_outline_rounded,
            onTap: onWishlistTap,
            tint: wished ? IunaPalette.bellGold : null,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.card, required this.onSpeak});
  final CardRow card;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final tint = rarityFill(card.rarity);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.3, -1),
            end: const Alignment(0.3, 1),
            colors: [IunaPalette.paper, tint],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(74, 53, 32, 0.25),
              blurRadius: 40,
              offset: Offset(0, 16),
              spreadRadius: -16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'card-kanji-${card.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            card.kanji,
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: IunaPalette.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.kana,
                        style: const TextStyle(
                          fontSize: 18,
                          color: IunaPalette.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RarityChip(
                      rarity: card.rarity,
                      size: RarityChipSize.header,
                    ),
                    const SizedBox(height: 6),
                    InkResponse(
                      onTap: onSpeak,
                      radius: 22,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0x99FFFDF6),
                          shape: BoxShape.circle,
                          boxShadow: panelShadow(),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.volume_up_rounded,
                          size: 16,
                          color: IunaPalette.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              card.meaning,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: IunaPalette.ink2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (card.jlptLevel != null)
                  _BasicChip(label: 'JLPT N${card.jlptLevel}'),
                _BasicChip(label: rarityName(card.rarity)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BasicChip extends StatelessWidget {
  const _BasicChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x0F4A3520),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color.fromRGBO(74, 53, 32, 0.06),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: IunaPalette.ink2,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: paperPanelDecoration(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trailing == null)
              IunaEyebrow(title)
            else
              Row(children: [Expanded(child: IunaEyebrow(title)), trailing!]),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: IunaPalette.ink.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: IunaPalette.ink3),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: IunaPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuspendRow extends StatelessWidget {
  const _SuspendRow({required this.suspended, required this.onTap});
  final bool suspended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: IunaPalette.ink.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.pause_circle_outline_rounded,
              size: 18,
              color: IunaPalette.ink3,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Suspended',
                style: TextStyle(fontSize: 13, color: IunaPalette.ink3),
              ),
            ),
            Switch.adaptive(
              value: suspended,
              onChanged: (_) => onTap(),
              activeTrackColor: IunaPalette.bellGold,
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: IunaPalette.ink3,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
}

enum _TutorJob { write, translate }
