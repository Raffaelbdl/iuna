import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../services/tts.dart';
import '../theme/iuna_theme.dart';
import '../widgets/section_header.dart';
import 'game_draw.dart';
import 'game_widgets.dart';
import 'pairs.dart';

/// Match each card's two faces: kanji to reading, word to meaning, or
/// a spoken word to its writing. Modes take turns, round by round.
/// Practice only: the deck's scheduling is never touched.
class PairsScreen extends StatefulWidget {
  const PairsScreen({
    super.key,
    required this.db,
    this.seed,
    this.clock = DateTime.now,
    this.speak,
  });

  final AppDatabase db;

  /// Pins the draw and the shuffles, for goldens and tests.
  final int? seed;
  final DateTime Function() clock;

  /// Says a sound tile aloud; TTS when null.
  final void Function(String kana)? speak;

  @override
  State<PairsScreen> createState() => _PairsScreenState();
}

enum _TileLook { idle, selected, matched, wrong }

class _PairsScreenState extends State<PairsScreen> {
  late final IunaRepository _repo = IunaRepository(widget.db);
  late final Random _random = Random(widget.seed);

  bool _loading = true;
  List<DailyDeckEntry> _cards = const [];
  Map<int, DailyDeckEntry> _byId = const {};
  GameMemory _memory = GameMemory();

  PairsRound? _round;

  /// The round's cards as [GameMemory] had them before the deal.
  Map<int, GameSighting?> _beforeRound = const {};
  int _roundIndex = 0;
  DateTime _startedAt = DateTime(0);
  Duration? _took;

  /// The two tiles of a wrong pair, flashed briefly.
  Set<PairTile> _wrong = const {};
  Timer? _wrongTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wrongTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final (cards, memory) = await (
      _repo.gameCards(),
      _repo.getGameMemory(),
    ).wait;
    if (!mounted) return;
    _cards = cards;
    _byId = {for (final c in cards) c.card.id: c};
    _memory = GameMemory.parse(memory)..startSession();
    setState(() {
      _loading = false;
      _deal();
    });
  }

  /// Deals the next round in this round's mode, or in the next mode
  /// that has enough cards for it.
  void _deal() {
    final order = drawOrder(_cards, _memory, _random);
    PairsRound? round;
    for (var i = 0; i < PairsMode.values.length && round == null; i++) {
      final mode =
          PairsMode.values[(_roundIndex + i) % PairsMode.values.length];
      round = PairsRound.deal(order, mode, _random);
    }
    _round = round;
    _took = null;
    _wrong = const {};
    _startedAt = widget.clock();
    if (round == null) return;
    _beforeRound = _memory.saw(round.cardIds);
    _save();
  }

  void _save() => unawaited(_repo.setGameMemory(_memory.encode()));

  void _nextRound() => setState(() {
    _roundIndex++;
    _deal();
  });

  /// Drops the round (a sound round in a busy room, say) for the next
  /// mode. Its cards weren't practised, so they don't rest, unless one
  /// was already missed.
  void _skip() {
    final missed = _round!.missedCards;
    _memory.restore({
      for (final MapEntry(:key, :value) in _beforeRound.entries)
        if (!missed.contains(key)) key: value,
    });
    _nextRound();
  }

  void _onTap(PairTile tile) {
    final round = _round!;
    if (round.finished) return;
    if (tile.sound) (widget.speak ?? TtsService.instance.speak)(tile.text);
    // A selected sound tile replays rather than letting go.
    if (tile.sound && identical(round.selected, tile)) return;
    final first = round.selected;
    final result = round.tap(tile);
    setState(() {
      switch (result) {
        case PairsTap.miss:
          _memory.missed(first!.cardId);
          _save();
          _wrong = {first, tile};
          _wrongTimer?.cancel();
          _wrongTimer = Timer(const Duration(milliseconds: 450), () {
            if (mounted) setState(() => _wrong = const {});
          });
        case PairsTap.match when round.finished:
          _took = widget.clock().difference(_startedAt);
        case _:
          break;
      }
    });
  }

  _TileLook _look(PairTile tile) {
    final round = _round!;
    if (round.matched.contains(tile.cardId)) return _TileLook.matched;
    if (_wrong.contains(tile)) return _TileLook.wrong;
    if (identical(round.selected, tile)) return _TileLook.selected;
    return _TileLook.idle;
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    return GamePage(
      title: 'Pairs',
      onSkip: round == null || round.finished ? null : _skip,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : round == null
          ? const GameNotice(
              text:
                  'Pairs needs at least $kMinPairs cards you have met. '
                  'Open a pack and flip its cards to start.',
            )
          : round.finished
          ? _summary(round)
          : _Board(round: round, look: _look, onTap: _onTap),
    );
  }

  Widget _summary(PairsRound round) {
    final seconds = (_took ?? Duration.zero).inSeconds;
    return GameSummary(
      kicker: round.misses == 0 ? 'かんぺき' : 'できた',
      headline: round.misses == 0 ? 'A clean sweep.' : 'All pairs found.',
      figures: [
        (
          value:
              '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
          label: 'time',
        ),
        (
          value: '${round.misses}',
          label: round.misses == 1 ? 'miss' : 'misses',
        ),
      ],
      missed: [for (final id in round.missedCards) ?_byId[id]?.card],
      onNext: _nextRound,
      onDone: () => Navigator.of(context).pop(),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.round, required this.look, required this.onTap});

  final PairsRound round;
  final _TileLook Function(PairTile) look;
  final ValueChanged<PairTile> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        children: [
          Row(
            children: [
              IunaEyebrow(round.mode.label),
              const Spacer(),
              Text(
                '${round.matched.length} / ${round.size}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: IunaPalette.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < round.size; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tile in [round.left[i], round.right[i]]) ...[
                    if (tile.side == PairSide.right) const SizedBox(width: 12),
                    Expanded(
                      child: _Tile(
                        tile: tile,
                        look: look(tile),
                        onTap: () => onTap(tile),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.look, required this.onTap});

  final PairTile tile;
  final _TileLook look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (fill, border) = switch (look) {
      _TileLook.idle => (IunaPalette.paper, const Color(0x0F4A3520)),
      _TileLook.selected => (const Color(0xFFFFF1D6), IunaPalette.bellGold),
      _TileLook.matched => (
        IunaPalette.rarityCommonFill,
        IunaPalette.rarityCommon,
      ),
      _TileLook.wrong => (IunaPalette.raritySsrFill, IunaPalette.raritySsr),
    };
    final ink = look == _TileLook.wrong
        ? IunaPalette.raritySsrInk
        : IunaPalette.ink;
    final Widget face = tile.sound
        ? Icon(Icons.volume_up_rounded, size: 28, color: ink)
        : tile.japanese
        ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tile.text,
              maxLines: 1,
              style: TextStyle(
                fontSize: tile.side == PairSide.left ? 24 : 19,
                fontWeight: tile.side == PairSide.left
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: ink,
              ),
            ),
          )
        : Text(
            tile.text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: ink,
            ),
          );
    return GestureDetector(
      key: ValueKey('pair-${tile.side.name}-${tile.cardId}'),
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: look == _TileLook.matched ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: paperPanelDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(IunaRadii.md),
            border: Border.all(
              color: border,
              width: look == _TileLook.idle ? 0.5 : 2,
            ),
          ),
          alignment: Alignment.center,
          child: face,
        ),
      ),
    );
  }
}
