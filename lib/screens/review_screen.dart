import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/example_line.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/notice.dart';
import '../widgets/progress_dots.dart';
import '../widgets/section_header.dart';
import '../widgets/sense_row.dart';
import '../widgets/snack.dart';
import '../widgets/tappable.dart';
import '../widgets/vocab_card.dart';
import 'review_done_screen.dart';
import 'today_flow.dart';

/// Drag-to-grade review loop. Tap the kanji-only front to flip; the
/// back lists numbered senses. Drag the card past 90px to commit a
/// grade, or tap the Forgot / Got it pills.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.db, this.random, this.now});

  final AppDatabase db;

  /// Seeds the draw order; goldens pin it.
  final math.Random? random;

  /// Pins the clock for the deck, the grades and the recap; tests pass it.
  final DateTime? now;

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
  bool _failed = false;
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
    final List<DailyDeckEntry> deck;
    final Map<int, List<CardSenseRow>> senses;
    try {
      deck = await _repo.assembleDailyDeck(now: widget.now);
      senses = await _repo.sensesForCards([for (final e in deck) e.card.id]);
    } catch (e, s) {
      logLoadError('Review', e, s);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _deck = deck;
      _senses = senses;
      _loading = false;
      _failed = false;
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
      await _finish();
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
      now: widget.now,
    );
    if (!mounted) return;

    if (correct) _correctCount++;
    _gradedCardIds.add(entry.card.id);
    _undoStack.add(_GradeUndo(result.snapshot));

    if (_index + 1 >= _deck.length) {
      await _finish();
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

  /// Shows the recap over the finished session. It stays underneath so
  /// the recap's undo can bring the last card back; every other way out
  /// of the recap leaves both.
  Future<void> _finish() async {
    final undo = await Navigator.of(context).push<bool>(
      todayRoute(
        (_) => ReviewDoneScreen(
          db: widget.db,
          correct: _correctCount,
          total: _gradedCardIds.length,
          doneCardIds: List.of(_gradedCardIds),
          canUndo: true,
          now: widget.now,
        ),
      ),
    );
    if (undo == true && mounted) await _undoLast(fromRecap: true);
  }

  /// Rolls back the last grade or suspension. From the recap, the last
  /// card is still the current one, so the index stays.
  Future<void> _undoLast({bool fromRecap = false}) async {
    if (_undoStack.isEmpty || _undoing) return;
    if (!fromRecap && _index == 0) return;
    final action = _undoStack.removeLast();
    setState(() => _undoing = true);
    HapticFeedback.selectionClick();
    var reflip = true;
    try {
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
          // The user hadn't flipped this card when they suspended —
          // come back with the front showing so the flow reads
          // naturally.
          reflip = false;
      }
    } catch (e) {
      _undoStack.add(action);
      if (!mounted) return;
      setState(() => _undoing = false);
      showErrorSnack(context, "Couldn't undo that card.", e);
      return;
    }
    if (!mounted) return;
    setState(() {
      if (!fromRecap) _index -= 1;
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
    if (_failed || _deck.isEmpty) {
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
                      label: _failed ? '' : '0 / 0',
                      onClose: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: _failed
                          ? LoadErrorNotice(
                              onRetry: () {
                                setState(() {
                                  _loading = true;
                                  _failed = false;
                                });
                                _bootstrap();
                              },
                            )
                          : const _NoCards(),
                    ),
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
          _RevealButton(onTap: _flip),
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

  /// When non-null, an undo arrow on the right rolls back the last
  /// grade. Absent at the start of the session and right after an undo,
  /// so it only shows when there's something to roll back. Close sits
  /// on the left, where every other screen keeps its way out.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return IunaTopBar(
      leading: IunaIconButton(
        icon: Icons.close_rounded,
        tooltip: 'End review',
        onTap: onClose,
      ),
      title: Text(
        label,
        style: IunaText.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: IunaPalette.ink2,
        ),
      ),
      trailing: onUndo == null
          ? null
          : IunaIconButton(
              icon: Icons.undo_rounded,
              tooltip: 'Undo last card',
              onTap: onUndo,
            ),
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
                          IunaIconButton(
                            icon: Icons.info_outline_rounded,
                            tooltip: 'Card details',
                            onTap: onDetails,
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
                                      style: IunaText.bodySmall.copyWith(
                                        color: IunaPalette.ink3,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (senses.isEmpty)
                                      Text(
                                        card.meaning,
                                        textAlign: TextAlign.center,
                                        style: IunaText.body.copyWith(
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
                                                    style: IunaText.chip.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: IunaPalette.ink3,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      senses[i].gloss,
                                                      style: IunaText.bodySmall.copyWith(
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
                      flipped ? '← forgot · got it →' : 'tap to reveal',
                      textAlign: TextAlign.center,
                      style: IunaText.caption.copyWith(
                        fontStyle: FontStyle.italic,
                        color: IunaPalette.ink3,
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
                            child: const _SwipeVerdict(
                              wash: IunaPalette.wrongWash,
                              ink: IunaPalette.wrongInk,
                              icon: Icons.close_rounded,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Opacity(
                            opacity: rightOpacity,
                            child: const _SwipeVerdict(
                              wash: IunaPalette.rightWash,
                              ink: IunaPalette.rightInk,
                              icon: Icons.check_rounded,
                            ),
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

/// The tint over a card dragged toward a grade, with its mark, so the
/// grade doesn't rest on red and green alone.
class _SwipeVerdict extends StatelessWidget {
  const _SwipeVerdict({
    required this.wash,
    required this.ink,
    required this.icon,
  });

  final Color wash;
  final Color ink;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: wash,
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: IunaPalette.paper.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 44, color: ink),
        ),
      ),
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
              gradient: const [
                IunaPalette.wrongFill,
                IunaPalette.wrongFillDeep,
              ],
              fg: IunaPalette.wrongInk,
              onTap: onForgot,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AnswerBtn(
              icon: Icons.check_rounded,
              label: 'Got it',
              gradient: const [
                IunaPalette.rightFill,
                IunaPalette.rightFillDeep,
              ],
              fg: IunaPalette.rightInk,
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
    return Tappable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(999),
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
              style: IunaText.label.copyWith(
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IunaCtaButton(
        label: 'Reveal',
        leadingIcon: Icons.visibility_rounded,
        onTap: onTap,
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
          Text(
            'Nothing to review right now.',
            style: IunaText.bodyLarge.copyWith(color: IunaPalette.ink2),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(IunaRadii.lg)),
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
                            style: IunaText.body.copyWith(
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
                          for (final ex in examples) ExampleLine(example: ex),
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
    return Tappable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: IunaPalette.paperGlass,
          borderRadius: BorderRadius.circular(IunaRadii.md),
          border: Border.all(color: IunaPalette.hairline, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.pause_circle_outline_rounded,
              size: 20,
              color: IunaPalette.ink2,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suspend this card',
                    style: IunaText.label.copyWith(
                      color: IunaPalette.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Skip it now and remove it from future reviews. You '
                    'can unsuspend from the collection.',
                    style: IunaText.caption.copyWith(
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
                  style: IunaText.body.copyWith(color: IunaPalette.ink3),
                ),
              ],
            ),
          ),
          IunaIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onTap: onClose,
          ),
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
        color: IunaPalette.paperGlass,
        borderRadius: BorderRadius.circular(IunaRadii.md),
        border: Border.all(color: IunaPalette.hairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IunaPanelTitle(title),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
