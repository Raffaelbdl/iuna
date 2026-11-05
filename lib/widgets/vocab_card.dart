import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';

/// Vocab card frame from the redesign — rounded 22px, rarity-tinted
/// 160° gradient, soft physical-TCG shadow, optional holo shimmer for
/// SR / SSR / UR. Children draw the actual content (kanji/kana/gloss
/// or the senses-list back); this widget owns the chrome.
class VocabCard extends StatefulWidget {
  const VocabCard({
    super.key,
    required this.rarity,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.holo = true,
    this.elevation = 1.0,
  });

  final Rarity rarity;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Whether to overlay a holo shimmer for SR+ rarities. Disabling lets
  /// callers (Done screen previews, etc.) opt out without re-styling.
  final bool holo;

  /// Multiplier for the drop shadow strength.
  final double elevation;

  @override
  State<VocabCard> createState() => _VocabCardState();
}

class _VocabCardState extends State<VocabCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  bool get _shouldShimmer => widget.holo && rarityStars(widget.rarity) >= 3;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    if (_shouldShimmer) _shimmer.repeat();
  }

  @override
  void didUpdateWidget(covariant VocabCard old) {
    super.didUpdateWidget(old);
    if (_shouldShimmer && !_shimmer.isAnimating) {
      _shimmer.repeat();
    } else if (!_shouldShimmer && _shimmer.isAnimating) {
      _shimmer.stop();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = rarityFill(widget.rarity);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.3, -1),
          end: const Alignment(0.3, 1),
          colors: [IunaPalette.paper, tint],
        ),
        border: Border.all(
          color: const Color.fromRGBO(74, 53, 32, 0.08),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(IunaRadii.lg),
        boxShadow: [
          for (final s in cardShadow())
            BoxShadow(
              color: s.color.withValues(
                alpha: (s.color.a * widget.elevation).clamp(0.0, 1.0),
              ),
              blurRadius: s.blurRadius,
              offset: s.offset,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(IunaRadii.lg),
        child: Stack(
          children: [
            Padding(padding: widget.padding, child: widget.child),
            if (_shouldShimmer)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _HoloPainter(_shimmer)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated diagonal sheen — paints a tilted rainbow gradient over the
/// card and slides it across in a 4.5s loop, blended with screen so it
/// reads as "holo" rather than washing the card out.
class _HoloPainter extends CustomPainter {
  _HoloPainter(this.progress) : super(repaint: progress);
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x00000000),
    );

    // Diagonal sweep from top-right to bottom-left, advancing offset
    // across the diagonal so the band marches once per loop.
    final diag = size.width + size.height;
    final shift = -1.0 + progress.value * 2.0; // -1 .. 1
    final gradient = LinearGradient(
      begin: const Alignment(1.2, -1.2),
      end: const Alignment(-1.2, 1.2),
      stops: const [0.0, 0.45, 0.5, 0.55, 0.7, 1.0],
      colors: const [
        Color(0x00FFFFFF),
        Color(0xA6FFFFFF),
        Color(0x66FFC8FF),
        Color(0x66B4DCFF),
        Color(0x80FFFFFF),
        Color(0x00FFFFFF),
      ],
      transform: GradientTranslation(shift * diag),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = gradient.createShader(Offset.zero & size)
        ..blendMode = BlendMode.screen
        ..color = const Color(0x8CFFFFFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HoloPainter old) => old.progress != progress;
}

class GradientTranslation extends GradientTransform {
  const GradientTranslation(this.dx);
  final double dx;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()..translateByDouble(dx, 0.0, 0.0, 1.0);
  }
}

/// Per-size metrics for [RarityChip].
enum RarityChipSize {
  regular(padH: 10, padV: 5, letterSpacing: 0.6, gap: 5),
  compact(padH: 8, padV: 4, letterSpacing: 0.6, gap: 4),
  header(padH: 10, padV: 5, letterSpacing: null, gap: 4),
  tiny(padH: 6, padV: 3, letterSpacing: 0.4, gap: 3);

  const RarityChipSize({
    required this.padH,
    required this.padV,
    required this.letterSpacing,
    required this.gap,
  });

  final double padH;
  final double padV;
  final double? letterSpacing;
  final double gap;
}

/// Gacha-style rarity badge in the redesign style: small letter +
/// star-count, rarity-tinted fill, rarity-ink text.
class RarityChip extends StatelessWidget {
  const RarityChip({
    super.key,
    required this.rarity,
    this.size = RarityChipSize.regular,
    this.named = false,
    this.stars = true,
  });
  final Rarity rarity;
  final RarityChipSize size;

  /// Off where the card already shows its stars large, as on the reveal.
  final bool stars;

  /// Spells the tier out after the stars ("Super Rare").
  final bool named;

  @override
  Widget build(BuildContext context) {
    final ink = rarityInk(rarity);
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: size.padH, vertical: size.padV),
      decoration: BoxDecoration(
        color: rarityFill(rarity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color.fromRGBO(74, 53, 32, 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rarityCode(rarity),
            style: IunaText.chip.copyWith(
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: size.letterSpacing,
            ),
          ),
          if (stars) ...[
            SizedBox(width: size.gap),
            Text(
              '★' * rarityStars(rarity),
              style: TextStyle(fontSize: 10, color: ink),
            ),
          ],
          if (named) ...[
            SizedBox(width: size.gap + 2),
            Text(
              rarityName(rarity),
              style: IunaText.chip.copyWith(color: ink),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      label: '${rarityName(rarity)} card',
      excludeSemantics: true,
      child: chip,
    );
  }
}

/// A small tag beside a headword, such as its JLPT level.
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    // The same pill as [CardStatusChip], which often sits beside it.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: IunaPalette.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: IunaPalette.hairline, width: 0.5),
      ),
      child: Text(
        label,
        style: IunaText.chip.copyWith(color: IunaPalette.ink2),
      ),
    );
  }
}

// One wording for where a card stands, wherever it is shown.
const kNotCollectedLabel = 'Not in your collection yet';
const kWishlistedLabel = 'On your wishlist';
const kOwnedLabel = 'In your collection';

/// Where a headword stands in the learner's deck: the one chip for it,
/// on card detail, Add card and the tutor's word sheet.
class CardStatusChip extends StatelessWidget {
  const CardStatusChip({super.key, required this.status});
  final CardLookupStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      CardLookupStatus.notFound ||
      CardLookupStatus.available => (
        kNotCollectedLabel,
        Icons.lock_outline_rounded,
      ),
      CardLookupStatus.wishlisted => (kWishlistedLabel, Icons.bookmark_rounded),
      CardLookupStatus.owned => (kOwnedLabel, Icons.check_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: IunaPalette.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: IunaPalette.hairline, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: IunaPalette.ink2),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: IunaText.chip.copyWith(color: IunaPalette.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
