import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// One numbered sense: gloss, then part of speech, then prose.
class SenseRow extends StatelessWidget {
  const SenseRow({
    super.key,
    required this.ordinal,
    required this.gloss,
    this.pos = '',
    this.definition = '',
    this.showDivider = false,
    this.gap = 8,
  });

  final int ordinal;
  final String gloss;
  final String pos;
  final String definition;
  final bool showDivider;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(
                  color: IunaPalette.ink.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$ordinal.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: IunaPalette.ink3,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gloss,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: IunaPalette.ink,
                    height: 1.4,
                  ),
                ),
                if (pos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      pos,
                      style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: IunaPalette.inkMute,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                if (definition.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      definition,
                      style: const TextStyle(
                        fontSize: 13,
                        color: IunaPalette.ink2,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
