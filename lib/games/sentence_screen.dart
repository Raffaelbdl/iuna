import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/jmdict_lookup.dart' show kJmdictFileName;
import '../db/repository.dart';
import '../db/sqlite_open.dart';
import '../screens/settings_screen.dart';
import '../services/dict_download.dart';
import '../services/tts.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/section_header.dart';
import '../widgets/tappable.dart';
import 'game_draw.dart';
import 'game_widgets.dart';
import 'sentence_feed.dart';
import 'sentences.dart';

/// The games on example sentences, with the English as the clue:
/// rebuild one from its tiles, or fill a particle gap ([game]). The
/// sentences are the examples of owned cards, split by the dictionary
/// on the fly, so the games need it downloaded. Practice only: the
/// deck's scheduling is never touched.
class SentenceScreen extends StatefulWidget {
  const SentenceScreen({
    super.key,
    required this.db,
    this.game = SentenceGame.order,
    this.seed,
    this.tiler,
    this.speak,
  });

  final AppDatabase db;
  final SentenceGame game;

  /// Pins the draw and the shuffles, for goldens and tests.
  final int? seed;

  /// Splits sentences into tiles; the downloaded dictionary, in an
  /// isolate, when null.
  final SentenceTiler? tiler;

  /// Says the sentence aloud; TTS when null.
  final void Function(String text)? speak;

  @override
  State<SentenceScreen> createState() => _SentenceScreenState();
}

class _SentenceScreenState extends State<SentenceScreen> {
  late final IunaRepository _repo = IunaRepository(widget.db);
  late final Random _random = Random(widget.seed);

  bool _noDictionary = false;
  bool _exhausted = false;
  bool _summary = false;

  SentenceFeed? _feed;
  GameMemory _memory = GameMemory();
  SentenceTask? _task;

  /// The card's sighting before this puzzle showed, for a skip.
  Map<int, GameSighting?> _before = const {};

