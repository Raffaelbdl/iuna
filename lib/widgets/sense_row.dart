import 'package:flutter/material.dart';

import '../core/jmdict_labels.dart';
import '../db/jmdict_lookup.dart';
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
              style: IunaText.bodySmall.copyWith(
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
                  style: IunaText.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: IunaPalette.ink,
                    height: 1.4,
                  ),
                ),
                if (pos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      posLabel(pos),
                      style: IunaText.caption.copyWith(
                        fontStyle: FontStyle.italic,
                        color: IunaPalette.ink3,
                      ),
                    ),
                  ),
                if (definition.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      definition,
                      style: IunaText.bodySmall.copyWith(
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

/// A dictionary entry's senses, numbered, as a preview sheet lists them.
class JmdictSenseList extends StatelessWidget {
  const JmdictSenseList(this.senses, {super.key});

  final List<JmdictSense> senses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < senses.length; i++)
          SenseRow(
            ordinal: i + 1,
            gloss: senses[i].gloss,
            pos: senses[i].pos,
            definition: senses[i].def,
            showDivider: i > 0,
          ),
      ],
    );
  }
}
