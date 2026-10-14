import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/booster_pack.dart';
import '../widgets/cta_button.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/progress_dots.dart';
import '../widgets/vocab_card.dart';

/// One-by-one card reveal after the pack-intro splash. Tap or press
/// "Next card" to advance; the final card pops the screen with the
/// picked ids so the caller can route into the review flow. When the
/// user has more than one daily pack remaining, all of them are claimed
/// upfront and revealed in one chained sequence — a short pack-tear
/// animation plays between packs so the boundary stays felt.
class BoosterRevealScreen extends StatefulWidget {
  const BoosterRevealScreen({super.key, required this.db, this.random});

  final AppDatabase db;

  /// Seeds the draw order; goldens pin it.
  final math.Random? random;

  @override
  State<BoosterRevealScreen> createState() => _BoosterRevealScreenState();
}

class _BoosterRevealScreenState extends State<BoosterRevealScreen>
    with TickerProviderStateMixin {
  late final IunaRepository _repo = IunaRepository(
    widget.db,
    random: widget.random,
  );

  bool _loading = true;
  List<CardRow> _cards = const [];

  /// Card indices where a new pack starts. Used to fire the inline
  /// tear animation when the user advances *into* one of these
  /// indices. The very first pack starts at 0 and never plays the
  /// in-between tear (the pack-intro splash already handled it).
  final Set<int> _packStarts = <int>{};

  /// Pack number (1-based) that owns the card at each index. Drives
  /// the "Pack X / N" badge in the top bar so the user knows where
  /// they are within the chained reveal.
  final List<int> _packForIndex = <int>[];
  int _totalPacks = 0;

  final Set<int> _revealed = {0};
  int _index = 0;
  bool _tearing = false;

  /// True while a suspend→replace swap is mid-flight (DB write +
  /// exit animation running in parallel). Blocks rapid re-taps on the
  /// Suspend pill so the same slot can't be swapped twice while the
  /// first transaction is still committing.
  bool _swapping = false;

  /// Set to true while [_finalizeAndPop] runs so a double-tap on
  /// "Start review" can't fire two pops.
  bool _finalizing = false;

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  /// Inline tear that plays between packs. Mirrors the pack-intro tear
  /// timing so the visual cadence stays consistent across the flow.
  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// Suspend-and-swap animation. Drives a short shake + fade-to-gray +
  /// fade-out on the rejected card so the gesture reads as "no, not
  /// this one" before the replacement snaps into the slot.
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final claims = await _repo.claimAllAvailableBoosters();
    if (!mounted) return;
    final cards = <CardRow>[];
    for (var i = 0; i < claims.length; i++) {
      if (claims[i].cards.isEmpty) continue;
      _packStarts.add(cards.length);
      for (final c in claims[i].cards) {
        cards.add(c);
        _packForIndex.add(i + 1);
      }
    }
    if (cards.isEmpty) {
      Navigator.of(context).pop(<int>[]);
      return;
    }
    setState(() {
      _cards = cards;
      _totalPacks = _packStarts.length;
      _loading = false;
    });
    // Mark the first card seen + fire a haptic for the high tiers.
    final first = cards[0];
    if (rarityStars(first.rarity) >= 4) HapticFeedback.heavyImpact();
    unawaited(_repo.markCardsSeen([first.id]));
  }

  @override
  void dispose() {
    _exit.dispose();
    _tear.dispose();
    _swap.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    if (_loading || _tearing || _finalizing || _swapping) return;
    if (_index >= _cards.length - 1) {
      await _finalizeAndPop();
      return;
    }
    await _exit.forward(from: 0);
    if (!mounted) return;
    final next = _index + 1;

    // Pack boundary: play the inline tear before the next card lands.
    // Keeps the user oriented when boostersPerDay > 1 chains multiple
    // packs into a single reveal session.
    if (_packStarts.contains(next) && next != 0) {
      setState(() {
        _tearing = true;
        _index = next;
        _revealed.add(next);
      });
      _exit.reset();
      HapticFeedback.mediumImpact();
      await _tear.forward(from: 0);
      if (!mounted) return;
      _tear.reset();
      setState(() => _tearing = false);
    } else {
      setState(() {
        _index = next;
        _revealed.add(next);
      });
      _exit.reset();
    }

    final card = _cards[next];
    if (rarityStars(card.rarity) >= 4) {
      HapticFeedback.heavyImpact();
    } else if (rarityStars(card.rarity) == 3) {
      HapticFeedback.mediumImpact();
    }
    unawaited(_repo.markCardsSeen([card.id]));
  }

  /// Suspends the active card and swaps a fresh replacement into the
  /// same slot. Total pack size stays the same — the user sees one new
  /// card take the place of the one they shelved, not an extra card
  /// appended at the end. If the unseen pool can't supply a
  /// replacement (very late game), we fall through to a regular
  /// [_advance] so the user moves past the suspended slot rather than
  /// being stuck on a blank.
  Future<void> _suspendCurrent() async {
    if (_loading || _tearing || _finalizing || _swapping) return;
    final card = _cards[_index];
    HapticFeedback.selectionClick();
    setState(() => _swapping = true);

    // Animation + DB write race together; the swap lands once both
    // finish so the user doesn't see the card exit and then a stale
    // copy linger for a frame.
    final animFuture = _swap.forward(from: 0);
    final replaceFuture = _repo.suspendAndReplace(suspendCardIds: [card.id]);
    await animFuture;
    final replacements = await replaceFuture;
    if (!mounted) return;

    if (replacements.isEmpty) {
      // Unseen pool ran dry. Card is still suspended in the DB; we just
      // can't mint a replacement. Skip the slot like a normal advance.
      _swap.reset();
      setState(() => _swapping = false);
      await _advance();
      return;
    }

    final r = replacements.first;
    setState(() {
      _cards[_index] = r;
      _swapping = false;
    });
    _swap.reset();
    unawaited(_repo.markCardsSeen([r.id]));
    if (rarityStars(r.rarity) >= 4) {
      HapticFeedback.heavyImpact();
    } else if (rarityStars(r.rarity) == 3) {
      HapticFeedback.mediumImpact();
    }
  }

  /// End-of-session pop. Suspensions and replacements were already
  /// committed in-line by [_suspendCurrent], so the payload here is
  /// just a "did the reveal happen?" sentinel for the parent route.
  Future<void> _finalizeAndPop() async {
    if (_finalizing) return;
    setState(() => _finalizing = true);
    if (!mounted) return;
    Navigator.of(context).pop(_cards.map((c) => c.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 41)),
            SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final card = _cards[_index];
    final isLast = _index >= _cards.length - 1;
    final packNum = _packForIndex.isEmpty ? 1 : _packForIndex[_index];
    final packLabel = _totalPacks > 1
        ? 'Pack $packNum / $_totalPacks · '
        : 'Booster · ';
    return Column(
      children: [
        _TopBar(
          label: '$packLabel${_index + 1} / ${_cards.length}',
          onClose: _finalizeAndPop,
        ),
        ProgressDots(count: _cards.length, index: _index, revealed: _revealed),
        const SizedBox(height: 6),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_exit, _swap]),
                builder: (_, _) {
                  // Two animation paths share this card slot: the
                  // regular advance/exit (_exit) and the suspend swap
                  // (_swap). _swapping picks which set of transforms
                  // drives the build. They never run concurrently —
                  // _suspendCurrent / _advance both guard on each
                  // other's flag.
                  final t = Curves.easeInCubic.transform(_exit.value);
                  final s = _swap.value;
                  // Exit (advance) transforms — translate up + slight
                  // scale + tilt + fade.
                  final exitDy = -30 * t;
                  final exitScale = 1 - 0.08 * t;
                  final exitRot = -3 * t * math.pi / 180;
                  final exitFade = 1 - t;
                  // Swap (suspend) transforms — quick shake, then
                  // hold while desaturating to gray, then fade out.
                  final shakeDx = s < 0.33
                      ? math.sin((s / 0.33) * math.pi * 4) * 14
                      : 0.0;
                  final desat = (s / 0.33).clamp(0.0, 1.0);
                  final swapScale = 1 - 0.04 * s;
                  final swapFade = s > 0.78 ? 1 - ((s - 0.78) / 0.22) : 1.0;

                  final dx = _swapping ? shakeDx : 0.0;
                  final dy = _swapping ? 0.0 : exitDy;
                  final scale = _swapping ? swapScale : exitScale;
                  final rot = _swapping ? 0.0 : exitRot;
                  final fade = _swapping ? swapFade : exitFade;

                  return Opacity(
                    // While the pack-tear is playing the underlying card
                    // sits hidden so the user reads the pack as the only
                    // thing on screen during the boundary.
                    opacity: _tearing ? 0 : 1,
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.rotate(
                          angle: rot,
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: fade,
                              child: ColorFiltered(
                                colorFilter: _grayscale(_swapping ? desat : 0),
                                child: GestureDetector(
                                  onTap: _advance,
                                  child: _RevealCard(card: card),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_tearing)
                AnimatedBuilder(
                  animation: _tear,
                  builder: (_, _) {
                    final v = _tear.value;
                    final tearT = Curves.easeOutCubic.transform(v);
                    final scale = 1 + tearT * 0.18;
                    final rot = -tearT * (4 * math.pi / 180);
                    // Pack appears, flashes, then fades out as the
                    // tear completes — leaving the next card to render
                    // as soon as `_tearing` flips back to false.
                    final fade = v < 0.85 ? 1.0 : (1 - (v - 0.85) / 0.15);
                    return Opacity(
                      opacity: fade.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: rot,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const BoosterPack(
                                width: 200,
                                height: 280,
                                label: '日本語',
                                jpFooter: 'パック',
                                kumaSize: 140,
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity:
                                        (1 - (v - 0.3).abs() * 3).clamp(
                                          0.0,
                                          1.0,
                                        ) *
                                        0.85,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            Color(0xFFFFF7E0),
                                            Color(0x00FFF7E0),
                                          ],
                                          stops: [0.0, 0.6],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Row(
            children: [
              _SuspendPill(onTap: _swapping ? null : _suspendCurrent),
              const SizedBox(width: 10),
              Expanded(
                child: IunaCtaButton(
                  label: isLast ? 'Start review' : 'Next card',
                  onTap: _advance,
                  trailingIcon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Interpolated grayscale matrix. `amount` 0 leaves the source untouched,
/// 1 fully desaturates using ITU-R BT.709 luminance weights. Used during
/// the suspend-and-swap animation to wash the rejected card to gray
/// before it fades out.
ColorFilter _grayscale(double amount) {
  // dart format off
  if (amount <= 0) {
    return const ColorFilter.matrix([
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  final a = amount.clamp(0.0, 1.0);
  return ColorFilter.matrix([
    1 - a + a * r, a * g, a * b, 0, 0,
    a * r, 1 - a + a * g, a * b, 0, 0,
    a * r, a * g, 1 - a + a * b, 0, 0,
    0, 0, 0, 1, 0,
  ]);
  // dart format on
}

class _SuspendPill extends StatelessWidget {
  const _SuspendPill({required this.onTap});

  /// `null` means a suspend→swap is already mid-flight; greys the pill
  /// out so the user can't queue a second swap on the same slot before
  /// the first one lands.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: disabled
            ? ghostPillDecoration(color: const Color(0x33B8D8C9))
            : ghostPillDecoration(boxShadow: panelShadow()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pause_circle_outline_rounded,
              size: 18,
              color: disabled ? IunaPalette.ink3 : IunaPalette.ink2,
            ),
            const SizedBox(width: 6),
            Text(
              'Suspend',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: disabled ? IunaPalette.ink3 : IunaPalette.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.label, required this.onClose});
  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return IunaTopBar(
      leading: IunaIconButton(icon: Icons.close_rounded, onTap: onClose),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: IunaPalette.ink2,
          height: 1,
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.card});
  final CardRow card;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth * 0.78, 280.0);
        final height = width * 4 / 3;
        return SizedBox(
          width: width,
          height: height,
          child: VocabCard(
            rarity: card.rarity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RarityChip(rarity: card.rarity),
                    if (rarityStars(card.rarity) >= 4)
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: Color(0xFFE8B96B),
                      ),
                  ],
                ),
                Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.kanji,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: IunaPalette.ink,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      card.kana,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: IunaPalette.ink3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      card.meaning,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: IunaPalette.ink2,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < rarityStars(card.rarity); i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          '★',
                          style: TextStyle(
                            fontSize: 16,
                            color: rarityInk(card.rarity),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