  /// This round's puzzles, and whether each was right.
  final _round = <(SentencePuzzle, bool)>[];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _feed?.dispose();
    super.dispose();
  }

  static Future<SentenceTiler?> _dictionaryTiler() async {
    if (!await DictDownload.isInstalled()) return null;
    return isolateTiler((await documentsFile(kJmdictFileName)).path);
  }

  Future<void> _start() async {
    final (tiler, cards, memory) = await (
      widget.tiler == null ? _dictionaryTiler() : Future.value(widget.tiler),
      _repo.gameCards(),
      _repo.getGameMemory(),
    ).wait;
    if (!mounted) return;
    if (tiler == null) {
      setState(() => _noDictionary = true);
      return;
    }
    // _advance draws it.
    _noDictionary = false;
    _memory = GameMemory.parse(memory)..startSession();
    _feed = SentenceFeed(
      repo: _repo,
      cards: cards,
      memory: _memory,
      random: _random,
      tile: tiler,
      shape: widget.game.shape,
    );
    await _advance();
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SettingsScreen(db: widget.db)));
    if (!mounted) return;
    await _start();
  }

  void _save() => unawaited(_repo.setGameMemory(_memory.encode()));

  Future<void> _advance() async {
    setState(() => _task = null);
    final puzzle = await _feed!.next();
    if (!mounted) return;
    setState(() {
      if (puzzle == null) {
        _exhausted = true;
        _summary = _round.isNotEmpty;
        return;
      }
      _task = switch (widget.game) {
        SentenceGame.order => SentenceBoard(puzzle, _random),
        SentenceGame.particles => ParticleBoard(puzzle, _random),
      };
      _before = _memory.saw([puzzle.card.card.id]);
      _memory.sawExample(puzzle.example.id);
    });
    _save();
  }

  /// Counts [task], just answered, toward the round.
  void _answered(SentenceTask task) {
    final right = task.right!;
    if (!right) _memory.missed(task.puzzle.card.card.id);
    _round.add((task.puzzle, right));
    _save();
  }

  void _tap(int tile) => setState(() => (_task! as SentenceBoard).tap(tile));

  void _check() {
    final board = _task! as SentenceBoard;
    if (!board.complete || board.checked) return;
    setState(() {
      board.check();
      _answered(board);
    });
  }

  void _pick(String particle) {
    final gap = _task! as ParticleBoard;
    if (gap.right != null) return;
    setState(() {
      gap.pick(particle);
      _answered(gap);
    });
  }

  void _next() {
    if (_round.length >= kSentencesPerRound) {
      setState(() {
        _task = null;
        _summary = true;
      });
    } else {
      _advance();
    }
  }

  /// Drops the sentence; its card wasn't practised, so it doesn't rest.
  void _skip() {
    _memory.restore(_before);
    _save();
    _advance();
  }

  void _nextRound() {
    setState(() {
      _round.clear();
      _summary = false;
    });
    if (!_exhausted) _advance();
  }

  void _speak(String text) => (widget.speak ?? TtsService.instance.speak)(text);

  @override
  Widget build(BuildContext context) {
    final task = _task;
    return GamePage(
      title: widget.game.title,
      skipLabel: 'Skip sentence',
      onSkip: task == null || task.right != null ? null : _skip,
      body: _body(task),
    );
  }

  Widget _body(SentenceTask? task) {
    if (_noDictionary) {
      return GameNotice(
        text:
            'Sentences are split into tiles with the offline dictionary. '
            'Download it in Settings, then come back.',
        action: (label: 'Open Settings', onTap: _openSettings),
      );
    }
    if (_summary) {
      final right = _round.where((r) => r.$2).length;
      final all = right == _round.length;
      return GameSummary(
        kicker: all ? 'かんぺき' : 'できた',
        headline: all ? 'Every sentence right.' : 'Round done.',
        figures: [(value: '$right / ${_round.length}', label: 'right')],
        missed: [
          for (final (p, ok) in _round)
            if (!ok) p.card.card,
        ],
        onNext: _nextRound,
        onDone: () => Navigator.of(context).pop(),
      );
    }
    if (task != null) {
      final answered = task.right != null;
      final (middle, note) = switch (task) {
        SentenceBoard() => (
          _Order(board: task, onTap: _tap),
          task.right == true && task.reordered
              ? 'Also right. The example has it as:'
              : null,
        ),
        ParticleBoard() => (_Gap(gap: task, onPick: _pick), null),
      };
      return _Frame(
        prompt: widget.game.prompt,
        number: _round.length + (answered ? 0 : 1),
        english: task.puzzle.example.translation ?? '',
        middle: middle,
        verdict: !answered
            ? null
            : _Verdict(
                right: task.right!,
                note: task.right! ? note : 'The sentence reads:',
                sentence: task.puzzle.tiles.text,
                onSpeak: () => _speak(task.puzzle.example.sentence),
              ),
        action: answered
            ? IunaCtaButton(
                label: 'Next',
                trailingIcon: Icons.arrow_forward_rounded,
                onTap: _next,
              )
            : task is SentenceBoard
            ? AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: task.complete ? 1 : 0.4,
                child: IunaCtaButton(label: 'Check', onTap: _check),
              )
            : null,
      );
    }
    if (!_exhausted) return const Center(child: CircularProgressIndicator());
    return const GameNotice(
      text:
          'No more sentences for now. They come from the examples of '
          'the cards you own, so more cards bring more of them.',
    );
  }
}

/// What every sentence puzzle shows: the prompt and progress, the
/// English, the game's [middle], the verdict once answered, and the
/// [action] at the bottom.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.prompt,
    required this.number,
    required this.english,
    required this.middle,
    required this.verdict,
    required this.action,
  });

  final String prompt;
  final int number;
  final String english;
  final Widget middle;
  final Widget? verdict;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final verdict = this.verdict;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Row(
                children: [
                  IunaEyebrow(prompt),
                  const Spacer(),
                  Text(
                    '$number / $kSentencesPerRound',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: IunaPalette.ink3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: paperPanelDecoration(),
                child: Text(
                  english,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: IunaPalette.ink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              middle,
              if (verdict != null) ...[const SizedBox(height: 20), verdict],
            ],
          ),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: action,
          ),
      ],
    );
  }
}

/// Sentence builder: the placed tiles, then the bank until checked.
class _Order extends StatelessWidget {
  const _Order({required this.board, required this.onTap});

