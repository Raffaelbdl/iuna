import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// How an [OptionTile] shows that it is picked, beyond its fill.
enum OptionMark {
  /// None: a tap acts at once (a chat answer, a settings choice).
  none,

  /// A radio dot: one of several, chosen before submitting.
  radio,

  /// A check box: any number, or an opt-out like "I don't know".
  checkbox,
}

/// One answer row: the chat's question options, the quiz card's options
/// and opt-out, and the choice dialogs in Settings.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.mark = OptionMark.none,
    this.quiet = false,
    this.faded = false,
    this.tag,
    this.subtitle,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final OptionMark mark;

  /// The opt-out: unboxed, so it never competes with the options.
  final bool quiet;

  /// The options left over once another was picked.
  final bool faded;

  /// A short note on the right, e.g. "Your answer".
  final String? tag;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(IunaRadii.md),
      side: selected
          ? const BorderSide(color: IunaPalette.ctaBottom, width: 1.5)
          : quiet
          ? BorderSide.none
          : const BorderSide(color: Color.fromRGBO(74, 53, 32, 0.12)),
    );
    final ink = faded || (quiet && !selected)
        ? IunaPalette.ink3
        : IunaPalette.ink;
    final tag = this.tag;
    final subtitle = this.subtitle;
    return MergeSemantics(
      child: Semantics(
        button: mark == OptionMark.none,
        selected: mark == OptionMark.none ? selected : null,
        checked: mark == OptionMark.none ? null : selected,
        inMutuallyExclusiveGroup: mark == OptionMark.radio,
        enabled: onTap != null,
        child: Material(
          color: selected
              ? IunaPalette.optionPicked
              : quiet
              ? Colors.transparent
              : IunaPalette.paper2,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (mark != OptionMark.none) ...[
                      _Mark(mark: mark, on: selected, dim: onTap == null),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: IunaText.body.copyWith(
                              height: 1.35,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: ink,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: IunaText.caption.copyWith(
                                height: 1.35,
                                color: IunaPalette.ink3,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        tag,
                        style: IunaText.chip.copyWith(
                          color: IunaPalette.ink3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.mark, required this.on, required this.dim});

  final OptionMark mark;
  final bool on;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final color = on
        ? IunaPalette.ctaBottom
        : dim
        ? IunaPalette.inkMute
        : IunaPalette.ink3;
    final radio = mark == OptionMark.radio;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: on && !radio ? IunaPalette.ctaBottom : null,
        shape: radio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radio ? null : BorderRadius.circular(5),
        border: Border.all(color: color, width: 1.6),
      ),
      alignment: Alignment.center,
      child: !on
          ? null
          : radio
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: IunaPalette.ctaBottom,
                shape: BoxShape.circle,
              ),
            )
          : const Icon(Icons.check_rounded, size: 15, color: IunaPalette.paper),
    );
  }
}
