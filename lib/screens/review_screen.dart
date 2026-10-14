import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/progress_dots.dart';
import '../widgets/section_header.dart';
import '../widgets/sense_row.dart';
import '../widgets/vocab_card.dart';
import 'review_done_screen.dart';

/// Drag-to-grade review loop. Tap the kanji-only front to flip; the
/// back lists numbered senses. Drag the card past 90px to commit a
/// grade, or tap the Forgot / Got it pills.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.db, this.random});

  final AppDatabase db;

  /// Seeds the draw order; goldens pin it.
  final math.Random? random;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with TickerProviderStateMixin {
  late final IunaRepository _repo = IunaRepository(
    widget.db,
    random: widget.random,
  );

  bool _loading = true;
  List<DailyDeckEntry> _deck = const [];
  int _index = 0;
  int _correctCount = 0;
  bool _flipped = false;
  Offset _drag = Offset.zero;
  bool _dragging = false;
  int _exitDir = 0; // -1 left, +1 right

  /// Stack of reversible actions from this review session, oldest at
  /// index 0. Pushed on every grade *or* suspension, popped on undo —
  /// lets the user roll all the way back to card 1. Session-scoped:
  /// discarded when the screen disposes, since the next review session
  /// may not contain the same cards.
  final List<_UndoAction> _undoStack = [];
  bool _undoing = false;

  /// Card ids the user actually graded in this session (suspended ones
  /// are excluded). Feeds the done screen's "you reviewed these" recap
  /// so a suspended card doesn't appear in the rundown.
  final List<int> _gradedCardIds = [];

  /// Wall-clock instant the active card was first shown. Reset on every
  /// `_showCurrent`; consumed by `_grade` to record review duration.
  DateTime _shownAt = DateTime.now();

  Map<int, List<CardSenseRow>> _senses = const {};

  List<CardSenseRow> get _sensesForCurrent =>
      _senses[_deck[_index].card.id] ?? const [];

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final deck = await _repo.assembleDailyDeck();
    final senses = await _repo.sensesForCards([
      for (final e in deck) e.card.id,
    ]);
    if (!mounted) return;
    setState(() {
      _deck = deck;
      _senses = senses;
      _loading = false;
    });
    if (deck.isNotEmpty) _showCurrent();
  }

  void _showCurrent() => _shownAt = DateTime.now();

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipped) return;
    setState(() => _flipped = true);
  }

  Future<void> _showDetails() async {
    if (!_flipped) return;
    final entry = _deck[_index];
    final examples = await _repo.examplesForCard(entry.card.id);
    if (!mounted) return;
    final action = await showModalBottomSheet<_SheetAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _DetailsSheet(
        card: entry.card,
        senses: _sensesForCurrent,
        examples: examples,
      ),
    );
    if (!mounted) return;
    if (action == _SheetAction.suspend) {
      await _suspendCurrent();
    }
  }

  /// Suspends the active card and advances to the next one. The card is
  /// removed from the review queue for future sessions too — undo
  /// reverses the suspension and steps the index back.
  Future<void> _suspendCurrent() async {
    if (_undoing) return;
    final entry = _deck[_index];
    HapticFeedback.lightImpact();
    setState(() => _exitDir = -1);
    await _exit.forward(from: 0);
    await _repo.setSuspended(entry.card.id, true);
    if (!mounted) return;

    _undoStack.add(_SuspendUndo(entry.card.id));

    if (_index + 1 >= _deck.length) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewDoneScreen(
            db: widget.db,
            correct: _correctCount,
            total: _gradedCardIds.length,
            doneCardIds: _gradedCardIds,
          ),
        ),
      );
      return;
    }

    setState(() {
      _index += 1;
      _flipped = false;
      _drag = Offset.zero;
      _dragging = false;
      _exitDir = 0;
    });
    _exit.reset();
    _showCurrent();
  }

  Future<void> _grade(bool correct) async {
    if (!_flipped) return;
    if (_undoing) return;
    final entry = _deck[_index];
    final durationMs = DateTime.now().difference(_shownAt).inMilliseconds;
    HapticFeedback.lightImpact();
    setState(() => _exitDir = correct ? 1 : -1);
    await _exit.forward(from: 0);
    final result = await _repo.applyReview(
      cardId: entry.card.id,
      correct: correct,
      durationMs: durationMs,
    );
    if (!mounted) return;

    if (correct) _correctCount++;
    _gradedCardIds.add(entry.card.id);
    _undoStack.add(_GradeUndo(result.snapshot));

    if (_index + 1 >= _deck.length) {
      // Push the done screen and pop ourselves on the way out so the
      // back stack keeps the home → done relation, not home → review →
      // done with a stranded review.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewDoneScreen(
            db: widget.db,
            correct: _correctCount,
            total: _gradedCardIds.length,
            doneCardIds: _gradedCardIds,
          ),
        ),
      );
      return;
    }

    setState(() {
      _index += 1;
      _flipped = false;
      _drag = Offset.zero;
      _dragging = false;
      _exitDir = 0;
    });
    _exit.reset();
    _showCurrent();
  }

  Future<void> _undoLast() async {
    if (_undoStack.isEmpty || _undoing || _index == 0) return;
    final action = _undoStack.removeLast();
    setState(() => _undoing = true);
    HapticFeedback.selectionClick();
    var reflip = true;
    switch (action) {
      case _GradeUndo(:final snapshot):
        await _repo.undoReview(snapshot);
        if (snapshot.correct && _correctCount > 0) _correctCount -= 1;
        if (_gradedCardIds.isNotEmpty &&
            _gradedCardIds.last == snapshot.priorUserCard.cardId) {
          _gradedCardIds.removeLast();
        }
      case _SuspendUndo(:final cardId):
        await _repo.setSuspended(cardId, false);
        // The user hadn't flipped this card when they suspended — come
        // back with the front showing so the flow reads naturally.
        reflip = false;
    }
    if (!mounted) return;
    setState(() {
      _index -= 1;
      // The user already saw the answer side after a grade; come back
      // flipped so they can re-grade without an extra tap. After a
      // suspension we come back unflipped (see above).
      _flipped = reflip;
      _drag = Offset.zero;
      _dragging = false;
      _exitDir = 0;
      _undoing = false;
    });
    _exit.reset();
    _showCurrent();
  }

  void _onPanStart(DragStartDetails _) {
    if (!_flipped || _exitDir != 0) return;
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    setState(() => _drag = _drag + d.delta);
  }

  Future<void> _onPanEnd(DragEndDetails _) async {
    if (!_dragging) return;
    setState(() => _dragging = false);
    const threshold = 90.0;
    if (_drag.dx > threshold) {
      await _grade(true);
    } else if (_drag.dx < -threshold) {
      await _grade(false);
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: IunaPalette.bg,
        body: DecoratedBox(
          decoration: iunaPageBackground(),
          child: const Stack(
            children: [
              Positioned.fill(child: HexBg(seed: 17)),
              Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }
    if (_deck.isEmpty) {
      return Scaffold(
        backgroundColor: IunaPalette.bg,
        body: DecoratedBox(
          decoration: iunaPageBackground(),
          child: Stack(
            children: [
              const Positioned.fill(child: HexBg(seed: 17)),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      label: '0 / 0',
                      onClose: () => Navigator.of(context).maybePop(),
                    ),
                    const Expanded(child: _NoCards()),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 17)),
            SafeArea(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final total = _deck.length;
    final entry = _deck[_index];
    return Column(
      children: [
        _TopBar(
          label: '${_index + 1} / $total',
          onClose: () => Navigator.of(context).maybePop(),
          onUndo: _undoStack.isNotEmpty && _index > 0 && !_undoing
              ? _undoLast
              : null,
        ),
        const SizedBox(height: 4),
        ProgressDots(count: total, index: _index),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_index + 1 < total) _GhostCard(deck: _deck, index: _index),
                _buildActiveCard(entry),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_flipped)
          _AnswerRow(onForgot: () => _grade(false), onGotIt: () => _grade(true))
        else
          _GhostHint(onTap: _flip),
        SizedBox(height: 12 + MediaQuery.paddingOf(context).bottom),
      ],
    );
  }

  Widget _buildActiveCard(DailyDeckEntry entry) {
    return AnimatedBuilder(
      animation: _exit,
      builder: (_, _) {
        final exitT = Curves.easeInCubic.transform(_exit.value);
        final exiting = _exitDir != 0;
        // Drag-time pose; the exit animation interpolates from this
        // pose to the off-screen target so the card doesn't snap back
        // to origin on release.
        final dragDx = _drag.dx;
        final dragDy = _drag.dy * 0.25;
        final dragRot = _drag.dx * 0.06 * math.pi / 180;
        final targetDx = _exitDir * 500.0;
        const targetDy = -120.0;
        final targetRot = _exitDir * 18 * math.pi / 180;
        final dx = exiting ? dragDx + (targetDx - dragDx) * exitT : dragDx;
        final dy = exiting ? dragDy + (targetDy - dragDy) * exitT : dragDy;
        final rot = exiting ? dragRot + (targetRot - dragRot) * exitT : dragRot;
        final fade = exiting ? 1 - exitT : 1.0;

        final leftOpacity = (-_drag.dx / 120).clamp(0.0, 1.0).toDouble();
        final rightOpacity = (_drag.dx / 120).clamp(0.0, 1.0).toDouble();

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: rot,
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0).toDouble(),
              child: GestureDetector(
                onTap: _flip,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: _ReviewVocab(
                  entry: entry,
                  flipped: _flipped,
                  senses: _sensesForCurrent,
                  leftOpacity: leftOpacity,
                  rightOpacity: rightOpacity,
                  isDragging: _dragging,
                  onDetails: _showDetails,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.label, required this.onClose, this.onUndo});
  final String label;
  final VoidCallback onClose;

  /// When non-null, the left-side icon flips from a back chevron to an
  /// undo arrow that rolls back the last grade. Hidden (chevron returns
  /// to closing the screen) at the start of the session and immediately
  /// after a successful undo, so the affordance only shows up when
  /// there's actually something to roll back.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final undoActive = onUndo != null;
    return IunaTopBar(
      leading: IunaIconButton(
        icon: undoActive ? Icons.undo_rounded : Icons.chevron_left_rounded,
        onTap: undoActive ? onUndo : onClose,
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: IunaPalette.ink2,
        ),
      ),
      trailing: IunaIconButton(icon: Icons.close_rounded, onTap: onClose),
    );
  }
}

class _GhostCard extends StatelessWidget {
  const _GhostCard({required this.deck, required this.index});
  final List<DailyDeckEntry> deck;
  final int index;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = math.min(constraints.maxWidth * 0.78, 280.0);
        final height = width * 4 / 3;
        return Transform.translate(
          offset: const Offset(0, 14),
          child: Transform.scale(
            scale: 0.94,
            child: Opacity(
              opacity: 0.5,
              child: SizedBox(
                width: width,
                height: height,
                child: VocabCard(
                  rarity: deck[index + 1].card.rarity,
                  holo: false,
                  elevation: 0.4,
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReviewVocab extends StatelessWidget {
  const _ReviewVocab({
    required this.entry,
    required this.flipped,
    required this.senses,
    required this.leftOpacity,
    required this.rightOpacity,
    required this.isDragging,
    required this.onDetails,
  });

  final DailyDeckEntry entry;
  final bool flipped;
  final List<CardSenseRow> senses;
  final double leftOpacity;
  final double rightOpacity;
  final bool isDragging;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = math.min(constraints.maxWidth * 0.78, 300.0);
        final height = width * 4 / 3;
        final card = entry.card;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              VocabCard(
                rarity: card.rarity,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RarityChip(rarity: card.rarity),
                        if (flipped)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onDetails,
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: IunaPalette.ink2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: !flipped
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  card.kanji,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w700,
                                    color: IunaPalette.ink,
                                    height: 1,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Text(
                                      card.kanji,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: IunaPalette.ink,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      card.kana,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: IunaPalette.ink3,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (senses.isEmpty)
                                      Text(
                                        card.meaning,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: IunaPalette.ink,
                                        ),
                                      )
                                    else
                                      Column(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < senses.length && i < 3;
                                            i++
                                          )
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 3,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${i + 1}.',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: IunaPalette.ink3,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      senses[i].gloss,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: IunaPalette.ink,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    Text(
                      flipped ? '← swipe to grade →' : 'tap to reveal',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: IunaPalette.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(IunaRadii.lg),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Opacity(
                            opacity: leftOpacity,
                            child: const ColoredBox(color: Color(0x99E57373)),
                          ),
                        ),
                        Positioned.fill(
                          child: Opacity(
                            opacity: rightOpacity,
                            child: const ColoredBox(color: Color(0x997BC47F)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.onForgot, required this.onGotIt});
  final VoidCallback onForgot;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _AnswerBtn(
              icon: Icons.close_rounded,
              label: 'Forgot',
              gradient: const [Color(0xFFFDE2E7), Color(0xFFF7C0CB)],
              fg: const Color(0xFF7A2A3A),
              onTap: onForgot,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AnswerBtn(
              icon: Icons.check_rounded,
              label: 'Got it',
              gradient: const [Color(0xFFD9EEE2), Color(0xFFB6DCC6)],
              fg: const Color(0xFF1F5A40),
              onTap: onGotIt,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerBtn extends StatelessWidget {
  const _AnswerBtn({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(74, 53, 32, 0.18),
              blurRadius: 18,
              offset: Offset(0, 8),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostHint extends StatelessWidget {
  const _GhostHint({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: ghostPillDecoration(),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_rounded, size: 16, color: IunaPalette.ink2),
              SizedBox(width: 8),
              Text(
                'Tap card or here to reveal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: IunaPalette.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoCards extends StatelessWidget {
  const _NoCards();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.celebration_rounded,
            size: 72,
            color: IunaPalette.bellGold,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nothing to review right now.',
            style: TextStyle(fontSize: 16, color: IunaPalette.ink2),
          ),
          const SizedBox(height: 16),
          IunaCtaButton(
            label: 'Back home',
            shrinkWrap: true,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Reversible actions captured in the in-session undo stack. Sealed so
/// the undo-button dispatch is exhaustive; adding a new flavour (e.g.
/// "bury for the day") forces both push + pop sites to compile.
sealed class _UndoAction {
  const _UndoAction();
}

class _GradeUndo extends _UndoAction {
  const _GradeUndo(this.snapshot);
  final ReviewSnapshot snapshot;
}

class _SuspendUndo extends _UndoAction {
  const _SuspendUndo(this.cardId);
  final int cardId;
}

/// Action the [_DetailsSheet] returns to its caller. `null` (sheet
/// dismissed without choosing) is the implicit "no-op" outcome and is
/// represented as a plain `Navigator.pop()` without a value.
enum _SheetAction { suspend }

/// Modal-bottom-sheet peek into a card's full senses + examples while a
/// review is in progress. Suppresses the review-state and wishlist
/// blocks of [CardDetailScreen] — those would distract from the swipe
/// loop and the schedule is about to change anyway.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.card,
    required this.senses,
    required this.examples,
  });

  final CardRow card;
  final List<CardSenseRow> senses;
  final List<ExampleRow> examples;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: IunaPalette.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(74, 53, 32, 0.25),
              blurRadius: 32,
              offset: Offset(0, -8),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: IunaPalette.ink.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _SheetHeader(
              card: card,
              onClose: () => Navigator.of(context).maybePop(),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _SheetSection(
                    title: 'Senses',
                    child: senses.isEmpty
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
                              for (var i = 0; i < senses.length; i++)
                                SenseRow(
                                  ordinal: senses[i].ordinal,
                                  gloss: senses[i].gloss,
                                  pos: senses[i].pos,
                                  definition: senses[i].definition,
                                  showDivider: i > 0,
                                  gap: 6,
                                ),
                            ],
                          ),
                  ),
                  if (examples.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SheetSection(
                      title: 'Examples',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final ex in examples)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '・${ex.sentence}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: IunaPalette.ink2,
                                  height: 1.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SuspendTile(
                    onTap: () =>
                        Navigator.of(context).pop(_SheetAction.suspend),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuspendTile extends StatelessWidget {
  const _SuspendTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0x66FFFDF6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color.fromRGBO(74, 53, 32, 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.pause_circle_outline_rounded,
              size: 20,
              color: IunaPalette.ink2,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suspend this card',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: IunaPalette.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Skip it now and remove it from future reviews. You '
                    'can unsuspend from the collection.',
                    style: TextStyle(
                      fontSize: 12,
                      color: IunaPalette.ink3,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: IunaPalette.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.card, required this.onClose});
  final CardRow card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.kanji,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: IunaPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card.kana,
                  style: const TextStyle(fontSize: 14, color: IunaPalette.ink3),
                ),
              ],
            ),
          ),
          IunaIconButton(icon: Icons.close_rounded, onTap: onClose),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x66FFFDF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromRGBO(74, 53, 32, 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IunaEyebrow(title),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