  final SentenceBoard board;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tiles = board.tiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Well(
          child: board.placed.isEmpty
              ? const Center(
                  child: Text(
                    'Tap the tiles in order',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: IunaPalette.ink3,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var at = 0; at < board.placed.length; at++)
                      _Chip(
                        key: ValueKey('placed-${board.placed[at]}'),
                        text: tiles.tiles[board.placed[at]],
                        look: !board.checked
                            ? _ChipLook.idle
                            : board.placedRight(at)
                            ? _ChipLook.right
                            : _ChipLook.wrong,
                        onTap: () => onTap(board.placed[at]),
                      ),
                    if (board.complete)
                      Text(
                        tiles.end,
                        style: const TextStyle(
                          fontSize: 18,
                          color: IunaPalette.ink2,
                        ),
                      ),
                  ],
                ),
        ),
        if (!board.checked) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final i in board.bank)
                _Chip(
                  key: ValueKey('bank-$i'),
                  text: tiles.tiles[i],
                  look: board.placed.contains(i)
                      ? _ChipLook.ghost
                      : _ChipLook.idle,
                  onTap: board.placed.contains(i) ? null : () => onTap(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Particle gap: the sentence with its blank, then the choices.
class _Gap extends StatelessWidget {
  const _Gap({required this.gap, required this.onPick});

  final ParticleBoard gap;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final (before, after) = gap.around;
    final picked = gap.picked;
    const style = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.6,
      color: IunaPalette.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Well(
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: before),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _Chip(
                      // An ideographic space sizes the blank like a kana.
                      text: picked ?? '\u3000',
                      look: picked == null
                          ? _ChipLook.ghost
                          : gap.right!
                          ? _ChipLook.right
                          : _ChipLook.wrong,
                      onTap: null,
                    ),
                  ),
                ),
                TextSpan(text: after),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final p in gap.choices)
              _Chip(
                key: ValueKey('choice-$p'),
                text: p,
                look: picked == null
                    ? _ChipLook.idle
                    : p == gap.answer
                    ? _ChipLook.right
                    : p == picked
                    ? _ChipLook.wrong
                    : _ChipLook.idle,
                onTap: picked == null ? () => onPick(p) : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// The area a sentence is built or read in.
class _Well extends StatelessWidget {
  const _Well({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x80FFFDF6),
        borderRadius: BorderRadius.circular(IunaRadii.md),
        border: Border.all(color: const Color(0x294A3520), width: 1),
      ),
      child: child,
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.right,
    required this.note,
    required this.sentence,
    required this.onSpeak,
  });

  final bool right;

  /// Over [sentence], which shows only with a note.
  final String? note;
  final String sentence;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = right
        ? (IunaPalette.rarityCommonFill, IunaPalette.rarityCommonInk)
        : (IunaPalette.raritySsrFill, IunaPalette.raritySsrInk);
    final note = this.note;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(IunaRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  right ? '正解 · Right.' : 'Not quite.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 6),
                  Text(note, style: TextStyle(fontSize: 12, color: ink)),
                  const SizedBox(height: 4),
                  Text(
                    sentence,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: IunaPalette.ink,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tooltip(
            message: 'Listen',
            child: IconButton(
              onPressed: onSpeak,
              icon: Icon(Icons.volume_up_rounded, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChipLook { idle, ghost, right, wrong }

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.text,
    required this.look,
    required this.onTap,
  });

  final String text;
  final _ChipLook look;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (fill, border, ink) = switch (look) {
      _ChipLook.idle => (
        IunaPalette.paper,
        const Color(0x1F4A3520),
        IunaPalette.ink,
      ),
      _ChipLook.ghost => (
        const Color(0x00000000),
        const Color(0x1F4A3520),
        const Color(0x00000000),
      ),
      _ChipLook.right => (
        IunaPalette.rarityCommonFill,
        IunaPalette.rarityCommon,
        IunaPalette.ink,
      ),
      _ChipLook.wrong => (
        IunaPalette.raritySsrFill,
        IunaPalette.raritySsr,
        IunaPalette.raritySsrInk,
      ),
    };
    // A mark beside the colour, so right and wrong don't rest on hue.
    final mark = switch (look) {
      _ChipLook.right => Icons.check_rounded,
      _ChipLook.wrong => Icons.close_rounded,
      _ => null,
    };
    return Tappable(
      onTap: onTap,
      label: switch (look) {
        _ChipLook.right => 'Right',
        _ChipLook.wrong => 'Wrong',
        _ => null,
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(IunaRadii.sm),
          border: Border.all(color: border, width: 1),
          boxShadow: look == _ChipLook.idle
              ? const [
                  BoxShadow(
                    color: Color(0x144A3520),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mark != null) ...[
              Icon(mark, size: 18, color: ink),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
