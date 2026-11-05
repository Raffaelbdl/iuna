import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../widgets/cta_button.dart';
import '../widgets/example_line.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_bottom_nav.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/section_header.dart';
import '../widgets/sense_row.dart';
import '../widgets/snack.dart';
import '../widgets/tappable.dart';
import '../widgets/vocab_card.dart';
import 'app_nav.dart';

class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({
    super.key,
    required this.db,
    required this.cardId,
    this.from = IunaNavTab.collection,
    this.learn,
  });

  final AppDatabase db;
  final int cardId;

  /// The tab the card was opened from, which the nav keeps highlighted.
  final IunaNavTab from;

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

  bool _barTucked = false;

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

  /// Snack bars clear the ask bar while it shows.
  void _snack(String text, {SnackBarAction? action, int seconds = 4}) {
    final tutor = LearnSettings.instance.available.value && _card != null;
    showSnack(
      context,
      text,
      action: action,
      duration: Duration(seconds: seconds),
      bottom: tutor ? AskBar.snackInset : null,
    );
  }

  Future<void> _onWishlistTap() async {
    final next = await _repo.toggleWishlist(widget.cardId);
    if (!mounted) return;
    setState(() => _wished = next);
    final card = _card;
    final owned = _userCard != null;
    _snack(
      !next
          ? 'Removed from your wishlist.'
          : owned
          ? 'Added ${card?.kanji ?? "card"} to your wishlist.'
          : 'Added ${card?.kanji ?? "card"} to your wishlist — it shows '
                'up in a pack soon.',
      seconds: 3,
    );
  }

  Future<void> _onSuspendTap() async {
    final user = _userCard;
    if (user == null) return;
    final next = !user.suspended;
    await _repo.setSuspended(widget.cardId, next);
    if (!mounted) return;
    setState(() => _userCard = user.copyWith(suspended: next));
    _snack(
      next
          ? 'Suspended — this card won\'t appear in review.'
          : 'Unsuspended — back in your review queue.',
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
      if (mounted) _snack(e.message);
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
    _snack(
      "Cleared Kuma-sensei's examples.",
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await _repo.addGeneratedExamples(widget.cardId, removed);
          await _load();
        },
      ),
    );
  }

  FocusCard _focusCard(CardRow card) =>
      FocusCard.fromDeck(card, _senses, userCard: _userCard, wished: _wished);

  Widget _askBar(CardRow card, Widget nav) {
    return AskBar(
      env: _learn,
      hint: 'Ask Kuma-sensei about ${card.kanji}…',
      nav: nav,
      card: () => _focusCard(card),
      // The tutor may have bookmarked this very card.
      onReturn: _load,
      collapsed: _barTucked,
    );
  }

  /// Scrolling down to read tucks the chat bar away; scrolling back up
  /// brings it back.
  bool _onScroll(UserScrollNotification n) {
    final tuck = switch (n.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _barTucked,
    };
    if (tuck != _barTucked) setState(() => _barTucked = tuck);
    return false;
  }

  void _onSpeakerTap() {
    final card = _card;
    if (card == null) return;
    TtsService.instance.speak(card.kana);
  }

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
      active: widget.from,
      atTabRoot: false,
    );
    final card = _card;
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 13)),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(
                    onBack: () => Navigator.of(context).maybePop(),
                    wished: _wished,
                    onWishlistTap: card == null ? null : _onWishlistTap,
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : card == null
                        ? const Center(
                            child: Text(
                              'This card is no longer in Iuna.',
                              style: TextStyle(color: IunaPalette.ink3),
                            ),
                          )
                        : _buildBody(card, tutor: tutor),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: IunaNavFade(
                  height: tutor && !_barTucked ? AskBar.inset : 120,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: tutor ? _askBar(card!, nav) : nav,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CardRow card, {required bool tutor}) {
    final untranslated = tutor && _examples.any((e) => e.translation == null);
    return NotificationListener<UserScrollNotification>(
      onNotification: tutor ? _onScroll : null,
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 4, 0, tutor ? AskBar.inset : 110),
        children: [
          _Hero(
            card: card,
            owned: _userCard != null,
            onSpeak: _onSpeakerTap,
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Senses',
            child: _senses.isEmpty
                ? Text(
                    card.meaning,
                    style: IunaText.body.copyWith(
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
          if (_examples.isNotEmpty || tutor) ...[
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
              child: _examples.isEmpty && _job != _TutorJob.write
                  ? _NoExamples(onWrite: _writeExamples)
                  : _examples.isEmpty
                  ? Row(
                      children: [
                        SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Kuma-sensei is writing some…',
                          style: IunaText.bodySmall.copyWith(color: IunaPalette.ink3),
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
                  _Kv(
                    label: 'Memory level',
                    value: '${_userCard!.level}',
                  ),
                  _Kv(
                    label: 'Time between reviews',
                    value: _formatInterval(_userCard!.intervalMinutes),
                  ),
                  _Kv(
                    label: 'Last reviewed',
                    value: _formatDate(_userCard!.lastReviewed) ?? 'Never',
                  ),
                  _Kv(
                    label: 'Next review',
                    value: _formatDate(_userCard!.nextDue) ?? '—',
                  ),
                  _Kv(
                    label: 'Collected',
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
    );
  }

  static String _formatInterval(int minutes) {
    String plural(int n, String unit) => n == 1 ? '1 $unit' : '$n ${unit}s';
    if (minutes <= 0) return 'Not yet scheduled';
    if (minutes < 60) return plural(minutes, 'minute');
    if (minutes < 60 * 24) return plural((minutes / 60).round(), 'hour');
    return plural((minutes / (60 * 24)).round(), 'day');
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

  /// Null while there is no card to wish for.
  final VoidCallback? onWishlistTap;

  @override
  Widget build(BuildContext context) {
    return IunaTopBar(
      leading: IunaIconButton(
        icon: Icons.chevron_left_rounded,
        tooltip: 'Back',
        onTap: onBack,
      ),
      title: Text(
        'Card detail',
        style: IunaText.subtitle.copyWith(
          color: IunaPalette.ink2,
          letterSpacing: 0.6,
        ),
      ),
      trailing: onWishlistTap == null
          ? null
          : IunaIconButton(
              icon: wished
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              tooltip: wished ? 'Remove from wishlist' : 'Add to wishlist',
              selected: wished,
              onTap: onWishlistTap,
              tint: wished ? IunaPalette.bellGold : null,
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.card, required this.owned, required this.onSpeak});
  final CardRow card;
  final bool owned;
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
          borderRadius: BorderRadius.circular(IunaRadii.xl),
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
                      named: true,
                    ),
                    Semantics(
                      button: true,
                      label: 'Play pronunciation',
                      excludeSemantics: true,
                      child: Tooltip(
                        message: 'Play pronunciation',
                        child: InkResponse(
                          onTap: onSpeak,
                          radius: 24,
                          child: SizedBox.square(
                            dimension: 48,
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: IunaPalette.paper,
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
                          ),
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
              style: IunaText.body.copyWith(
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
                if (!owned)
                  const _BasicChip(
                    label: kNotCollectedLabel,
                    icon: Icons.lock_outline_rounded,
                  ),
                if (card.jlptLevel != null)
                  _BasicChip(label: 'JLPT N${card.jlptLevel}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BasicChip extends StatelessWidget {
  const _BasicChip({required this.label, this.icon});
  final String label;
  final IconData? icon;

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: IunaPalette.ink2),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: IunaText.chip.copyWith(
              color: IunaPalette.ink2,
            ),
          ),
        ],
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
          borderRadius: BorderRadius.circular(IunaRadii.md),
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
              style: IunaText.bodySmall.copyWith(color: IunaPalette.ink3),
            ),
          ),
          Text(
            value,
            style: IunaText.bodySmall.copyWith(
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
    return Tappable(
      onTap: onTap,
      selected: suspended,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
            Expanded(
              child: Text(
                'Suspended',
                style: IunaText.bodySmall.copyWith(color: IunaPalette.ink3),
              ),
            ),
            ExcludeSemantics(
              child: Switch.adaptive(
                value: suspended,
                onChanged: (_) => onTap(),
                activeTrackColor: IunaPalette.bellGold,
              ),
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
          foregroundColor: IunaPalette.ink2,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(label, style: IunaText.bodySmall),
      );
}

/// The Examples panel of a card without any, while the tutor is on.
class _NoExamples extends StatelessWidget {
  const _NoExamples({required this.onWrite});
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No example sentences yet. Kuma-sensei can write a few at your '
          'level.',
          style: IunaText.bodySmall.copyWith(height: 1.4, color: IunaPalette.ink3),
        ),
        const SizedBox(height: 10),
        IunaGhostButton(
          label: 'Get examples',
          leadingIcon: Icons.auto_awesome_rounded,
          shrinkWrap: true,
          onTap: onWrite,
        ),
      ],
    );
  }
}

enum _TutorJob { write, translate }
