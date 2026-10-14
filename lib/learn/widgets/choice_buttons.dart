import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../agent/quiz.dart';

/// The options of a question the tutor asked in chat, plus the "I don't
/// know" every question offers. A tap answers with the option's text.
class ChoiceButtons extends StatelessWidget {
  const ChoiceButtons({super.key, required this.options, this.reply, this.onChoose});

  final List<String> options;

  /// The learner's reply, once given: the option it matches stays marked.
  final String? reply;

  /// Null while the question can't be answered: already answered, or
  /// Kuma-sensei is still talking.
  final ValueChanged<String>? onChoose;

  @override
  Widget build(BuildContext context) {
    final chosen = reply?.trim();
    final choose = onChoose;
    Widget choice(String label, {bool quiet = false}) => _Choice(
          label: label,
          quiet: quiet,
          chosen: label == chosen,
          faded: chosen != null && label != chosen,
          onTap: choose == null ? null : () => choose(label),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in options)
          Padding(padding: const EdgeInsets.only(top: 8), child: choice(o)),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: choice(kDefaultSkipLabel, quiet: true),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.chosen,
    required this.faded,
    this.quiet = false,
    this.onTap,
  });

  final String label;
  final bool chosen;
  final bool faded;

  /// The opt-out: always there, never competing with the options.
  final bool quiet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(IunaRadii.sm),
      side: chosen
          ? const BorderSide(color: IunaPalette.bellGold, width: 1.2)
          : quiet
              ? BorderSide.none
              : const BorderSide(color: Color.fromRGBO(74, 53, 32, 0.12)),
    );
    return Material(
      color: chosen
          ? const Color(0xFFFDE9C9)
          : quiet
              ? Colors.transparent
              : IunaPalette.paper2,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: quiet ? 8 : 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: quiet ? 13 : 14,
                    height: 1.35,
                    fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                    color: faded || (quiet && !chosen) ? IunaPalette.ink3 : IunaPalette.ink,
                  ),
                ),
              ),
              if (chosen) const Icon(Icons.check_rounded, size: 18, color: IunaPalette.ctaBottom),
            ],
          ),
        ),
      ),
    );
  }
}
