import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/booster_pack.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/notice.dart';
import '../widgets/tappable.dart';
import 'booster_reveal_screen.dart';
import 'review_screen.dart';
import 'today_flow.dart';

/// Splash before the booster reveal: floating Kuma-stamped pack with
/// "N new cards await" copy. Tap the pack to play a flash + scale
/// animation, then route to the reveal.
class PackIntroScreen extends StatefulWidget {
  const PackIntroScreen({super.key, required this.db, this.kumaSeed});

  final AppDatabase db;

  /// Pins the Kuma variant for goldens; null randomizes it per mount.
  final int? kumaSeed;

  @override
  State<PackIntroScreen> createState() => _PackIntroScreenState();
}

class _PackIntroScreenState extends State<PackIntroScreen>
    with TickerProviderStateMixin {
  late final IunaRepository _repo = IunaRepository(widget.db);

  /// 4s gentle float idle.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  /// One-shot tear: scale up + rotate + flash.
  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  /// Null until the preview has loaded, so the first frames don't
  /// claim the pack is already open.
  int? _newCount;
  bool _failed = false;
  int get _packs => ((_newCount ?? 0) / kDefaultPackSize).ceil();

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      // Preview only: the booster screen does the claiming.
      final preview = await _repo.boosterPreview();
      if (!mounted) return;
      setState(() {
        _newCount = preview.newCards;
        _failed = false;
      });
    } catch (e, s) {
      logLoadError('Pack intro', e, s);
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _tear.dispose();
    super.dispose();
  }

  /// True once the user has tapped the pack and the tear animation has
  /// played out. While `_handedOff`, the pack widget is hidden so this
  /// route reads as a blank slate when the booster reveal pops back to
  /// it — otherwise the post-tear pack pose flashes into view between
  /// the reveal and the review and reads as a stray second opening.
  bool _handedOff = false;

  Future<void> _open() async {
    if (_newCount == null) return;
    if (_tear.isAnimating || _tear.isCompleted) return;
    HapticFeedback.mediumImpact();
    await _tear.forward();
    if (!mounted) return;
    setState(() => _handedOff = true);
    final picked = await Navigator.of(context).push<List<int>>(
      todayRoute((_) => BoosterRevealScreen(db: widget.db)),
    );
    if (!mounted) return;
    if (picked != null) {
      await Navigator.of(context).pushReplacement(
        todayRoute((_) => ReviewScreen(db: widget.db)),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 41, calmTop: 1)),
            // Once the user has tapped the pack and BoosterRevealScreen
            // has been pushed, drop this route's foreground content to
            // zero opacity. Otherwise the post-tear pose flashes during
            // the pop transition between the reveal and ReviewScreen.
            Opacity(
              opacity: _handedOff ? 0 : 1,
              child: SafeArea(
                child: Column(
                  children: [
                    _TopBar(onClose: () => Navigator.of(context).pop()),
                    if (_failed)
                      Expanded(
                        child: LoadErrorNotice(
                          onRetry: () {
                            setState(() => _failed = false);
                            _loadCount();
                          },
                        ),
                      )
                    else if (_newCount == null)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Expanded(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_idle, _tear]),
                          builder: (_, _) {
                            final idleY = math.sin(_idle.value * math.pi * 2) * 8;
                            final tearT = Curves.easeOutCubic.transform(
                              _tear.value,
                            );
                            final scale = 1 + tearT * 0.18;
                            final rot = -tearT * (4 * math.pi / 180);
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _packs > 1
                                      ? "TODAY'S PACKS"
                                      : "TODAY'S PACK",
                                  style: IunaText.caption.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: IunaPalette.ink3,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  switch (_newCount ?? 0) {
                                    0 => 'Pack already opened',
                                    1 => '1 new card awaits',
                                    _ => '$_newCount new cards await',
                                  },
                                  textAlign: TextAlign.center,
                                  style: IunaText.headline.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: IunaPalette.ink,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Tappable(
                                  onTap: _open,
                                  label: 'Open the pack',
                                  child: Transform.translate(
                                    offset: Offset(0, idleY),
                                    child: Transform.scale(
                                      scale: scale,
                                      child: Transform.rotate(
                                        angle: rot,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            BoosterPack(
                                              width: 200,
                                              height: 280,
                                              label: '日本語',
                                              jpFooter: 'パック',
                                              kumaSize: 140,
                                              variantSeed: widget.kumaSeed,
                                            ),
                                            if (_tear.isAnimating ||
                                                _tear.isCompleted)
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: Opacity(
                                                    opacity:
                                                        (1 -
                                                                (_tear.value -
                                                                            0.3)
                                                                        .abs() *
                                                                    3)
                                                            .clamp(0.0, 1.0) *
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
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'tap the pack to untie it',
                                  style: IunaText.bodySmall.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: IunaPalette.ink3,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
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
